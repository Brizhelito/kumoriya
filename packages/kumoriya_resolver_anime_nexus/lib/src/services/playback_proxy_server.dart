import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../services/hls_manifest_parser.dart';
import '../services/playback_session_worker.dart';
import '../utils/nexus_constants.dart';

/// Runtime readiness states for the Anime Nexus session lifecycle.
///
/// Used by [NexusPlaybackProxySession.ensurePlayable] to decide whether the
/// session can serve content immediately or must wait for a rebuild.
enum RuntimeReadiness { idle, building, playable, degraded, failed }

final class NexusPlaybackProxySession {
  NexusPlaybackProxySession({
    required this.playbackId,
    required this.dio,
    required this.episodeId,
    required this.videoId,
    required this.fingerprint,
    required this.candidateHosts,
    required this.masterManifest,
    required this.worker,
    void Function(String message)? onDebugLog,
  }) : _debugLogSink = onDebugLog;

  final String playbackId;
  final Dio dio;
  final String episodeId;
  final String videoId;
  final String fingerprint;
  final List<String> candidateHosts;
  final NexusMasterManifest masterManifest;
  final NexusPlaybackSessionWorker worker;
  final void Function(String message)? _debugLogSink;
  final Map<String, Future<_FetchedManifest>> _variantManifestCache =
      <String, Future<_FetchedManifest>>{};
  final Map<String, Future<_FetchedManifest>> _seekPrefetchCache =
      <String, Future<_FetchedManifest>>{};
  final Map<String, Future<Response<List<int>>>> _initSegmentCache =
      <String, Future<Response<List<int>>>>{};
  final Map<String, Future<Response<List<int>>>> _mediaSegmentCache =
      <String, Future<Response<List<int>>>>{};

  String? edgeHost;
  String? _sessionId;
  DateTime lastAccessed = DateTime.now();
  int _lastProgressSegmentIndex = -1;

  /// When `true`, the session is in the middle of a seek and the first
  /// target segment has not yet been served. During this window,
  /// [_prefetchNextSegments] is deferred to avoid competing with the
  /// critical seek-target segment delivery.
  bool _seekPrefetchActive = false;

  /// Current readiness of the underlying WS runtime.
  RuntimeReadiness _readiness = RuntimeReadiness.playable;

  /// Singleflight rebuild future.  All concurrent callers that need a
  /// playable runtime await the same [Future] instead of spawning
  /// parallel rebuilds.
  Future<void>? _rebuildFuture;

  /// Circuit breaker: consecutive auth failures trigger exponential backoff
  /// to avoid thrashing rebuilds when authentication is persistently failing.
  int _authFailureCount = 0;
  DateTime? _authFailureBackoffUntil;

  void touch() {
    lastAccessed = DateTime.now();
  }

  Future<void> reportProgress(int segmentIndex) async {
    if (segmentIndex <= _lastProgressSegmentIndex) {
      return;
    }
    _lastProgressSegmentIndex = segmentIndex;
    _log('reportProgress segmentIndex=$segmentIndex');
    try {
      await worker.sendProgress(segmentIndex: segmentIndex);
    } catch (_) {
      // Progress is advisory; segment delivery takes priority.
    }
  }

  /// Ensures the session runtime is in a playable state.
  ///
  /// Uses a **singleflight** pattern: if a rebuild is already in progress,
  /// all concurrent callers await the same [Future] instead of spawning
  /// parallel rebuilds.  The critical data path (master / init / segment
  /// handlers) calls this instead of the old debounced `ensureReady`.
  Future<void> ensurePlayable() async {
    // Circuit breaker: if auth is persistently failing, reject immediately.
    final backoffUntil = _authFailureBackoffUntil;
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil)) {
      _log(
        'ensurePlayable circuit-breaker active '
        'failures=$_authFailureCount backoffUntil=$backoffUntil',
      );
      throw StateError(
        'Anime Nexus auth circuit-breaker active: '
        '$_authFailureCount consecutive failures, '
        'retry after $backoffUntil',
      );
    }

    // Fast path: runtime is confirmed playable and no rebuild pending.
    if (_readiness == RuntimeReadiness.playable && _rebuildFuture == null) {
      _log('ensurePlayable fast-path playable');
      return;
    }

    // Join an existing rebuild if one is already in flight.
    final existing = _rebuildFuture;
    if (existing != null) {
      _log('ensurePlayable join existing rebuild');
      await existing;
      return;
    }

    // Start a new rebuild.
    _log('ensurePlayable start rebuild readiness=$_readiness');
    final future = _doRebuild(forceReconnect: true, requestResetStream: false);
    _rebuildFuture = future;
    try {
      await future;
    } finally {
      if (identical(_rebuildFuture, future)) {
        _rebuildFuture = null;
      }
    }
  }

  /// Triggers a session refresh and ensures the runtime is rebuilt.
  ///
  /// Called by fetch retry loops when a data-path operation detects that the
  /// current session/auth is broken.  Uses the singleflight rebuild future
  /// so concurrent callers coalesce behind a single reconstruction.
  Future<void> refreshRuntime({bool requestResetStream = false}) async {
    _log(
      'refreshRuntime requestResetStream=$requestResetStream '
      'readiness=$_readiness',
    );
    _lastProgressSegmentIndex = -1;
    _readiness = RuntimeReadiness.degraded;

    // If a rebuild is already in flight, join it instead of starting another.
    final existing = _rebuildFuture;
    if (existing != null) {
      _log('refreshRuntime join existing rebuild');
      await existing;
      return;
    }

    final future = _doRebuild(
      forceReconnect: true,
      requestResetStream: requestResetStream,
    );
    _rebuildFuture = future;
    try {
      await future;
    } finally {
      if (identical(_rebuildFuture, future)) {
        _rebuildFuture = null;
      }
    }
  }

  /// Internal rebuild implementation shared by [ensurePlayable] and
  /// [refreshRuntime].  Only one instance runs at a time per session.
  ///
  /// Soft handover: the old [_sessionId] is kept alive until the new session
  /// is validated, so in-flight requests using cached tokens can still
  /// complete against the CDN.
  Future<void> _doRebuild({
    required bool forceReconnect,
    required bool requestResetStream,
  }) async {
    final previousReadiness = _readiness;
    _readiness = RuntimeReadiness.building;
    _log(
      'rebuildRuntime start forceReconnect=$forceReconnect '
      'requestResetStream=$requestResetStream '
      'previousReadiness=$previousReadiness',
    );
    try {
      if (requestResetStream) {
        await worker.refreshSession(requestResetStream: true);
      } else {
        await worker.ensureReady(forceReconnect: forceReconnect);
      }

      // Validate the rebuilt session by obtaining a fresh session ID.
      // Only update _sessionId after validation succeeds (soft handover).
      final sessionId = await worker.getSessionId();
      _sessionId = sessionId;
      edgeHost = null;
      _authFailureCount = 0;
      _authFailureBackoffUntil = null;
      _readiness = RuntimeReadiness.playable;
      _log('rebuildRuntime authenticated sessionId=$sessionId');
      _log('rebuildRuntime playable');
    } catch (error) {
      _readiness = RuntimeReadiness.failed;
      _sessionId = null;
      edgeHost = null;
      if (_isAuthError(error)) {
        _authFailureCount++;
        _authFailureBackoffUntil = DateTime.now().add(
          _computeAuthBackoff(_authFailureCount),
        );
        _log(
          'rebuildRuntime auth-circuit-breaker '
          'failures=$_authFailureCount '
          'backoffUntil=$_authFailureBackoffUntil',
        );
      }
      _log('rebuildRuntime failed error=$error');
      rethrow;
    }
  }

  static bool _isAuthError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('authentication failed') ||
        msg.contains('auth failed') ||
        msg.contains('unauthorized') ||
        msg.contains('invalid session') ||
        msg.contains('session expired');
  }

  static Duration _computeAuthBackoff(int failureCount) {
    final capped = failureCount.clamp(1, 10);
    // 3s → 6s → 12s → 24s → 30s cap
    final seconds = min(30, 3 * (1 << (capped - 1)));
    return Duration(seconds: seconds);
  }

  Future<String> ensureSessionId() async {
    final cached = _sessionId?.trim() ?? '';
    if (cached.isNotEmpty) {
      _log('ensureSessionId cached sessionId=$cached');
      return cached;
    }
    final sessionId = await worker.getSessionId();
    _sessionId = sessionId;
    _log('ensureSessionId fetched sessionId=$sessionId');
    return sessionId;
  }

  NexusVideoStreamEntry? findVideoStream({
    required String variant,
    required int track,
  }) {
    for (final stream in masterManifest.streamEntries) {
      if (stream.metadata.variant == variant &&
          stream.metadata.track == track) {
        return stream;
      }
    }
    return null;
  }

  NexusAudioTrackEntry? findAudioStream({
    required String variant,
    required int track,
  }) {
    for (final stream in masterManifest.audioEntries) {
      if (stream.metadata.variant == variant &&
          stream.metadata.track == track) {
        return stream;
      }
    }
    return null;
  }

  Future<_FetchedManifest> getOrCreateVariantManifest({
    required String variant,
    required int track,
    required Future<_FetchedManifest> Function() loader,
  }) {
    final cacheKey = '$variant:$track';
    final existing = _variantManifestCache[cacheKey];
    if (existing != null) {
      return existing;
    }

    final future = loader();
    _variantManifestCache[cacheKey] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (_) {
          if (identical(_variantManifestCache[cacheKey], future)) {
            _variantManifestCache.remove(cacheKey);
          }
        },
      ),
    );
    return future;
  }

  Future<Response<List<int>>> getOrCreateInitSegment({
    required String path,
    required Future<Response<List<int>>> Function() loader,
  }) {
    final existing = _initSegmentCache[path];
    if (existing != null) return existing;
    final future = loader();
    _initSegmentCache[path] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (_) {
          if (identical(_initSegmentCache[path], future)) {
            _initSegmentCache.remove(path);
          }
        },
      ),
    );
    return future;
  }

  Future<Response<List<int>>> getOrCreateMediaSegment({
    required String cacheKey,
    required Future<Response<List<int>>> Function() loader,
  }) {
    final existing = _mediaSegmentCache[cacheKey];
    if (existing != null) return existing;
    final future = loader();
    _mediaSegmentCache[cacheKey] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (_) {
          if (identical(_mediaSegmentCache[cacheKey], future)) {
            _mediaSegmentCache.remove(cacheKey);
          }
        },
      ),
    );
    return future;
  }

  void _log(String message) {
    _debugLogSink?.call('[anime-nexus.proxy:$playbackId] $message');
  }
}

