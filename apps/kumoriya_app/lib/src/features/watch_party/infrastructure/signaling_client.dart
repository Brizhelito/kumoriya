import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Ephemeral WebSocket client for WebRTC signaling relay.
/// Connects to the server only to exchange SDP offers/answers and ICE
/// candidates between peers. Once P2P DataChannels are established the
/// connection should be closed via [dispose].
final class SignalingClient {
  SignalingClient({
    required String wsUrl,
    required String accessToken,
  }) : _wsUrl = wsUrl,
       _accessToken = accessToken;

  final String _wsUrl;
  final String _accessToken;

  WebSocketChannel? _channel;
  final _controller = StreamController<SignalEnvelope>.broadcast();
  StreamSubscription<dynamic>? _sub;

  /// Stream of incoming signaling messages.
  Stream<SignalEnvelope> get messages => _controller.stream;

  bool get isConnected => _channel != null;

  /// Connect to the signaling relay for [roomId].
  void connect(String roomId) {
    if (_channel != null) return;

    final parsed = Uri.parse('$_wsUrl/api/v1/party/$roomId/signal');
    // Uri.parse leaves port=0 for wss:// with no explicit port.
    // WebSocketChannel.connect passes that 0 to HttpClient, failing the
    // upgrade. Force 443 for wss, 80 for ws when the port is implicit.
    final withPort = parsed.port == 0
        ? parsed.replace(port: parsed.scheme == 'wss' ? 443 : 80)
        : parsed;
    // Send auth as query param — WebSocket API does not support custom
    // headers consistently across platforms.
    final uri = withPort.replace(
      queryParameters: {'token': _accessToken},
    );
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (dynamic data) {
        if (data is! String) return;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _controller.add(SignalEnvelope.fromJson(json));
        } catch (_) {
          // Ignore malformed messages.
        }
      },
      onError: (Object error) {
        _controller.addError(error);
      },
      onDone: () {
        _cleanup();
      },
    );
  }

  /// Send a signaling message to a specific peer.
  void send({
    required String type,
    required String to,
    required Map<String, dynamic> payload,
  }) {
    _channel?.sink.add(jsonEncode({
      'type': type,
      'to': to,
      'payload': payload,
    }));
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

  /// Close the WebSocket connection.
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _cleanup();
    _controller.close();
  }

  void _cleanup() {
    _channel = null;
    _sub = null;
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
