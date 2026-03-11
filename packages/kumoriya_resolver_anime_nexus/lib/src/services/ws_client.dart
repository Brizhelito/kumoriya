import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/nexus_ws_models.dart';
import '../utils/nexus_constants.dart';

final class NexusWsException implements Exception {
  const NexusWsException(this.message);

  final String message;

  @override
  String toString() => 'NexusWsException: $message';
}

final class NexusWsClient {
  NexusWsClient({
    required String episodeId,
    required String fingerprint,
    String? cookieHeader,
    required String m3u8Url,
  }) : _episodeId = episodeId,
       _fingerprint = fingerprint,
       _cookieHeader = cookieHeader,
       _m3u8Url = m3u8Url;

  final String _episodeId;
  final String _fingerprint;
  final String? _cookieHeader;
  final String _m3u8Url;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;

  NexusWsSession? _session;
  String? _wsRef;
  bool _closed = false;
  bool _needsReconnect = false;
  Completer<void>? _reconnectCompleter;
  int _ackCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _acks =
      <int, Completer<Map<String, dynamic>>>{};
  final Map<String, _ManifestTokenRequest> _manifestRequestsByKey =
      <String, _ManifestTokenRequest>{};
  final Map<String, String> _manifestKeysByToken = <String, String>{};
  final Map<String, String> _latestManifestTokenByKey = <String, String>{};
  final Map<String, NexusStreamToken> _prefetchedManifestTokenByKey =
      <String, NexusStreamToken>{};
  final Set<String> _manifestPrefetchInFlight = <String>{};

  NexusWsSession get session {
    final session = _session;
    if (session == null) {
      throw const NexusWsException(
        'connect() must complete before session access.',
      );
    }
    return session;
  }

  Future<void> connect({required String wsRef}) async {
    _closed = false;
    _wsRef = wsRef;
    await _openAndAuthenticate(wsRef: wsRef);
  }

  Future<void> ensureActiveSession({bool forceReconnect = false}) async {
    if (_closed) {
      throw const NexusWsException('Anime Nexus WebSocket is already closed.');
    }
    if (!forceReconnect && !_needsReconnect && _session != null) {
      return;
    }
    await _reconnect(force: forceReconnect);
  }

  Future<void> refreshSession({bool requestResetStream = false}) async {
    if (requestResetStream) {
      _send('42/video,${jsonEncode(<Object>['reset-stream'])}');
    }
    _needsReconnect = true;
    await ensureActiveSession(forceReconnect: true);
  }

  Future<void> _openAndAuthenticate({required String wsRef}) async {
    final ready = Completer<void>();
    final authed = Completer<void>();

    _socket = await _openSocket();
    _subscription = _socket!.listen(
      (raw) => _onFrame(raw.toString(), ready: ready, authed: authed),
      onError: (Object error) {
        if (!ready.isCompleted) {
          ready.completeError(error);
        }
        if (!authed.isCompleted) {
          authed.completeError(error);
        }
        _failAllPending(error);
      },
      onDone: () {
        const closed = NexusWsException(
          'Anime Nexus WebSocket closed unexpectedly.',
        );
        if (!ready.isCompleted) {
          ready.completeError(closed);
        }
        if (!authed.isCompleted) {
          authed.completeError(closed);
        }
        _failAllPending(closed);
      },
    );

    await ready.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw const NexusWsException(
        'Anime Nexus namespace connect timed out.',
      ),
    );

