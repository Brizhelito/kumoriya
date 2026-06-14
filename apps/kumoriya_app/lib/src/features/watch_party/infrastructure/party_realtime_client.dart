import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../application/models/models.dart';
import 'party_debug_logger.dart';

const bool _watchPartyVerboseLogs = bool.fromEnvironment(
  'WATCH_PARTY_VERBOSE_LOGS',
  defaultValue: false,
);

/// Incoming envelope as parsed from the Party Realtime Worker. The shape
/// matches the TypeScript `WSEnvelope` emitted by `PartyRoomDO`.
final class PartyEventEnvelope {
  const PartyEventEnvelope({
    required this.type,
    required this.sentAtMs,
    this.roomId,
    this.roomVersion,
    this.sender,
    this.eventId,
    this.messageId,
    this.payload = const <String, dynamic>{},
  });

  final String type;
  final int sentAtMs;
  final String? roomId;
  final int? roomVersion;
  final String? sender;
  final String? eventId;
  final String? messageId;
  final Map<String, dynamic> payload;

  static PartyEventEnvelope? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'];
      if (type is! String) return null;
      final payload = decoded['payload'];
      return PartyEventEnvelope(
        type: type,
        sentAtMs: (decoded['sentAt'] as num?)?.toInt() ?? 0,
        roomId: decoded['roomId'] as String?,
        roomVersion: (decoded['roomVersion'] as num?)?.toInt(),
        sender: decoded['sender'] as String?,
        eventId: decoded['eventId'] as String?,
        messageId: decoded['messageId'] as String?,
        payload: payload is Map<String, dynamic>
            ? payload
            : const <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }
}

/// Connection lifecycle observable by the notifier.
enum PartyRealtimeStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  expiredSession,
  closed,
  error,
}

/// Lightweight Ack/Error response correlation object.
final class PartyAck {
  const PartyAck({
    required this.messageId,
    required this.success,
    this.type,
    this.error,
  });
  final String messageId;
  final bool success;
  final String? type;
  final String? error;
}

/// Session refresh callback. When the server reports
/// `expired_token` the client asks the app for a fresh session and retries.
typedef SessionRefresher = Future<PartyRealtimeSession?> Function();

/// Ed25519-authenticated WebSocket client for the Party Realtime Worker.
///
/// Responsibilities:
///   - Open `wss://.../ws?token=…` using the session emitted by kumoriya-api.
///   - Send `hello` on open and `heartbeat` every `heartbeatIntervalSec`.
///   - Reconnect with exponential backoff when the socket drops.
///   - Refresh the session token once when the server closes with
///     `expired_token`.
///   - Expose a stream of parsed envelopes to the reducer layer.
final class PartyRealtimeClient {
  PartyRealtimeClient({
    required PartyRealtimeSession session,
    required this.sessionRefresher,
    this.maxReconnectAttempts = 6,
  }) : _session = session;

  PartyRealtimeSession _session;
  final SessionRefresher sessionRefresher;
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;
  bool _refreshedThisSession = false;

  final _events = StreamController<PartyEventEnvelope>.broadcast();
  final _status = StreamController<PartyRealtimeStatus>.broadcast();
  PartyRealtimeStatus _currentStatus = PartyRealtimeStatus.idle;

  String get roomId => _session.roomId;
  Stream<PartyEventEnvelope> get events => _events.stream;
  Stream<PartyRealtimeStatus> get statusChanges => _status.stream;
  PartyRealtimeStatus get status => _currentStatus;
  bool get isConnected => _currentStatus == PartyRealtimeStatus.connected;

  void connect() {
    if (_disposed) return;
    _emitStatus(PartyRealtimeStatus.connecting);
    _openSocket();
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
    if (!_events.isClosed) await _events.close();
    if (!_status.isClosed) await _status.close();
  }

  // ── Client → server senders ────────────────────────────────────────────────

  String sendHello() => _send('hello', <String, dynamic>{});

  String sendSetReady(bool ready) =>
      _send('set_ready', <String, dynamic>{'ready': ready});

  String sendSetStatus(PartyMemberStatus status) =>
      _send('set_status', <String, dynamic>{'status': status.jsonValue});

  String sendReaction(String reaction) =>
      _send('send_reaction', <String, dynamic>{'reaction': reaction});