final class NexusPlaybackProxyServer {
  NexusPlaybackProxyServer._();

  static final NexusPlaybackProxyServer instance = NexusPlaybackProxyServer._();

  HttpServer? _server;
  Timer? _cleanupTimer;
  final Map<String, NexusPlaybackProxySession> _sessions =
      <String, NexusPlaybackProxySession>{};

  Future<void> registerSession(NexusPlaybackProxySession session) async {
    await _ensureStarted();
    _sessions[session.playbackId] = session;
    session._log(
      'registerSession server=${_server?.address.address}:${_server?.port}',
    );
  }

  Future<void> primeStream({
    required NexusPlaybackProxySession session,
    required NexusVideoStreamEntry stream,
  }) async {
    session._log(
      'primeStream variant=${stream.metadata.variant} track=${stream.metadata.track}',
    );
    await session.ensurePlayable();
    final manifests = await Future.wait(
      _variantManifestFutures(session: session, stream: stream),
    );

    // After variant manifests are fetched, prefetch init segments and the
    // first media segment for each track.  These are the next resources the
    // HLS demuxer will request — having them cached eliminates ~4-8s of
    // sequential WS-token + CDN round-trips from the open path.
    _prefetchInitAndFirstSegments(
      session: session,
      variant: stream.metadata.variant,
      manifests: manifests,
    );
  }

  Future<void> shutdown() async {
    final cleanupTimer = _cleanupTimer;
    _cleanupTimer = null;
    cleanupTimer?.cancel();

    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();
    for (final session in sessions) {
      await session.worker.close();
    }

    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Uri qualityMasterUri({
    required NexusPlaybackProxySession session,
    required NexusVideoStreamEntry stream,
  }) {
    final server = _server;
    if (server == null) {
      throw StateError('Proxy server must be started before building URLs.');
    }

    return Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      pathSegments: <String>[
        'anime-nexus',
        session.playbackId,
        'master',
        stream.metadata.variant,
        '${stream.metadata.track}.m3u8',
      ],
    );
  }

  Future<void> _ensureStarted() async {
    if (_server != null) {
      return;
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest, onError: (_) {});
    _cleanupTimer ??= Timer.periodic(
      const Duration(minutes: 2),
      (_) => _evictExpiredSessions(),
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments;
      if (segments.length < 3 || segments.first != 'anime-nexus') {
        _writeText(
          request.response,
          statusCode: HttpStatus.notFound,
          body: 'Not found',
        );
        return;
      }

      final session = _sessions[segments[1]];
      if (session == null) {
        _writeText(
          request.response,
          statusCode: HttpStatus.gone,
          body: 'Playback session expired',
        );
        return;
      }

      session.touch();
      session._log(
        'request route=${segments[2]} path=${request.uri.path} query=${request.uri.query}',
      );
      switch (segments[2]) {
        case 'master':
          await _serveMasterManifest(request, session, segments);
          return;
        case 'variant':
          await _serveVariantManifest(request, session, segments);
          return;
        case 'init':
          await _serveInitSegment(request, session, segments);
          return;
        case 'segment':
          await _serveMediaSegment(request, session, segments);
          return;
        case 'seek-prefetch':
          await _handleSeekPrefetch(request, session);
          return;
        case 'ensure-playable':
          await _handleEnsurePlayable(request, session);
          return;
        case 'warmup-seek-window':
          await _handleWarmupSeekWindow(request, session);
          return;
        default:
          _writeText(
            request.response,
            statusCode: HttpStatus.notFound,
            body: 'Unknown route',
          );
      }
    } catch (error) {
      _writeText(
        request.response,
        statusCode: HttpStatus.internalServerError,
        body: 'Anime Nexus proxy failure: $error',
      );
    }
  }

  Future<void> _serveMasterManifest(
    HttpRequest request,
    NexusPlaybackProxySession session,
    List<String> segments,
  ) async {
    try {
      await session.ensurePlayable().timeout(const Duration(seconds: 15));
    } catch (error) {
      throw StateError('Anime Nexus master ensurePlayable failed: $error');
    }
    final variant = segments[3];
    final track = _parseTerminalInt(segments[4]);
    final stream = session.findVideoStream(variant: variant, track: track);
    if (stream == null) {
      _writeText(
        request.response,
        statusCode: HttpStatus.notFound,
        body: 'Unknown quality stream',
      );
      return;
    }

    final matchingAudio = _matchingAudioStreams(
      session: session,
      stream: stream,
    );
    session._log(
      'serveMasterManifest variant=$variant track=$track audio=${matchingAudio.length}',
    );

    // Extract seekNonce from query parameters to pass to warmup.
    // If seekNonce is present, the orchestrator is opening for a seek,
    // and we should NOT prefetch segments 0-2 (the seek-prefetch path
    // handles segment warming with absolute CDN indices).
    final seekNonceStr = request.uri.queryParameters['seekNonce'];
    final seekTargetMs = seekNonceStr != null
        ? int.tryParse(seekNonceStr)
        : null;

    _startVariantPrewarm(
      session: session,
      videoStream: stream,
      audioStreams: matchingAudio,
      seekTargetMs: seekTargetMs,
    );

    final lines = <String>['#EXTM3U'];
    for (final audio in matchingAudio) {
      lines.add(
        _replaceMediaUri(
          audio.originalLine,
          _variantUri(
            request,
            session: session,
            variant: audio.metadata.variant,
            track: audio.metadata.track,
          ).toString(),
        ),
      );
    }
    lines.add(stream.infoLine);
    lines.add(
      _variantUri(
        request,
        session: session,
        variant: stream.metadata.variant,
        track: stream.metadata.track,
      ).toString(),
    );

    _writeManifest(request.response, lines.join('\n'));
  }

  Future<void> _serveVariantManifest(
    HttpRequest request,
    NexusPlaybackProxySession session,
    List<String> segments,
  ) async {
    try {
      await session.ensurePlayable().timeout(const Duration(seconds: 15));
    } catch (error) {
      throw StateError('Anime Nexus variant ensurePlayable failed: $error');
    }
    final variant = segments[3];
    final track = _parseTerminalInt(segments[4]);
    final seekTargetMs = _parseSeekTargetMs(request.requestedUri);
    session._log(
      'serveVariantManifest variant=$variant track=$track seekTargetMs=$seekTargetMs',
    );
    final Future<_FetchedManifest> Function() loader = () =>
        _loadVariantManifest(
          session: session,
          variant: variant,
          track: track,
          request: request,
        );

    _FetchedManifest manifest;
    if (seekTargetMs != null) {
      // Check if a prefetch for this exact seek is already in flight.
      final prefetchKey = '$variant:$track:$seekTargetMs';
      final prefetched = session._seekPrefetchCache.remove(prefetchKey);
      manifest = prefetched != null ? await prefetched : await loader();

      // When serving the video variant (track=0) on seek, proactively
      // start fetching the sibling audio variant so it is ready when
      // mpv requests it next.  Saves ~1.5s of sequential latency.
      if (track == 0) {
        _prefetchSiblingAudioVariantForSeek(
          session: session,
          variant: variant,
          seekTargetMs: seekTargetMs,
          request: request,
        );
      }
    } else {
      manifest = await session.getOrCreateVariantManifest(
        variant: variant,
        track: track,
        loader: loader,
      );
    }
    _writeManifest(request.response, manifest.body);
  }

