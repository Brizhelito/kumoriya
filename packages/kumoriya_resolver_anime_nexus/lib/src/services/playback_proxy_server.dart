import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../services/hls_manifest_parser.dart';
import '../services/playback_session_worker.dart';
import '../utils/nexus_constants.dart';

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

  String? edgeHost;
  String? _sessionId;
  DateTime lastAccessed = DateTime.now();
  int _lastProgressSegmentIndex = -1;

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

  Future<void> ensureReady({bool forceReconnect = false}) {
    _log('ensureReady forceReconnect=$forceReconnect');
    return worker.ensureReady(forceReconnect: forceReconnect);
  }

  Future<void> refreshRuntime({bool requestResetStream = false}) async {
    _log('refreshRuntime requestResetStream=$requestResetStream');
    _lastProgressSegmentIndex = -1;
    edgeHost = null;
    _sessionId = null;
    await worker.refreshSession(requestResetStream: requestResetStream);
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
    await session.ensureReady();
    await Future.wait(
      _variantManifestFutures(session: session, stream: stream),
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
      if (segments.length < 5 || segments.first != 'anime-nexus') {
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
      await session.ensureReady();
    } catch (error) {
      throw StateError('Anime Nexus master ensureReady failed: $error');
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

    _startVariantPrewarm(
      session: session,
      videoStream: stream,
      audioStreams: matchingAudio,
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
      await session.ensureReady();
    } catch (error) {
      throw StateError('Anime Nexus variant ensureReady failed: $error');
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
    final manifest = seekTargetMs != null
        ? await loader()
        : await session.getOrCreateVariantManifest(
            variant: variant,
            track: track,
            loader: loader,
          );
    _writeManifest(request.response, manifest.body);
  }

  void _startVariantPrewarm({
    required NexusPlaybackProxySession session,
    required NexusVideoStreamEntry videoStream,
    required List<NexusAudioTrackEntry> audioStreams,
  }) {
    unawaited(
      Future.wait(
        _variantManifestFutures(
          session: session,
          stream: videoStream,
          audioStreams: audioStreams,
        ),
      ).then<void>(
        (_) {},
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
    await session.ensureReady();
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

    final upstream = await _fetchManifestProtectedBytes(
      session: session,
      path: path,
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
    await session.ensureReady();
    final variant = segments[3];
    final track = _parseTerminalInt(segments[4]);
    final segmentIndex = _parseTerminalInt(segments[5]);
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
    session._log(
      'serveMediaSegment variant=$effectiveVariant track=$effectiveTrack segmentIndex=$segmentIndex path=$path',
    );

    final upstream = await _fetchSegmentWithRetry(
      session: session,
      variant: effectiveVariant,
      track: effectiveTrack,
      segmentIndex: segmentIndex,
      path: path,
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

  Future<_FetchedManifest> _fetchSignedManifest({
    required NexusPlaybackProxySession session,
    required String manifestPath,
    String? preferredHost,
  }) async {
    Response<String>? response;
    String body = '';
    Uri? signedUrl;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        session._log(
          'fetchSignedManifest retry attempt=${attempt + 1} manifestPath=$manifestPath',
        );
        await session.refreshRuntime(requestResetStream: attempt >= 2);
      }
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

    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        session._log(
          'fetchManifestProtectedBytes retry attempt=${attempt + 1} path=$path',
        );
        await session.refreshRuntime(requestResetStream: attempt >= 1);
      }
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

    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        session._log(
          'fetchSegmentWithRetry retry attempt=${attempt + 1} variant=$variant track=$track segmentIndex=$segmentIndex',
        );
        await session.refreshRuntime(requestResetStream: attempt >= 1);
      }
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
        session._log(
          'fetchSegmentWithRetry attempt=${attempt + 1} host=$host status=${upstream.statusCode} variant=$variant track=$track segmentIndex=$segmentIndex path=$path',
        );

        if (upstream.statusCode == HttpStatus.ok) {
          session.edgeHost = host;
          if (track == 0) {
            await session.reportProgress(segmentIndex);
          }
          session._log(
            'fetchSegmentWithRetry success host=$host variant=$variant track=$track segmentIndex=$segmentIndex bytes=${upstream.data?.length ?? 0}',
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
      );
      startBlockIndex = selection.blockIndex;
      relativeStartOffsetSeconds = selection.relativeStartOffsetSeconds;
      session._log(
        'rewriteVariantManifest seekTargetMs=$seekTargetMs '
        'startBlockIndex=$startBlockIndex segmentIndex=${segmentBlocks[startBlockIndex].segmentIndex} '
        'relativeStart=${relativeStartOffsetSeconds.toStringAsFixed(3)}',
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
  }) {
    final prerollMs = max(4000, min(seekTargetMs, 10000));
    final desiredStartMs = max(0, seekTargetMs - prerollMs);
    var accumulatedMs = 0.0;

    for (var index = 0; index < blocks.length; index++) {
      final nextAccumulatedMs =
          accumulatedMs + (blocks[index].durationSeconds * 1000);
      if (nextAccumulatedMs >= desiredStartMs) {
        final relativeStartSeconds =
            max(0, seekTargetMs - accumulatedMs) / 1000;
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
