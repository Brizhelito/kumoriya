/// Short-lived realtime session emitted by kumoriya-api when the client
/// creates/joins a watch-party room. The client uses `websocketUrl` to open
/// a WebSocket against the Party Realtime Worker; the token is embedded in
/// the URL and also exposed as `sessionToken` so clients can reconstruct
/// the URL on reconnect if needed.
final class PartyRealtimeSession {
  const PartyRealtimeSession({
    required this.roomId,
    required this.websocketUrl,
    required this.sessionToken,
    required this.expiresAt,
    required this.heartbeatIntervalSec,
  });

  final String roomId;
  final String websocketUrl;
  final String sessionToken;
  final DateTime expiresAt;
  final int heartbeatIntervalSec;

  factory PartyRealtimeSession.fromJson(Map<String, dynamic> json) =>
      PartyRealtimeSession(
        roomId: json['roomId'] as String,
        websocketUrl: json['websocketUrl'] as String,
        sessionToken: json['sessionToken'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          ((json['expiresAt'] as num).toInt()) * 1000,
          isUtc: true,
        ),
        heartbeatIntervalSec: (json['heartbeatIntervalSec'] as num).toInt(),
      );
}

/// Combined response from /api/v1/party and /api/v1/party/join when the
/// realtime v2 flow is enabled. The `room` carries bootstrap metadata; the
/// authoritative snapshot arrives later over the WebSocket.
final class PartyRoomWithSession<T> {
  const PartyRoomWithSession({required this.room, required this.session});
  final T room;
  final PartyRealtimeSession session;
}
