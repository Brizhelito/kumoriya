package dev.kumoriya.exoplayer.nexus

import android.net.Uri
import android.util.Log
import kotlinx.coroutines.runBlocking
import okhttp3.Cookie
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Owns the native state of one anime.nexus playback.
 *
 * Life cycle:
 *  1. [bootstrap] runs the HTTP bootstrap synchronously from the caller
 *     thread (page scrape → stream data → hls url).
 *  2. [connectWs] opens the Socket.IO session and blocks until the
 *     `connected` event fires. Tokens can be requested after this returns.
 *  3. [getManifestToken] / [getSegmentToken] proxy to the WS client. They
 *     are called from the Media3 loader threads on every CDN fetch.
 *  4. [close] tears down the WS client. The shared [OkHttpClient] is
 *     session-scoped too and GC-collected when this goes away.
 *
 * The class is thread-safe: the WS client itself guards token request
 * state with a [java.util.concurrent.ConcurrentHashMap] and atomic ack ids.
 */
internal class NexusPlaybackSession private constructor(
    val episodeId: String,
    val videoId: String,
    val attestRef: String,
    val hlsUrl: String,
    val fingerprint: String,
    initialEdgeHost: String,
    edgeFallbacks: List<String>,
    val http: OkHttpClient,
    val cookieJar: NexusCookieJar,
    val ws: NexusWsClient,
    // External WebVTT/SRT subtitles advertised by the anime.nexus stream
    // API, already fetched in the bootstrap so [PlayerInstance
    // .attachNexusSession] can merge them as inline `data:` sources
    // without relying on the default HTTP DataSource (which would miss
    // the Origin/Referer/cookie set the subtitle CDN demands and 403).
    val subtitles: List<ResolvedSubtitle>,
    val onDebugLog: ((String) -> Unit)?,
) {
    @Volatile private var closed = false

    // Edge host can change mid-session when the primary edge starts
    // returning 403 `Token validation failed` while other edges still
    // honour the WS-minted tokens (observed on residential ISPs where
    // the Cloudflare WAF fingerprints the IP but rotates decisions
    // per-edge).  Reads happen from Media3 loader threads; writes go
    // through [rotateEdge] under the selector's intrinsic lock.
    @Volatile private var edgeHostRef: String = initialEdgeHost
    private val edgeFallbacks: ArrayDeque<String> =
        ArrayDeque(edgeFallbacks.filter { it != initialEdgeHost })
    private val rotateLock = Any()

    // Tracks distinct edges that have rejected tokens with the
    // `Token validation failed` body. Two burned edges are enough to
    // declare the client IP globally WAF-blocked: rotating further is
    // futile, only a network switch recovers.
    private val burnedEdges: MutableSet<String> = HashSet()
    private val burnLock = Any()

    val edgeHost: String
        get() = edgeHostRef

    val sessionId: String
        get() = ws.session?.sessionId.orEmpty()

    /**
     * Record that [edge] returned `Token validation failed`.
     * Returns the number of distinct edges burned so far in this session.
     */
    fun recordTokenRejection(edge: String): Int = synchronized(burnLock) {
        burnedEdges.add(edge)
        burnedEdges.size
    }

    /**
     * True once at least [threshold] distinct edges have rejected tokens
     * in this session — at that point rotating further is a waste of
     * user-visible loading time; the client IP is globally WAF-blocked.
     */
    fun isLikelyWafBlocked(threshold: Int = 2): Boolean =
        synchronized(burnLock) { burnedEdges.size >= threshold }

    /**
     * Rotate to the next best edge when the current one rejects tokens.
     * Returns `true` if a rotation happened and callers may retry; `false`
     * when the fallback list is empty and the caller must surface the
     * error.
     */
    fun rotateEdge(reason: String): Boolean = synchronized(rotateLock) {
        val next = edgeFallbacks.removeFirstOrNull() ?: run {
            onDebugLog?.invoke(
                "[edge-selector] rotate-exhausted from=$edgeHostRef " +
                    "reason=$reason",
            )
            // Drop the process-wide cache so the next playback session
            // re-probes instead of inheriting the burned primary.
            NexusEdgeSelector.invalidateCache()
            return@synchronized false
        }
        onDebugLog?.invoke(
            "[edge-selector] rotate from=$edgeHostRef to=$next " +
                "reason=$reason remaining=${edgeFallbacks.size}",
        )
        edgeHostRef = next
        true
    }

    fun close() {
        if (closed) return
        closed = true
        ws.close()
    }

    /** Blocks on the Media3 loader thread until the WS returns a token. */
    fun getManifestToken(
        manifestPath: String,
    ): NexusStreamToken = runBlocking {
        ws.getManifestToken(manifestPath = manifestPath, videoId = videoId)
    }

    fun getSegmentToken(
        variant: String,
        segmentIndex: Int,
        track: Int,
    ): NexusStreamToken = runBlocking {
        ws.getSegmentToken(
            variant = variant,
            segmentIndex = segmentIndex,
            track = track,
            videoId = videoId,
        )
    }

    companion object {
        /**
         * Runs the full bootstrap and opens the WS. Throws [NexusException]
         * subclasses on any failure — the caller is expected to map those
         * to a Flutter-side error.
         */
        fun open(
            watchUrl: String,
            onDebugLog: ((String) -> Unit)? = null,
        ): NexusPlaybackSession {
            // Fan the debug log to both the Flutter event channel and
            // logcat, so `adb logcat -s NexusSession:V` surfaces every
            // step even when the Dart side is unreachable.
            val log: (String) -> Unit = { line ->
                Log.d(LOG_TAG, line)
                onDebugLog?.invoke(line)
            }
            try {
                return doOpen(watchUrl, log)
            } catch (e: Throwable) {
                Log.e(LOG_TAG, "bootstrap failed: ${e.message}", e)
                throw e
            }
        }

        private fun doOpen(
            watchUrl: String,
            onDebugLog: (String) -> Unit,
        ): NexusPlaybackSession {
            val browser = NexusBrowserSession.generate()

            val cookieJar = NexusCookieJar()
            // Seed the synthetic `sid` cookie on both the anime.nexus and
            // api.anime.nexus origins — the server binds the session to it
            // on the very first hit.
            val hosts = listOf("anime.nexus", "api.anime.nexus")
            for (host in hosts) {
                cookieJar.seedHeader(
                    "https://$host/".toHttpUrl(),
                    browser.seedCookieHeader,
                )
            }

            val http = NexusHttpClient.build(cookieJar)
            onDebugLog(
                "[anime-nexus] bootstrap fingerprint=${browser.fingerprint}",
            )

            val scrape = NexusPageScraper(http).scrape(watchUrl)
            onDebugLog(
                "[anime-nexus] scrape episodeId=${scrape.episodeId} " +
                    "attestRef=${scrape.attestRef.take(8)}…",
            )

            val stream = NexusStreamDataFetcher(http).fetch(
                episodeId = scrape.episodeId,
                fingerprint = browser.fingerprint,
            )
            onDebugLog(
                "[anime-nexus] stream videoId=${stream.videoId} " +
                    "hls=${stream.hlsUrl}",
            )

            // Diagnostic: dump the cookies available to the WS upgrade host
            // right before we open the socket. If `anime_nexus_session` is
            // missing, CDN tokens will silently fail validation.
            val wsCookieHeader = cookieJar.asCookieHeader(
                "https://${NexusConstants.WS_HOST}/".toHttpUrl(),
            ) ?: "(none)"
            onDebugLog("[anime-nexus] pre-ws cookies=$wsCookieHeader")

            val ws = NexusWsClient(
                http = http,
                episodeId = scrape.episodeId,
                fingerprint = browser.fingerprint,
                m3u8Url = stream.hlsUrl,
                onDebugLog = onDebugLog,
            )

            runBlocking { ws.connect(scrape.attestRef) }
            onDebugLog(
                "[anime-nexus] ws-ready sessionId=${ws.session?.sessionId}",
            )

            // Initial manifest token warms the WS pipe and matches the
            // reference resolver's handshake. The token itself is not
            // reused — actual variant/segment fetches mint fresh tokens.
            runBlocking { ws.getInitialManifestToken() }

            // Pick a CDN edge via `/api/cdn/health` + ping probes. The API
            // sometimes writes a regional edge host (e.g. `cl1`) into the
            // master manifest that rejects our signed tokens; we override
            // that with the edge the anime.nexus SPA would pick.
            val fallbackHost = Uri.parse(stream.hlsUrl).host.orEmpty()
                .takeIf { it.endsWith(".cdn.nexus") }
                ?: NexusConstants.CDN_BASE.toHttpUrl().host
            val edgeSelection = runBlocking {
                NexusEdgeSelector.selectRanked(
                    http = http,
                    fallbackHost = fallbackHost,
                    log = onDebugLog,
                )
            }
            onDebugLog(
                "[anime-nexus] edge-host=${edgeSelection.primary} " +
                    "fallbacks=${edgeSelection.fallbacks}",
            )

            // Pre-fetch VTT/SRT bytes with the same auth set the stream
            // endpoint needed (cookies from the cookieJar + browser
            // headers + fingerprint). The subtitle CDN 403s on anonymous
            // fetches, which is why Media3's default HTTP DataSource
            // silently drops these tracks on attach.
            val resolvedSubs = resolveSubtitles(
                http = http,
                raw = stream.subtitles,
                fingerprint = browser.fingerprint,
                episodeId = scrape.episodeId,
                onDebugLog = onDebugLog,
            )

            return NexusPlaybackSession(
                episodeId = scrape.episodeId,
                videoId = stream.videoId,
                attestRef = scrape.attestRef,
                hlsUrl = stream.hlsUrl,
                fingerprint = browser.fingerprint,
                initialEdgeHost = edgeSelection.primary,
                edgeFallbacks = edgeSelection.fallbacks,
                http = http,
                cookieJar = cookieJar,
                ws = ws,
                subtitles = resolvedSubs,
                onDebugLog = onDebugLog,
            )
        }

        /**
         * Download each subtitle track returned by the stream API with
         * the exact header set the Dart reference resolver sends. Drops
         * tracks that 4xx / error out silently — subtitles are optional
         * and we never want to fail playback because of them.
         */
        private fun resolveSubtitles(
            http: OkHttpClient,
            raw: List<NexusStreamDataFetcher.Subtitle>,
            fingerprint: String,
            episodeId: String,
            onDebugLog: (String) -> Unit,
        ): List<ResolvedSubtitle> {
            if (raw.isEmpty()) return emptyList()
            val out = ArrayList<ResolvedSubtitle>(raw.size)
            for (sub in raw) {
                try {
                    val req = Request.Builder()
                        .url(sub.src)
                        .header("User-Agent", NexusConstants.USER_AGENT)
                        .header(
                            "Accept",
                            "text/vtt,text/plain,application/x-subrip,*/*",
                        )
                        .header(
                            "Accept-Language",
                            NexusConstants.ACCEPT_LANGUAGE,
                        )
                        .header(
                            "Referer",
                            "${NexusConstants.MAIN_BASE}/watch/$episodeId",
                        )
                        .header("Origin", NexusConstants.MAIN_BASE)
                        .header("x-client-fingerprint", fingerprint)
                        .header("x-fingerprint", fingerprint)
                        .build()
                    http.newCall(req).execute().use { resp ->
                        if (!resp.isSuccessful) {
                            onDebugLog(
                                "[anime-nexus.subtitle] skip " +
                                    "label='${sub.label}' http=${resp.code} " +
                                    "src=${sub.src}",
                            )
                            return@use
                        }
                        val bytes = resp.body?.bytes()
                        if (bytes == null || bytes.isEmpty()) {
                            onDebugLog(
                                "[anime-nexus.subtitle] skip empty body " +
                                    "label='${sub.label}'",
                            )
                            return@use
                        }
                        val mime = guessSubtitleMime(sub.src)
                        out.add(
                            ResolvedSubtitle(
                                content = bytes,
                                mimeType = mime,
                                language = sub.srcLang,
                                label = sub.label,
                            ),
                        )
                        onDebugLog(
                            "[anime-nexus.subtitle] fetched " +
                                "label='${sub.label}' bytes=${bytes.size} " +
                                "mime=$mime",
                        )
                    }
                } catch (e: Exception) {
                    onDebugLog(
                        "[anime-nexus.subtitle] error label='${sub.label}' " +
                            "${e.javaClass.simpleName}: ${e.message}",
                    )
                }
            }
            return out
        }

        private fun guessSubtitleMime(rawUri: String): String {
            val path = rawUri.substringBefore('?').lowercase()
            return when {
                path.endsWith(".vtt") -> "text/vtt"
                path.endsWith(".srt") -> "application/x-subrip"
                path.endsWith(".ass") ||
                    path.endsWith(".ssa") -> "text/x-ssa"
                else -> "text/vtt"
            }
        }

        private const val LOG_TAG = "NexusSession"
    }

    /** Classify a URL so the DataSource can sign it correctly. */
    internal enum class UrlKind {
        MASTER,
        VARIANT_MANIFEST,
        INIT,
        SEGMENT,
        UNKNOWN,
    }

    internal fun classify(uri: Uri): UrlKind {
        // Real-world AnimeNexus hosts (2026-04):
        //  - master lives on api.anime.nexus
        //  - variant manifests, init segments and media segments live on
        //    `*.cdn.nexus` (cl1, us1, eu1, …)
        // Unknown hosts fall through to UNKNOWN so we fail loudly instead
        // of leaking unsigned requests.
        val host = uri.host.orEmpty().lowercase()
        val path = uri.path.orEmpty().lowercase()
        if (uri.toString() == hlsUrl) return UrlKind.MASTER
        val isAnimeNexus =
            host == "anime.nexus" || host.endsWith(".anime.nexus")
        val isCdnNexus = host == "cdn.nexus" || host.endsWith(".cdn.nexus")
        if (!isAnimeNexus && !isCdnNexus) return UrlKind.UNKNOWN
        return when {
            path.endsWith(".m3u8") -> UrlKind.VARIANT_MANIFEST
            path.endsWith(".mp4") && path.contains("_init-") -> UrlKind.INIT
            path.endsWith(".m4s") || path.endsWith(".mp4") ||
                path.endsWith(".ts") -> UrlKind.SEGMENT
            else -> UrlKind.UNKNOWN
        }
    }

    /**
     * Rewrite a `*.cdn.nexus` URI to the edge we picked for this session.
     * Leaves non-CDN URIs untouched so master manifest on api.anime.nexus
     * is not accidentally redirected.
     */
    internal fun rewriteToEdge(uri: Uri): Uri {
        val host = uri.host.orEmpty().lowercase()
        if (host == edgeHost.lowercase()) return uri
        val isCdnNexus = host == "cdn.nexus" || host.endsWith(".cdn.nexus")
        if (!isCdnNexus) return uri
        return uri.buildUpon().authority(edgeHost).build()
    }

    internal fun browserFetchHeaders(): Map<String, String> = mapOf(
        "User-Agent" to NexusConstants.USER_AGENT,
        "Accept" to "*/*",
        "Accept-Language" to NexusConstants.ACCEPT_LANGUAGE,
        "Origin" to NexusConstants.MAIN_BASE,
        "Referer" to "${NexusConstants.MAIN_BASE}/",
        "sec-fetch-dest" to "empty",
        "sec-fetch-mode" to "cors",
        "sec-fetch-site" to "cross-site",
    )

    internal fun cdnRequestHeaders(): Map<String, String> =
        browserFetchHeaders() + mapOf(
            "x-client-fingerprint" to fingerprint,
            "x-fingerprint" to fingerprint,
            "x-session-id" to sessionId,
            "x-video-uuid" to episodeId,
        )
}

/**
 * A subtitle track already downloaded by the bootstrap — bytes live
 * in memory so [PlayerInstance] can wrap them as `data:` URIs and
 * bypass the default HTTP DataSource (which lacks the auth set the
 * anime.nexus subtitle CDN requires).
 */
internal data class ResolvedSubtitle(
    val content: ByteArray,
    val mimeType: String,
    val language: String?,
    val label: String,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ResolvedSubtitle) return false
        return mimeType == other.mimeType &&
            language == other.language &&
            label == other.label &&
            content.contentEquals(other.content)
    }

    override fun hashCode(): Int {
        var result = content.contentHashCode()
        result = 31 * result + mimeType.hashCode()
        result = 31 * result + (language?.hashCode() ?: 0)
        result = 31 * result + label.hashCode()
        return result
    }
}