    _send(
      '42/video,${jsonEncode(<Object>[
        'auth',
        <String, String>{'ref': wsRef, 'fingerprint': _fingerprint},
      ])}',
    );

    await authed.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw const NexusWsException('Anime Nexus auth handshake timed out.'),
    );
    _needsReconnect = false;
  }

  Future<NexusStreamToken> getInitialManifestToken() {
    return _getManifestToken(
      const _ManifestTokenRequest(
        key: _initialManifestTokenKey,
        manifestPath: null,
        videoId: null,
      ),
    );
  }

  Future<NexusStreamToken> getManifestToken({
    required String manifestPath,
    required String videoId,
  }) {
    return _getManifestToken(
      _ManifestTokenRequest(
        key: manifestPath,
        manifestPath: manifestPath,
        videoId: videoId,
      ),
    );
  }

  Future<NexusStreamToken> getSegmentToken({
    required String variant,
    required int segmentIndex,
    required int track,
    required String videoId,
  }) {
    return _getToken(<String, Object?>{
      'requestType': 'segment',
      'variant': variant,
      'segIdx': segmentIndex,
      'track': track,
      'videoId': videoId,
    });
  }

  Future<NexusStreamToken> _getManifestToken(
    _ManifestTokenRequest request,
  ) async {
    await ensureActiveSession();

    final prefetched = _prefetchedManifestTokenByKey.remove(request.key);
    if (prefetched != null) {
      _rememberManifestToken(request, prefetched);
      return prefetched;
    }

    final previousToken = _latestManifestTokenByKey[request.key];
    final params = request.toSocketParams(previousToken: previousToken);
    final token = await _getToken(params);
    _rememberManifestToken(request, token);
    return token;
  }

  Future<NexusStreamToken> _getToken(Map<String, Object?> params) async {
    await ensureActiveSession();

    final socket = _socket;
    if (socket == null) {
      throw const NexusWsException(
        'Anime Nexus WebSocket is not connected to request tokens.',
      );
    }

    final ackId = _ackCounter++;
    final completer = Completer<Map<String, dynamic>>();
    _acks[ackId] = completer;

    socket.add('42/video,$ackId${jsonEncode(<Object>['getToken', params])}');

    final payload = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _acks.remove(ackId);
        throw const NexusWsException('Anime Nexus getToken timed out.');
      },
    );

    if (payload['error'] != null) {
      _needsReconnect = true;
      final error =
          payload['error']?.toString().trim() ?? 'Token request failed.';
      final code = payload['code']?.toString().trim();
      throw NexusWsException(
        code == null || code.isEmpty ? error : '$error ($code)',
      );
    }

    final token = NexusStreamToken.fromMap(payload);
    if (token.token.trim().isEmpty) {
      throw const NexusWsException(
        'Anime Nexus token response did not include a token.',
      );
    }
    return token;
  }

  void _rememberManifestToken(
    _ManifestTokenRequest request,
    NexusStreamToken token,
  ) {
    final previousToken = _latestManifestTokenByKey[request.key];
    if (previousToken != null) {
      _manifestKeysByToken.remove(previousToken);
    }

    _manifestRequestsByKey[request.key] = request;
    _latestManifestTokenByKey[request.key] = token.token;
    _manifestKeysByToken[token.token] = request.key;
  }

  Future<void> close() async {
    _closed = true;
    _needsReconnect = false;
    _failAllPending(
      const NexusWsException('Anime Nexus WebSocket was closed.'),
    );
    await _closeSocket();
  }

  Future<void> _closeSocket() async {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
    }
  }

  Future<void> _reconnect({required bool force}) async {
    final pending = _reconnectCompleter;
    if (pending != null) {
      return pending.future;
    }

    final completer = Completer<void>();
    _reconnectCompleter = completer;

    () async {
      try {
        final wsRef = _wsRef;
        if (wsRef == null) {
          throw const NexusWsException(
            'Anime Nexus WebSocket cannot reconnect before connect().',
          );
        }

        if (force || _socket != null) {
          await _closeSocket();
        }
        _session = null;
        await _openAndAuthenticate(wsRef: wsRef);
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (identical(_reconnectCompleter, completer)) {
          _reconnectCompleter = null;
        }
      }
    }();

    return completer.future;
  }

  static const String _initialManifestTokenKey = '__initial__';

  void _scheduleManifestPrefetch(String prevToken) {
    final key = _manifestKeysByToken[prevToken];
    if (key == null) {
      return;
    }

    final request = _manifestRequestsByKey[key];
    if (request == null || _manifestPrefetchInFlight.contains(key)) {
      return;
    }

    _manifestPrefetchInFlight.add(key);
    unawaited(() async {
      try {
        final token = await _getToken(
          request.toSocketParams(previousToken: prevToken),
        );
        _prefetchedManifestTokenByKey[key] = token;
        _manifestKeysByToken[token.token] = key;
      } catch (_) {
        // Ignore speculative refresh failures; the next foreground fetch
        // will re-establish state if required.
      } finally {
        _manifestPrefetchInFlight.remove(key);
      }
    }());
  }

  void _onFrame(
    String message, {
    required Completer<void> ready,
    required Completer<void> authed,
  }) {
    if (message.startsWith('0{')) {
      _send('40/video,');
      return;
    }

    if (message == '2') {
      _send('3');
      return;
    }

    if (message.startsWith('40/video,')) {
      if (!ready.isCompleted) {
        ready.complete();
      }
      return;
    }

    if (message.startsWith('42/video,')) {
      _handleEvent(message.substring('42/video,'.length), authed: authed);
      return;
    }

    if (message.startsWith('43/video,')) {
      _handleAck(message.substring('43/video,'.length));
    }
  }

  void _handleEvent(String payload, {required Completer<void> authed}) {
    try {
      final list = jsonDecode(payload) as List<dynamic>;
      final event = list[0] as String;
      final data = list[1] as Map<String, dynamic>;

      if (event == 'connected') {
        _session = NexusWsSession(
          sessionId: data['sessionId']?.toString() ?? '',
          authenticated: data['authenticated'] == true,
          sessionExpiry: data['sessionExpiry'] is int
              ? data['sessionExpiry'] as int
              : int.tryParse(data['sessionExpiry']?.toString() ?? '') ?? 0,
        );
        if (!authed.isCompleted) {
          authed.complete();
        }
        return;
      }

      if (event == 'getToken' &&
          data['requestType']?.toString() == 'manifest') {
        final prevToken = data['prevToken']?.toString().trim() ?? '';
        if (prevToken.isNotEmpty) {
          _scheduleManifestPrefetch(prevToken);
        }
        return;
      }

      if (event == 'reset-challenge') {
        _needsReconnect = true;
        return;
      }

      if (event == 'authentication-error') {
        final message =
            data['message']?.toString().trim() ?? 'Authentication failed.';
        final error = NexusWsException(
          'Anime Nexus WebSocket auth failed: $message',
        );
        _needsReconnect = true;
        if (!authed.isCompleted) {
          authed.completeError(error);
        }
        _failAllPending(error);
      }
    } catch (_) {
      return;
    }
  }

  void _handleAck(String payload) {
    final bracketIndex = payload.indexOf('[');
    if (bracketIndex <= 0) {
      return;
    }

    final ackId = int.tryParse(payload.substring(0, bracketIndex));
    if (ackId == null) {
      return;
    }

    final completer = _acks.remove(ackId);
    if (completer == null) {
      return;
    }

    try {
      final list = jsonDecode(payload.substring(bracketIndex)) as List<dynamic>;
      final map = list.first as Map<String, dynamic>;
      if (map['error'] != null) {
        _needsReconnect = true;
        final error =
            map['error']?.toString().trim() ?? 'Anime Nexus ack failed.';
        final code = map['code']?.toString().trim();
        completer.completeError(
          NexusWsException(
            code == null || code.isEmpty ? error : '$error ($code)',
          ),
        );
        return;
      }
      completer.complete(map);
    } catch (error) {
      completer.completeError(error);
    }
  }

  void _send(String frame) {
    _socket?.add(frame);
  }

  void _failAllPending(Object error) {
    for (final completer in _acks.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _acks.clear();
  }

  Uri _buildUri() {
    return Uri(
      scheme: 'wss',
      host: 'prd-socket.anime.nexus',
      path: '/api/socket/',
      queryParameters: <String, String>{
        'videoId': _episodeId,
        'fingerprint': _fingerprint,
        'm3u8Url': _m3u8Url,
        'EIO': '4',
        'transport': 'websocket',
      },
    );
  }

  Future<WebSocket> _openSocket() async {
    final wsUri = _buildUri();
    final httpUri = wsUri.replace(
      scheme: wsUri.scheme == 'wss' ? 'https' : 'http',
    );
    final client = HttpClient();
    final request = await client.openUrl('GET', httpUri);
    final key = _buildWebSocketKey();

    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Version', '13')
      ..set('Sec-WebSocket-Key', key)
      ..set('Origin', NexusConstants.mainBase)
      ..set(HttpHeaders.userAgentHeader, NexusConstants.userAgent);

    final cookieHeader = _cookieHeader;
    if (cookieHeader != null) {
      for (final cookie in _parseCookies(cookieHeader)) {
        request.cookies.add(cookie);
      }
    }

    final response = await request.close();
    if (response.statusCode != HttpStatus.switchingProtocols) {
      throw NexusWsException(
        'Anime Nexus WebSocket upgrade failed with status ${response.statusCode}.',
      );
    }

    final socket = await response.detachSocket();
    return WebSocket.fromUpgradedSocket(socket, serverSide: false);
  }

  String _buildWebSocketKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  List<Cookie> _parseCookies(String cookieHeader) {
    return cookieHeader
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.contains('='))
        .map((part) {
          final separator = part.indexOf('=');
          return Cookie(
            part.substring(0, separator),
            part.substring(separator + 1),
          );
        })
        .toList(growable: false);
  }

  Future<void> sendProgress({required int segmentIndex}) async {
    await ensureActiveSession();
    final payload = jsonEncode(<Object>[
      'progress',
      <String, int>{'segIdx': segmentIndex},
    ]);
    _send('42/video,$payload');
  }
}

final class _ManifestTokenRequest {
  const _ManifestTokenRequest({
    required this.key,
    required this.manifestPath,
    required this.videoId,
  });

  final String key;
  final String? manifestPath;
  final String? videoId;

  Map<String, Object?> toSocketParams({required String? previousToken}) {
    return <String, Object?>{
      'requestType': 'manifest',
      'prevToken': previousToken,
      if (manifestPath != null) 'manifestUrl': manifestPath,
      if (videoId != null) 'videoId': videoId,
    };
  }
}
