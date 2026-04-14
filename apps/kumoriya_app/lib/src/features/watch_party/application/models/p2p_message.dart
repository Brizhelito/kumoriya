import 'dart:convert';

/// Messages sent over WebRTC DataChannels between peers.
/// These never touch the server.
enum P2PMessageType {
  /// Playback synchronization.
  sync,

  /// Emoji/gesture reaction.
  reaction,

  /// Text chat message.
  chat,

  /// Episode change request (host only).
  episodeChange,

  /// Full media change — different anime or episode (host only).
  mediaChange,

  /// Ready state toggle.
  ready,

  /// Kick a member (host only).
  kick,
}

final class P2PMessage {
  const P2PMessage({
    required this.type,
    required this.senderId,
    this.senderName = '',
    this.payload = const {},
  });

  final P2PMessageType type;
  final String senderId;
  final String senderName;
  final Map<String, dynamic> payload;

  String encode() => jsonEncode({
        'type': type.name,
        'senderId': senderId,
        'senderName': senderName,
        'payload': payload,
      });

  static P2PMessage? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final typeName = json['type'] as String;
      final type = P2PMessageType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => P2PMessageType.sync,
      );
      return P2PMessage(
        type: type,
        senderId: json['senderId'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '',
        payload: json['payload'] as Map<String, dynamic>? ?? {},
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Convenience constructors ──

extension P2PMessageFactory on P2PMessage {
  static P2PMessage syncState({
    required String senderId,
    required bool isPlaying,
    required int positionMs,
  }) =>
      P2PMessage(
        type: P2PMessageType.sync,
        senderId: senderId,
        payload: {'isPlaying': isPlaying, 'positionMs': positionMs},
      );

  static P2PMessage reaction({
    required String senderId,
    required String senderName,
    required String emoji,
  }) =>
      P2PMessage(
        type: P2PMessageType.reaction,
        senderId: senderId,
        senderName: senderName,
        payload: {'emoji': emoji},
      );

  static P2PMessage chatMessage({
    required String senderId,
    required String senderName,
    required String text,
  }) =>
      P2PMessage(
        type: P2PMessageType.chat,
        senderId: senderId,
        senderName: senderName,
        payload: {'text': text},
      );

  static P2PMessage episodeChange({
    required String senderId,
    required double episodeNumber,
  }) =>
      P2PMessage(
        type: P2PMessageType.episodeChange,
        senderId: senderId,
        payload: {'episodeNumber': episodeNumber},
      );

  /// Host changes anime + episode (full navigation change).
  static P2PMessage mediaChange({
    required String senderId,
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
  }) =>
      P2PMessage(
        type: P2PMessageType.mediaChange,
        senderId: senderId,
        payload: {
          'anilistId': anilistId,
          'animeTitle': animeTitle,
          'episodeNumber': episodeNumber,
        },
      );

  static P2PMessage readyToggle({
    required String senderId,
    required bool ready,
  }) =>
      P2PMessage(
        type: P2PMessageType.ready,
        senderId: senderId,
        payload: {'ready': ready},
      );
}
