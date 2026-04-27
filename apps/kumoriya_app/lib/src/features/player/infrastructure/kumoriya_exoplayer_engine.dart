import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kumoriya_exoplayer/kumoriya_exoplayer.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../application/models/embedded_tracks.dart';
import '../application/models/player_diagnostics.dart';
import '../application/services/playback_engine.dart';

/// Android playback engine backed by the first-party `kumoriya_exoplayer`
/// plugin (native Media3 + custom anime.nexus pipeline).
///
/// Replaces [ExoPlayerPlaybackEngine] (Flutter's `video_player`) on Android
/// so we can drive:
///   - Every generic MP4/HLS/DASH stream through Media3 natively.
///   - anime.nexus via the native bootstrap + WS token signer (no Dart
///     loopback proxy).
///
/// Route hint:
///   - Pass a [ResolvedStream.url] of `kumoriya-native:anime-nexus?watch=…`
///     to trigger the anime.nexus bootstrap.
///   - Any other URL goes through the plain [KumoriyaExoPlayerController.open]
///     path with the resolved headers.
///
/// Known gaps (tracked in Fase 3 / 3b of the kumoriya_exoplayer plan):
///   - Embedded audio/subtitle switching not exposed yet (no-op).
///   - External subtitle sideload (VTT/SRT) not wired yet (no-op).
///   - Smart audio boost above 100 % clamped.
///   - Predictive prewarm, diagnostics overlay: no-op.
/// Outcome of a [KumoriyaExoPlayerEngine.onUrlExpired] callback — the
/// caller may either hand back a freshly-resolved URL (which the engine
/// swaps in without losing playback position) or return `null` to let
/// the player surface the failure as-is.
class RefreshedStreamUrl {
  const RefreshedStreamUrl({
    required this.url,
    this.headers = const <String, String>{},
    this.mimeType,
  });

  final Uri url;
  final Map<String, String> headers;
  final String? mimeType;
}

/// Signature for the URL-refresh hook that [KumoriyaExoPlayerEngine]
/// invokes when Media3 reports a 401/403/410 on the base stream.
typedef UrlExpiredResolver =
    Future<RefreshedStreamUrl?> Function(Uri oldUrl, int? httpCode);

final class KumoriyaExoPlayerEngine implements PlaybackEngine {
  KumoriyaExoPlayerEngine({this.onDebugLog, this.onUrlExpired});

  /// Sink for native log lines (Kotlin `Log.i/d/e` forwarded via
  /// `NativeLog` events). Wire this from the playground so probe JSONs
  /// capture Kotlin-side diagnostics instead of requiring a separate
  /// `adb logcat` session.
  final void Function(String message)? onDebugLog;

  /// Optional URL-refresh hook fired when the native side reports a
  /// 401/403/410 on the base stream. When present, the engine awaits the
  /// callback and — if it returns a non-null [RefreshedStreamUrl] —
  /// swaps the URL in without losing playback position. Leave as `null`
  /// to let the failure propagate as a regular playback error (current
  /// default; orchestrator wiring lands in a follow-up slice).
  final UrlExpiredResolver? onUrlExpired;

  KumoriyaExoPlayerController? _controller;
  bool _disposed = false;
  final List<StreamSubscription<Object?>> _controllerSubs =
      <StreamSubscription<Object?>>[];

  /// Display-ready aspect ratio of the current stream, or `null` before
  /// Media3 reports its first video size. [PlayerVideoSurface] rebuilds
  /// the `AspectRatio` wrapper on change so ABR-driven resolution swaps
  /// keep the surface correctly sized.
  final ValueNotifier<double?> aspectRatio = ValueNotifier<double?>(null);

  Completer<void>? _firstFrameCompleter;
  bool _firstFrameSignalled = false;

  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<EmbeddedTracks> _embeddedTracks =
      StreamController<EmbeddedTracks>.broadcast();
  final StreamController<CueEvent> _cues =
      StreamController<CueEvent>.broadcast();

  /// Texture id for the [Texture] widget, or `null` before the first open
  /// has succeeded.
  int? get textureId => _controller?.textureId;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<bool> get bufferingStream => _buffering.stream;

  @override
  Stream<bool> get completedStream => _completed.stream;

  @override
  Stream<String> get errorStream => _errors.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();

  @override
  Stream<double> get bufferingPercentageStream => const Stream<double>.empty();

  @override
  Stream<EmbeddedTracks> get embeddedTracksStream => _embeddedTracks.stream;

  /// Subtitle cue events from Media3. Each event carries decoded subtitle
  /// text with timing information for the overlay widget.
  Stream<CueEvent> get cueStream => _cues.stream;

