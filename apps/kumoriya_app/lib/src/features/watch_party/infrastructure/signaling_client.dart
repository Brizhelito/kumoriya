import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'party_debug_logger.dart';

const bool _watchPartyVerboseLogs = bool.fromEnvironment(
  'WATCH_PARTY_VERBOSE_LOGS',
  defaultValue: false,
);

void _wsLog(String msg) {
  if (!_watchPartyVerboseLogs) return;
  dev.log(msg, name: 'PartyWS');
}

void _wsDebug(String msg) {
  if (!_watchPartyVerboseLogs) return;
  PartyDebugLogger.log('WS', msg);
}

/// Ephemeral WebSocket client for WebRTC signaling relay.
///
/// Keeps the WS alive with keepalive pongs every 20s and automatically
/// reconnects if the connection drops while the client is still active.
/// This is necessary because HF Spaces proxy closes idle connections
/// and the WS must stay open until P2P DataChannels are established.
final class SignalingClient {
  SignalingClient({required String wsUrl, required String accessToken})
    : _wsUrl = wsUrl,
      _accessToken = accessToken;

  final String _wsUrl;
  final String _accessToken;

  WebSocketChannel? _channel;
  final _controller = StreamController<SignalEnvelope>.broadcast();
  StreamSubscription<dynamic>? _sub;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;

  String? _activeRoomId;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;

  /// Stream of incoming signaling messages.
  Stream<SignalEnvelope> get messages => _controller.stream;

  bool get isConnected => _channel != null;

  /// Connect to the signaling relay for [roomId].
  void connect(String roomId) {
    if (_channel != null) return;
    _activeRoomId = roomId;
    _disposed = false;
    _reconnectAttempts = 0;
    _connectInternal(roomId);
  }

  void _connectInternal(String roomId) {
    if (_disposed) return;

    _wsLog('connect: roomId=$roomId attempt=$_reconnectAttempts');
    _wsDebug('connect: roomId=$roomId attempt=$_reconnectAttempts');

    final parsed = Uri.parse('$_wsUrl/api/v1/party/$roomId/signal');
    final withPort = parsed.port == 0
        ? parsed.replace(port: parsed.scheme == 'wss' ? 443 : 80)
        : parsed;
    final uri = withPort.replace(queryParameters: {'token': _accessToken});
    _wsDebug('connect: uri=$uri');

    _channel = WebSocketChannel.connect(uri);
    _wsDebug('WebSocketChannel.connect called');

    // Send keepalive immediately on connect, then every 20s.
    // HF Spaces proxy idle timeout is ~30-60s — 20s keeps us safely under it.
    sendPong();
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_channel != null) {
        _wsLog('keepalive pong');
        sendPong();
      }
    });

    _sub?.cancel();
    _sub = _channel!.stream.listen(
      (dynamic data) {
        // Any received message resets the reconnect counter — connection is healthy.
        _reconnectAttempts = 0;

        if (data is! String) return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _wsLog('recv: type=${json["type"]}');
          _wsDebug(
            'recv: type=${json["type"]} from=${json["from"]} to=${json["to"]}',
          );
          _controller.add(SignalEnvelope.fromJson(json));
        } catch (e) {
          _wsDebug(
            'recv: parse error: $e raw=${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}',
          );
        }
      },
      onError: (Object error) {
        _wsLog('error: $error');
        _wsDebug('error: $error');
        _controller.addError(error);
        _handleDisconnect();
      },
      onDone: () {
        _wsLog('connection closed');
        _wsDebug('connection closed — stream done');
        _handleDisconnect();
      },
    );
    _wsDebug('stream listener attached');
  }

  void _handleDisconnect() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _channel = null;
    _sub = null;

    if (_disposed || _activeRoomId == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _wsLog('reconnect: max attempts reached, giving up');
      _wsDebug('reconnect: FAILED after $_maxReconnectAttempts attempts');
      return;
    }

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final delay = Duration(seconds: 1 << (_reconnectAttempts - 1));
    _wsLog('reconnect: attempt $_reconnectAttempts in ${delay.inSeconds}s');
    _wsDebug(
      'reconnect: scheduling attempt $_reconnectAttempts in ${delay.inSeconds}s',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_disposed && _activeRoomId != null) {
        _connectInternal(_activeRoomId!);
      }
    });
  }

  /// Send a signaling message to a specific peer.
  void send({
    required String type,
    required String to,
    required Map<String, dynamic> payload,
  }) {
    _wsLog('send: type=$type to=$to');
    _channel?.sink.add(
      jsonEncode({'type': type, 'to': to, 'payload': payload}),
    );
  }

  /// Send an SDP offer to [targetUserId].
  void sendOffer(String targetUserId, Map<String, dynamic> sdp) {
    send(type: 'offer', to: targetUserId, payload: sdp);
  }

  /// Send an SDP answer to [targetUserId].
  void sendAnswer(String targetUserId, Map<String, dynamic> sdp) {
    send(type: 'answer', to: targetUserId, payload: sdp);
  }

  /// Send an ICE candidate to [targetUserId].
  void sendCandidate(String targetUserId, Map<String, dynamic> candidate) {
    send(type: 'candidate', to: targetUserId, payload: candidate);
  }

  /// Send a keepalive pong to prevent server timeout.
  void sendPong() {
    _channel?.sink.add(jsonEncode({'type': 'pong'}));
  }

  /// Close the WebSocket connection permanently.
  void dispose() {
    _wsLog('dispose');
    _disposed = true;
    _activeRoomId = null;
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    if (!_controller.isClosed) _controller.close();
  }
}

/// Parsed signaling message from the server relay.
final class SignalEnvelope {
  const SignalEnvelope({
    required this.type,
    this.from,
    this.to,
    this.payload = const {},
  });

  final String type;
  final String? from;
  final String? to;
  final Map<String, dynamic> payload;

  factory SignalEnvelope.fromJson(Map<String, dynamic> json) => SignalEnvelope(
    type: json['type'] as String,
    from: json['from'] as String?,
    to: json['to'] as String?,
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : {},
  );

  bool get isOffer => type == 'offer';
  bool get isAnswer => type == 'answer';
  bool get isCandidate => type == 'candidate';
  bool get isPeerJoined => type == 'peer_joined';
  bool get isPeerLeft => type == 'peer_left';
  bool get isRoomState => type == 'room_state';
}