  String sendLeaveRoom() => _send('leave_room', <String, dynamic>{});

  String sendRequestSnapshot() =>
      _send('request_snapshot', <String, dynamic>{});

  /// Playback intents are host-only. The Worker enforces this; the client
  /// passes through whatever the host-side UI requests.
  ///
  /// `sourcePluginId`, `serverName`, and `resolverPluginId` are only
  /// meaningful for the `source_selected` action; the Worker ignores
  /// them for other actions but accepts them for forward-compat.
  String sendPlaybackIntent({
    required String action,
    int? positionMs,
    int? anilistId,
    double? episodeNumber,
    String? sourcePluginId,
    String? serverName,
    String? resolverPluginId,
  }) {
    final payload = <String, dynamic>{'action': action};
    if (positionMs != null) payload['positionMs'] = positionMs;
    if (anilistId != null) payload['anilistId'] = anilistId;
    if (episodeNumber != null) payload['episodeNumber'] = episodeNumber;
    if (sourcePluginId != null) payload['sourcePluginId'] = sourcePluginId;
    if (serverName != null) payload['serverName'] = serverName;
    if (resolverPluginId != null) {
      payload['resolverPluginId'] = resolverPluginId;
    }
    return _send('playback_intent', payload);
  }

  /// Host-only: request the Worker to evict `targetUserId`. The target
  /// receives a `kicked` event on its own socket before the Worker closes
  /// their connection.
  String sendKickMember({required String targetUserId, String? reason}) {
    final payload = <String, dynamic>{'targetUserId': targetUserId};
    if (reason != null) payload['reason'] = reason;
    return _send('kick_member', payload);
  }

  /// Host-only: transfer host authority to `targetUserId` without leaving
  /// the room. The Worker broadcasts the existing `host_transferred`
  /// event so every client (including the old host) picks up the change.
  String sendTransferHost({required String targetUserId}) =>
      _send('transfer_host', <String, dynamic>{'targetUserId': targetUserId});

  /// Relay a WebRTC signal. Reserved for future voice chat — the lobby
  /// never uses this.
  String sendWebRtcSignal({
    required String targetUserId,
    required String type,
    required Object? signal,
  }) => _send('webrtc_signal', <String, dynamic>{
    'targetUserId': targetUserId,
    'type': type,
    'signal': signal,
  });

  // ── Internals ──────────────────────────────────────────────────────────────

  String _send(String type, Map<String, dynamic> payload) {
    final messageId = _makeMessageId();
    final envelope = <String, dynamic>{
      'type': type,
      'messageId': messageId,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    };
    final channel = _channel;
    if (channel == null) {
      _debug('drop-send: $type (no socket)');
      return messageId;
    }
    try {
      channel.sink.add(jsonEncode(envelope));
    } catch (e) {
      _debug('send $type failed: $e');
    }
    return messageId;
  }

  void _openSocket() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;

