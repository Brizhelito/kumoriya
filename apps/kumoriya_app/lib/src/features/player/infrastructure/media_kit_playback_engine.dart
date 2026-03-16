import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../application/services/playback_engine.dart';

final class MediaKitPlaybackEngine implements PlaybackEngine {
  static const List<Duration> _hlsPrerollWindows = <Duration>[
    Duration(seconds: 4),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  MediaKitPlaybackEngine({
    void Function(String message)? onDebugLog,
    void Function(String reason)? onVideoOutputFallbackRequested,
    bool forceSoftwareVideoOutput = false,
  }) : _debugLogSink = onDebugLog,
       _videoOutputFallbackSink = onVideoOutputFallbackRequested,
       _forceSoftwareVideoOutput = forceSoftwareVideoOutput,
       player = Player(
         configuration: PlayerConfiguration(
           logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.error,
           bufferSize: 128 * 1024 * 1024,
         ),
       ) {
    final useSoftwareVideoOutput = _shouldUseSoftwareVideoOutput();
    videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !useSoftwareVideoOutput,
      ),
    );
    _log(
      'video-controller-config softwareOutput=$useSoftwareVideoOutput platform=$defaultTargetPlatform',
    );
    _attachVideoControllerDebugStreams();
    _attachNativeDebugStreams();
  }

  final Player player;
  late final VideoController videoController;
  final void Function(String message)? _debugLogSink;
  final void Function(String reason)? _videoOutputFallbackSink;
  final bool _forceSoftwareVideoOutput;
  bool _disposed = false;
  int _openGeneration = 0;
  bool _firstFrameRendered = false;
  bool _videoOutputFallbackTriggered = false;
  Timer? _videoOutputFallbackTimer;
  Uri? _currentAnimeNexusProxyBaseUri;
  String? _currentAnimeNexusPlaybackId;
  String? _currentAnimeNexusVariant;
  /// Base master URL for the current anime-nexus stream, without query params.
  /// Used by seekTo() to rebuild the URL with a fresh seekNonce.
  Uri? _currentAnimeNexusMasterUri;
  final List<StreamSubscription<dynamic>> _debugSubscriptions =
      <StreamSubscription<dynamic>>[];
  late final String _instanceId = identityHashCode(this).toRadixString(16);

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
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    final generation = ++_openGeneration;
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
      // Store the base master URL (sans seekNonce) so seekTo() can rebuild it.
      _currentAnimeNexusMasterUri = stream.url.replace(queryParameters: <String, String>{});
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
      _currentAnimeNexusMasterUri = null;
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
        );
        return;
      }
      await _openAnimeNexusInitialStream(stream);
      return;
    }
    if (stream.isHls &&
        startPosition != null &&
        startPosition > Duration.zero) {
      if (_isAnimeNexusManagedSeekWindow(stream.url)) {
        await _openAnimeNexusManagedSeekWindow(
          stream,
          requestedPosition: startPosition,
        );
        return;
      }
      await _openHlsAtPosition(stream, startPosition);
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

  Future<void> _openAnimeNexusInitialStream(ResolvedStream stream) async {
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
    await _waitUntilReady();
    _throwIfInvalidated(generation);
    final warmedUp = await _waitForPlaybackWarmup(
      timeout: const Duration(seconds: 25),
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
    return player.setSubtitleTrack(SubtitleTrack.no());
  }

  @override
  Future<void> pause() {
    _log('pause');
    return player.pause();
  }

  @override
  Future<void> play() {
    _log('play');
    return player.play();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _log('seekTo position=$position');
    _signalSeekPrefetch(position);
    if (_currentAnimeNexusProxyBaseUri != null) {
      // Anime Nexus multi-track HLS: reopen with trimmed manifest instead
      // of native seek.  mpv's ffmpeg HLS demuxer does not re-fetch audio
      // segments on native seek — only video — leaving playback stuck in
      // buffering forever.  Reopening with seekNonce makes the proxy trim
      // both audio and video manifests so mpv initialises all tracks from
      // the target position.
      final seekUrl = _buildAnimeNexusSeekUrl(position);
      if (seekUrl != null) {
        _log(
          'seekTo anime-nexus-reopen target=$position seekUrl=$seekUrl',
        );
        await _openAnimeNexusManagedSeekWindow(
          ResolvedStream(
            url: seekUrl,
            isHls: true,
          ),
          requestedPosition: position,
        );
        return;
      }
      // Fallback: if we can't build the seek URL, try native seek.
      await _seekWhenReady(position);
      return;
    }
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

    final prefetchUri = baseUri.replace(
      pathSegments: <String>['anime-nexus', playbackId, 'seek-prefetch'],
      queryParameters: <String, String>{
        'target': position.inMilliseconds.toString(),
        if (_currentAnimeNexusVariant != null)
          'variant': _currentAnimeNexusVariant!,
      },
    );
    _log('seekPrefetch signal target=$position uri=$prefetchUri');

    // Fire-and-forget — prefetch is best-effort and must not block seek.
    unawaited(
      HttpClient()
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
      final client = HttpClient();
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 18));
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      final statusCode = response.statusCode;
      await response.drain<void>();
      client.close(force: false);
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

    final uri = baseUri.replace(
      pathSegments: <String>['anime-nexus', playbackId, 'warmup-seek-window'],
      queryParameters: <String, String>{
        'target': startPosition.inMilliseconds.toString(),
        if (_currentAnimeNexusVariant != null)
          'variant': _currentAnimeNexusVariant!,
      },
    );
    _log('warmupProxySeekWindow start target=$startPosition uri=$uri');

    try {
      final client = HttpClient();
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      await response.drain<void>();
      client.close(force: false);
      _log('warmupProxySeekWindow complete status=${response.statusCode}');
    } catch (error) {
      // Warmup is best-effort — don't block open on warmup failure.
      _log('warmupProxySeekWindow failed error=$error');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _videoOutputFallbackTimer?.cancel();
    for (final subscription in _debugSubscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
  }

  Future<void> _openHlsAtPosition(
    ResolvedStream stream,
    Duration startPosition,
  ) async {
    final generation = _openGeneration;
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
    await _waitUntilReady();
    _throwIfInvalidated(generation);
    final startApplied = await _waitForRequestedStartPosition(startPosition);
    _throwIfInvalidated(generation);
    if (startApplied) {
      final progressed = await _waitForPlaybackProgressFromTarget(
        startPosition,
      );
      _throwIfInvalidated(generation);
      if (progressed) {
        _log(
          'hls-reopen start-property progressed target=$startPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
        );
        return;
      }
      _log(
        'hls-reopen start-property stalled target=$startPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      for (final window in _hlsPrerollWindows) {
        final prerollStart = _computePrerollStart(startPosition, window);
        if (prerollStart < startPosition) {
          _throwIfInvalidated(generation);
          final recovered = await _openHlsFromPreroll(
            stream,
            requestedPosition: startPosition,
            prerollStart: prerollStart,
          );
          if (recovered) {
            return;
          }
        }
      }
    }

    _throwIfInvalidated(generation);
    await _waitForPlaybackWarmup();
    _log(
      'hls-reopen start-property fallback buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
    _throwIfInvalidated(generation);
    await _seekWhenReady(startPosition);
    _log(
      'hls-reopen seeked buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
  }

  Future<void> _openAnimeNexusManagedSeekWindow(
    ResolvedStream stream, {
    required Duration requestedPosition,
  }) async {
    final generation = _openGeneration;
    final seekPhaseStart = DateTime.now();
    _log(
      'hls-windowed-reopen start url=${stream.url} requested=$requestedPosition',
    );
    _throwIfInvalidated(generation);
    await player.stop();
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
    await _waitUntilReady();
    final readyElapsed = DateTime.now().difference(seekPhaseStart);
    _log(
      'seekLatency phase=wait-until-ready '
      'elapsed=${readyElapsed.inMilliseconds}ms',
    );
    _throwIfInvalidated(generation);
    // Reduced from 25s → 8s: proxy pre-warms content in background,
    // so if it hasn't arrived in 8s, waiting longer won't help.
    await _waitForPlaybackWarmup(timeout: const Duration(seconds: 8));
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

  Future<void> _waitUntilReady() async {
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

    timeoutTimer = Timer(const Duration(seconds: 25), () {
      _log(
        'waitUntilReady timeout buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      complete();
    });

    try {
      await completer.future;
    } finally {
      timeoutTimer.cancel();
      await durationSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<void> _seekWhenReady(Duration targetPosition) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      _throwIfDisposed();
      await player.seek(targetPosition);
      _log(
        'seekWhenReady attempt=$attempt target=$targetPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      final reached = await _waitForPosition(targetPosition);
      if (reached) {
        _log(
          'seekWhenReady reached target=$targetPosition on attempt=$attempt',
        );
        return;
      }
      await _waitUntilReady();
    }
  }

  Future<bool> _waitForPlaybackWarmup({
    Duration timeout = const Duration(seconds: 3),
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

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<bool> _waitForRequestedStartPosition(Duration targetPosition) async {
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

    timeoutTimer = Timer(const Duration(seconds: 6), () {
      _log(
        'waitForRequestedStartPosition timeout target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} duration=${player.state.duration}',
      );
      complete(false);
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<bool> _waitForPlaybackProgressFromTarget(
    Duration targetPosition,
  ) async {
    if (player.state.position >
        targetPosition + const Duration(milliseconds: 400)) {
      _log(
        'waitForPlaybackProgressFromTarget immediate target=$targetPosition position=${player.state.position}',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    Timer? timeoutTimer;
    Timer? pollTimer;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    positionSub = player.stream.position.listen((position) {
      if (position > targetPosition + const Duration(milliseconds: 400)) {
        _log(
          'waitForPlaybackProgressFromTarget advanced target=$targetPosition position=$position',
        );
        complete(true);
      }
    });

    pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _log(
        'progress-poll playing=${player.state.playing} buffering=${player.state.buffering} completed=${player.state.completed} position=${player.state.position} duration=${player.state.duration} buffer=${player.state.buffer} percent=${player.state.bufferingPercentage}',
      );
    });

    timeoutTimer = Timer(const Duration(seconds: 6), () {
      _log(
        'waitForPlaybackProgressFromTarget timeout target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} completed=${player.state.completed} buffer=${player.state.buffer} percent=${player.state.bufferingPercentage}',
      );
      complete(false);
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      pollTimer.cancel();
      await positionSub.cancel();
    }
  }

  Future<bool> _openHlsFromPreroll(
    ResolvedStream stream, {
    required Duration requestedPosition,
    required Duration prerollStart,
  }) async {
    final generation = _openGeneration;
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
    await _waitUntilReady();
    final prerollApplied = await _waitForRequestedStartPosition(prerollStart);
    if (!prerollApplied) {
      _log(
        'hls-reopen preroll failed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    final progressed = await _waitForPlaybackProgressFromTarget(prerollStart);
    if (!progressed) {
      _log(
        'hls-reopen preroll stalled requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    await _seekWhenReady(requestedPosition);
    final seekApplied = await _waitForPosition(requestedPosition);
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

  Future<bool> _waitForPosition(Duration targetPosition) async {
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

  Future<void> _configureDecoderForStream(ResolvedStream stream) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      return;
    }

    final isAnimeNexus = _isAnimeNexusLoopback(stream.url);
    final hwdec =
        isAnimeNexus &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.windows)
        ? 'no'
        : 'auto-safe';

    try {
      final properties = <Future<void>>[
        platform.setProperty('hwdec', hwdec),
        platform.setProperty('vd-lavc-software-fallback', 'yes'),
      ];

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
        // Keep a seekable demuxer cache so backward seeks within
        // already-downloaded content are near-instant without re-fetching.
        properties.add(platform.setProperty('demuxer-seekable-cache', 'yes'));
      }

      await Future.wait(properties);

      _log(
        'decoder-config hwdec=$hwdec platform=$defaultTargetPlatform animeNexus=$isAnimeNexus',
      );
    } catch (error) {
      _log('decoder-config failed hwdec=$hwdec error=$error');
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

  /// Builds an anime-nexus master URL with seekNonce from the stored master URI.
  /// Preserves the original variant/track path so the proxy routes correctly.
  /// Returns null if no stream is currently open.
  Uri? _buildAnimeNexusSeekUrl(Duration position) {
    final masterUri = _currentAnimeNexusMasterUri;
    if (masterUri == null) return null;
    return _appendSeekNonce(masterUri, position);
  }

  bool _shouldUseSoftwareVideoOutput() {
    return _forceSoftwareVideoOutput;
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
    if (!kDebugMode) {
      return;
    }

    _debugSubscriptions.add(
      player.stream.log.listen((event) {
        final lower = '${event.prefix} ${event.level} ${event.text}'
            .toLowerCase();
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
    if (!kDebugMode) {
      return;
    }
    final formatted =
        '[player.engine#$_instanceId ${DateTime.now().toIso8601String()}] '
        '$message';
    debugPrint(formatted);
    _debugLogSink?.call(formatted);
  }
}
