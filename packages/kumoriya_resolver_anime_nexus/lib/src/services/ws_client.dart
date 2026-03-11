import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/nexus_ws_models.dart';

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
    required String m3u8Url,
  }) : _episodeId = episodeId,
       _fingerprint = fingerprint,
       _m3u8Url = m3u8Url;

  final String _episodeId;
  final String _fingerprint;
  final String _m3u8Url;

  late final WebSocketChannel _channel;
  late final StreamSubscription<dynamic> _subscription;

  NexusWsSession? _session;
  int _ackCounter = 0;
  final Map<int, Completer<Map<String, dynamic>>> _acks =
      <int, Completer<Map<String, dynamic>>>{};

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
    final ready = Completer<void>();
    final authed = Completer<void>();

    _channel = IOWebSocketChannel.connect(_buildUri());
    _subscription = _channel.stream.listen(
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
  }

  Future<NexusStreamToken> getInitialManifestToken() {
    return _getToken(<String, Object?>{
      'requestType': 'manifest',
      'prevToken': null,
    });
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _channel.sink.close();
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
      completer.complete(list.first as Map<String, dynamic>);
    } catch (error) {
      completer.completeError(error);
    }
  }

  Future<NexusStreamToken> _getToken(Map<String, Object?> params) async {
    final ackId = _ackCounter++;
    final completer = Completer<Map<String, dynamic>>();
    _acks[ackId] = completer;

    _send('42/video,$ackId${jsonEncode(<Object>['getToken', params])}');

    final payload = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _acks.remove(ackId);
        throw const NexusWsException('Anime Nexus getToken timed out.');
      },
    );

    return NexusStreamToken.fromMap(payload);
  }

  void _send(String frame) {
    _channel.sink.add(frame);
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
}