    final url = _session.websocketUrl;
    _debug('connect attempt=$_reconnectAttempts url=${_maskToken(url)}');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
    } catch (e) {
      _debug('connect threw: $e');
      _scheduleReconnect(reason: 'socket_threw');
      return;
    }

    _sub = _channel!.stream.listen(
      (dynamic raw) {
        if (raw is! String) return;
        // Short-circuit the heartbeat auto-response. It is intentionally
        // not a PartyEventEnvelope (it must match setWebSocketAutoResponse
        // byte-for-byte) so we must not waste a parse attempt on it.
        if (raw == _heartbeatAckLiteral) return;
        final envelope = PartyEventEnvelope.tryParse(raw);
        if (envelope == null) {
          _debug('recv: parse failure (${raw.length} bytes)');
          return;
        }
        if (!_events.isClosed) _events.add(envelope);
        // First message after a (re)connect transitions us to connected.
        if (_currentStatus != PartyRealtimeStatus.connected) {
          _onConnectedEstablished();
        }
      },
      onError: (Object err) {
        _debug('error: $err');
        _emitStatus(PartyRealtimeStatus.error);
        _scheduleReconnect(reason: 'stream_error');
      },
      onDone: () {
        _debug(
          'socket done; closeCode=${_channel?.closeCode} closeReason=${_channel?.closeReason}',
        );
        final closeCode = _channel?.closeCode;
        final closeReason = _channel?.closeReason ?? '';
        if (_isAuthClose(closeCode, closeReason)) {
          _handleAuthFailure();
          return;
        }
        _scheduleReconnect(reason: 'socket_closed');
      },
      cancelOnError: false,
    );

    // Fire `hello` and start the heartbeat as soon as the socket is attached;
    // we transition to `connected` on the first received frame.
    //
    // R2: heartbeats are sent as the raw literal string `{"t":"hb"}`, which
    // matches the `setWebSocketAutoResponse` pair configured on the Worker
    // side. When this literal arrives at the DO, Cloudflare replies with
    // `{"t":"hb_ack"}` WITHOUT waking the DO from hibernation and WITHOUT
    // counting a billable request. This eliminates the per-heartbeat DO
    // cost (previously: one envelope in + one storage put + one ack out).
    _heartbeatTimer?.cancel();
    final interval = Duration(seconds: _session.heartbeatIntervalSec);
    _heartbeatTimer = Timer.periodic(interval, (_) {
      final channel = _channel;
      if (channel == null) return;
      try {
        channel.sink.add(_heartbeatLiteral);
      } catch (e) {
        _debug('heartbeat send failed: $e');
      }
    });
    sendHello();
  }

  /// Exact literal the Worker's `setWebSocketAutoResponse` is keyed on.
  /// MUST NOT drift — any whitespace or extra field would bypass the
  /// auto-response and fall back to the billable `handleHeartbeat` path.
  static const String _heartbeatLiteral = '{"t":"hb"}';

  /// The fixed response CF emits for `_heartbeatLiteral`. Swallowed in the
  /// receive pipeline so it never reaches the envelope parser.
  static const String _heartbeatAckLiteral = '{"t":"hb_ack"}';

  void _onConnectedEstablished() {
    _reconnectAttempts = 0;
    _refreshedThisSession = false;
    _emitStatus(PartyRealtimeStatus.connected);
  }

  void _scheduleReconnect({required String reason}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channel = null;
    if (_disposed) return;

    if (_reconnectAttempts >= maxReconnectAttempts) {
      _debug(
        'giving up reconnect after $_reconnectAttempts attempts ($reason)',
      );
      _emitStatus(PartyRealtimeStatus.error);
      return;
    }
    _reconnectAttempts++;
    final backoffMs = 250 * (1 << (_reconnectAttempts - 1));
    final cappedMs = backoffMs > 8000 ? 8000 : backoffMs;
    _debug('reconnect in ${cappedMs}ms ($reason)');
    _emitStatus(PartyRealtimeStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: cappedMs), _openSocket);
  }

  Future<void> _handleAuthFailure() async {
    _heartbeatTimer?.cancel();
    _channel = null;
    if (_refreshedThisSession) {
      _debug('already refreshed once; giving up');
      _emitStatus(PartyRealtimeStatus.expiredSession);
      return;
    }
    _refreshedThisSession = true;
    _emitStatus(PartyRealtimeStatus.reconnecting);
    try {
      final next = await sessionRefresher();
      if (next == null) {
        _emitStatus(PartyRealtimeStatus.expiredSession);
        return;
      }
      _session = next;
      _openSocket();
    } catch (e) {
      _debug('session refresh failed: $e');
      _emitStatus(PartyRealtimeStatus.expiredSession);
    }
  }

  bool _isAuthClose(int? code, String reason) {
    if (code == 4001 || code == 4002 || code == 4003) return true;
    if (reason.contains('expired_token') || reason.contains('invalid_token')) {
      return true;
    }
    return false;
  }

  void _emitStatus(PartyRealtimeStatus status) {
    _currentStatus = status;
    if (!_status.isClosed) _status.add(status);
  }

  String _makeMessageId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
  int _idCounter = 0;

  void _debug(String msg) {
    if (!_watchPartyVerboseLogs) return;
    dev.log(msg, name: 'PartyRealtime');
    PartyDebugLogger.log('Realtime', msg);
  }

  String _maskToken(String url) {
    try {
      final uri = Uri.parse(url);
      final redacted = {
        for (final e in uri.queryParameters.entries)
          e.key: e.key == 'token' ? '***' : e.value,
      };
      return uri.replace(queryParameters: redacted).toString();
    } catch (_) {
      return url;
    }
  }
}