  void _prefetchInitAndFirstSegments({
    required NexusPlaybackProxySession session,
    required String variant,
    required List<_FetchedManifest> manifests,
    int? seekTargetMs,
  }) {
    // When called during a seek, the seek-prefetch path (_doSegmentSeekPrefetch)
    // already handles segment warming using absolute CDN indices.  Fetching
    // segments 0/1/2 here would be wrong — those are the start-of-stream
    // segments, not the seek-target segments.
    if (seekTargetMs != null) {
      session._log(
        'prefetchInitAndFirstSegments skip seekTargetMs=$seekTargetMs — seek path handles segment warming',
      );
      return;
    }

    // Derive init and first-segment CDN paths from each variant manifest URI.
    // Pattern:  <base>_<variant>-<track>.m3u8
    //   init:   <base>_<variant>_init-<track>.mp4
    //   seg 0:  <base>_<variant>_0000-<track>.m4s
    for (final manifest in manifests) {
      final manifestPath = manifest.uri.path;
      final match = RegExp(r'_(\d+)-(\d+)\.m3u8$').firstMatch(manifestPath);
      if (match == null) continue;

      final v = match.group(1)!;
      final t = match.group(2)!;
      final trackInt = int.tryParse(t) ?? 0;
      final basePath = manifestPath.substring(0, match.start);

      final initPath = '${basePath}_${v}_init-$t.mp4';

      session._log('prefetch init=$initPath track=$t');

      unawaited(
        session
            .getOrCreateInitSegment(
              path: initPath,
              loader: () => _fetchManifestProtectedBytes(
                session: session,
                path: initPath,
              ),
            )
            .then<void>((_) {}, onError: (_) {}),
      );

      // Prefetch segments 0-2 so ffmpeg has ~12s of content cached per track.
      for (var segIdx = 0; segIdx < 3; segIdx++) {
        final padded = segIdx.toString().padLeft(4, '0');
        final segPath = '${basePath}_${v}_$padded-$t.m4s';
        final segCacheKey = '$v:$trackInt:$segIdx';
        unawaited(
          session
              .getOrCreateMediaSegment(
                cacheKey: segCacheKey,
                loader: () => _fetchSegmentWithRetry(
                  session: session,
                  variant: v,
                  track: trackInt,
                  segmentIndex: segIdx,
                  path: segPath,
                ),
              )
              .then<void>((_) {}, onError: (_) {}),
        );
      }
    }
  }

  void _prefetchNextSegments({
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    required int currentSegmentIndex,
    required String currentPath,
  }) {
    // Prefetch the next 2 segments for this track so they are cached when
    // ffmpeg requests them.  This overlaps WS-token + CDN fetch time with
    // the current segment's delivery, letting the buffer grow faster.
    for (var delta = 1; delta <= 2; delta++) {
      final nextIndex = currentSegmentIndex + delta;
      final nextPath = _deriveSegmentPath(currentPath, nextIndex);
      if (nextPath == null) continue;
      final cacheKey = '$variant:$track:$nextIndex';
      unawaited(
        session
            .getOrCreateMediaSegment(
              cacheKey: cacheKey,
              loader: () => _fetchSegmentWithRetry(
                session: session,
                variant: variant,
                track: track,
                segmentIndex: nextIndex,
                path: nextPath,
              ),
            )
            .then<void>((_) {
              session._log(
                'prefetchNext hit variant=$variant track=$track seg=$nextIndex',
              );
            }, onError: (_) {}),
      );
    }
  }

  String? _deriveSegmentPath(String currentPath, int targetIndex) {
    // Segment paths follow: <base>_<variant>_<NNNN>-<track>.m4s
    final match = RegExp(r'_(\d{4})-(\d+)\.(m4s)$').firstMatch(currentPath);
    if (match == null) return null;
    final padded = targetIndex.toString().padLeft(4, '0');
    return '${currentPath.substring(0, match.start)}_$padded-${match.group(2)}.${match.group(3)}';
  }