  /// Fan-out for the diagnostics overlay. Lazily starts the native
  /// diagnostics pipeline on the first subscriber so production users
  /// never pay for the analytics listener, and stops it once the last
  /// listener disconnects. Maps the plugin-native
  /// [DiagnosticsSnapshot] onto the shared [PlayerDiagnostics] shape
  /// expected by `PlayerDebugOverlay`.
  late final StreamController<PlayerDiagnostics> _diagnostics =
      StreamController<PlayerDiagnostics>.broadcast(
        onListen: () {
          _diagnosticsListeners += 1;
          if (_diagnosticsListeners != 1) return;
          // The debug overlay can subscribe before the first `open()` lands
          // (controller still null). Skip the native enable here — the
          // deferred branch in [_attachControllerStreams] re-runs the
          // diagnostics wiring once a controller exists, so we never miss
          // the first sample even in that race window.
          final controller = _controller;
          if (controller == null) return;
          controller.setDiagnosticsEnabled(true);
          _controllerSubs.add(
            controller.diagnosticsStream.listen(_onDiagnosticsSnapshot),
          );
        },
        onCancel: () {
          _diagnosticsListeners = (_diagnosticsListeners - 1).clamp(0, 1 << 30);
          if (_diagnosticsListeners == 0) {
            _controller?.setDiagnosticsEnabled(false);
          }
        },
      );
  int _diagnosticsListeners = 0;

  void _onDiagnosticsSnapshot(DiagnosticsSnapshot snap) {
    if (_diagnostics.isClosed) return;
    _diagnostics.add(
      PlayerDiagnostics(
        frameDropCount: snap.droppedVideoFrames,
        videoCodec: snap.videoCodec,
        hwdecCurrent: switch (snap.videoHardwareAccelerated) {
          true => snap.videoDecoder ?? 'hw',
          false => 'sw',
          null => null,
        },
        videoWidth: snap.videoWidth > 0 ? snap.videoWidth.round() : null,
        videoHeight: snap.videoHeight > 0 ? snap.videoHeight.round() : null,
        demuxerCacheDuration: snap.bufferedMs > 0
            ? snap.bufferedMs / 1000.0
            : null,
      ),
    );
  }

  @override
  Stream<PlayerDiagnostics> get diagnosticsStream => _diagnostics.stream;

  @override
  Future<void> get firstFrameRendered =>
      (_firstFrameCompleter ?? Completer<void>()).future;

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    if (_disposed) return;
    await _disposeController();

    _firstFrameCompleter = Completer<void>();
    _firstFrameSignalled = false;
    aspectRatio.value = null;

    final controller = await KumoriyaExoPlayerController.create();
    _controller = controller;
    _attachControllerStreams(controller);

