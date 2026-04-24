import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../application/services/playback_engine.dart';
import '../application/models/embedded_tracks.dart';
import '../application/models/player_diagnostics.dart';

const bool _playerVerboseLogs = bool.fromEnvironment(
  'PLAYER_VERBOSE_LOGS',
  defaultValue: false,
);

final class MediaKitPlaybackEngine implements PlaybackEngine {
  static const bool _verboseNativePlayerLogs = bool.fromEnvironment(
    'PLAYER_NATIVE_DEBUG_LOGS',
    defaultValue: false,
  );
  static const String _linuxVideoOutput = String.fromEnvironment(
    'PLAYER_LINUX_VO',
    defaultValue: '',
  );
  static const String _linuxHwdec = String.fromEnvironment(
    'PLAYER_LINUX_HWDEC',
    defaultValue: 'auto-safe',
  );

  /// Effectively unlimited demuxer buffer: 512 MB on mobile, 1 GB on desktop.
  /// Chosen to absorb long readahead windows on CDNs with rotating hosts
  /// (e.g. Desu) where each segment requires a fresh TCP+TLS handshake and
  /// starving the cache stalls playback.
  static int _bufferSizeForPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      return 512 * 1024 * 1024;
    }
    return 1024 * 1024 * 1024;
  }

  MediaKitPlaybackEngine({
    void Function(String message)? onDebugLog,
    void Function(String reason)? onVideoOutputFallbackRequested,
    bool forceSoftwareVideoOutput = false,
  }) : _debugLogSink = onDebugLog,
       _videoOutputFallbackSink = onVideoOutputFallbackRequested,
       _forceSoftwareVideoOutput = forceSoftwareVideoOutput,
       player = Player(
         configuration: PlayerConfiguration(
           logLevel: kDebugMode
               ? (_verboseNativePlayerLogs
                     ? MPVLogLevel.debug
                     : MPVLogLevel.warn)
               : MPVLogLevel.error,
           bufferSize: _bufferSizeForPlatform(),
         ),
       ) {
    final useSoftwareVideoOutput = _shouldUseSoftwareVideoOutput();
    final videoOutput = _preferredVideoOutput();
    final hwdec = _preferredHardwareDecoder();
    videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: videoOutput,
        hwdec: hwdec,
        enableHardwareAcceleration: !useSoftwareVideoOutput,
      ),
    );
    _log(
      'video-controller-config softwareOutput=$useSoftwareVideoOutput '
      'platform=$defaultTargetPlatform vo=${videoOutput ?? "default"} '
      'hwdec=${hwdec ?? "default"}',
    );
    if (_playerVerboseLogs) {
      _attachVideoControllerDebugStreams();
      _attachNativeDebugStreams();
    }
    // P9: Diagnostics polling is now started lazily when the first
    // listener subscribes to diagnosticsStream (onListen callback).
  }

  final Player player;
  late final VideoController videoController;
  final void Function(String message)? _debugLogSink;
  final void Function(String reason)? _videoOutputFallbackSink;
  final bool _forceSoftwareVideoOutput;
  bool _disposed = false;
  int _openGeneration = 0;
  Completer<void> _openCancellationCompleter = Completer<void>();
  bool _firstFrameRendered = false;
  bool _videoOutputFallbackTriggered = false;
  Timer? _videoOutputFallbackTimer;

  // P5: Stream that fires once when the first video frame is rendered.
  // Used by the orchestrator's visual gate to replace the fixed
  // position-threshold hack with a real frame-rendered signal.
  final Completer<void> _firstFrameCompleter = Completer<void>();

  /// Completes when the video controller renders its first frame.
  /// Used by the orchestrator to implement a frame-accurate visual gate.
  @override
  Future<void> get firstFrameRendered => _firstFrameCompleter.future;
  Uri? _currentAnimeNexusProxyBaseUri;
  String? _currentAnimeNexusPlaybackId;
  String? _currentAnimeNexusVariant;

  /// O9: Reused HttpClient for loopback proxy communication.  Avoids
  /// repeated TCP connection setup overhead across seek-prefetch,
  /// ensure-playable, and warmup calls.
  HttpClient? _proxyHttpClient;
  HttpClient get _proxyClient => _proxyHttpClient ??= HttpClient();
  final List<StreamSubscription<dynamic>> _debugSubscriptions =
      <StreamSubscription<dynamic>>[];
  late final String _instanceId = identityHashCode(this).toRadixString(16);

  // ── Diagnostics polling (debug only, lazy) ──────────────────────────────
  Timer? _diagnosticsTimer;
  int _diagnosticsListenerCount = 0;
  late final StreamController<PlayerDiagnostics> _diagnosticsController =
      StreamController<PlayerDiagnostics>.broadcast(
        onListen: _onDiagnosticsListenerAdded,
        onCancel: _onDiagnosticsListenerRemoved,
      );
  int? _lastSeekLatencyMs;

  void _onDiagnosticsListenerAdded() {
    _diagnosticsListenerCount++;
    if (_diagnosticsListenerCount == 1) {
      _startDiagnosticsPolling();
    }
  }

  void _onDiagnosticsListenerRemoved() {
    _diagnosticsListenerCount--;
    if (_diagnosticsListenerCount <= 0) {
      _diagnosticsListenerCount = 0;
      _diagnosticsTimer?.cancel();
      _diagnosticsTimer = null;
    }
  }

  @override
  Stream<PlayerDiagnostics> get diagnosticsStream =>
      _diagnosticsController.stream;

  /// Records a completed seek latency so the next diagnostics snapshot
  /// includes it.  Called by the orchestrator after measuring a seek.
  void recordSeekLatency(int milliseconds) {
    _lastSeekLatencyMs = milliseconds;
  }

  /// P9: Polling is now lazy — only active when there are listeners on
  /// the diagnostics stream (i.e. the debug overlay is visible).
  /// Interval increased from 2s to 5s to reduce overhead.
  void _startDiagnosticsPolling() {
    if (!kDebugMode || _disposed) return;
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollDiagnostics(),
    );
  }

  Future<void> _pollDiagnostics() async {
    if (_disposed || _diagnosticsController.isClosed) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;

    try {
      final results = await Future.wait(<Future<String>>[
        platform.getProperty('estimated-vf-fps').catchError((_) => ''),
        platform.getProperty('display-fps').catchError((_) => ''),
        platform.getProperty('frame-drop-count').catchError((_) => ''),
        platform.getProperty('decoder-frame-drop-count').catchError((_) => ''),
        platform.getProperty('current-vo').catchError((_) => ''),
        platform.getProperty('hwdec-current').catchError((_) => ''),
        platform.getProperty('video-format').catchError((_) => ''),
        platform.getProperty('video-codec').catchError((_) => ''),
        platform.getProperty('video-params/w').catchError((_) => ''),
        platform.getProperty('video-params/h').catchError((_) => ''),
        platform.getProperty('demuxer-cache-duration').catchError((_) => ''),
        platform.getProperty('demuxer-cache-state').catchError((_) => ''),
      ]);

      if (_disposed || _diagnosticsController.isClosed) return;

      int? cacheBytes;
      final cacheStateRaw = results[11];
      if (cacheStateRaw.isNotEmpty) {
        // demuxer-cache-state is JSON; extract total-bytes if available.
        try {
          final decoded = json.decode(cacheStateRaw) as Map<String, dynamic>;
          cacheBytes = (decoded['total-bytes'] as num?)?.toInt();
        } catch (_) {
          // Not JSON or unexpected shape — ignore.
        }
      }

      _diagnosticsController.add(
        PlayerDiagnostics(
          estimatedVfFps: double.tryParse(results[0]),
          displayFps: double.tryParse(results[1]),
          frameDropCount: int.tryParse(results[2]),
          decoderFrameDropCount: int.tryParse(results[3]),
          videoOutput: results[4].isEmpty ? null : results[4],
          hwdecCurrent: results[5].isEmpty ? null : results[5],
          videoFormat: results[6].isEmpty ? null : results[6],
          videoCodec: results[7].isEmpty ? null : results[7],
          videoWidth: int.tryParse(results[8]),
          videoHeight: int.tryParse(results[9]),
          demuxerCacheDuration: double.tryParse(results[10]),
          demuxerCacheBytes: cacheBytes,
          lastSeekLatencyMs: _lastSeekLatencyMs,
        ),
      );
    } catch (error) {
      _log('diagnostics-poll error=$error');
    }
  }

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<bool> get completedStream => player.stream.completed;

  @override
  Stream<String> get errorStream => player.stream.error;

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<Duration> get durationStream => player.stream.duration;

  @override
  Stream<Duration> get bufferStream => player.stream.buffer;

  @override
  Stream<double> get bufferingPercentageStream =>
      player.stream.bufferingPercentage;

  @override
  Stream<EmbeddedTracks> get embeddedTracksStream =>
      player.stream.tracks.map(_mapTracks);

  static EmbeddedTracks _mapTracks(Tracks tracks) {
    final audio = tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .map(
          (t) => EmbeddedAudioTrack(
            id: t.id,
            title: t.title,
            language: t.language,
          ),
        )
        .toList(growable: false);

    final subtitle = tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .map(
          (t) => EmbeddedSubtitleTrack(
            id: t.id,
            title: t.title,
            language: t.language,
          ),
        )
        .toList(growable: false);

    return EmbeddedTracks(audio: audio, subtitle: subtitle);
  }

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    final generation = _beginOpenSequence();
    final cancellation = _openCancellationCompleter.future;
    _log(
      'open url=${stream.url} hls=${stream.isHls} start=$startPosition generation=$generation headers=${stream.headers.keys.join(",")}',
    );
    _throwIfInvalidated(generation);
    if (_isAnimeNexusLoopback(stream.url)) {
      _currentAnimeNexusProxyBaseUri = Uri(
        scheme: stream.url.scheme,
        host: stream.url.host,
        port: stream.url.port,
      );
      _currentAnimeNexusPlaybackId = _extractAnimeNexusPlaybackId(stream.url);
      _currentAnimeNexusVariant = _extractAnimeNexusVariant(stream.url);
      // P0-B: Block until the proxy runtime is confirmed playable.
      await _ensureProxyPlayable();
      // P0-C: Fire-and-forget seek window warmup. The proxy responds
      // immediately (200 ok) and runs actual warmup in the background,
      // so awaiting the HTTP round-trip just adds ~300ms of dead time.
      unawaited(_warmupProxySeekWindow(startPosition));
    } else {
      _currentAnimeNexusProxyBaseUri = null;
      _currentAnimeNexusPlaybackId = null;
      _currentAnimeNexusVariant = null;
    }
    await _configureDecoderForStream(stream);
    _scheduleVideoOutputFallbackCheck(stream);
    if (_isAnimeNexusLoopback(stream.url)) {
      if (startPosition != null && startPosition > Duration.zero) {
        // Trimmed-manifest seek: add seekNonce so the proxy trims both
        // video and audio variant manifests to start at the target segment.
        // mpv's ffmpeg HLS demuxer only re-fetches video segments on native
        // seek, leaving audio stuck — trimmed manifests avoid native seek
        // entirely by letting mpv start at the right segment for all tracks.
        final seekUrl = _appendSeekNonce(stream.url, startPosition);
        _log(
          'anime-nexus-seek-open reopen-with-trimmed-manifest '
          'target=$startPosition seekUrl=$seekUrl',
        );
        await _openAnimeNexusManagedSeekWindow(
          ResolvedStream(
            url: seekUrl,
            qualityLabel: stream.qualityLabel,
            mimeType: stream.mimeType,
            isHls: stream.isHls,
            headers: stream.headers,
          ),
          requestedPosition: startPosition,
          cancellation: cancellation,
        );
        return;
      }
      await _openAnimeNexusInitialStream(stream, cancellation: cancellation);
      return;
    }
    if (stream.isHls &&
        startPosition != null &&
        startPosition > Duration.zero) {
      if (_isAnimeNexusManagedSeekWindow(stream.url)) {
        await _openAnimeNexusManagedSeekWindow(
          stream,
          requestedPosition: startPosition,
          cancellation: cancellation,
        );
        return;
      }
      await _openHlsAtPosition(
        stream,
        startPosition,
        cancellation: cancellation,
        generation: generation,
      );
      return;
    }

    return player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: startPosition,
      ),
      play: true,
    );
  }

  @override
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {
    if (_disposed) {
      return;
    }
    _log(
      'invalidatePendingOpen reason=$reason currentGeneration=$_openGeneration',
    );
    _cancelActiveOpenWaiters(reason);
    _openGeneration++;
    _videoOutputFallbackTimer?.cancel();
    try {
      await player.stop();
    } catch (error) {
      _log('invalidatePendingOpen stop-failed reason=$reason error=$error');
    }
  }

  Future<void> _openAnimeNexusInitialStream(
    ResolvedStream stream, {
    required Future<void> cancellation,
  }) async {
    final generation = _openGeneration;
    _log('anime-nexus-open start url=${stream.url}');
    _throwIfInvalidated(generation);
    await player.stop();
    _throwIfInvalidated(generation);
    await player.open(
      Media(stream.url.toString(), httpHeaders: stream.headers),
      play: true,
    );
    _log(
      'anime-nexus-open opened playing buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
    _throwIfInvalidated(generation);
    await _waitUntilReady(cancellation: cancellation);
    _throwIfInvalidated(generation);
    final warmedUp = await _waitForPlaybackWarmup(
      timeout: const Duration(seconds: 25),
      cancellation: cancellation,
    );
    if (!warmedUp) {
      _throwIfInvalidated(generation);
      throw StateError(
        'Anime Nexus playback did not warm up. '
        'buffering=${player.state.buffering} '
        'position=${player.state.position} '
        'duration=${player.state.duration}',
      );
    }
    _log(
      'anime-nexus-open ready buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
  }

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) {
    if (_disposed) return Future<void>.value();
    if (track.uri != null) {
      return player.setSubtitleTrack(
        SubtitleTrack.uri(
          track.uri.toString(),
          title: track.label,
          language: track.language,
        ),
      );
    }

    return player.setSubtitleTrack(
      SubtitleTrack.data(
        track.data!,
        title: track.label,
        language: track.language,
      ),
    );
  }

  @override
  Future<void> clearSubtitleTrack() {
    if (_disposed) return Future<void>.value();
    return player.setSubtitleTrack(SubtitleTrack.no());
  }

  @override
  Future<void> setEmbeddedAudioTrack(EmbeddedAudioTrack track) {
    if (_disposed) return Future<void>.value();
    _log('setEmbeddedAudioTrack id=${track.id} title=${track.title}');
    return player.setAudioTrack(
      AudioTrack(track.id, track.title, track.language),
    );
  }

  @override
  Future<void> setEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) {
    if (_disposed) return Future<void>.value();
    _log('setEmbeddedSubtitleTrack id=${track.id} title=${track.title}');
    return player.setSubtitleTrack(
      SubtitleTrack(track.id, track.title, track.language),
    );
  }

  @override
  Future<void> clearEmbeddedSubtitleTrack() {
    if (_disposed) return Future<void>.value();
    _log('clearEmbeddedSubtitleTrack');
    return player.setSubtitleTrack(SubtitleTrack.no());
  }

  @override
  Future<void> setPreferredSubtitleLanguages(List<String> languages) async {}

  // media_kit / libmpv exposes quality via HLS variants through a
  // different API (`player.streams.video` + hls-bitrate cap). The
  // desktop player_page does not surface a variant picker yet, so keep
  // both hooks as no-ops until that slice lands.
  @override
  Future<void> setEmbeddedVideoTrack(EmbeddedVideoTrack track) async {}

  @override
  Future<void> clearEmbeddedVideoTrack() async {}

  @override
  Future<void> pause() {
    if (_disposed) return Future<void>.value();
    _log('pause');
    return player.pause();
  }

  @override
  Future<void> play() {
    if (_disposed) return Future<void>.value();
    _log('play');
    return player.play();
  }

  @override
  Future<void> setVolume(double percent) {
    if (_disposed) return Future<void>.value();
    return player.setVolume(percent);
  }

  @override
  Future<void> setPlaybackSpeed(double rate) {
    if (_disposed) return Future<void>.value();
    return player.setRate(rate);
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_disposed) return;
    _log('seekTo position=$position');
    // Fire-and-forget: tell the proxy to pre-warm segments around the target
    // so they're cached by the time mpv's HLS demuxer requests them.
    _signalSeekPrefetch(position);
    // Native seek for all streams.  For Anime Nexus the full manifest is
    // already loaded in mpv (same as hls.js in a browser), so the HLS
    // demuxer can locate the right segment for every track.  This preserves
    // the demuxer cache — no stop/reopen cycle, no bandwidth waste.
    return player.seek(position);
  }

  @override
  Future<void> signalPredictivePrewarm(Duration position) async {
    _log('signalPredictivePrewarm position=$position');
    _signalSeekPrefetch(position);
  }

  void _signalSeekPrefetch(Duration position) {
    final baseUri = _currentAnimeNexusProxyBaseUri;
    final playbackId = _currentAnimeNexusPlaybackId;
    if (baseUri == null || playbackId == null || position <= Duration.zero) {
      return;
    }

    final prefetchQuery = <String, String>{
      'target': position.inMilliseconds.toString(),
    };
    final variant = _currentAnimeNexusVariant;
    if (variant != null) {
      prefetchQuery['variant'] = variant;
    }
    final prefetchUri = baseUri.replace(
      pathSegments: <String>['anime-nexus', playbackId, 'seek-prefetch'],
      queryParameters: prefetchQuery,
    );
    _log('seekPrefetch signal target=$position uri=$prefetchUri');

    // Fire-and-forget — prefetch is best-effort and must not block seek.
    unawaited(
      _proxyClient
          .getUrl(prefetchUri)
          .then((req) => req.close())
          .then((_) {})
          .catchError((_) {}),
    );
  }

  /// P0-B: Ensures the Anime Nexus proxy runtime is in a playable state
  /// before opening a stream.  Calls the proxy's `/ensure-playable` endpoint
  /// and awaits a successful response.  If the proxy is rebuilding its
  /// session, this blocks until the rebuild completes — preventing the player
  /// from opening against a broken auth pipeline.
  Future<void> _ensureProxyPlayable() async {
    final baseUri = _currentAnimeNexusProxyBaseUri;
    final playbackId = _currentAnimeNexusPlaybackId;
    if (baseUri == null || playbackId == null) return;

    final uri = baseUri.replace(
      pathSegments: <String>['anime-nexus', playbackId, 'ensure-playable'],
    );
    _log('ensureProxyPlayable start uri=$uri');
    _log('recovery open blocked waiting for playable runtime');

    try {
      final request = await _proxyClient
          .getUrl(uri)
          .timeout(const Duration(seconds: 18));
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      final statusCode = response.statusCode;
      await response.drain<void>();
      _log('ensureProxyPlayable status=$statusCode');

      if (statusCode != HttpStatus.ok) {
        throw StateError(
          'Anime Nexus proxy runtime not playable: status=$statusCode',
        );
      }
      _log('recovery open allowed');
    } catch (error) {
      _log('ensureProxyPlayable failed error=$error');
      rethrow;
    }
  }

  /// P0-C: Pre-warms the seek window (init segments + target media segments)
  /// before opening a stream.  Calls the proxy's `/warmup-seek-window`
  /// endpoint so the player opens over already-cached content, reducing
  /// initial buffering latency.
  Future<void> _warmupProxySeekWindow(Duration? startPosition) async {
    final baseUri = _currentAnimeNexusProxyBaseUri;
    final playbackId = _currentAnimeNexusPlaybackId;
    if (baseUri == null || playbackId == null) return;
    // Only warm up when seeking to a non-zero position.
    if (startPosition == null || startPosition <= Duration.zero) return;

    final warmupQuery = <String, String>{
      'target': startPosition.inMilliseconds.toString(),
    };
    final variant = _currentAnimeNexusVariant;
    if (variant != null) {
      warmupQuery['variant'] = variant;
    }
    final uri = baseUri.replace(
      pathSegments: <String>['anime-nexus', playbackId, 'warmup-seek-window'],
      queryParameters: warmupQuery,
    );
    _log('warmupProxySeekWindow start target=$startPosition uri=$uri');

    try {
      final request = await _proxyClient
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      await response.drain<void>();
      _log('warmupProxySeekWindow complete status=${response.statusCode}');
    } catch (error) {
      // Warmup is best-effort — don't block open on warmup failure.
      _log('warmupProxySeekWindow failed error=$error');
    }
  }

  @override
  Future<void> setSmartAudioBoost({required bool enabled}) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty('af', enabled ? 'dynaudnorm=f=150:g=15' : '');
    } catch (_) {
      // Best-effort: ignore if MPV property is not available.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _diagnosticsTimer?.cancel();
    _diagnosticsController.close();
    _videoOutputFallbackTimer?.cancel();
    _proxyHttpClient?.close(force: true);
    _proxyHttpClient = null;
    for (final subscription in _debugSubscriptions) {
      await subscription.cancel();
    }
    // Stop playback before disposing to reduce the race window where
    // AndroidVideoController.widListener can trigger a seek on the
    // already-disposed native player (media_kit internal race).
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (e) {
      _debugLogSink?.call('[MediaKitPlaybackEngine] dispose error=$e');
    }
  }

  Future<void> _openHlsAtPosition(
    ResolvedStream stream,
    Duration startPosition, {
    required Future<void> cancellation,
    required int generation,
  }) async {
    _log('hls-reopen start url=${stream.url} target=$startPosition');
    _throwIfInvalidated(generation);
    await player.stop();
    _log('hls-reopen stopped current media');
    _throwIfInvalidated(generation);
    await player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: startPosition,
      ),
      play: true,
    );
    _log(
      'hls-reopen opened playing buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
    _throwIfInvalidated(generation);
    await _waitUntilReady(cancellation: cancellation);
    _throwIfInvalidated(generation);
    final startApplied = await _waitForRequestedStartPosition(
      startPosition,
      cancellation: cancellation,
    );
    _throwIfInvalidated(generation);
    if (startApplied) {
      final playbackReady = await _waitForPlaybackStartConfirmation(
        startPosition,
        cancellation: cancellation,
      );
      _throwIfInvalidated(generation);
      if (playbackReady) {
        _log(
          'hls-reopen start-confirmed target=$startPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position} buffer=${player.state.buffer}',
        );
        return;
      }
      _log(
        'hls-reopen start-confirmation stalled target=$startPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position} buffer=${player.state.buffer}',
      );
      // P6: Single-shot preroll attempt instead of cascading 3 windows
      // (4s → 10s → 20s).  With native-seek-first (R5) this path is
      // rarely reached; when it is, one 10s preroll is sufficient — the
      // cascade added up to 30s of overhead for diminishing returns.
      final prerollStart = _computePrerollStart(
        startPosition,
        const Duration(seconds: 10),
      );
      if (prerollStart < startPosition) {
        _throwIfInvalidated(generation);
        final recovered = await _openHlsFromPreroll(
          stream,
          requestedPosition: startPosition,
          prerollStart: prerollStart,
          cancellation: cancellation,
          generation: generation,
        );
        if (recovered) {
          return;
        }
      }
    }

    _throwIfInvalidated(generation);
    await _waitForPlaybackWarmup(cancellation: cancellation);
    _log(
      'hls-reopen start-property fallback buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
    _throwIfInvalidated(generation);
    await _seekWhenReady(
      startPosition,
      generation: generation,
      cancellation: cancellation,
    );
    _log(
      'hls-reopen seeked buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
  }

  Future<void> _openAnimeNexusManagedSeekWindow(
    ResolvedStream stream, {
    required Duration requestedPosition,
    required Future<void> cancellation,
  }) async {
    final generation = _openGeneration;
    final seekPhaseStart = DateTime.now();
    _log(
      'hls-windowed-reopen start url=${stream.url} requested=$requestedPosition',
    );
    _throwIfInvalidated(generation);
    // O11: Fire warmup-seek-window concurrently with player.stop().
    // player.stop() takes ~100-300ms and is independent of the proxy's
    // warmup work (fetching init segments + target media segments).
    // Overlapping them shaves ~100-300ms off the seek critical path.
    await Future.wait(<Future<void>>[
      player.stop(),
      _warmupProxySeekWindow(requestedPosition),
    ]);
    _throwIfInvalidated(generation);
    final openPhaseStart = DateTime.now();
    await player.open(
      Media(stream.url.toString(), httpHeaders: stream.headers),
      play: true,
    );
    final openElapsed = DateTime.now().difference(openPhaseStart);
    _log(
      'hls-windowed-reopen opened playing buffering=${player.state.buffering} '
      'duration=${player.state.duration} position=${player.state.position}',
    );
    _log(
      'seekLatency phase=player-open-done '
      'elapsed=${openElapsed.inMilliseconds}ms',
    );
    _throwIfInvalidated(generation);
    await _waitUntilReady(cancellation: cancellation);
    final readyElapsed = DateTime.now().difference(seekPhaseStart);
    _log(
      'seekLatency phase=wait-until-ready '
      'elapsed=${readyElapsed.inMilliseconds}ms',
    );
    _throwIfInvalidated(generation);
    // Reduced from 25s → 8s: proxy pre-warms content in background,
    // so if it hasn't arrived in 8s, waiting longer won't help.
    await _waitForPlaybackWarmup(
      timeout: const Duration(seconds: 8),
      cancellation: cancellation,
    );
    final totalElapsed = DateTime.now().difference(seekPhaseStart);
    _log(
      'hls-windowed-reopen ready requested=$requestedPosition '
      'buffering=${player.state.buffering} '
      'duration=${player.state.duration} position=${player.state.position}',
    );
    _log(
      'seekLatency phase=engine-open-complete '
      'total=${totalElapsed.inMilliseconds}ms',
    );
  }

  Future<void> _waitUntilReady({
    Future<void>? cancellation,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (player.state.duration > Duration.zero) {
      _log(
        'waitUntilReady immediate buffering=${player.state.buffering} duration=${player.state.duration}',
      );
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<Duration> durationSub;
    late final StreamSubscription<bool> bufferingSub;
    Timer? timeoutTimer;
    bool sawBuffering = player.state.buffering;

    void complete() {
      if (completer.isCompleted) {
        return;
      }
      completer.complete();
    }

    durationSub = player.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        _log('waitUntilReady duration-ready duration=$duration');
        complete();
      }
    });

    bufferingSub = player.stream.buffering.listen((buffering) {
      if (buffering) {
        sawBuffering = true;
      }
      if (!buffering && sawBuffering && player.state.duration > Duration.zero) {
        _log(
          'waitUntilReady buffering-false duration=${player.state.duration}',
        );
        complete();
      }
    });

    timeoutTimer = Timer(timeout, () {
      _log(
        'waitUntilReady timeout buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      complete();
    });
    if (cancellation != null) {
      unawaited(
        cancellation.then((_) {
          _log(
            'waitUntilReady cancelled buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
          );
          complete();
        }),
      );
    }

    try {
      await completer.future;
    } finally {
      timeoutTimer.cancel();
      await durationSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<void> _seekWhenReady(
    Duration targetPosition, {
    required int generation,
    Future<void>? cancellation,
  }) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      _throwIfInvalidated(generation);
      await player.seek(targetPosition);
      _log(
        'seekWhenReady attempt=$attempt target=$targetPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      final reached = await _waitForPosition(
        targetPosition,
        cancellation: cancellation,
      );
      _throwIfInvalidated(generation);
      if (reached) {
        _log(
          'seekWhenReady reached target=$targetPosition on attempt=$attempt',
        );
        return;
      }
      await _waitUntilReady(
        cancellation: cancellation,
        timeout: const Duration(seconds: 4),
      );
    }
  }

  Future<bool> _waitForPlaybackWarmup({
    Duration timeout = const Duration(seconds: 3),
    Future<void>? cancellation,
  }) async {
    if (player.state.position > Duration.zero && !player.state.buffering) {
      _log(
        'waitForPlaybackWarmup immediate position=${player.state.position} buffering=${player.state.buffering}',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    late final StreamSubscription<bool> bufferingSub;
    Timer? timeoutTimer;
    var buffering = player.state.buffering;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    positionSub = player.stream.position.listen((position) {
      if (position > Duration.zero && !buffering) {
        _log('waitForPlaybackWarmup position=$position');
        complete(true);
      }
    });

    bufferingSub = player.stream.buffering.listen((next) {
      buffering = next;
      if (!next && player.state.position > Duration.zero) {
        _log(
          'waitForPlaybackWarmup buffering-false position=${player.state.position}',
        );
        complete(true);
      }
    });

    timeoutTimer = Timer(timeout, () {
      _log(
        'waitForPlaybackWarmup timeout position=${player.state.position} buffering=${player.state.buffering}',
      );
      complete(false);
    });
    if (cancellation != null) {
      unawaited(
        cancellation.then((_) {
          _log(
            'waitForPlaybackWarmup cancelled position=${player.state.position} buffering=${player.state.buffering}',
          );
          complete(false);
        }),
      );
    }

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<bool> _waitForRequestedStartPosition(
    Duration targetPosition, {
    Future<void>? cancellation,
  }) async {
    if (_isPositionNear(player.state.position, targetPosition)) {
      _log(
        'waitForRequestedStartPosition immediate target=$targetPosition position=${player.state.position}',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    late final StreamSubscription<bool> bufferingSub;
    Timer? timeoutTimer;
    var buffering = player.state.buffering;
    final observationStart = DateTime.now();

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    bool looksLikePlaybackStartedFromBeginning(Duration position) {
      if (targetPosition <= const Duration(seconds: 15)) {
        return false;
      }
      if (buffering) {
        return false;
      }
      if (player.state.duration <= Duration.zero) {
        return false;
      }
      if (DateTime.now().difference(observationStart) <
          const Duration(milliseconds: 1500)) {
        return false;
      }
      return position > Duration.zero && position < const Duration(seconds: 3);
    }

    positionSub = player.stream.position.listen((position) {
      if (_isPositionNear(position, targetPosition)) {
        _log(
          'waitForRequestedStartPosition reached target=$targetPosition position=$position',
        );
        complete(true);
        return;
      }
      if (looksLikePlaybackStartedFromBeginning(position)) {
        _log(
          'waitForRequestedStartPosition fallback-from-beginning target=$targetPosition position=$position',
        );
        complete(false);
      }
    });

    bufferingSub = player.stream.buffering.listen((next) {
      buffering = next;
      final position = player.state.position;
      if (_isPositionNear(position, targetPosition)) {
        _log(
          'waitForRequestedStartPosition buffering-update reached target=$targetPosition position=$position',
        );
        complete(true);
        return;
      }
      if (looksLikePlaybackStartedFromBeginning(position)) {
        _log(
          'waitForRequestedStartPosition buffering-update fallback-from-beginning target=$targetPosition position=$position',
        );
        complete(false);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      _log(
        'waitForRequestedStartPosition timeout target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} duration=${player.state.duration}',
      );
      complete(false);
    });
    if (cancellation != null) {
      unawaited(
        cancellation.then((_) {
          _log(
            'waitForRequestedStartPosition cancelled target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} duration=${player.state.duration}',
          );
          complete(false);
        }),
      );
    }

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<bool> _waitForPlaybackStartConfirmation(
    Duration targetPosition, {
    Future<void>? cancellation,
  }) async {
    if (_hasPlayableStartState(targetPosition)) {
      _log(
        'waitForPlaybackStartConfirmation immediate target=$targetPosition position=${player.state.position} buffer=${player.state.buffer}',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    late final StreamSubscription<bool> bufferingSub;
    late final StreamSubscription<Duration> bufferSub;
    late final StreamSubscription<Duration> durationSub;
    Timer? timeoutTimer;
    Timer? pollTimer;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    void checkState(String source) {
      if (_hasPlayableStartState(targetPosition)) {
        _log(
          'waitForPlaybackStartConfirmation ready source=$source target=$targetPosition position=${player.state.position} buffer=${player.state.buffer} buffering=${player.state.buffering}',
        );
        complete(true);
      }
    }

    positionSub = player.stream.position.listen((position) {
      checkState('position');
    });

    bufferingSub = player.stream.buffering.listen((_) {
      checkState('buffering');
    });

    bufferSub = player.stream.buffer.listen((_) {
      checkState('buffer');
    });

    durationSub = player.stream.duration.listen((_) {
      checkState('duration');
    });

    pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _log(
        'progress-poll playing=${player.state.playing} buffering=${player.state.buffering} completed=${player.state.completed} position=${player.state.position} duration=${player.state.duration} buffer=${player.state.buffer} percent=${player.state.bufferingPercentage}',
      );
    });

    timeoutTimer = Timer(const Duration(seconds: 6), () {
      _log(
        'waitForPlaybackStartConfirmation timeout target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} completed=${player.state.completed} buffer=${player.state.buffer} percent=${player.state.bufferingPercentage}',
      );
      complete(false);
    });
    if (cancellation != null) {
      unawaited(
        cancellation.then((_) {
          _log(
            'waitForPlaybackStartConfirmation cancelled target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} completed=${player.state.completed} buffer=${player.state.buffer}',
          );
          complete(false);
        }),
      );
    }

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      pollTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
      await bufferSub.cancel();
      await durationSub.cancel();
    }
  }

  Future<bool> _openHlsFromPreroll(
    ResolvedStream stream, {
    required Duration requestedPosition,
    required Duration prerollStart,
    required Future<void> cancellation,
    required int generation,
  }) async {
    _log(
      'hls-reopen preroll start requested=$requestedPosition preroll=$prerollStart',
    );
    _throwIfInvalidated(generation);
    await player.stop();
    _throwIfInvalidated(generation);
    await player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: prerollStart,
      ),
      play: true,
    );
    await _waitUntilReady(cancellation: cancellation);
    final prerollApplied = await _waitForRequestedStartPosition(
      prerollStart,
      cancellation: cancellation,
    );
    if (!prerollApplied) {
      _log(
        'hls-reopen preroll failed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    final playbackReady = await _waitForPlaybackStartConfirmation(
      prerollStart,
      cancellation: cancellation,
    );
    if (!playbackReady) {
      _log(
        'hls-reopen preroll stalled requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    await _seekWhenReady(
      requestedPosition,
      generation: generation,
      cancellation: cancellation,
    );
    final seekApplied = await _waitForPosition(
      requestedPosition,
      cancellation: cancellation,
    );
    if (!seekApplied) {
      _log(
        'hls-reopen preroll seek-failed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    _log(
      'hls-reopen preroll completed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
    );
    return true;
  }

  Duration _computePrerollStart(
    Duration targetPosition,
    Duration prerollWindow,
  ) {
    if (targetPosition <= prerollWindow) {
      return Duration.zero;
    }
    return targetPosition - prerollWindow;
  }

  Future<bool> _waitForPosition(
    Duration targetPosition, {
    Future<void>? cancellation,
  }) async {
    if (_isPositionNear(player.state.position, targetPosition)) {
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    Timer? timeoutTimer;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    positionSub = player.stream.position.listen((position) {
      if (_isPositionNear(position, targetPosition)) {
        _log(
          'waitForPosition reached position=$position target=$targetPosition',
        );
        complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 2), () {
      _log(
        'waitForPosition timeout position=${player.state.position} target=$targetPosition buffering=${player.state.buffering}',
      );
      complete(false);
    });
    if (cancellation != null) {
      unawaited(
        cancellation.then((_) {
          _log(
            'waitForPosition cancelled position=${player.state.position} target=$targetPosition buffering=${player.state.buffering}',
          );
          complete(false);
        }),
      );
    }

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError(
        'MediaKitPlaybackEngine was disposed during hls-reopen sequence.',
      );
    }
  }

  /// Generation-aware guard.  Aborts stale open/reopen sequences when the
  /// engine is disposed **or** a newer `open()` call has been initiated.
  void _throwIfInvalidated(int generation) {
    _throwIfDisposed();
    if (generation != _openGeneration) {
      throw StateError(
        'MediaKitPlaybackEngine open sequence invalidated '
        '(generation=$generation current=$_openGeneration).',
      );
    }
  }

  bool _isPositionNear(Duration actual, Duration expected) {
    return (actual - expected).inSeconds.abs() <= 2;
  }

  bool _hasPlayableStartState(Duration targetPosition) {
    if (player.state.duration <= Duration.zero ||
        player.state.buffering ||
        player.state.completed) {
      return false;
    }

    final position = player.state.position;
    if (position > targetPosition + const Duration(milliseconds: 400)) {
      return true;
    }
    if (!_isPositionNear(position, targetPosition) || !player.state.playing) {
      return false;
    }

    // Some sources report conservative/lagging buffer values even when mpv is
    // already decoding smoothly from the requested target. Treat near-target,
    // non-buffering playback as confirmed to avoid unnecessary reopen cascades.
    if (position > Duration.zero) {
      return true;
    }

    final buffer = player.state.buffer;
    return buffer > position + const Duration(milliseconds: 400) ||
        buffer > targetPosition + const Duration(milliseconds: 400) ||
        player.state.bufferingPercentage >= 95;
  }

  int _beginOpenSequence() {
    _cancelActiveOpenWaiters('superseded-by-new-open');
    return ++_openGeneration;
  }

  void _cancelActiveOpenWaiters(String reason) {
    if (!_openCancellationCompleter.isCompleted) {
      _log('open-sequence-cancel reason=$reason generation=$_openGeneration');
      _openCancellationCompleter.complete();
    }
    _openCancellationCompleter = Completer<void>();
  }

  Future<void> _configureDecoderForStream(ResolvedStream stream) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }

    final isAnimeNexus = _isAnimeNexusLoopback(stream.url);
    // Zilla serves AV1-in-fMP4 (ftyp brand av01 verified in runtime probe).
    // auto-safe stalls for 12-37 s logging "Could not open codec" before
    // falling back to software dav1d. Pure software (hwdec=no) skips the
    // fallback dance but cannot keep up with 1080p AV1 on mid-tier SoCs
    // (Helio G99), which stalls after rendering the first I-frame.
    // Force mediacodec-copy: uses Android's c2.android.av1-dav1d decoder
    // (software underneath but with MediaCodec's tighter platform
    // integration), avoiding both the codec-open stall and the pure-libav
    // throughput wall.
    final isZillaAv1 = stream.url.host.contains('zilla-networks');
    // On Android the device has no AV1 HW decoder (verified on Helio G99),
    // so auto-safe burns 12-37 s attempting MediaCodec before falling back
    // to libdav1d. Force software up front for Zilla; everywhere else let
    // mpv pick the best HW path.
    final hwdecValue = isZillaAv1
        ? (defaultTargetPlatform == TargetPlatform.android ? 'no' : 'auto-safe')
        : 'auto-safe';

    try {
      final cores = Platform.numberOfProcessors;
      // Zilla AV1 on Android needs every core + loop-filter skip to decode
      // 1080p in real time on Helio G99 class SoCs. Baseline (non-Zilla)
      // keeps cores-1 so the UI thread always has headroom.
      final decodeThreads =
          (isZillaAv1 && defaultTargetPlatform == TargetPlatform.android)
          ? cores.clamp(1, 8)
          : (cores > 2 ? cores - 1 : 1);

      final properties = <Future<void>>[
        // R2: Use auto-safe everywhere — mpv picks the best hw decoder
        // (mediacodec on Android, d3d11va on Windows) and falls back to
        // software automatically.  The old anime-nexus hwdec='no' forced
        // software decode even on 1080p+ which caused low FPS.
        platform.setProperty('hwdec', hwdecValue),
        platform.setProperty('vd-lavc-software-fallback', 'yes'),
        // R2: Use multi-threaded software decoding as fallback.  cores-1
        // avoids starving the Flutter UI thread; Zilla AV1 overrides this
        // and takes all cores because decode is the bottleneck.
        platform.setProperty('vd-lavc-threads', '$decodeThreads'),
        // Force precise seeking to the exact requested timestamp instead of
        // snapping to the previous keyframe — prevents blocky/corrupted
        // frames that appear when the decoder starts mid-GOP.
        // R2: Use 'default' — mpv uses hr-seek for short seeks (< ~60s)
        // and keyframe seek for long jumps, balancing accuracy vs speed.
        platform.setProperty('hr-seek', 'default'),
        // Keep all frames during a seek instead of dropping them — avoids
        // visual glitches (green/grey flash) while decoding catches up.
        platform.setProperty('hr-seek-framedrop', 'no'),
        // Lock video presentation to the audio clock for smooth playback
        // and correct A/V sync after seeks.
        platform.setProperty('video-sync', 'audio'),
      ];

      // Zilla AV1 on Android: force the dav1d-perf cocktail.
      // - vd-lavc-skiploopfilter=all: skips the AV1 deblocking loop filter,
      //   cutting ~25-35% of decode CPU with only minor edge ringing.
      // - vd-lavc-skipframe=nonref: drop non-reference frames when behind
      //   (B-frame equivalents); preserves I/P frames so visual continuity
      //   is kept even when the decoder cannot keep up.
      // - vd-lavc-fast=yes: enable all non-bitexact codec optimizations.
      // - framedrop=vo: drop frames at the output stage when the decoder
      //   falls behind audio, instead of letting the whole pipeline stall.
      // - cache-secs=30 / demuxer-readahead-secs=30: give the decoder a
      //   generous runway of fetched data so it can batch-decode and catch
      //   up during the slow warmup of libdav1d.
      if (isZillaAv1 && defaultTargetPlatform == TargetPlatform.android) {
        properties.addAll(<Future<void>>[
          platform.setProperty('vd-lavc-skiploopfilter', 'all'),
          platform.setProperty('vd-lavc-skipframe', 'nonref'),
          platform.setProperty('vd-lavc-fast', 'yes'),
          platform.setProperty('framedrop', 'vo'),
          platform.setProperty('cache', 'yes'),
          platform.setProperty('cache-secs', '30'),
          platform.setProperty('demuxer-readahead-secs', '30'),
        ]);
      }

      // Effectively unlimited demuxer buffers on all platforms.  Rotating-host
      // CDNs (Desu) force a new TCP+TLS handshake per segment; small buffers
      // leave no slack to absorb the overhead and stall playback.  Values
      // below are a hard ceiling — mpv only allocates what it actually needs
      // for the active readahead window.
      if (defaultTargetPlatform == TargetPlatform.android) {
        properties.add(platform.setProperty('demuxer-max-bytes', '512MiB'));
        properties.add(
          platform.setProperty('demuxer-max-back-bytes', '256MiB'),
        );
      } else {
        properties.add(platform.setProperty('demuxer-max-bytes', '2GiB'));
        properties.add(platform.setProperty('demuxer-max-back-bytes', '1GiB'));
      }

      // R2: Non-anime-nexus streams also benefit from a seekable demuxer
      // cache and generous readahead to reduce re-fetching on backward seek.
      if (!isAnimeNexus) {
        properties.add(platform.setProperty('demuxer-seekable-cache', 'yes'));
        // Readahead window raised to ~1h so mpv keeps pre-fetching as long
        // as there is bandwidth headroom.  Combined with the 512 MiB demuxer
        // ceiling this absorbs long handshake-heavy sequences on rotating
        // CDN hosts without starving playback.
        properties.add(platform.setProperty('demuxer-readahead-secs', '3600'));
        // R5: Start decoding immediately instead of waiting for the buffer
        // to fill.  Non-AN streams typically resolve to direct or CDN URLs
        // with good throughput; stalling for initial cache fill adds 1-3s
        // of unnecessary latency before the first frame.
        properties.add(platform.setProperty('cache-pause-initial', 'no'));
        // R5: Disable cache-induced pause after seeks.  mpv's default
        // cache-pause-wait (1s) makes every seek feel sluggish because the
        // player pauses until the cache refills.  The seek-stall watch in
        // the orchestrator provides a safer timeout mechanism.
        properties.add(platform.setProperty('cache-pause', 'no'));
        // R6 (mobile buffering fix): tune ffmpeg/lavf network stack for
        // real-world CDNs (StreamWish, Pixeldrain, Zilla, Okru…). Without
        // these overrides a ~5 s read timeout plus no reconnect means a
        // single WiFi power-save dip or CDN TCP RST stalls playback until
        // the orchestrator reopens (multi-second gap). The anime-nexus
        // branch below already uses a similar set against the loopback
        // proxy.
        //
        // - timeout=30s: ffmpeg read/write timeout per operation
        // - rw_timeout=15s: socket RW timeout (guards against silent stalls)
        // - reconnect + reconnect_streamed: transparently rebuild the TCP
        //   connection on drops instead of propagating EOF to the demuxer
        // - reconnect_on_network_error + reconnect_on_http_error: cover
        //   edge/CDN 5xx retries
        // - reconnect_delay_max=5s: cap backoff so stalls stay short
        // - http_persistent=1: HTTP/1.1 keep-alive so HLS segment fetches
        //   reuse the same TCP/TLS session instead of re-handshaking every
        //   ~10 s — the main source of stutter on mobile Chromium-less
        //   stacks.
        properties.add(
          platform.setProperty(
            'demuxer-lavf-o',
            'timeout=30000000,rw_timeout=15000000,'
                'reconnect=1,reconnect_streamed=1,'
                'reconnect_on_network_error=1,reconnect_on_http_error=4xx+5xx,'
                'reconnect_delay_max=5,http_persistent=1,'
                // http_multiple=1: open HLS segment N+1 in parallel while N
                // still decodes — critical on rotating-host CDNs (Desu)
                // where keepalive cannot be reused across segments.
                // http_seekable=0: skip the initial Range probe on segment
                // opens — segments are fetched whole, the probe just burns
                // one extra RTT per segment.
                'http_multiple=1,http_seekable=0',
          ),
        );
        // Mirror the ffmpeg timeout at the mpv network-timeout level so
        // non-lavf code paths (stream protocols handled by mpv directly,
        // e.g. raw https reads) share the same budget.
        properties.add(platform.setProperty('network-timeout', '30'));
        // Stream-level read buffer: small increase from the 512 KiB mpv
        // default reduces read() syscalls on mobile without harming
        // latency. Keeps first-frame unchanged.
        properties.add(platform.setProperty('stream-buffer-size', '1MiB'));
      }

      if (isAnimeNexus) {
        // Allow the demuxer to read ~2.5 minutes ahead so playback stays
        // smooth while the proxy pre-fetches segments in the background.
        properties.add(platform.setProperty('demuxer-readahead-secs', '150'));
        // Raise ffmpeg's HTTP read timeout from 5 s to 30 s and enable
        // HTTP keep-alive for connections to the localhost proxy.
        properties.add(
          platform.setProperty(
            'demuxer-lavf-o',
            'timeout=30000000,http_persistent=1',
          ),
        );
        // Start decoding immediately instead of waiting for the buffer to
        // fill — the proxy pre-warms init segments and first media segments
        // so data is already available when mpv begins requesting it.
        properties.add(platform.setProperty('cache-pause-initial', 'no'));
        // O12: Disable cache-induced pause entirely.  The proxy guarantees
        // pre-warmed content for both initial open and seeks, so mpv should
        // never stall waiting for cache to fill.  cache-pause-wait defaults
        // to 1s which adds unnecessary latency after every seek.
        properties.add(platform.setProperty('cache-pause', 'no'));
        // Keep a seekable demuxer cache so backward seeks within
        // already-downloaded content are near-instant without re-fetching.
        properties.add(platform.setProperty('demuxer-seekable-cache', 'yes'));
      }

      await Future.wait(properties);

      _log(
        'decoder-config hwdec=$hwdecValue platform=$defaultTargetPlatform '
        'animeNexus=$isAnimeNexus zillaAv1=$isZillaAv1',
      );
    } catch (error) {
      _log('decoder-config failed error=$error');
    }
  }

  bool _isAnimeNexusLoopback(Uri url) {
    if (!(url.host == '127.0.0.1' || url.host == 'localhost')) {
      return false;
    }
    return url.pathSegments.contains('anime-nexus');
  }

  String? _extractAnimeNexusPlaybackId(Uri url) {
    final segments = url.pathSegments;
    final idx = segments.indexOf('anime-nexus');
    if (idx < 0 || idx + 1 >= segments.length) return null;
    return segments[idx + 1];
  }

  /// Extracts the variant from an anime-nexus proxy URL.
  ///
  /// URL format: /anime-nexus/{playbackId}/master/{variant}/{track}.m3u8
  String? _extractAnimeNexusVariant(Uri url) {
    final segments = url.pathSegments;
    final idx = segments.indexOf('master');
    if (idx < 0 || idx + 1 >= segments.length) return null;
    return segments[idx + 1];
  }

  bool _isAnimeNexusManagedSeekWindow(Uri url) {
    if (!_isAnimeNexusLoopback(url)) {
      return false;
    }
    if (!url.queryParameters.containsKey('seekNonce')) {
      return false;
    }
    return true;
  }

  /// Appends `seekNonce` query parameter to an anime-nexus master URL.
  /// The proxy uses this to serve trimmed variant manifests starting at
  /// the target segment — ensuring both video and audio tracks initialize
  /// from the seek position.
  Uri _appendSeekNonce(Uri url, Duration position) {
    return url.replace(
      queryParameters: <String, String>{
        ...url.queryParameters,
        'seekNonce': position.inMilliseconds.toString(),
      },
    );
  }

  bool _shouldUseSoftwareVideoOutput() {
    return _forceSoftwareVideoOutput;
  }

  String? _preferredVideoOutput() {
    if (!Platform.isLinux) {
      return null;
    }
    final candidate = _linuxVideoOutput.trim();
    if (candidate.isEmpty) {
      return null;
    }
    return candidate;
  }

  String? _preferredHardwareDecoder() {
    if (!Platform.isLinux) {
      return null;
    }
    final candidate = _linuxHwdec.trim();
    if (candidate.isEmpty) {
      return null;
    }
    return candidate;
  }

  void _attachVideoControllerDebugStreams() {
    if (!kDebugMode) {
      return;
    }

    void logTexture() {
      _log('video-controller textureId=${videoController.id.value}');
    }

    void logRect() {
      _log('video-controller rect=${videoController.rect.value}');
    }

    videoController.id.addListener(logTexture);
    videoController.rect.addListener(logRect);

    _debugSubscriptions.add(
      Stream<void>.fromFuture(
        videoController.waitUntilFirstFrameRendered,
      ).listen(
        (_) {
          _firstFrameRendered = true;
          if (!_firstFrameCompleter.isCompleted) {
            _firstFrameCompleter.complete();
          }
          _videoOutputFallbackTimer?.cancel();
          _log(
            'video-controller first-frame-rendered rect=${videoController.rect.value} textureId=${videoController.id.value}',
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          _log('video-controller first-frame error=$error');
        },
      ),
    );
  }

  void _scheduleVideoOutputFallbackCheck(ResolvedStream stream) {
    _videoOutputFallbackTimer?.cancel();
    if (_disposed || _forceSoftwareVideoOutput || _firstFrameRendered) {
      return;
    }
    if (!(defaultTargetPlatform == TargetPlatform.windows &&
        _isAnimeNexusLoopback(stream.url))) {
      return;
    }
    _videoOutputFallbackTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed || _firstFrameRendered || _videoOutputFallbackTriggered) {
        return;
      }
      // Grace period: let the event loop process any pending first-frame
      // events that may have been scheduled in the same cycle as this timer.
      _videoOutputFallbackTimer = Timer(const Duration(milliseconds: 500), () {
        if (_disposed || _firstFrameRendered || _videoOutputFallbackTriggered) {
          return;
        }
        _videoOutputFallbackTriggered = true;
        _log(
          'video-output-fallback-requested reason=no_first_frame textureId=${videoController.id.value} rect=${videoController.rect.value}',
        );
        _videoOutputFallbackSink?.call('no_first_frame');
      });
    });
  }

  void _attachNativeDebugStreams() {
    if (!kDebugMode || !_verboseNativePlayerLogs) {
      return;
    }

    _debugSubscriptions.add(
      player.stream.log.listen((event) {
        final lower = '${event.prefix} ${event.level} ${event.text}'
            .toLowerCase();
        // Suppress known benign mpv/platform messages that are not actionable.
        const suppressed = [
          'failed to create egl surface',
          'property not found',
          'failed to create file cache',
          'reading plaintext playlist',
        ];
        if (suppressed.any((p) => lower.contains(p))) {
          return;
        }
        final shouldLog =
            event.level == 'error' ||
            event.level == 'warn' ||
            lower.contains('eof') ||
            lower.contains('cache') ||
            lower.contains('buffer') ||
            lower.contains('segment') ||
            lower.contains('hls') ||
            lower.contains('http') ||
            lower.contains('tcp') ||
            lower.contains('demux');
        if (!shouldLog) {
          return;
        }
        _log(
          'native-log prefix=${event.prefix} level=${event.level} text=${event.text}',
        );
      }),
    );

    _debugSubscriptions.add(
      player.stream.buffer.listen((buffer) {
        if (!player.state.buffering && buffer <= Duration.zero) {
          return;
        }
        _log(
          'native-buffer time=$buffer percent=${player.state.bufferingPercentage} position=${player.state.position} duration=${player.state.duration}',
        );
      }),
    );

    _debugSubscriptions.add(
      player.stream.bufferingPercentage.listen((percentage) {
        if (!player.state.buffering && percentage <= 0) {
          return;
        }
        _log(
          'native-buffering percent=$percentage buffer=${player.state.buffer} position=${player.state.position} duration=${player.state.duration}',
        );
      }),
    );
  }

  void _log(String message) {
    if (!kDebugMode || !_playerVerboseLogs) {
      return;
    }
    final formatted =
        '[player.engine#$_instanceId ${DateTime.now().toIso8601String()}] '
        '$message';
    debugPrint(formatted);
    _debugLogSink?.call(formatted);
  }
}