  void _prefetchSiblingAudioVariantForSeek({
    required NexusPlaybackProxySession session,
    required String variant,
    required int seekTargetMs,
    required HttpRequest request,
  }) {
    final videoStream = session.findVideoStream(variant: variant, track: 0);
    if (videoStream == null || videoStream.audioGroupId == null) {
      return;
    }
    final audioStream = session.masterManifest.audioEntries
        .where((audio) => audio.groupId == videoStream.audioGroupId)
        .firstOrNull;
    if (audioStream == null) {
      return;
    }
    final audioTrack = audioStream.metadata.track;
    final prefetchKey = '$variant:$audioTrack:$seekTargetMs';
    if (session._seekPrefetchCache.containsKey(prefetchKey)) {
      return;
    }
    session._log(
      'prefetchSiblingAudio variant=$variant audioTrack=$audioTrack seekTargetMs=$seekTargetMs',
    );
    final future = _loadVariantManifest(
      session: session,
      variant: audioStream.metadata.variant,
      track: audioTrack,
      request: request,
    );
    session._seekPrefetchCache[prefetchKey] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (_) {
          session._seekPrefetchCache.remove(prefetchKey);
        },
      ),
    );
  }

  void _startVariantPrewarm({
    required NexusPlaybackProxySession session,
    required NexusVideoStreamEntry videoStream,
    required List<NexusAudioTrackEntry> audioStreams,
    int? seekTargetMs,
  }) {
    unawaited(
      Future.wait(
        _variantManifestFutures(
          session: session,
          stream: videoStream,
          audioStreams: audioStreams,
        ),
      ).then<void>(
        (manifests) {
          // Variant manifests are cached — now kick off init segments and
          // first media segments so they are ready when ffmpeg asks for them.
          _prefetchInitAndFirstSegments(
            session: session,
            variant: videoStream.metadata.variant,
            manifests: manifests,
            seekTargetMs: seekTargetMs,
          );
        },
        onError: (_) {
          // Warmup is best-effort. Foreground variant requests retry on demand.
        },
      ),
    );
  }

  List<NexusAudioTrackEntry> _matchingAudioStreams({
    required NexusPlaybackProxySession session,
    required NexusVideoStreamEntry stream,
  }) {
    if (stream.audioGroupId == null) {
      return const <NexusAudioTrackEntry>[];
    }

    return session.masterManifest.audioEntries
        .where((audio) => audio.groupId == stream.audioGroupId)
        .toList(growable: false);
  }

  List<Future<_FetchedManifest>> _variantManifestFutures({
    required NexusPlaybackProxySession session,
    required NexusVideoStreamEntry stream,
    List<NexusAudioTrackEntry>? audioStreams,
  }) {
    final matchingAudio =
        audioStreams ?? _matchingAudioStreams(session: session, stream: stream);

    return <Future<_FetchedManifest>>[
      session.getOrCreateVariantManifest(
        variant: stream.metadata.variant,
        track: stream.metadata.track,
        loader: () => _loadVariantManifest(
          session: session,
          variant: stream.metadata.variant,
          track: stream.metadata.track,
        ),
      ),
      ...matchingAudio.map(
        (audio) => session.getOrCreateVariantManifest(
          variant: audio.metadata.variant,
          track: audio.metadata.track,
          loader: () => _loadVariantManifest(
            session: session,
            variant: audio.metadata.variant,
            track: audio.metadata.track,
          ),
        ),
      ),
    ];
  }

  Future<_FetchedManifest> _loadVariantManifest({
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    HttpRequest? request,
  }) async {
    final videoEntry = session.findVideoStream(variant: variant, track: track);
    final audioEntry = session.findAudioStream(variant: variant, track: track);
    final manifestPath = videoEntry?.uri.path ?? audioEntry?.uri.path;
    final manifestHost = videoEntry?.uri.host ?? audioEntry?.uri.host;
    if (manifestPath == null) {
      throw StateError('Unknown Anime Nexus variant manifest: $variant/$track');
    }

    final manifest = await _fetchSignedManifest(
      session: session,
      manifestPath: manifestPath,
      preferredHost: manifestHost,
    );
    final seekTargetMs = _parseSeekTargetMs(request?.requestedUri);
    session._log(
      'loadVariantManifest variant=$variant track=$track manifestPath=$manifestPath realUri=${manifest.uri} seekTargetMs=$seekTargetMs',
    );
    final baseUri = manifest.uri.replace(query: '');
    final rewritten = _rewriteVariantManifest(
      request: request,
      session: session,
      variant: variant,
      track: track,
      manifestBody: manifest.body,
      baseUri: baseUri,
      seekTargetMs: seekTargetMs,
    );

    return _FetchedManifest(body: rewritten, uri: manifest.uri);
  }

  Future<void> _serveInitSegment(
    HttpRequest request,
    NexusPlaybackProxySession session,
    List<String> segments,
  ) async {
    await session.ensurePlayable().timeout(const Duration(seconds: 15));
    final path = request.uri.queryParameters['path']?.trim() ?? '';
    if (path.isEmpty) {
      _writeText(
        request.response,
        statusCode: HttpStatus.badRequest,
        body: 'Missing init path',
      );
      return;
    }
    session._log('serveInitSegment path=$path');

    final upstream = await session.getOrCreateInitSegment(
      path: path,
      loader: () => _fetchManifestProtectedBytes(session: session, path: path),
    );
    await _writeBinary(
      request.response,
      statusCode: upstream.statusCode ?? HttpStatus.badGateway,
      body: upstream.data ?? const <int>[],
      contentType:
          upstream.headers.value(Headers.contentTypeHeader) ??
          'application/octet-stream',
      contentLength: upstream.data?.length,
    );
  }

  Future<void> _serveMediaSegment(
    HttpRequest request,
    NexusPlaybackProxySession session,
    List<String> segments,
  ) async {
    await session.ensurePlayable().timeout(const Duration(seconds: 15));
    final variant = segments[3];
    final track = _parseTerminalInt(segments[4]);
    final localSegmentIndex = _parseTerminalInt(segments[5]);
    final path = request.uri.queryParameters['path']?.trim() ?? '';
    if (path.isEmpty) {
      _writeText(
        request.response,
        statusCode: HttpStatus.badRequest,
        body: 'Missing segment path',
      );
      return;
    }

    final effectiveVariant = _parseVariantFromMediaPath(path) ?? variant;
    final effectiveTrack = _parseTrackFromMediaPath(path) ?? track;

    // Task 3.2: Parse absolute CDN index from path= query parameter
    // instead of using local playlist ordinal from URL path.
    // Example: path=%2Fanime%2F...mkv_1600_0175-1.m4s → absolute index 175
    // This fixes the bug where seek-prefetch collapsed to absoluteTarget=0
    // when the real seek was near segments 175/176.
    final absoluteSegmentIndex = _parseSegmentIndexFromCdnPath(path);
    final segmentIndex = absoluteSegmentIndex ?? localSegmentIndex;

    // CRITICAL: If seek target is high (> 100) and we couldn't parse absolute
    // index from CDN path, log error. Silent collapse to 0 was a key symptom.
    if (absoluteSegmentIndex == null && localSegmentIndex > 100) {
      session._log(
        'serveMediaSegment no-absolute-source localIndex=$localSegmentIndex '
        'path=$path — using local ordinal (may be incorrect for windowed playlist)',
      );
    }

    session._log(
      'serveMediaSegment variant=$effectiveVariant track=$effectiveTrack '
      'segmentIndex=$segmentIndex (absolute=${absoluteSegmentIndex ?? "null"} '
      'local=$localSegmentIndex) path=$path',
    );

    final segmentCacheKey = '$effectiveVariant:$effectiveTrack:$segmentIndex';
    final upstream = await session.getOrCreateMediaSegment(
      cacheKey: segmentCacheKey,
      loader: () => _fetchSegmentWithRetry(
        session: session,
        variant: effectiveVariant,
        track: effectiveTrack,
        segmentIndex: segmentIndex,
        path: path,
      ),
    );

    // Defer prefetch during seek critical path — the first segment served
    // after a seek should not trigger 4 extra concurrent fetches (2 per track)
    // that compete with the actual target segment delivery.
    if (session._seekPrefetchActive) {
      session._log(
        'prefetchNext deferred — seek prefetch active '
        'variant=$effectiveVariant track=$effectiveTrack seg=$segmentIndex',
      );
      session._seekPrefetchActive = false;
    } else {
      _prefetchNextSegments(
        session: session,
        variant: effectiveVariant,
        track: effectiveTrack,
        currentSegmentIndex: segmentIndex,
        currentPath: path,
      );
    }

    await _writeBinary(
      request.response,
      statusCode: upstream.statusCode ?? HttpStatus.badGateway,
      body: upstream.data ?? const <int>[],
      contentType:
          upstream.headers.value(Headers.contentTypeHeader) ??
          'application/octet-stream',
      contentLength: upstream.data?.length,
    );
  }

  Future<void> _handleSeekPrefetch(
    HttpRequest request,
    NexusPlaybackProxySession session,
  ) async {
    final targetMs = int.tryParse(request.uri.queryParameters['target'] ?? '');
    if (targetMs == null || targetMs <= 0) {
      _writeText(request.response, statusCode: HttpStatus.ok, body: 'no-op');
      return;
    }

    // Extract active variant from query params if provided by the engine.
    final activeVariant = request.uri.queryParameters['variant'];

    // Respond immediately — prefetch runs in background.
    _writeText(request.response, statusCode: HttpStatus.ok, body: 'ok');
    session._log(
      'seekPrefetch targetMs=$targetMs activeVariant=$activeVariant',
    );
    session._seekPrefetchActive = true;

    // Find the matching stream for the active variant, or fall back to first.
    NexusVideoStreamEntry? videoStream;
    if (activeVariant != null && activeVariant.isNotEmpty) {
      videoStream = session.masterManifest.streamEntries
          .where((s) => s.metadata.variant == activeVariant)
          .firstOrNull;
      if (videoStream == null) {
        session._log(
          'seekPrefetch variant-miss activeVariant=$activeVariant '
          '— falling back to first stream',
        );
      }
    }
    videoStream ??= session.masterManifest.streamEntries.firstOrNull;
    if (videoStream == null) return;

    final variant = videoStream.metadata.variant;
    session._log(
      'seekQuality seekPrefetch resolvedVariant=$variant '
      'requestedVariant=$activeVariant',
    );

    // Collect tracks to prefetch: video + sibling audio.
    final tracksToWarm = <({String variant, int track})>[
      (variant: variant, track: videoStream.metadata.track),
    ];
    if (videoStream.audioGroupId != null) {
      for (final audio in session.masterManifest.audioEntries) {
        if (audio.groupId == videoStream.audioGroupId) {
          tracksToWarm.add((
            variant: audio.metadata.variant,
            track: audio.metadata.track,
          ));
        }
      }
    }

    for (final info in tracksToWarm) {
      _prefetchSegmentsAtPosition(
        session: session,
        variant: info.variant,
        track: info.track,
        targetMs: targetMs,
      );
    }
  }

  Future<void> _handleEnsurePlayable(
    HttpRequest request,
    NexusPlaybackProxySession session,
  ) async {
    session._log('handleEnsurePlayable readiness=${session._readiness}');
    try {
      await session.ensurePlayable().timeout(const Duration(seconds: 15));
      session._log('handleEnsurePlayable → playable');
      _writeText(request.response, statusCode: HttpStatus.ok, body: 'playable');
    } catch (error) {
      session._log('handleEnsurePlayable failed error=$error');
      _writeText(
        request.response,
        statusCode: HttpStatus.serviceUnavailable,
        body: 'Runtime not playable: $error',
      );
    }
  }

  Future<void> _handleWarmupSeekWindow(
    HttpRequest request,
    NexusPlaybackProxySession session,
  ) async {
    final targetMs = int.tryParse(request.uri.queryParameters['target'] ?? '');
    // Fix C: Extract active variant from query parameters if provided
    final activeVariant = request.uri.queryParameters['variant'];

    session._log(
      'warmupSeekWindow start targetMs=$targetMs activeVariant=$activeVariant',
    );

    try {
      // Safety gate — session should already be playable when this is called
      // after ensure-playable, but re-check for race-condition resilience.
      await session.ensurePlayable().timeout(const Duration(seconds: 15));

      // Find the video stream matching the active variant, or fall back.
      NexusVideoStreamEntry? videoStream;
      if (activeVariant != null && activeVariant.isNotEmpty) {
        videoStream = session.masterManifest.streamEntries
            .where((s) => s.metadata.variant == activeVariant)
            .firstOrNull;
        if (videoStream == null) {
          session._log(
            'warmupSeekWindow variant-miss activeVariant=$activeVariant '
            '— falling back to first stream',
          );
        }
      }
      videoStream ??= session.masterManifest.streamEntries.firstOrNull;
      if (videoStream == null) {
        session._log('warmupSeekWindow no video stream');
        _writeText(
          request.response,
          statusCode: HttpStatus.ok,
          body: 'no-stream',
        );
        return;
      }

      session._log(
        'seekQuality warmupSeekWindow resolvedVariant=${videoStream.metadata.variant} '
        'requestedVariant=$activeVariant '
        'track=${videoStream.metadata.track} targetMs=$targetMs',
      );

      session._log('warmupSeekWindow accepting immediately to not block seek');
      _writeText(request.response, statusCode: HttpStatus.ok, body: 'ok');
      session._seekPrefetchActive = true;

      final currentStream = videoStream;
      unawaited(
        Future(() async {
          try {
            // 1. Load variant manifests (cached or fresh).
            final manifests = await Future.wait(
              _variantManifestFutures(session: session, stream: currentStream),
            ).timeout(const Duration(seconds: 10));

            // 2. Await init segments — critical for playback start.
            await _warmupInitSegments(
              session: session,
              manifests: manifests,
            ).timeout(const Duration(seconds: 8));

            // 3. Fire-and-forget target segment prefetch (non-blocking).
            if (targetMs != null && targetMs > 0) {
              final variant = currentStream.metadata.variant;
              final tracksToWarm = <({String variant, int track})>[
                (variant: variant, track: currentStream.metadata.track),
              ];
              if (currentStream.audioGroupId != null) {
                for (final audio in session.masterManifest.audioEntries) {
                  if (audio.groupId == currentStream.audioGroupId) {
                    tracksToWarm.add((
                      variant: audio.metadata.variant,
                      track: audio.metadata.track,
                    ));
                  }
                }
              }
              for (final info in tracksToWarm) {
                _prefetchSegmentsAtPosition(
                  session: session,
                  variant: info.variant,
                  track: info.track,
                  targetMs: targetMs,
                );
              }
            }

            session._log(
              'warmupSeekWindow background complete targetMs=$targetMs',
            );
          } catch (error) {
            session._log('warmupSeekWindow background failed error=$error');
          }
        }),
      );
    } catch (error) {
      session._log('warmupSeekWindow error=$error');
      try {
        _writeText(
          request.response,
          statusCode: HttpStatus.ok,
          body: 'partial',
        );
      } catch (_) {}
    }
  }

  /// Awaits init segment loading for all tracks in the given manifests.
  ///
  /// Unlike [_prefetchInitAndFirstSegments] which is fire-and-forget, this
  /// method returns a [Future] that completes when all init segments are
  /// cached.  The player cannot parse media segments without init segments,
  /// so this is a critical-path warmup step.
  Future<void> _warmupInitSegments({
    required NexusPlaybackProxySession session,
    required List<_FetchedManifest> manifests,
  }) async {
    final initFutures = <Future<void>>[];
    for (final manifest in manifests) {
      final manifestPath = manifest.uri.path;
      final match = RegExp(r'_(\d+)-(\d+)\.m3u8$').firstMatch(manifestPath);
      if (match == null) continue;

      final v = match.group(1)!;
      final t = match.group(2)!;
      final basePath = manifestPath.substring(0, match.start);
      final initPath = '${basePath}_${v}_init-$t.mp4';

      session._log('warmupInit init=$initPath');
      initFutures.add(
        session
            .getOrCreateInitSegment(
              path: initPath,
              loader: () => _fetchManifestProtectedBytes(
                session: session,
                path: initPath,
              ),
            )
            .then<void>(
              (_) {
                session._log('warmupInit cached init=$initPath');
              },
              onError: (error) {
                session._log('warmupInit failed init=$initPath error=$error');
              },
            ),
      );
    }
    await Future.wait(initFutures);
  }

  void _prefetchSegmentsAtPosition({
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    required int targetMs,
  }) {
    final cacheKey = '$variant:$track';
    final manifestFuture = session._variantManifestCache[cacheKey];
    if (manifestFuture == null) {
      session._log(
        'seekPrefetch skip variant=$variant track=$track — no cached manifest',
      );
      return;
    }

    unawaited(
      manifestFuture.then((manifest) {
        _doSegmentSeekPrefetch(
          session: session,
          manifest: manifest,
          variant: variant,
          track: track,
          targetMs: targetMs,
        );
      }, onError: (_) {}),
    );
  }

  /// Returns the absolute CDN segment index window for a seek target.
  ///
  /// The window is [max(0, N-2) .. min(maxSegmentIndex, N+4)] where N is the
  /// absolute CDN index of the target segment.  This is used by
  /// [_doSegmentSeekPrefetch] to prefetch the correct CDN segments.
  ///
  /// R2: Widened from [N..N+2] to [N-2..N+4] (7 segments ≈ 28s) to give
  /// native seek more room inside the window.  Forward-biased because the
  /// user typically keeps watching after seeking.
  ///
  /// IMPORTANT: [targetSegmentIndex] must be the ABSOLUTE CDN index (parsed
  /// from the segment URL via [_parseSegmentIndex]), NOT the local playlist
  /// ordinal.  Using the local ordinal here is the P1-A bug.
  List<int> buildAbsoluteSeekWindow({
    required int targetSegmentIndex,
    required int maxSegmentIndex,
  }) {
    final start = max(0, targetSegmentIndex - 2);
    final end = min(maxSegmentIndex, targetSegmentIndex + 4);
    return <int>[for (var i = start; i <= end; i++) i];
  }

  void _doSegmentSeekPrefetch({
    required NexusPlaybackProxySession session,
    required _FetchedManifest manifest,
    required String variant,
    required int track,
    required int targetMs,
  }) {
    // FIX 1.3: Log active variant/track for warmup
    session._log(
      'seekWarmup active-variant variant=$variant track=$track targetMs=$targetMs',
    );

    // Extract base path from manifest CDN URI.
    // Pattern: <base>_<variant>-<track>.m3u8
    final manifestPath = manifest.uri.path;
    final match = RegExp(r'_(\d+)-(\d+)\.m3u8$').firstMatch(manifestPath);
    if (match == null) {
      session._log(
        'seekPrefetch skip variant=$variant track=$track — bad manifest path',
      );
      return;
    }

    final v = match.group(1)!;
    final t = match.group(2)!;
    final trackInt = int.tryParse(t) ?? track;
    final basePath = manifestPath.substring(0, match.start);

    // Walk EXTINF lines to find the target segment, then read its URL to
    // extract the ABSOLUTE CDN index via _parseSegmentIndex.
    // Using the local playlist ordinal (P1-A bug) produces wrong CDN paths
    // when the manifest starts at an index > 0 (e.g. index 211 after a seek).
    int? absoluteTargetIndex;
    var accumulatedMs = 0.0;
    bool nextLineIsTargetSegment = false;
    int? maxAbsoluteIndex;

    for (final rawLine in manifest.body.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (nextLineIsTargetSegment && !line.startsWith('#')) {
        // This is the segment URL for the target segment.
        // FIX 1.1: Parse absolute index from path= query parameter (CDN path),
        // not from loopback path. The loopback URL has format:
        // http://127.0.0.1:PORT/.../segment/VARIANT/TRACK/LOCAL_INDEX?path=CDN_PATH
        // We need the CDN_PATH to get the absolute index.
        final segmentUri = Uri.parse(line);
        final cdnPath = segmentUri.queryParameters['path'];
        if (cdnPath != null && cdnPath.isNotEmpty) {
          absoluteTargetIndex = _parseSegmentIndexFromCdnPath(cdnPath);
          session._log(
            'seekWarmup source-cdn-path path=$cdnPath '
            'absoluteTarget=$absoluteTargetIndex',
          );
        } else {
          // Fallback: parse from segment path (non-loopback case)
          final segPath = segmentUri.path;
          absoluteTargetIndex = _parseSegmentIndex(segPath);
          session._log(
            'seekWarmup source-direct-path path=$segPath '
            'absoluteTarget=$absoluteTargetIndex',
          );
        }
        nextLineIsTargetSegment = false;
        // Don't break — continue to find maxAbsoluteIndex.
      }

      if (!line.startsWith('#') && !line.startsWith('#EXT-X-ENDLIST')) {
        // Track the last segment URL to determine maxAbsoluteIndex.
        // FIX 1.1: Same logic - parse from path= query parameter if available
        final segmentUri = Uri.parse(line);
        final cdnPath = segmentUri.queryParameters['path'];
        if (cdnPath != null && cdnPath.isNotEmpty) {
          maxAbsoluteIndex = _parseSegmentIndexFromCdnPath(cdnPath);
        } else {
          final segPath = segmentUri.path;
          maxAbsoluteIndex = _parseSegmentIndex(segPath);
        }
      }

      if (line.startsWith('#EXTINF:') && absoluteTargetIndex == null) {
        final payload = line.substring('#EXTINF:'.length);
        final rawValue = payload.split(',').first.trim();
        final duration = double.tryParse(rawValue) ?? 0;
        final segEndMs = accumulatedMs + duration * 1000;
        if (segEndMs >= targetMs) {
          nextLineIsTargetSegment = true;
        } else {
          accumulatedMs = segEndMs;
        }
      }
    }

    if (absoluteTargetIndex == null) {
      session._log(
        'seekPrefetch skip variant=$variant track=$track — could not resolve absolute index',
      );
      return;
    }

    // FIX 1.2: Guard against invalid zero target when seek is non-zero
    // If seekTargetMs > 0 but we resolved absoluteTarget=0, something is wrong.
    // This prevents warming segments 0-2 when the real target is high (e.g., 175).
    if (targetMs > 0 && absoluteTargetIndex == 0) {
      session._log(
        'seekWarmup skip-invalid-zero-target seekTargetMs=$targetMs '
        'absoluteTarget=$absoluteTargetIndex — refusing to warm start segments for non-zero seek',
      );
      return;
    }

    final window = buildAbsoluteSeekWindow(
      targetSegmentIndex: absoluteTargetIndex,
      maxSegmentIndex: maxAbsoluteIndex ?? absoluteTargetIndex + 3,
    );

    // FIX 1.4: Enhanced logging for absolute window
    session._log(
      'seekWarmup absolute-window targetSegment=$absoluteTargetIndex '
      'window=[${window.join(", ")}] maxIndex=${maxAbsoluteIndex ?? "unknown"}',
    );

    for (final segIdx in window) {
      final segCacheKey = '$v:$trackInt:$segIdx';
      if (session._mediaSegmentCache.containsKey(segCacheKey)) continue;

      final padded = segIdx.toString().padLeft(4, '0');
      final segPath = '${basePath}_${v}_$padded-$t.m4s';
      unawaited(
        session
            .getOrCreateMediaSegment(
              cacheKey: segCacheKey,
              loader: () => _fetchSegmentWithRetry(
                session: session,
                variant: v,
                track: trackInt,
                segmentIndex: segIdx,
                path: segPath,
              ),
            )
            .then<void>((_) {
              session._log(
                'seekPrefetch hit variant=$v track=$trackInt seg=$segIdx',
              );
            }, onError: (_) {}),
      );
    }

    session._log('seekWarmup complete targetSegment=$absoluteTargetIndex');
  }

  Future<_FetchedManifest> _fetchSignedManifest({
    required NexusPlaybackProxySession session,
    required String manifestPath,
    String? preferredHost,
  }) async {
    Response<String>? response;
    String body = '';
    Uri? signedUrl;
    int lastUpstreamStatus = 0;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        if (_shouldRebuildSessionOnRetry(null, lastUpstreamStatus)) {
          session._log(
            'fetchSignedManifest rebuild attempt=${attempt + 1} manifestPath=$manifestPath',
          );
          await session.refreshRuntime(requestResetStream: attempt >= 2);
        } else {
          session._log(
            'fetchSignedManifest transient-retry attempt=${attempt + 1} manifestPath=$manifestPath',
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      lastUpstreamStatus = 0;
      late final String sessionId;
      late final dynamic token;
      try {
        sessionId = await session.ensureSessionId();
      } catch (error) {
        throw StateError(
          'Anime Nexus manifest session id failed on attempt ${attempt + 1}: $error',
        );
      }
      try {
        token = await session.worker.getManifestToken(
          manifestPath: manifestPath,
          videoId: session.episodeId,
        );
      } catch (error) {
        throw StateError(
          'Anime Nexus manifest token failed on attempt ${attempt + 1}: $error',
        );
      }

      for (final host in _orderedHosts(session, preferredHost: preferredHost)) {
        signedUrl = _signedManifestUrl(
          host: host,
          path: manifestPath,
          token: token.token,
          sessionId: sessionId,
        );
        response = await session.dio.get<String>(
          signedUrl.toString(),
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
            headers: _cdnRequestHeaders(
              fingerprint: session.fingerprint,
              sessionId: sessionId,
              videoUuid: session.episodeId,
            ),
          ),
        );

        body = response.data?.trim() ?? '';
        session._log(
          'fetchSignedManifest attempt=${attempt + 1} host=$host status=${response.statusCode} manifestPath=$manifestPath bodyPrefix=${body.substring(0, min(body.length, 24))}',
        );
        lastUpstreamStatus = response.statusCode ?? 0;
        if (response.statusCode == 200 && body.startsWith('#EXTM3U')) {
          session.edgeHost = host;
          session._log(
            'fetchSignedManifest success host=$host manifestPath=$manifestPath',
          );
          return _FetchedManifest(body: body, uri: response.realUri);
        }
      }
    }

    throw StateError('Anime Nexus manifest request failed for $signedUrl');
  }

  Future<Response<List<int>>> _fetchManifestProtectedBytes({
    required NexusPlaybackProxySession session,
    required String path,
  }) async {
    Response<List<int>>? upstream;

    int lastMpbStatus = 0;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        if (_shouldRebuildSessionOnRetry(null, lastMpbStatus)) {
          session._log(
            'fetchManifestProtectedBytes rebuild attempt=${attempt + 1} path=$path',
          );
          await session.refreshRuntime(requestResetStream: attempt >= 1);
        } else {
          session._log(
            'fetchManifestProtectedBytes transient-retry attempt=${attempt + 1} path=$path',
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      lastMpbStatus = 0;
      final sessionId = await session.ensureSessionId();

      final token = await session.worker.getManifestToken(
        manifestPath: path,
        videoId: session.episodeId,
      );

      for (final host in _orderedHosts(session)) {
        upstream = await _fetchUpstreamBytes(
          session: session,
          sessionId: sessionId,
          url: _signedSegmentUrl(
            host: host,
            path: path,
            token: token.token,
            sessionId: sessionId,
          ),
        );
        session._log(
          'fetchManifestProtectedBytes attempt=${attempt + 1} host=$host status=${upstream.statusCode} path=$path',
        );

        lastMpbStatus = upstream.statusCode ?? 0;
        if (upstream.statusCode == HttpStatus.ok) {
          session.edgeHost = host;
          session._log(
            'fetchManifestProtectedBytes success host=$host path=$path bytes=${upstream.data?.length ?? 0}',
          );
          return upstream;
        }
      }
    }

    return upstream ??
        Response<List<int>>(
          requestOptions: RequestOptions(path: path),
          statusCode: HttpStatus.badGateway,
          data: const <int>[],
        );
  }

  Future<Response<List<int>>> _fetchUpstreamBytes({
    required NexusPlaybackProxySession session,
    required String sessionId,
    required Uri url,
  }) async {
    return session.dio.get<List<int>>(
      url.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 500,
        headers: _cdnRequestHeaders(
          fingerprint: session.fingerprint,
          sessionId: sessionId,
          videoUuid: session.episodeId,
        ),
      ),
    );
  }

  Future<Response<List<int>>> _fetchSegmentWithRetry({
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    required int segmentIndex,
    required String path,
  }) async {
    Response<List<int>>? upstream;
    Object? lastError;
    int lastUpstreamStatus = 0;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        if (_shouldRebuildSessionOnRetry(lastError, lastUpstreamStatus)) {
          session._log(
            'fetchSegmentWithRetry rebuild attempt=${attempt + 1} variant=$variant track=$track segmentIndex=$segmentIndex',
          );
          await session.refreshRuntime(requestResetStream: attempt >= 2);
        } else {
          session._log(
            'fetchSegmentWithRetry transient-retry attempt=${attempt + 1} variant=$variant track=$track segmentIndex=$segmentIndex',
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      lastError = null;
      lastUpstreamStatus = 0;
      try {
        final sessionId = await session.ensureSessionId();

        final token = await session.worker.getSegmentToken(
          variant: variant,
          segmentIndex: segmentIndex,
          track: track,
          videoId: session.episodeId,
        );

        for (final host in _orderedHosts(session)) {
          upstream = await _fetchUpstreamBytes(
            session: session,
            sessionId: sessionId,
            url: _signedSegmentUrl(
              host: host,
              path: path,
              token: token.token,
              sessionId: sessionId,
            ),
          );
          lastUpstreamStatus = upstream.statusCode ?? 0;
          session._log(
            'fetchSegmentWithRetry attempt=${attempt + 1} host=$host status=${upstream.statusCode} variant=$variant track=$track segmentIndex=$segmentIndex path=$path',
          );

          if (upstream.statusCode == HttpStatus.ok) {
            session.edgeHost = host;
            if (track == 0) {
              unawaited(session.reportProgress(segmentIndex));
            }
            session._log(
              'fetchSegmentWithRetry success host=$host variant=$variant track=$track segmentIndex=$segmentIndex bytes=${upstream.data?.length ?? 0}',
            );
            return upstream;
          }
        }
      } catch (error) {
        lastError = error;
        session._log(
          'fetchSegmentWithRetry error attempt=${attempt + 1} variant=$variant track=$track segmentIndex=$segmentIndex error=$error',
        );
        if (attempt >= 2) {
          // Last attempt — return a bad-gateway response instead of throwing
          // so the proxy returns 502 (retriable) rather than 500 (server bug).
          return Response<List<int>>(
            requestOptions: RequestOptions(path: path),
            statusCode: HttpStatus.badGateway,
            data: const <int>[],
          );
        }
      }
    }

    return upstream ??
        Response<List<int>>(
          requestOptions: RequestOptions(path: path),
          statusCode: HttpStatus.badGateway,
          data: const <int>[],
        );
  }

  /// Returns `true` if a fetch retry should trigger a full session rebuild.
  /// Transient CDN/network errors (5xx, connection reset, timeout, EOF) are
  /// retried locally with a short delay — only auth/token errors rebuild.
  bool _shouldRebuildSessionOnRetry(Object? error, int lastUpstreamStatus) {
    // Explicit auth/token rejection from CDN → rebuild.
    if (lastUpstreamStatus == 401 || lastUpstreamStatus == 403) {
      return true;
    }
    // CDN server errors (502, 503, 504) → transient, don't rebuild.
    if (lastUpstreamStatus >= 500) {
      return false;
    }
    if (error == null) {
      // No exception, just non-200 from CDN — conservative: rebuild.
      return true;
    }
    final msg = error.toString().toLowerCase();
    // Auth/token/session errors → rebuild.
    if (msg.contains('authentication') ||
        msg.contains('unauthorized') ||
        msg.contains('token') ||
        msg.contains('session expired') ||
        msg.contains('invalid session')) {
      return true;
    }
    // Transient network errors → don't rebuild.
    if (msg.contains('connection closed') ||
        msg.contains('eof') ||
        msg.contains('timeout') ||
        msg.contains('reset') ||
        msg.contains('partial') ||
        msg.contains('broken pipe') ||
        msg.contains('header')) {
      return false;
    }
    // Unknown error — conservative default is rebuild.
    return true;
  }

  List<String> _orderedHosts(
    NexusPlaybackProxySession session, {
    String? preferredHost,
  }) {
    final activePreferredHost =
        preferredHost != null && preferredHost.isNotEmpty
        ? preferredHost
        : session.edgeHost;
    if (activePreferredHost == null || activePreferredHost.isEmpty) {
      return session.candidateHosts;
    }

    return <String>[
      activePreferredHost,
      ...session.candidateHosts.where((host) => host != activePreferredHost),
    ];
  }

  Uri _variantUri(
    HttpRequest? request, {
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
  }) {
    final base =
        request?.requestedUri ??
        qualityMasterUri(
          session: session,
          stream:
              session.findVideoStream(variant: variant, track: track) ??
              session.masterManifest.streamEntries.first,
        );
    return base.replace(
      pathSegments: <String>[
        'anime-nexus',
        session.playbackId,
        'variant',
        variant,
        '$track.m3u8',
      ],
      queryParameters: _forwardedQuery(request?.requestedUri),
    );
  }

  Uri _initUri(
    HttpRequest? request, {
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    required String path,
  }) {
    final base =
        request?.requestedUri ??
        _variantUri(null, session: session, variant: variant, track: track);
    return base.replace(
      pathSegments: <String>[
        'anime-nexus',
        session.playbackId,
        'init',
        variant,
        '$track.mp4',
      ],
      queryParameters: <String, String>{
        ..._forwardedQuery(request?.requestedUri),
        'path': path,
      },
    );
  }

  Uri _segmentUri(
    HttpRequest? request, {
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    required int segmentIndex,
    required String path,
  }) {
    final base =
        request?.requestedUri ??
        _variantUri(null, session: session, variant: variant, track: track);
    return base.replace(
      pathSegments: <String>[
        'anime-nexus',
        session.playbackId,
        'segment',
        variant,
        '$track',
        '$segmentIndex.m4s',
      ],
      queryParameters: <String, String>{
        ..._forwardedQuery(request?.requestedUri),
        'path': path,
      },
    );
  }

  Map<String, String> _forwardedQuery(Uri? uri) {
    if (uri == null) {
      return const <String, String>{};
    }

    final forwarded = <String, String>{};
    for (final key in const <String>{'run', 'seekNonce'}) {
      final value = uri.queryParameters[key]?.trim() ?? '';
      if (value.isNotEmpty) {
        forwarded[key] = value;
      }
    }
    return forwarded;
  }

  int? _parseSeekTargetMs(Uri? uri) {
    if (uri == null) {
      return null;
    }

    final raw = uri.queryParameters['seekNonce']?.trim() ?? '';
    final value = int.tryParse(raw);
    return value != null && value > 0 ? value : null;
  }

  String _rewriteVariantManifest({
    required HttpRequest? request,
    required NexusPlaybackProxySession session,
    required String variant,
    required int track,
    required String manifestBody,
    required Uri baseUri,
    required int? seekTargetMs,
  }) {
    final headerLines = <String>[];
    final footerLines = <String>[];
    final pendingSegmentLines = <String>[];
    final segmentBlocks = <_VariantSegmentBlock>[];

    for (final rawLine in manifestBody.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (segmentBlocks.isEmpty && pendingSegmentLines.isEmpty) {
          headerLines.add(rawLine);
        } else if (pendingSegmentLines.isNotEmpty) {
          pendingSegmentLines.add(rawLine);
        }
        continue;
      }

      if (line.startsWith('#EXT-X-ENDLIST')) {
        footerLines.add(rawLine);
        continue;
      }

      if (line.startsWith('#EXT-X-MAP:')) {
        final initPath = _extractMapPath(line, baseUri);
        final rewrittenMapLine = _replaceMapUri(
          line,
          _initUri(
            request,
            session: session,
            variant: variant,
            track: track,
            path: initPath,
          ).toString(),
        );
        if (segmentBlocks.isEmpty && pendingSegmentLines.isEmpty) {
          headerLines.add(rewrittenMapLine);
        } else {
          pendingSegmentLines.add(rewrittenMapLine);
        }
        continue;
      }

      if (line.startsWith('#')) {
        final isSegmentMetadata =
            line.startsWith('#EXTINF:') || pendingSegmentLines.isNotEmpty;
        if (segmentBlocks.isEmpty &&
            pendingSegmentLines.isEmpty &&
            !isSegmentMetadata) {
          headerLines.add(rawLine);
        } else {
          pendingSegmentLines.add(rawLine);
        }
        continue;
      }

      final segmentPath = baseUri.resolve(line).path;
      final segmentIndex = _parseSegmentIndex(segmentPath);
      segmentBlocks.add(
        _VariantSegmentBlock(
          lines: <String>[
            ...pendingSegmentLines,
            _segmentUri(
              request,
              session: session,
              variant: variant,
              track: track,
              segmentIndex: segmentIndex,
              path: segmentPath,
            ).toString(),
          ],
          durationSeconds: _parseSegmentDurationSeconds(pendingSegmentLines),
          segmentIndex: segmentIndex,
        ),
      );
      pendingSegmentLines.clear();
    }

    if (segmentBlocks.isEmpty) {
      return <String>[...headerLines, ...footerLines].join('\n');
    }

    var startBlockIndex = 0;
    var relativeStartOffsetSeconds = 0.0;
    if (seekTargetMs != null && seekTargetMs > 0) {
      final selection = _selectSeekStartBlock(
        blocks: segmentBlocks,
        seekTargetMs: seekTargetMs,
        anchorTimeMs: seekTargetMs,
      );
      startBlockIndex = selection.blockIndex;
      relativeStartOffsetSeconds = selection.relativeStartOffsetSeconds;

      // Fix D: Log anchor compartido A/V para validar que ambos tracks
      // usan el mismo anchorTimeMs como referencia temporal
      final blockAbsoluteStartMs = segmentBlocks
          .take(startBlockIndex)
          .fold<double>(
            0.0,
            (sum, block) => sum + block.durationSeconds * 1000,
          );
      final effectiveAnchorMs =
          blockAbsoluteStartMs + (relativeStartOffsetSeconds * 1000);

      session._log(
        'avAnchor shared targetMs=$seekTargetMs track=$track '
        'blockIndex=$startBlockIndex segmentIndex=${segmentBlocks[startBlockIndex].segmentIndex} '
        'blockAbsoluteStartMs=${blockAbsoluteStartMs.toStringAsFixed(0)} '
        'relativeStart=${relativeStartOffsetSeconds.toStringAsFixed(3)} '
        'effectiveAnchorMs=${effectiveAnchorMs.toStringAsFixed(0)}',
      );

      // R2: Log window policy for observability.
      session._log(
        'managedWindowPolicy backSegments=2 forwardSegments=4 '
        'totalSegments=${segmentBlocks.length - startBlockIndex}',
      );
    }

    final filteredHeaderLines = headerLines
        .where(
          (line) =>
              !line.trim().startsWith('#EXT-X-MEDIA-SEQUENCE') &&
              !line.trim().startsWith('#EXT-X-START'),
        )
        .toList(growable: false);

    final rewritten = <String>[
      ...filteredHeaderLines,
      if (seekTargetMs != null && seekTargetMs > 0)
        '#EXT-X-START:TIME-OFFSET=${relativeStartOffsetSeconds.toStringAsFixed(3)},PRECISE=YES',
      if (seekTargetMs != null && seekTargetMs > 0)
        '#EXT-X-MEDIA-SEQUENCE:${segmentBlocks[startBlockIndex].segmentIndex}',
    ];

    for (final block in segmentBlocks.skip(startBlockIndex)) {
      rewritten.addAll(block.lines);
    }
    rewritten.addAll(footerLines);
    return rewritten.join('\n');
  }

  _SeekWindowSelection _selectSeekStartBlock({
    required List<_VariantSegmentBlock> blocks,
    required int seekTargetMs,
    required int anchorTimeMs,
  }) {
    final prerollMs = max(2000, min(seekTargetMs, 6000));
    final desiredStartMs = max(0, seekTargetMs - prerollMs);
    var accumulatedMs = 0.0;

    for (var index = 0; index < blocks.length; index++) {
      final nextAccumulatedMs =
          accumulatedMs + (blocks[index].durationSeconds * 1000);
      if (nextAccumulatedMs >= desiredStartMs) {
        // Use the shared anchorTimeMs as the reference point so that both
        // video and audio tracks compute the same effective playback anchor.
        // Formula: relativeStart = anchorTimeMs/1000 - blockAbsoluteStart
        // where blockAbsoluteStart = accumulatedMs/1000 at the selected block.
        final blockAbsoluteStartSeconds = accumulatedMs / 1000.0;
        final relativeStartSeconds = max(
          0.0,
          anchorTimeMs / 1000.0 - blockAbsoluteStartSeconds,
        );
        return _SeekWindowSelection(
          blockIndex: index,
          relativeStartOffsetSeconds: relativeStartSeconds,
        );
      }
      accumulatedMs = nextAccumulatedMs;
    }

    final lastIndex = max(0, blocks.length - 1);
    return _SeekWindowSelection(
      blockIndex: lastIndex,
      relativeStartOffsetSeconds: 0,
    );
  }

  double _parseSegmentDurationSeconds(List<String> lines) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.startsWith('#EXTINF:')) {
        continue;
      }
      final payload = line.substring('#EXTINF:'.length);
      final rawValue = payload.split(',').first.trim();
      final durationSeconds = double.tryParse(rawValue);
      if (durationSeconds != null && durationSeconds >= 0) {
        return durationSeconds;
      }
    }
    return 0;
  }

  Map<String, String> _browserFetchHeaders() {
    return <String, String>{
      'User-Agent': NexusConstants.userAgent,
      'Accept': '*/*',
      'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
      'Origin': NexusConstants.mainBase,
      'Referer': '${NexusConstants.mainBase}/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'cross-site',
    };
  }

  Map<String, String> _cdnRequestHeaders({
    required String fingerprint,
    required String sessionId,
    required String videoUuid,
  }) {
    return <String, String>{
      ..._browserFetchHeaders(),
      'x-client-fingerprint': fingerprint,
      'x-fingerprint': fingerprint,
      'x-session-id': sessionId,
      'x-video-uuid': videoUuid,
    };
  }

  Uri _signedManifestUrl({
    required String host,
    required String path,
    required String token,
    required String sessionId,
  }) {
    return Uri.https(host, path, <String, String>{
      'token': token,
      'requestType': 'manifest',
      'sessionId': sessionId,
    });
  }

  Uri _signedSegmentUrl({
    required String host,
    required String path,
    required String token,
    required String sessionId,
  }) {
    return Uri.https(host, path, <String, String>{
      'token': token,
      'requestType': 'segment',
      'sessionId': sessionId,
      'segmentPath': path,
    });
  }

  String _extractMapPath(String line, Uri baseUri) {
    final match = RegExp(r'URI=\"([^\"]+)\"').firstMatch(line);
    if (match == null) {
      throw StateError('Anime Nexus init line missing URI: $line');
    }
    return baseUri.resolve(match.group(1)!).path;
  }

  String _replaceMapUri(String line, String replacement) {
    return line.replaceFirst(
      RegExp(r'URI=\"([^\"]+)\"'),
      'URI=\"$replacement\"',
    );
  }

  String _replaceMediaUri(String line, String replacement) {
    return line.replaceFirst(
      RegExp(r'URI=\"([^\"]+)\"'),
      'URI=\"$replacement\"',
    );
  }

  int _parseSegmentIndex(String path) {
    final match = RegExp(r'_([0-9]+)-[0-9]+\.(?:m4s|mp4)$').firstMatch(path);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1)!) ?? 0;
  }

  /// Parses the absolute CDN segment index from a CDN path.
  ///
  /// Task 3.2: Extract segment index from CDN path query parameter.
  /// Example: `path=%2Fanime%2F...mkv_1600_0175-1.m4s` → decode →
  /// `/anime/.../mkv_1600_0175-1.m4s` → extract `0175` → return `175`
  ///
  /// Pattern: `_(\d{4})-(\d+)\.m4s` where first capture group is the
  /// zero-padded absolute CDN index.
  ///
  /// Returns null if the pattern doesn't match (defensive parsing).
  int? _parseSegmentIndexFromCdnPath(String cdnPath) {
    // The path may be URL-encoded, decode it first
    final decoded = Uri.decodeComponent(cdnPath);

    // Match pattern: _NNNN-T.m4s where NNNN is zero-padded absolute index
    // Example: mkv_1600_0175-1.m4s → capture "0175" → parse to 175
    final match = RegExp(r'_(\d{4})-(\d+)\.m4s$').firstMatch(decoded);
    if (match == null) {
      return null;
    }

    final indexStr = match.group(1);
    if (indexStr == null) {
      return null;
    }

    return int.tryParse(indexStr);
  }

  String? _parseVariantFromMediaPath(String path) {
    final match = RegExp(
      r'_(\d+)(?:_init)?_(?:\d+|[a-z]+)-\d+\.(?:mp4|m4s|ts)$',
      caseSensitive: false,
    ).firstMatch(path);
    return match?.group(1);
  }

  int? _parseTrackFromMediaPath(String path) {
    final match = RegExp(
      r'_(?:\d+)(?:_init)?_(?:\d+|[a-z]+)-(\d+)\.(?:mp4|m4s|ts)$',
      caseSensitive: false,
    ).firstMatch(path);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  int _parseTerminalInt(String segment) {
    final raw = segment.split('.').first;
    return int.tryParse(raw) ?? 0;
  }

  void _evictExpiredSessions() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 20));
    final expired = _sessions.entries
        .where((entry) => entry.value.lastAccessed.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final playbackId in expired) {
      final session = _sessions.remove(playbackId);
      session?._log('evictExpiredSession');
      unawaited(session?.worker.close());
    }
  }

  void _writeManifest(HttpResponse response, String body) {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.parse(
      'application/vnd.apple.mpegurl',
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write('$body\n');
    unawaited(response.close());
  }

  Future<void> _writeBinary(
    HttpResponse response, {
    required int statusCode,
    required List<int> body,
    required String contentType,
    required int? contentLength,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.parse(
      contentType.split(';').first,
    );
    if (contentLength != null) {
      response.headers.contentLength = contentLength;
    }
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.add(body);
    await response.close();
  }

  void _writeText(
    HttpResponse response, {
    required int statusCode,
    required String body,
  }) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.text;
    response.write(body);
    unawaited(response.close());
  }
}

final class _FetchedManifest {
  const _FetchedManifest({required this.body, required this.uri});

  final String body;
  final Uri uri;
}

final class _VariantSegmentBlock {
  const _VariantSegmentBlock({
    required this.lines,
    required this.durationSeconds,
    required this.segmentIndex,
  });

  final List<String> lines;
  final double durationSeconds;
  final int segmentIndex;
}

final class _SeekWindowSelection {
  const _SeekWindowSelection({
    required this.blockIndex,
    required this.relativeStartOffsetSeconds,
  });

  final int blockIndex;
  final double relativeStartOffsetSeconds;
}

String generateNexusPlaybackId() {
  final random = Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