    try {
      final nexusWatchUrl = _nativeAnimeNexusWatchUrl(stream.url);
      if (nexusWatchUrl != null) {
        await controller.openAnimeNexus(
          nexusWatchUrl,
          startPosition: startPosition,
        );
      } else {
        // Media3 needs an explicit mimeType for URLs whose path lacks the
        // canonical extension (e.g. Zilla's `/m3u8/<hash>`).
        //
        // IMPORTANT: [stream.isHls] wins over [stream.mimeType]. Media3
        // 1.4.1 only recognises the legacy `application/x-mpegURL` string
        // (see `MimeTypes.APPLICATION_M3U8`). Resolvers that report the
        // canonical IANA `application/vnd.apple.mpegurl` would otherwise
        // downgrade to `ProgressiveMediaSource` and fail sniffing with
        // `ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED`. Kotlin side also
        // normalises aliases for extra safety.
        final String? mimeType = stream.isHls
            ? 'application/x-mpegURL'
            : stream.mimeType;
        await controller.open(
          stream.url.toString(),
          headers: Map<String, String>.from(stream.headers),
          mimeType: mimeType,
          startPosition: startPosition,
        );
      }
      if (_disposed) return;
      await controller.play();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[kumoriya_exoplayer] open failed: $error\n$stack');
      }
      if (!_errors.isClosed) {
        _errors.add('kumoriya_exoplayer.open_failed: $error');
      }
      rethrow;
    }
  }

  /// Decodes the `kumoriya-native:anime-nexus?watch=<encoded>` carrier URL
  /// injected upstream by [StartEpisodePlaybackUseCase]. Returns `null` for
  /// any normal HTTP(s) URL so the caller falls through to [open].
  String? _nativeAnimeNexusWatchUrl(Uri url) {
    if (url.scheme != 'kumoriya-native') return null;
    if (url.host != 'anime-nexus') return null;
    final encoded = url.queryParameters['watch'];
    if (encoded == null || encoded.isEmpty) return null;
    return Uri.decodeComponent(encoded);
  }

  void _attachControllerStreams(KumoriyaExoPlayerController controller) {
    _controllerSubs
      ..add(
        controller.playingStream.listen((value) {
          if (_playing.isClosed) return;
          _playing.add(value);
          if (value) _maybeSignalFirstFrame();
        }),
      )
      ..add(
        controller.bufferingStream.listen((value) {
          if (_buffering.isClosed) return;
          _buffering.add(value);
        }),
      )
      ..add(
        controller.positionStream.listen((value) {
          if (_position.isClosed) return;
          _position.add(value);
          if (value > Duration.zero) _maybeSignalFirstFrame();
        }),
      )
      ..add(
        controller.durationStream.listen((value) {
          if (_duration.isClosed) return;
          _duration.add(value);
        }),
      )
      ..add(
        controller.completedStream.listen((_) {
          if (_completed.isClosed) return;
          _completed.add(true);
        }),
      )
      ..add(
        controller.errorStream.listen((event) {
          if (_errors.isClosed) return;
          _errors.add('${event.code}: ${event.message}');
        }),
      )
      ..add(
        controller.logStream.listen((line) {
          onDebugLog?.call(line);
        }),
      )
      ..add(
        controller.videoSizeStream.listen((size) {
          aspectRatio.value = size.aspectRatio;
        }),
      )
      ..add(controller.audioTracksStream.listen((_) => _publishEmbedded()))
      ..add(controller.subtitleTracksStream.listen((_) => _publishEmbedded()))
      ..add(controller.videoTracksStream.listen((_) => _publishEmbedded()))
      ..add(controller.urlExpiredStream.listen(_handleUrlExpired))
      ..add(
        controller.cueStream.listen((event) {
          if (_cues.isClosed) return;
          _cues.add(event);
        }),
      );
    // When a debug overlay was already subscribed before open() landed
    // (e.g. the user toggled it on the settings page first), enable
    // diagnostics on the fresh controller so the overlay keeps getting
    // samples across stream swaps.
    if (_diagnosticsListeners > 0) {
      controller.setDiagnosticsEnabled(true);
      _controllerSubs.add(
        controller.diagnosticsStream.listen(_onDiagnosticsSnapshot),
      );
    }
  }

  /// Fire the user-supplied [onUrlExpired] hook (when wired) and swap
  /// in the refreshed URL it returns. Swallows errors from the hook so a
  /// buggy orchestrator never turns into a crash — the player just
  /// surfaces the original failure in that case.
  Future<void> _handleUrlExpired(UrlExpired event) async {
    final hook = onUrlExpired;
    if (hook == null) {
      onDebugLog?.call(
        '[kumoriya_exoplayer] urlExpired code=${event.httpCode} '
        'url=${event.url} — no resolver wired, leaving error in place',
      );
      return;
    }
    final oldUri = Uri.tryParse(event.url);
    if (oldUri == null) return;
    try {
      final refreshed = await hook(oldUri, event.httpCode);
      if (refreshed == null || _disposed) return;
      final controller = _controller;
      if (controller == null || controller.isDisposed) return;
      await controller.swapUrl(
        refreshed.url.toString(),
        headers: refreshed.headers,
        mimeType: refreshed.mimeType,
      );
    } catch (err, stack) {
      onDebugLog?.call(
        '[kumoriya_exoplayer] onUrlExpired hook threw: $err\n$stack',
      );
    }
  }

  /// Rebuild and publish the combined [EmbeddedTracks] snapshot from the
  /// controller's latest caches so every update covers audio + subtitle
  /// simultaneously (mirrors how the legacy media_kit engine exposed
  /// both in a single stream event).
  void _publishEmbedded() {
    if (_embeddedTracks.isClosed) return;
    final c = _controller;
    if (c == null) return;
    _embeddedTracks.add(
      EmbeddedTracks(
        audio: c.audioTracks
            .map(
              (t) => EmbeddedAudioTrack(
                id: t.id,
                title: t.label,
                language: t.language,
              ),
            )
            .toList(growable: false),
        subtitle: c.subtitleTracks
            .map(
              (t) => EmbeddedSubtitleTrack(
                id: t.id,
                title: t.label,
                language: t.language,
                selected: t.selected,
              ),
            )
            .toList(growable: false),
        video: c.videoTracks
            .map(
              (t) => EmbeddedVideoTrack(
                id: t.id,
                label: t.label,
                width: t.width,
                height: t.height,
                bitrate: t.bitrate,
                frameRate: t.frameRate,
                selected: t.selected,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  void _maybeSignalFirstFrame() {
    if (_firstFrameSignalled) return;
    final completer = _firstFrameCompleter;
    if (completer == null || completer.isCompleted) return;
    _firstFrameSignalled = true;
    completer.complete();
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> setVolume(double percent) async {
    // kumoriya_exoplayer uses 0..1 like video_player — clamp the media_kit
    // 0..300 range. Boost above 100 % requires Fase 4 native EQ work.
    final clamped = (percent / 100.0).clamp(0.0, 1.0);
    await _controller?.setVolume(clamped);
  }

  @override
  Future<void> setPlaybackSpeed(double rate) async {
    await _controller?.setPlaybackSpeed(rate);
  }

  // ── Not yet supported on native engine ──────────────────────────────

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) async {
    final controller = _controller;
    if (controller == null) return;
    final uri = track.uri;
    if (uri == null) {
      // Inline `data` payload — native side only knows how to fetch via
      // URL today. A future slice can teach the plugin to accept inline
      // bytes (e.g. via a `data:` URL or a tempfile dance). Until then,
      // drop the track with a diagnostic log so the UI at least knows
      // the attach failed.
      if (kDebugMode) {
        debugPrint(
          '[kumoriya_exoplayer] setSubtitleTrack skip id=${track.id} '
          'label=${track.label}: inline `data` payloads unsupported',
        );
      }
      return;
    }
    await controller.addExternalSubtitle(
      uri: uri.toString(),
      mimeType: _guessSubtitleMimeType(uri),
      language: track.language,
      label: track.label,
    );
    // Embedded-inventory event will land after Media3 integrates the
    // merged source — the UI picks the new track from there.
  }

  @override
  Future<void> clearSubtitleTrack() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.clearExternalSubtitles();
    await controller.clearSubtitleTrack();
  }

  static String _guessSubtitleMimeType(Uri url) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.vtt')) return 'text/vtt';
    if (path.endsWith('.srt')) return 'application/x-subrip';
    if (path.endsWith('.ass') || path.endsWith('.ssa')) return 'text/x-ssa';
    return 'text/vtt';
  }

  @override
  Future<void> setEmbeddedAudioTrack(EmbeddedAudioTrack track) async {
    await _controller?.selectAudioTrack(track.id);
  }

  @override
  Future<void> setEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) async {
    await _controller?.selectSubtitleTrack(track.id);
  }

  @override
  Future<void> clearEmbeddedSubtitleTrack() async {
    await _controller?.clearSubtitleTrack();
  }

  @override
  Future<void> setPreferredSubtitleLanguages(List<String> languages) async {
    await _controller?.setPreferredSubtitleLanguages(languages);
  }

  @override
  Future<void> setEmbeddedVideoTrack(EmbeddedVideoTrack track) async {
    await _controller?.selectVideoTrack(track.id);
  }

  @override
  Future<void> clearEmbeddedVideoTrack() async {
    await _controller?.clearVideoTrackOverride();
  }

  @override
  Future<void> signalPredictivePrewarm(Duration position) async {}

  @override
  Future<void> setSmartAudioBoost({required bool enabled}) async {
    final controller = _controller;
    if (controller == null) return;
    // The legacy media_kit engine mapped "smart boost on" to a
    // soft-knee compressor via libmpv's `af` chain. The native Media3
    // pipeline gets an equivalent effect through `LoudnessEnhancer`
    // (+6 dB headroom so >100 % volume doesn't hard-clip) plus a
    // modest voice-clarity EQ so dialog stays intelligible over
    // music. Tuning numbers are intentionally conservative — runtime
    // A/B on AnimeNexus ES will revise them.
    if (enabled) {
      await controller.setOverallGainDb(6.0);
      await controller.setVoiceClarity(0.7);
    } else {
      await controller.setOverallGainDb(0.0);
      await controller.setVoiceClarity(0.0);
    }
  }

  @override
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {}

  // ── Teardown ────────────────────────────────────────────────────────

  Future<void> _disposeController() async {
    for (final sub in _controllerSubs) {
      await sub.cancel();
    }
    _controllerSubs.clear();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _disposeController();
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _errors.close();
    await _position.close();
    await _duration.close();
    await _embeddedTracks.close();
    await _cues.close();
    if (!_diagnostics.isClosed) await _diagnostics.close();
    aspectRatio.dispose();
  }
}
