package dev.kumoriya.exoplayer

import android.content.Context
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.LoudnessEnhancer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import dev.kumoriya.exoplayer.http.KumoriyaHttpClient
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.text.TextOutput
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.source.SingleSampleMediaSource
import dev.kumoriya.exoplayer.nexus.NexusDataSourceFactory
import dev.kumoriya.exoplayer.nexus.NexusPlaybackSession
import dev.kumoriya.exoplayer.nexus.ResolvedSubtitle
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry

/**
 * One ExoPlayer instance + one Flutter SurfaceTexture.
 *
 * Owns the main-thread lifecycle of the underlying `ExoPlayer`, pushes
 * playback state to Flutter through [EventChannel] and exposes the
 * imperative API (open / play / pause / seek / setVolume / setSpeed /
 * dispose) consumed by the plugin.
 */
class PlayerInstance(
    private val context: Context,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry,
    binaryMessenger: io.flutter.plugin.common.BinaryMessenger,
) : Player.Listener {

    val textureId: Long = textureEntry.id()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val surface: Surface = Surface(textureEntry.surfaceTexture())

    // Shared OkHttp-backed factory for all non-Nexus HTTP requests.
    // Cross-protocol redirects (http↔https) are handled by the underlying
    // OkHttpClient's `followSslRedirects(true)`. Every call to [open] (or
    // [attachNexusSession]) rebuilds the User-Agent and defaultRequestProperties
    // so no state leaks across streams.
    private val dataSourceFactory: OkHttpDataSource.Factory =
        KumoriyaHttpClient.asMedia3Factory()

    // We intentionally do NOT install a custom `MediaSourceFactory` on
    // the player. Every `open()` call builds the right
    // [HlsMediaSource] / [DashMediaSource] / [ProgressiveMediaSource]
    // explicitly from the resolver-declared mimeType. This mirrors what
    // Flutter's `video_player_android` plugin does and keeps us immune
    // to Media3's strict MIME-string dispatch in
    // `DefaultMediaSourceFactory` (which only recognises the legacy
    // `application/x-mpegURL` and silently downgrades unrecognised
    // aliases to Progressive with an `UnrecognizedInputFormatException`).
    //
    // Media3 1.9+ disabled the legacy SubtitleDecoder path by default,
    // causing a crash when loading `text/x-ssa` samples via
    // `SingleSampleMediaSource`. We re-enable it on the TextRenderer
    // using the experimental flag (the only knob Media3 exposes for
    // SSA/ASS support without rewriting to the new cue-only pipeline).
    private val player: ExoPlayer = ExoPlayer.Builder(context)
        .setRenderersFactory(
            object : DefaultRenderersFactory(context) {
                override fun buildTextRenderers(
                    context: Context,
                    output: TextOutput,
                    outputLooper: Looper,
                    extensionRendererMode: Int,
                    out: ArrayList<Renderer>,
                ) {
                    super.buildTextRenderers(
                        context,
                        output,
                        outputLooper,
                        extensionRendererMode,
                        out,
                    )
                    // The last renderer added is the TextRenderer we care about.
                    val textRenderer = out.lastOrNull()
                        as? androidx.media3.exoplayer.text.TextRenderer
                    textRenderer?.experimentalSetLegacyDecodingEnabled(true)
                }

            },
        )
        .build()
        .also { p ->
            p.setVideoSurface(surface)
            p.addListener(this)
            p.trackSelectionParameters = p.trackSelectionParameters
                .buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                .build()
        }

    private val eventChannel = EventChannel(
        binaryMessenger,
        "dev.kumoriya.exoplayer/events/$textureId",
    )
    private var eventSink: EventChannel.EventSink? = null

    private val positionRunnable: Runnable = object : Runnable {
        override fun run() {
            if (released) return
            val pos = player.currentPosition
            if (pos >= 0) {
                sendEvent(mapOf("event" to "position", "value" to pos))
            }
            mainHandler.postDelayed(this, POSITION_POLL_MS)
        }
    }

    @Volatile
    private var released = false

    /**
     * Current native anime.nexus session when playing via [openNexus], or
     * `null` when the active MediaItem comes from the default factory.
     */
    private var nexusSession: NexusPlaybackSession? = null

    /**
     * Last base [MediaSource] handed to the player — the raw stream
     * (Hls/Dash/Progressive or the anime.nexus source) **without** any
     * external subtitles merged in. Kept so we can rebuild a
     * [MergingMediaSource] on the fly when subtitles are attached/cleared
     * without re-opening upstream (which would restart the ABR warm-up).
     */
    private var currentBaseSource: MediaSource? = null

    /**
     * URL that drives [currentBaseSource]. Exposed to Dart through the
     * `urlExpired` event so the Dart side can re-resolve the same stream
     * on a 401/403/410 without losing the mapping back to the resolver
     * pipeline. `null` while playing through [attachNexusSession], where
     * the signed segment URLs are minted per-request by the data source
     * and do not have a stable "old URL" to refresh.
     */
    private var currentBaseUrl: String? = null

    /**
     * Factory used to fetch external subtitle files. Falls back to the
     * shared [dataSourceFactory] so the HTTP configuration (UA, cookies,
     * custom headers) matches the base stream — critical for sources
     * whose CDN rejects anonymous subtitle requests.
     */
    // Wrap the HTTP factory in DefaultDataSource so subtitle attachments
    // can use file://, data:, content:// and asset: URIs in addition to
    // plain HTTPS. Needed for the anime.nexus bootstrap, which inlines
    // subtitle VTT bytes as `data:text/vtt;base64,…` to sidestep the CDN
    // auth requirement (see [attachNexusSession]).
    private val subtitleDataSourceFactory: DataSource.Factory
        get() = DefaultDataSource.Factory(context, dataSourceFactory)

    /**
     * External subtitles currently merged on top of [currentBaseSource].
     * Preserved across play/pause/seek; cleared by [open], re-applied on
     * every base-source swap.
     */
    private val externalSubtitles: MutableList<ExternalSubtitleSpec> =
        mutableListOf()

    /**
     * Global audio-gain boost (AudioFX `LoudnessEnhancer`). Lazily
     * created once [player.audioSessionId] is known, torn down when the
     * gain is reset to 0 dB or when the player is released.
     */
    private var loudnessEnhancer: LoudnessEnhancer? = null

    /**
     * Voice-clarity EQ (`DynamicsProcessing`, API 28+). Attached to the
     * same audio session as [loudnessEnhancer]. `null` when strength is
     * 0 or when running on API < 28 (then the feature is a no-op).
     */
    private var dynamicsProcessing: DynamicsProcessing? = null

    /** Latest gain requested by Dart, applied when a session becomes available. */
    private var pendingGainDb: Double = 0.0

    /** Latest voice-clarity strength requested by Dart, 0..1 clamped. */
    private var pendingVoiceClarity: Double = 0.0

    /**
     * Analytics collector attached to the player while diagnostics are
     * enabled. `null` means the collector is detached; toggling on
     * re-creates it because stats are reset-on-enable to avoid stale
     * numbers from a previous session bleeding into the overlay.
     */
    private var diagnosticsCollector: DiagnosticsCollector? = null

    /**
     * Runnable that polls [diagnosticsCollector] and emits a
     * `diagnostics` event. Posted at [DIAGNOSTICS_POLL_MS] cadence while
     * diagnostics are enabled; removed on disable and on release.
     */
    private val diagnosticsRunnable: Runnable = object : Runnable {
        override fun run() {
            if (released) return
            if (diagnosticsCollector == null) return
            emitDiagnosticsSnapshot()
            mainHandler.postDelayed(this, DIAGNOSTICS_POLL_MS)
        }
    }

    init {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
                // Emit current snapshot so late listeners catch up.
                emitPlaybackStateSnapshot()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    // --- Imperative API -------------------------------------------------

    fun open(
        url: String,
        headers: Map<String, String>,
        startPositionMs: Long?,
        mimeType: String? = null,
    ) {
        requireNotReleased()
        releaseNexusSession()
        emitLog(
            "[open] url=$url mimeType=${mimeType ?: "(auto)"} " +
                "headerKeys=${headers.keys.toList()} " +
                "startPositionMs=${startPositionMs ?: 0}",
        )
        // Mirror `video_player_android` exactly:
        //   1. If the caller's headers carry a User-Agent, promote it to the
        //      factory's `userAgent` field (because Media3 overrides any UA
        //      from defaultRequestProperties with the field value).
        //   2. Put every other header into defaultRequestProperties.
        //   3. Always reset both on each open so stale state from a previous
        //      stream cannot bleed across unrelated requests.
        dataSourceFactory.setUserAgent(KumoriyaHttpClient.extractUserAgent(headers))
        dataSourceFactory.setDefaultRequestProperties(
            KumoriyaHttpClient.headersWithoutUserAgent(headers),
        )
        val resolvedMime = normaliseMimeType(mimeType)
        val itemBuilder = MediaItem.Builder().setUri(Uri.parse(url))
        if (resolvedMime != null) {
            itemBuilder.setMimeType(resolvedMime)
        }
        val mediaItem = itemBuilder.build()
        // Explicit factory dispatch — see note on the missing
        // [setMediaSourceFactory] call up top for why we pick the factory
        // here instead of trusting `DefaultMediaSourceFactory`.
        val source = buildMediaSource(mediaItem, resolvedMime)
        emitLog("[open] mediaSource=${source.javaClass.simpleName}")
        // Fresh stream — drop any previously-attached external subtitles
        // so they do not bleed across unrelated media. Callers can
        // re-attach with [addExternalSubtitle] after the open resolves.
        externalSubtitles.clear()
        currentBaseUrl = url
        installBaseSource(source, startPositionMs)
    }

    /**
     * Run the anime.nexus bootstrap + WS handshake off the main thread.
     * The returned [NexusPlaybackSession] is ready for ExoPlayer — call
     * [attachNexusSession] from the main thread to swap it in.
     *
     * Split in two phases on purpose: bootstrap does synchronous HTTP +
     * `runBlocking` on the WS connect (needs an IO thread), while
     * [attachNexusSession] calls `player.setMediaSource` which ExoPlayer
     * requires to run on the thread that built the player (main).
     */
    internal fun bootstrapNexusSession(watchUrl: String): NexusPlaybackSession {
        requireNotReleased()
        return NexusPlaybackSession.open(watchUrl) { line ->
            // Forward native logs to the Flutter event channel so Dart
            // debugging surfaces them alongside playback state.
            sendEvent(mapOf("event" to "log", "value" to line))
        }
    }

    /**
     * Take ownership of [session] and feed it into ExoPlayer via an
     * [HlsMediaSource] backed by [NexusDataSourceFactory]. Must run on the
     * main thread.
     */
    internal fun attachNexusSession(
        session: NexusPlaybackSession,
        startPositionMs: Long?,
    ) {
        requireNotReleased()
        releaseNexusSession()
        nexusSession = session
        val factory = NexusDataSourceFactory(session)
        val source = HlsMediaSource.Factory(factory)
            .createMediaSource(MediaItem.fromUri(Uri.parse(session.hlsUrl)))
        externalSubtitles.clear()
        // Seed the external subtitles the anime.nexus stream API
        // advertised (WebVTT/SRT) BEFORE [installBaseSource] runs so
        // [buildSourceWithSubtitles] picks them up on the first prepare.
        // The HLS master on anime.nexus does not declare EXT-X-MEDIA
        // TYPE=SUBTITLES groups — subtitles live on a separate CDN
        // endpoint returned alongside the HLS URL, so they have to be
        // merged as external tracks or they never surface in the UI.
        //
        // Bytes were already fetched during the bootstrap (with the
        // auth set the CDN requires). We wrap them as `data:…;base64,…`
        // URIs so [subtitleDataSourceFactory] can feed them to Media3
        // without going back out to the network.
        for (sub in session.subtitles) {
            val mime = normaliseSubtitleMimeType(sub.mimeType) ?: run {
                emitLog(
                    "[anime-nexus] skip subtitle label=${sub.label} — " +
                        "unsupported mime=${sub.mimeType}",
                )
                continue
            }
            val base64 = android.util.Base64.encodeToString(
                sub.content,
                android.util.Base64.NO_WRAP,
            )
            val dataUri = "data:$mime;base64,$base64"
            externalSubtitles.add(
                ExternalSubtitleSpec(
                    uri = dataUri,
                    mimeType = mime,
                    language = sub.language,
                    label = sub.label,
                ),
            )
        }
        if (externalSubtitles.isNotEmpty()) {
            emitLog(
                "[anime-nexus] seeded ${externalSubtitles.size} external " +
                    "subtitle tracks as data URIs",
            )
        }
        currentBaseUrl = null
        installBaseSource(source, startPositionMs)
    }

    fun play() {
        requireNotReleased()
        player.playWhenReady = true
    }

    fun pause() {
        requireNotReleased()
        player.playWhenReady = false
    }

    fun seekTo(positionMs: Long) {
        requireNotReleased()
        player.seekTo(positionMs)
    }

    fun setVolume(value: Float) {
        requireNotReleased()
        player.volume = value.coerceIn(0f, 1f)
    }

    fun setSpeed(rate: Float) {
        requireNotReleased()
        player.setPlaybackSpeed(rate.coerceAtLeast(0.25f))
    }

    /**
     * Select the audio track identified by [trackId] — the string id
     * produced by [emitAudioTracksEvent] (format `"groupIndex:trackIndex"`).
     *
     * Uses Media3's `TrackSelectionParameters.setOverrideForType` so the
     * switch stays in effect across the currently loaded media item and
     * does not reopen the stream (position is preserved automatically).
     */
    fun selectAudioTrack(trackId: String) {
        requireNotReleased()
        val (groupIdx, trackIdx) = parseTrackId(trackId) ?: run {
            emitLog("[audio-track] ignored invalid trackId='$trackId'")
            return
        }
        val groups = player.currentTracks.groups
        val group = groups.getOrNull(groupIdx)
        if (group == null || group.type != C.TRACK_TYPE_AUDIO) {
            emitLog(
                "[audio-track] ignored out-of-range trackId='$trackId' " +
                    "groups=${groups.size}",
            )
            return
        }
        if (trackIdx !in 0 until group.length) {
            emitLog(
                "[audio-track] ignored invalid trackIndex=$trackIdx " +
                    "group.length=${group.length}",
            )
            return
        }
        val override = TrackSelectionOverride(
            group.mediaTrackGroup,
            listOf(trackIdx),
        )
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setOverrideForType(override)
            .build()
        emitLog(
            "[audio-track] applied trackId='$trackId' " +
                "label='${group.getTrackFormat(trackIdx).label ?: ""}'",
        )
    }

    /**
     * Select the text track identified by [trackId] — same encoding as
     * [selectAudioTrack]. Covers both embedded (`#EXT-X-MEDIA:TYPE=SUBTITLES`,
     * MKV/MP4 internal) and merged external tracks, since both surface
     * under the same `TRACK_TYPE_TEXT` groups once [MergingMediaSource]
     * has been applied.
     */
    fun selectSubtitleTrack(trackId: String) {
        requireNotReleased()
        val (groupIdx, trackIdx) = parseTrackId(trackId) ?: run {
            emitLog("[subtitle-track] ignored invalid trackId='$trackId'")
            return
        }
        val groups = player.currentTracks.groups
        val group = groups.getOrNull(groupIdx)
        if (group == null || group.type != C.TRACK_TYPE_TEXT) {
            emitLog(
                "[subtitle-track] ignored out-of-range trackId='$trackId' " +
                    "groups=${groups.size}",
            )
            return
        }
        if (trackIdx !in 0 until group.length) {
            emitLog(
                "[subtitle-track] ignored invalid trackIndex=$trackIdx " +
                    "group.length=${group.length}",
            )
            return
        }
        val override = TrackSelectionOverride(
            group.mediaTrackGroup,
            listOf(trackIdx),
        )
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setOverrideForType(override)
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
            .build()
        emitLog(
            "[subtitle-track] applied trackId='$trackId' " +
                "label='${group.getTrackFormat(trackIdx).label ?: ""}'",
        )
    }

    /**
     * Set the preferred subtitle languages for auto-selection.
     * Requires Media3 1.1+.
     */
    fun setPreferredSubtitleLanguages(languages: List<String>) {
        requireNotReleased()
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setPreferredTextLanguages(*languages.toTypedArray())
            .build()
        emitLog("[subtitle-track] preferredLanguages=${languages.joinToString(",")}")
    }

    /**
     * Select the video track identified by [trackId] — same encoding as
     * [selectAudioTrack]. Forces ABR off for the video type and pins the
     * player to the requested variant. Used by the Dart quality picker
     * on HLS streams where the variants are the actual quality ladder.
     */
    fun selectVideoTrack(trackId: String) {
        requireNotReleased()
        val (groupIdx, trackIdx) = parseTrackId(trackId) ?: run {
            emitLog("[video-track] ignored invalid trackId='$trackId'")
            return
        }
        val groups = player.currentTracks.groups
        val group = groups.getOrNull(groupIdx)
        if (group == null || group.type != C.TRACK_TYPE_VIDEO) {
            emitLog(
                "[video-track] ignored out-of-range trackId='$trackId' " +
                    "groups=${groups.size}",
            )
            return
        }
        if (trackIdx !in 0 until group.length) {
            emitLog(
                "[video-track] ignored invalid trackIndex=$trackIdx " +
                    "group.length=${group.length}",
            )
            return
        }
        val override = TrackSelectionOverride(
            group.mediaTrackGroup,
            listOf(trackIdx),
        )
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setOverrideForType(override)
            .build()
        val format = group.getTrackFormat(trackIdx)
        emitLog(
            "[video-track] applied trackId='$trackId' " +
                "res=${format.width}x${format.height} bitrate=${format.bitrate}",
        )
    }

    /**
     * Drop any video-track override — hands quality selection back to
     * Media3's ABR heuristics. Pair with a Dart "Auto" picker entry.
     */
    fun clearVideoTrackOverride() {
        requireNotReleased()
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .build()
        emitLog("[video-track] cleared — ABR re-enabled")
    }

    /**
     * Disable text-track rendering — drops any selection override and
     * marks the text type as disabled so Media3 stops surfacing cues.
     * Safe to call even when no subtitle was selected.
     */
    fun clearSubtitleTrack() {
        requireNotReleased()
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .clearOverridesOfType(C.TRACK_TYPE_TEXT)
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            .build()
        emitLog("[subtitle-track] cleared")
    }

    /**
     * Merge an external subtitle file on top of the currently playing
     * stream. [mimeType] must be one of Media3's recognised subtitle MIME
     * types (`text/vtt`, `application/x-subrip`, `text/x-ssa`). The track
     * appears in the next `subtitleTracks` event and can be selected
     * through [selectSubtitleTrack].
     *
     * Playback position is preserved — we rebuild a [MergingMediaSource]
     * and re-hand it to the player with `resetPosition=false`.
     *
     * Multiple subtitles with the same [language] overwrite each other;
     * callers that want side-by-side tracks should use distinct
     * [language]/[label] pairs.
     */
    fun addExternalSubtitle(
        uri: String,
        mimeType: String,
        language: String?,
        label: String?,
    ) {
        requireNotReleased()
        val normalisedMime = normaliseSubtitleMimeType(mimeType) ?: run {
            emitLog(
                "[external-subtitle] ignored unsupported mimeType='$mimeType' " +
                    "uri=$uri",
            )
            return
        }
        // De-dupe on (uri, language) so repeated calls from Dart (e.g. on
        // rebuild) don't keep stacking identical sources into the merge.
        externalSubtitles.removeAll {
            it.uri == uri && it.language == language
        }
        externalSubtitles.add(
            ExternalSubtitleSpec(
                uri = uri,
                mimeType = normalisedMime,
                language = language,
                label = label,
            ),
        )
        emitLog(
            "[external-subtitle] added uri=$uri mime=$normalisedMime " +
                "language=${language ?: "(none)"} label=${label ?: "(none)"} " +
                "total=${externalSubtitles.size}",
        )
        rebuildWithExternalSubtitles()
    }

    /**
     * Drop every merged external subtitle and revert to the bare base
     * source. Embedded subtitles (inside the container) are unaffected.
     */
    fun clearExternalSubtitles() {
        requireNotReleased()
        if (externalSubtitles.isEmpty()) return
        externalSubtitles.clear()
        emitLog("[external-subtitle] cleared")
        rebuildWithExternalSubtitles()
    }

    /**
     * Replace the currently playing base stream with [url], preserving
     * playback position. Intended as the counterpart to the
     * `urlExpired` event — once Dart has re-resolved a fresh signed URL
     * (or picked a mirror), this brings the player back online without
     * the user re-entering the playback flow.
     *
     * When [startPositionMs] is `null` the play-head is restored from
     * [Player.getCurrentPosition] before the swap. Headers and mimeType
     * follow the same semantics as [open].
     */
    fun swapUrl(
        url: String,
        headers: Map<String, String>,
        mimeType: String?,
        startPositionMs: Long?,
    ) {
        requireNotReleased()
        releaseNexusSession()
        emitLog(
            "[swap-url] url=$url mimeType=${mimeType ?: "(auto)"} " +
                "headerKeys=${headers.keys.toList()}",
        )
        dataSourceFactory.setUserAgent(KumoriyaHttpClient.extractUserAgent(headers))
        dataSourceFactory.setDefaultRequestProperties(
            KumoriyaHttpClient.headersWithoutUserAgent(headers),
        )

        val resolvedMime = normaliseMimeType(mimeType)
        val itemBuilder = MediaItem.Builder().setUri(Uri.parse(url))
        if (resolvedMime != null) itemBuilder.setMimeType(resolvedMime)
        val source = buildMediaSource(itemBuilder.build(), resolvedMime)

        currentBaseUrl = url
        val restoreMs = startPositionMs ?: player.currentPosition.coerceAtLeast(0L)
        // Preserve external subtitles across the swap — the user did not
        // ask for them to go away, only the base CDN failed.
        installBaseSource(source, restoreMs)
    }

    /**
     * Apply a global gain in decibels on top of the master volume.
     * Values ≤ 0 tear the underlying `LoudnessEnhancer` down; values > 0
     * enable it with `gain_mb = dB * 100`. AudioFX in AOSP is one-sided:
     * negative gains are not supported on `LoudnessEnhancer`, so we
     * clamp to 0 and advise callers to use the base `setVolume` for
     * attenuation.
     *
     * Safe to call before the player has an audio session id — the
     * request is cached in [pendingGainDb] and applied on the next
     * `STATE_READY` transition.
     */
    fun setOverallGainDb(db: Double) {
        requireNotReleased()
        pendingGainDb = db.coerceAtLeast(0.0)
        applyPendingAudioFx()
    }

    /**
     * Apply the voice-clarity preset at [strength] (0..1). `0` disables
     * the EQ entirely; `1` is the maximum boost we ship — roughly +4 dB
     * between 1 and 4 kHz paired with a –6 dB cut below 120 Hz. The
     * preset is intentionally conservative so dialog becomes clearer
     * without the stream sounding boxy on headphones.
     *
     * No-op on API < 28 (DynamicsProcessing only exists from Pie).
     */
    fun setVoiceClarity(strength: Double) {
        requireNotReleased()
        pendingVoiceClarity = strength.coerceIn(0.0, 1.0)
        applyPendingAudioFx()
    }

    /**
     * Toggle the diagnostics pipeline on/off. When enabled the player
     * attaches a [DiagnosticsCollector] and starts polling it every
     * [DIAGNOSTICS_POLL_MS], emitting a `diagnostics` event with codec,
     * decoder, dropped-frame counters, bandwidth, and buffer health.
     *
     * Off by default so we don't pay the per-frame analytics cost in
     * production UIs that don't show the overlay.
     */
    fun setDiagnosticsEnabled(enabled: Boolean) {
        requireNotReleased()
        if (enabled) {
            if (diagnosticsCollector != null) return
            val collector = DiagnosticsCollector()
            player.addAnalyticsListener(collector)
            diagnosticsCollector = collector
            // Emit the initial snapshot immediately so Dart consumers
            // have something to render while we wait for the first
            // bandwidth / decoder callbacks to land.
            emitDiagnosticsSnapshot()
            mainHandler.removeCallbacks(diagnosticsRunnable)
            mainHandler.postDelayed(diagnosticsRunnable, DIAGNOSTICS_POLL_MS)
            emitLog("[diagnostics] enabled")
        } else {
            val collector = diagnosticsCollector ?: return
            player.removeAnalyticsListener(collector)
            diagnosticsCollector = null
            mainHandler.removeCallbacks(diagnosticsRunnable)
            emitLog("[diagnostics] disabled")
        }
    }

    fun release() {
        if (released) return
        released = true
        mainHandler.removeCallbacks(positionRunnable)
        mainHandler.removeCallbacks(diagnosticsRunnable)
        diagnosticsCollector?.let(player::removeAnalyticsListener)
        diagnosticsCollector = null
        eventChannel.setStreamHandler(null)
        eventSink = null
        try {
            player.removeListener(this)
            player.release()
        } catch (_: Throwable) {
            // Best effort; nothing to do if ExoPlayer already tore itself down.
        }
        releaseNexusSession()
        currentBaseSource = null
        currentBaseUrl = null
        externalSubtitles.clear()
        releaseAudioFx()
        surface.release()
        textureEntry.release()
    }

    fun isReleased(): Boolean = released

    // --- Player.Listener -----------------------------------------------

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        sendEvent(mapOf("event" to "playing", "value" to isPlaying))
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        when (playbackState) {
            Player.STATE_BUFFERING -> sendEvent(
                mapOf("event" to "buffering", "value" to true),
            )
            Player.STATE_READY -> {
                sendEvent(mapOf("event" to "buffering", "value" to false))
                val duration = player.duration
                if (duration > 0) {
                    sendEvent(mapOf("event" to "duration", "value" to duration))
                }
                // Audio session is usually ready by STATE_READY — apply
                // any gain / voice-clarity the caller queued before the
                // player had one.
                applyPendingAudioFx()
            }
            Player.STATE_ENDED -> sendEvent(
                mapOf("event" to "completed", "value" to true),
            )
            Player.STATE_IDLE -> {
                // No-op: idle is the initial / post-release state.
            }
        }
    }

    override fun onTracksChanged(tracks: Tracks) {
        emitAudioTracksEvent(tracks)
        emitSubtitleTracksEvent(tracks)
        emitVideoTracksEvent(tracks)
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        if (videoSize.width <= 0 || videoSize.height <= 0) return
        // Pre-apply the pixel aspect ratio so Dart can treat
        // (width, height) as display-sized and compute
        // `width / height` directly for the `AspectRatio` widget.
        val correctedWidth = videoSize.width * videoSize.pixelWidthHeightRatio
        sendEvent(
            mapOf(
                "event" to "videoSize",
                "width" to correctedWidth.toDouble(),
                "height" to videoSize.height.toDouble(),
            ),
        )
        // Hint the compositor to match the stream's cadence so 23.976/24/25 fps
        // content does not judder on 60 Hz panels. Requires API 30+.
        applySurfaceFrameRate(player.videoFormat?.frameRate ?: 0f)
    }

    /**
     * Forward the active video frame rate to the Flutter [Surface] so Android's
     * display compositor can pick a matching refresh rate. This fixes the
     * periodic frame "stutter" visible on typical 60 Hz devices when playing
     * 23.976 / 24 / 25 fps sources.
     *
     * Uses the 3-arg overload on API 31+ to force refresh-rate switches
     * (`CHANGE_FRAMERATE_ALWAYS`); falls back to the 2-arg form on API 30; is a
     * no-op on older releases (no public API to request refresh-rate changes).
     */
    private var appliedSurfaceFrameRate: Float = 0f

    private fun applySurfaceFrameRate(frameRate: Float) {
        if (!surface.isValid) return
        val target = if (frameRate.isFinite() && frameRate > 0f) frameRate else 0f
        if (target == appliedSurfaceFrameRate) return
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    surface.setFrameRate(
                        target,
                        Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                        Surface.CHANGE_FRAME_RATE_ALWAYS,
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                    surface.setFrameRate(
                        target,
                        Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                    )
                }
            }
            appliedSurfaceFrameRate = target
        } catch (t: Throwable) {
            // Never let a frame-rate hint tear down playback — worst case we
            // keep the default cadence and log once for diagnostics.
            Log.w(LOG_TAG, "setFrameRate($target) failed: ${t.message}")
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        val causeChain = generateSequence<Throwable>(error.cause) { it.cause }
            .take(4)
            .joinToString(" -> ") {
                "${it.javaClass.simpleName}(${it.message ?: ""})"
            }
        emitLog(
            "[error] code=${error.errorCodeName} message=${error.message ?: ""} " +
                "causes=$causeChain",
        )

        val expiredCode = findExpiredResponseCode(error)
        val expiredUrl = currentBaseUrl
        if (expiredCode != null && expiredUrl != null) {
            // Emit the refresh hint **before** the generic error so Dart
            // subscribers that care about recovery get a chance to swap
            // in a fresh URL without first handling a terminal error.
            emitLog(
                "[url-expired] code=$expiredCode url=$expiredUrl — awaiting swapUrl",
            )
            sendEvent(
                mapOf(
                    "event" to "urlExpired",
                    "url" to expiredUrl,
                    "httpCode" to expiredCode,
                ),
            )
        }

        sendEvent(
            mapOf(
                "event" to "error",
                "code" to error.errorCodeName,
                "message" to (error.message ?: "unknown"),
            ),
        )
    }

    /**
     * Walk the [PlaybackException] cause chain looking for an HTTP-level
     * auth/expiry response code (401/403/410). Returns the code when found,
     * `null` otherwise — we only care about these because they're the
     * signature of a signed URL that the source server decided to rotate
     * or revoke while playback was ongoing.
     */
    private fun findExpiredResponseCode(error: PlaybackException): Int? {
        return generateSequence<Throwable>(error) { it.cause }
            .take(5)
            .filterIsInstance<HttpDataSource.InvalidResponseCodeException>()
            .map { it.responseCode }
            .firstOrNull { it == 401 || it == 403 || it == 410 }
    }

    override fun onCues(cueGroup: androidx.media3.common.text.CueGroup) {
        onCues(cueGroup.cues)
    }

    override fun onCues(cues: List<androidx.media3.common.text.Cue>) {
        val payload = cues.map { cue ->
            mapOf(
                "text" to cue.text?.toString(),
                "line" to cue.line,
                "lineType" to cue.lineType,
                "position" to cue.position,
            )
        }
        sendEvent(mapOf("event" to "subtitleCue", "value" to payload))
    }

    // --- Internals ------------------------------------------------------

    private fun startPositionPolling() {
        mainHandler.removeCallbacks(positionRunnable)
        mainHandler.postDelayed(positionRunnable, POSITION_POLL_MS)
    }

    private fun emitPlaybackStateSnapshot() {
        sendEvent(mapOf("event" to "playing", "value" to player.isPlaying))
        sendEvent(
            mapOf(
                "event" to "buffering",
                "value" to (player.playbackState == Player.STATE_BUFFERING),
            ),
        )
        if (player.duration > 0) {
            sendEvent(mapOf("event" to "duration", "value" to player.duration))
        }
        val currentSize = player.videoSize
        if (currentSize.width > 0 && currentSize.height > 0) {
            val correctedWidth =
                currentSize.width * currentSize.pixelWidthHeightRatio
            sendEvent(
                mapOf(
                    "event" to "videoSize",
                    "width" to correctedWidth.toDouble(),
                    "height" to currentSize.height.toDouble(),
                ),
            )
        }
        emitAudioTracksEvent(player.currentTracks)
        emitSubtitleTracksEvent(player.currentTracks)
        emitVideoTracksEvent(player.currentTracks)
    }

    /**
     * Walk [tracks] and emit the full audio-track inventory — every
     * track across every `TRACK_TYPE_AUDIO` group, each tagged with its
     * language, label, codec, channels, sample rate, and `selected`
     * flag. Id format is `"groupIndex:trackIndex"`, stable for the
     * lifetime of the [Tracks] snapshot and matched back in
     * [selectAudioTrack].
     *
     * Suppresses the emission when there are no audio tracks so Dart
     * can keep a cached empty list instead of an oscillation on early
     * STATE_READY frames before the ABR picker settles.
     */
    private fun emitAudioTracksEvent(tracks: Tracks) {
        val payload = mutableListOf<Map<String, Any?>>()
        // Muxed HLS audio (no `#EXT-X-MEDIA:TYPE=AUDIO` group) produces one
        // `TRACK_TYPE_AUDIO` TrackGroup per video variant, so anime.nexus
        // with 3 qualities yields three identical audio rows. Dedupe by
        // signature (language|label|codec|channels|sampleRate). We keep
        // the first group that carries a currently-selected track so the
        // UI's "active" marker matches what Media3 is actually playing.
        data class Sig(
            val language: String?,
            val label: String?,
            val codec: String?,
            val channels: Int,
            val sampleRate: Int,
        )
        val seen = mutableMapOf<Sig, Boolean>()
        tracks.groups.forEachIndexed { groupIdx, group ->
            if (group.type != C.TRACK_TYPE_AUDIO) return@forEachIndexed
            for (trackIdx in 0 until group.length) {
                val format = group.getTrackFormat(trackIdx)
                val sig = Sig(
                    language = format.language,
                    label = format.label,
                    codec = format.codecs,
                    channels = format.channelCount,
                    sampleRate = format.sampleRate,
                )
                val selected = group.isTrackSelected(trackIdx)
                val alreadySeen = seen.containsKey(sig)
                val prevHadSelection = seen[sig] == true
                // Skip exact duplicates unless the new one is the
                // actually-selected track and the previously kept copy was
                // not (swap-in to keep the active marker correct).
                if (alreadySeen && (prevHadSelection || !selected)) continue
                if (alreadySeen) {
                    // Remove the previously emitted stale copy so the swap
                    // preserves order-of-first-appearance for the rest.
                    payload.removeAll {
                        it["language"] == sig.language &&
                            it["label"] == sig.label &&
                            it["codec"] == sig.codec
                    }
                }
                seen[sig] = selected
                payload.add(
                    mapOf(
                        "id" to "$groupIdx:$trackIdx",
                        "label" to format.label,
                        "language" to format.language,
                        "codec" to format.codecs,
                        "channels" to
                            format.channelCount.takeIf { it > 0 },
                        "sampleRate" to
                            format.sampleRate.takeIf { it > 0 },
                        "bitrate" to format.bitrate.takeIf { it > 0 },
                        "selected" to selected,
                    ),
                )
            }
        }
        if (payload.isEmpty()) return
        sendEvent(mapOf("event" to "audioTracks", "value" to payload))
    }

    /**
     * Walk [tracks] and emit the full subtitle-track inventory —
     * every text-type group, each track tagged with its label, language
     * and `selected` flag. Unlike audio, we **always** emit (even when
     * the list is empty) so Dart consumers can drop previously cached
     * subtitles when a new stream exposes none.
     */
    private fun emitSubtitleTracksEvent(tracks: Tracks) {
        val payload = mutableListOf<Map<String, Any?>>()
        tracks.groups.forEachIndexed { groupIdx, group ->
            if (group.type != C.TRACK_TYPE_TEXT) return@forEachIndexed
            for (trackIdx in 0 until group.length) {
                val format = group.getTrackFormat(trackIdx)
                payload.add(
                    mapOf(
                        "id" to "$groupIdx:$trackIdx",
                        "label" to format.label,
                        "language" to format.language,
                        "codec" to format.codecs,
                        "mimeType" to format.sampleMimeType,
                        "selected" to group.isTrackSelected(trackIdx),
                    ),
                )
            }
        }
        sendEvent(mapOf("event" to "subtitleTracks", "value" to payload))
    }

    /**
     * Walk [tracks] and emit the full video-track inventory — every
     * `TRACK_TYPE_VIDEO` group, each track tagged with resolution,
     * bitrate, codec and `selected` flag. Used by the Dart quality
     * picker on HLS streams where the in-manifest variants (not
     * separate resolved URLs) are the actual quality ladder.
     *
     * Dedupes identical variants the same way [emitAudioTracksEvent]
     * does for muxed HLS — though in practice HLS master manifests
     * rarely duplicate video renditions.
     *
     * Emits unconditionally (including empty list) so the Dart side
     * can clear a stale cache when a stream swap drops to a single
     * video track.
     */
    private fun emitVideoTracksEvent(tracks: Tracks) {
        val payload = mutableListOf<Map<String, Any?>>()
        data class Sig(
            val width: Int,
            val height: Int,
            val bitrate: Int,
            val codec: String?,
        )
        val seen = mutableMapOf<Sig, Boolean>()
        tracks.groups.forEachIndexed { groupIdx, group ->
            if (group.type != C.TRACK_TYPE_VIDEO) return@forEachIndexed
            for (trackIdx in 0 until group.length) {
                val format = group.getTrackFormat(trackIdx)
                val sig = Sig(
                    width = format.width,
                    height = format.height,
                    bitrate = format.bitrate,
                    codec = format.codecs,
                )
                val selected = group.isTrackSelected(trackIdx)
                val alreadySeen = seen.containsKey(sig)
                val prevHadSelection = seen[sig] == true
                if (alreadySeen && (prevHadSelection || !selected)) continue
                if (alreadySeen) {
                    payload.removeAll {
                        it["width"] == sig.width &&
                            it["height"] == sig.height &&
                            it["bitrate"] == sig.bitrate
                    }
                }
                seen[sig] = selected
                payload.add(
                    mapOf(
                        "id" to "$groupIdx:$trackIdx",
                        "label" to format.label,
                        "codec" to format.codecs,
                        "width" to format.width.takeIf { it > 0 },
                        "height" to format.height.takeIf { it > 0 },
                        "bitrate" to format.bitrate.takeIf { it > 0 },
                        "frameRate" to
                            format.frameRate.takeIf { it > 0f }?.toDouble(),
                        "selected" to selected,
                    ),
                )
            }
        }
        sendEvent(mapOf("event" to "videoTracks", "value" to payload))
    }

    /**
     * Install [source] as the base media source, preserving [startPositionMs]
     * (or the current play-head when `null`) and re-merging any external
     * subtitles queued via [addExternalSubtitle]. Centralising this logic
     * keeps [open], [attachNexusSession] and [rebuildWithExternalSubtitles]
     * in lock-step with regards to `prepare` ordering, position polling,
     * and subtitle merging.
     */
    private fun installBaseSource(source: MediaSource, startPositionMs: Long?) {
        currentBaseSource = source
        val effective = buildSourceWithSubtitles(source)
        player.setMediaSource(effective)
        player.prepare()
        if (startPositionMs != null && startPositionMs > 0) {
            player.seekTo(startPositionMs)
        }
        startPositionPolling()
    }

    /**
     * Re-hand the current base source to the player with the latest
     * [externalSubtitles] merged in. Preserves position by capturing
     * [Player.getCurrentPosition] before the swap and seeking back after
     * `prepare`. Silent no-op when there is no base source yet (the next
     * [open] will naturally pick up the list).
     */
    private fun rebuildWithExternalSubtitles() {
        val base = currentBaseSource ?: return
        val restoreMs = player.currentPosition.coerceAtLeast(0L)
        val effective = buildSourceWithSubtitles(base)
        player.setMediaSource(effective, /* resetPosition = */ false)
        player.prepare()
        if (restoreMs > 0) {
            player.seekTo(restoreMs)
        }
    }

    /**
     * Wrap [base] in a [MergingMediaSource] when external subtitles are
     * queued; otherwise return [base] unchanged. The merged sources are
     * built with `treatLoadErrorsAsEndOfStream = true` so a flaky
     * subtitle CDN never fails the whole playback — the sub simply
     * doesn't show up.
     */
    private fun buildSourceWithSubtitles(base: MediaSource): MediaSource {
        if (externalSubtitles.isEmpty()) return base
        val sources = buildList<MediaSource> {
            add(base)
            externalSubtitles.forEach { spec ->
                val subtitleConfig = MediaItem.SubtitleConfiguration
                    .Builder(Uri.parse(spec.uri))
                    .setMimeType(spec.mimeType)
                    .setLanguage(spec.language)
                    .setLabel(spec.label)
                    .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                    .build()
                add(
                    SingleSampleMediaSource.Factory(subtitleDataSourceFactory)
                        .setTreatLoadErrorsAsEndOfStream(true)
                        .createMediaSource(subtitleConfig, C.TIME_UNSET),
                )
            }
        }
        return MergingMediaSource(*sources.toTypedArray())
    }

    /**
     * Realise [pendingGainDb] / [pendingVoiceClarity] against the current
     * `audioSessionId` (if any). Called after every user-facing setter
     * **and** on the first `STATE_READY` frame, because Media3 only
     * picks an audio session once the audio renderer initialises.
     */
    private fun applyPendingAudioFx() {
        val sessionId = player.audioSessionId
        if (sessionId == C.AUDIO_SESSION_ID_UNSET) {
            emitLog(
                "[audio-fx] deferred: session unset gainDb=$pendingGainDb " +
                    "voiceClarity=$pendingVoiceClarity",
            )
            return
        }

        // Loudness enhancer ------------------------------------------------
        val targetMb = (pendingGainDb * 100.0).toInt().coerceAtLeast(0)
        if (targetMb == 0) {
            loudnessEnhancer?.release()
            loudnessEnhancer = null
        } else {
            var enhancer = loudnessEnhancer
            if (enhancer == null || enhancer.id != sessionId) {
                try {
                    enhancer?.release()
                    enhancer = LoudnessEnhancer(sessionId)
                    loudnessEnhancer = enhancer
                } catch (t: Throwable) {
                    emitLog("[audio-fx] LoudnessEnhancer init failed: ${t.message}")
                    enhancer = null
                }
            }
            enhancer?.let {
                it.setTargetGain(targetMb)
                it.enabled = true
            }
        }

        // Voice clarity EQ -------------------------------------------------
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            if (pendingVoiceClarity > 0.0) {
                emitLog(
                    "[audio-fx] voice clarity unavailable: API<28 " +
                        "(current=${Build.VERSION.SDK_INT})",
                )
            }
        } else if (pendingVoiceClarity <= 0.0) {
            dynamicsProcessing?.release()
            dynamicsProcessing = null
        } else {
            var dp = dynamicsProcessing
            if (dp == null) {
                dp = tryBuildVoiceClarityProcessor(sessionId)
                dynamicsProcessing = dp
            }
            dp?.let { tuneVoiceClarity(it, pendingVoiceClarity) }
        }

        emitLog(
            "[audio-fx] applied gainMb=$targetMb voiceClarity=$pendingVoiceClarity " +
                "sessionId=$sessionId",
        )
    }

    /**
     * Assemble a snapshot of the latest diagnostics stats from
     * [diagnosticsCollector] **plus** live player telemetry (buffered
     * duration, current position) and emit it on the event channel.
     * No-op when the collector is detached so `setDiagnosticsEnabled(false)`
     * cleanly stops the stream.
     */
    private fun emitDiagnosticsSnapshot() {
        val collector = diagnosticsCollector ?: return
        val size = player.videoSize
        val correctedWidth =
            if (size.width > 0) size.width * size.pixelWidthHeightRatio
            else 0f
        sendEvent(
            mapOf(
                "event" to "diagnostics",
                "value" to mapOf(
                    "droppedVideoFrames" to collector.droppedVideoFrames,
                    "renderedVideoFrames" to collector.renderedVideoFrames,
                    "videoCodec" to collector.videoCodec,
                    "videoDecoder" to collector.videoDecoder,
                    "videoBitrate" to collector.videoBitrate,
                    "videoHardwareAccelerated" to collector.videoHardwareAccelerated,
                    "audioCodec" to collector.audioCodec,
                    "audioSampleRate" to collector.audioSampleRate,
                    "audioChannels" to collector.audioChannels,
                    "bandwidthBps" to collector.bandwidthBps,
                    "bufferedMs" to player.totalBufferedDuration,
                    "positionMs" to player.currentPosition.coerceAtLeast(0L),
                    "videoWidth" to correctedWidth.toDouble(),
                    "videoHeight" to size.height.toDouble(),
                ),
            ),
        )
    }

    /**
     * Drop both audio-fx instances without touching [pendingGainDb] /
     * [pendingVoiceClarity] — they are the user's intent and live as
     * long as the [PlayerInstance]. Called on full [release].
     */
    private fun releaseAudioFx() {
        try { loudnessEnhancer?.release() } catch (_: Throwable) {}
        try { dynamicsProcessing?.release() } catch (_: Throwable) {}
        loudnessEnhancer = null
        dynamicsProcessing = null
    }

    /**
     * Build a conservative 3-band pre-EQ + limiter pipeline tuned for
     * spoken-word clarity. The tuning here is intentionally modest — a
     * follow-up slice will widen the profile once we have the runtime
     * A/B gate against AnimeNexus ES. Returns `null` when the device
     * refuses to allocate the effect (some OEMs stub it out).
     */
    @androidx.annotation.RequiresApi(Build.VERSION_CODES.P)
    private fun tryBuildVoiceClarityProcessor(sessionId: Int): DynamicsProcessing? {
        return try {
            val cfg = DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                /* channelCount = */ 2,
                /* preEqInUse = */ true, /* preEqBandCount = */ 3,
                /* mbcInUse = */ false, /* mbcBandCount = */ 0,
                /* postEqInUse = */ false, /* postEqBandCount = */ 0,
                /* limiterInUse = */ true,
            ).build()
            DynamicsProcessing(0, sessionId, cfg)
        } catch (t: Throwable) {
            emitLog("[audio-fx] DynamicsProcessing init failed: ${t.message}")
            null
        }
    }

    /**
     * Re-shape [dp]'s pre-EQ to the requested [strength] (0..1). Cuts
     * sub-120 Hz rumble linearly (0 → –6 dB), boosts the 1–4 kHz dialog
     * band (0 → +4 dB), and leaves the high shelf flat.
     */
    @androidx.annotation.RequiresApi(Build.VERSION_CODES.P)
    private fun tuneVoiceClarity(dp: DynamicsProcessing, strength: Double) {
        val s = strength.coerceIn(0.0, 1.0).toFloat()
        // Channel 0 drives both in the favour-frequency-resolution variant.
        val preEq = dp.getPreEqByChannelIndex(0)
        preEq.setEnabled(true)
        preEq.getBand(0).apply {
            cutoffFrequency = 120f
            gain = -6f * s
            isEnabled = true
        }
        preEq.getBand(1).apply {
            cutoffFrequency = 1500f
            gain = 4f * s
            isEnabled = true
        }
        preEq.getBand(2).apply {
            cutoffFrequency = 6000f
            gain = 0f
            isEnabled = true
        }
        dp.setPreEqAllChannelsTo(preEq)
        dp.setEnabled(true)
    }

    /**
     * Map any commonly-used alias onto the exact MIME strings Media3
     * hard-codes in `MimeTypes` for subtitle parsers. Returns `null`
     * when the MIME type is not supported (caller logs + drops).
     */
    private fun normaliseSubtitleMimeType(raw: String): String? =
        when (raw.lowercase()) {
            "text/vtt",
            "text/webvtt" -> "text/vtt"
            "application/x-subrip",
            "application/srt",
            "text/srt" -> "application/x-subrip"
            "text/x-ssa",
            "text/ass" -> "text/x-ssa"
            else -> null
        }

    /**
     * Inverse of the `"groupIndex:trackIndex"` id produced by
     * [emitAudioTracksEvent]. Returns `null` when [raw] is malformed.
     */
    private fun parseTrackId(raw: String): Pair<Int, Int>? {
        val parts = raw.split(':')
        if (parts.size != 2) return null
        val g = parts[0].toIntOrNull() ?: return null
        val t = parts[1].toIntOrNull() ?: return null
        if (g < 0 || t < 0) return null
        return g to t
    }

    private fun emitLog(line: String) {
        // Mirror to logcat so offline diagnostics via
        // `adb logcat -s KumoriyaExoPlayer` do not depend on the
        // Flutter EventChannel staying subscribed.
        Log.i(LOG_TAG, line)
        sendEvent(mapOf("event" to "log", "value" to line))
    }

    /**
     * Pick the right [MediaSource] for [item] given the already-normalised
     * [resolvedMime]. Uses explicit factories (as Flutter's
     * `video_player_android` does) instead of relying on
     * `DefaultMediaSourceFactory` — that factory's MIME dispatch is
     * string-exact and was silently sending HLS streams with the canonical
     * IANA MIME to `ProgressiveMediaSource`.
     *
     * When [resolvedMime] is `null` (no hint from the resolver) we
     * fall through to Progressive, which matches legacy `video_player`
     * behaviour for `VideoFormat.other` / `null`.
     *
     * Local file URIs (`file://`, `content://`, etc.) use [DefaultDataSource.Factory]
     * so ExoPlayer can read from the filesystem; remote URLs keep using the
     * HTTP-only factory to avoid unnecessary delegation overhead.
     */
    private fun buildMediaSource(
        item: MediaItem,
        resolvedMime: String?,
    ): MediaSource {
        val uri = item.localConfiguration?.uri
        val effectiveMime = resolvedMime ?: inferMimeFromUri(uri)
        val factory = effectiveDataSourceFactoryForUri(uri)
        return when (effectiveMime) {
            "application/x-mpegURL" ->
                HlsMediaSource.Factory(factory).createMediaSource(item)
            "application/dash+xml" ->
                DashMediaSource.Factory(factory).createMediaSource(item)
            else ->
                ProgressiveMediaSource.Factory(factory).createMediaSource(item)
        }
    }

    /**
     * Returns [DefaultDataSource.Factory] for local/content URIs so
     * ExoPlayer can access the filesystem or Android content providers;
     * returns the cached [dataSourceFactory] (HTTP-only) for remote URLs
     * to avoid the overhead of the delegating chain.
     */
    private fun effectiveDataSourceFactoryForUri(uri: Uri?): DataSource.Factory {
        val scheme = uri?.scheme?.lowercase()
        return if (scheme == "file" || scheme == "content" || scheme == "asset") {
            DefaultDataSource.Factory(context, dataSourceFactory)
        } else {
            dataSourceFactory
        }
    }

    /**
     * Best-effort URI sniff used as a fallback when the resolver did not
     * declare a mimeType. Mirrors `Util.inferContentType` for the formats
     * we care about so resolvers that forget to set the flag still land
     * on the right [MediaSource] factory.
     */
    private fun inferMimeFromUri(uri: Uri?): String? {
        val path = uri?.path?.lowercase() ?: return null
        return when {
            path.endsWith(".m3u8") -> "application/x-mpegURL"
            path.endsWith(".mpd") -> "application/dash+xml"
            else -> null
        }
    }

    /**
     * Map common HLS / DASH MIME aliases to the exact strings Media3 1.x
     * hard-codes in `MimeTypes`. `DefaultMediaSourceFactory` only picks the
     * right media source factory when [MediaItem.localConfiguration.mimeType]
     * matches one of those constants verbatim, so resolvers that report the
     * IANA canonical form would otherwise silently fall through to
     * `ProgressiveMediaSource` and fail sniffing.
     */
    private fun normaliseMimeType(raw: String?): String? {
        if (raw == null) return null
        return when (raw.lowercase()) {
            "application/x-mpegurl",
            "application/vnd.apple.mpegurl",
            "audio/mpegurl",
            "audio/x-mpegurl" -> "application/x-mpegURL"
            "application/dash+xml" -> "application/dash+xml"
            else -> raw
        }
    }

    private fun sendEvent(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sink.success(payload)
        } else {
            mainHandler.post { eventSink?.success(payload) }
        }
    }

    private fun requireNotReleased() {
        check(!released) { "PlayerInstance($textureId) already released" }
    }

    private fun releaseNexusSession() {
        val session = nexusSession
        nexusSession = null
        session?.close()
    }

    companion object {
        private const val LOG_TAG = "KumoriyaExoPlayer"
        private const val POSITION_POLL_MS = 200L
        private const val DIAGNOSTICS_POLL_MS = 1000L
    }
}

/**
 * Deferred spec for an external subtitle file waiting to be merged on top
 * of the base [MediaSource]. Kept immutable so reinstalling the base
 * source (e.g. after an HLS rebuild) can rebuild the same list without
 * worrying about mutation races.
 */
private data class ExternalSubtitleSpec(
    val uri: String,
    val mimeType: String,
    val language: String?,
    val label: String?,
)
