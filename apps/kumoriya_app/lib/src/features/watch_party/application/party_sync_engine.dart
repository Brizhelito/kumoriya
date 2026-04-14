import 'dart:async';

import 'models/p2p_message.dart';
import '../infrastructure/webrtc_peer_manager.dart';

/// Callback types for the sync engine.
typedef OnSyncState = void Function(bool isPlaying, int positionMs);
typedef OnReaction = void Function(String senderId, String senderName, String emoji);
typedef OnChatMessage = void Function(String senderId, String senderName, String text);
typedef OnEpisodeChange = void Function(String senderId, double episodeNumber);
typedef OnMediaChange = void Function(String senderId, int anilistId, String animeTitle, double episodeNumber);
typedef OnReadyToggle = void Function(String senderId, bool ready);
typedef OnKick = void Function(String targetUserId);

/// Orchestrates P2P message routing for playback sync, reactions, chat,
/// and room control. Sits on top of [WebRtcPeerManager] and dispatches
/// incoming [P2PMessage]s to typed callbacks.
///
/// The host periodically broadcasts sync state. Members apply it.
final class PartySyncEngine {
  PartySyncEngine({
    required WebRtcPeerManager peerManager,
    required this.localUserId,
    required this.localUserName,
    required this.isHost,
  }) : _peerManager = peerManager {
    _peerManager.onMessage = _onMessage;
  }

  final WebRtcPeerManager _peerManager;
  final String localUserId;
  final String localUserName;
  final bool isHost;

  // ── Callbacks set by the provider/UI layer ──

  OnSyncState? onSyncState;
  OnReaction? onReaction;
  OnChatMessage? onChatMessage;
  OnEpisodeChange? onEpisodeChange;
  OnMediaChange? onMediaChange;
  OnReadyToggle? onReadyToggle;
  OnKick? onKick;

  Timer? _syncTimer;

  /// The latest local playback state — kept in sync by the player.
  bool _isPlaying = false;
  int _positionMs = 0;

  /// Threshold in ms — ignore sync if delta is below this.
  static const _syncThresholdMs = 1500;

  /// How often the host broadcasts sync state.
  static const _syncIntervalMs = 2000;

  /// Start periodic sync broadcasting (host only).
  void startHostSync() {
    if (!isHost) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(milliseconds: _syncIntervalMs),
      (_) => _broadcastSync(),
    );
  }

  /// Stop periodic sync broadcasting.
  void stopHostSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Update local playback state (called by the player layer).
  void updatePlaybackState({required bool isPlaying, required int positionMs}) {
    _isPlaying = isPlaying;
    _positionMs = positionMs;
  }

  /// Immediately broadcast current sync state (e.g. on play/pause).
  void broadcastSyncNow() {
    _broadcastSync();
  }

  /// Send a reaction emoji to all peers.
  void sendReaction(String emoji) {
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.reaction,
      senderId: localUserId,
      senderName: localUserName,
      payload: {'emoji': emoji},
    ));
  }

  /// Send a chat message to all peers.
  void sendChat(String text) {
    if (text.trim().isEmpty) return;
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.chat,
      senderId: localUserId,
      senderName: localUserName,
      payload: {'text': text},
    ));
  }

  /// Request an episode change (host only).
  void sendEpisodeChange(double episodeNumber) {
    if (!isHost) return;
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.episodeChange,
      senderId: localUserId,
      payload: {'episodeNumber': episodeNumber},
    ));
  }

  /// Request a full media change — different anime or episode (host only).
  void sendMediaChange({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
  }) {
    if (!isHost) return;
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.mediaChange,
      senderId: localUserId,
      payload: {
        'anilistId': anilistId,
        'animeTitle': animeTitle,
        'episodeNumber': episodeNumber,
      },
    ));
  }

  /// Toggle local ready state and broadcast.
  void sendReady(bool ready) {
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.ready,
      senderId: localUserId,
      payload: {'ready': ready},
    ));
  }

  /// Kick a member (host only).
  void kickMember(String targetUserId) {
    if (!isHost) return;
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.kick,
      senderId: localUserId,
      payload: {'targetUserId': targetUserId},
    ));
  }

  void dispose() {
    stopHostSync();
  }

  // ── Internal ──

  void _broadcastSync() {
    _peerManager.broadcast(P2PMessage(
      type: P2PMessageType.sync,
      senderId: localUserId,
      payload: {'isPlaying': _isPlaying, 'positionMs': _positionMs},
    ));
  }

  void _onMessage(String peerId, P2PMessage message) {
    switch (message.type) {
      case P2PMessageType.sync:
        _handleSync(message);
      case P2PMessageType.reaction:
        onReaction?.call(
          message.senderId,
          message.senderName,
          message.payload['emoji'] as String? ?? '❤️',
        );
      case P2PMessageType.chat:
        onChatMessage?.call(
          message.senderId,
          message.senderName,
          message.payload['text'] as String? ?? '',
        );
      case P2PMessageType.episodeChange:
        onEpisodeChange?.call(
          message.senderId,
          (message.payload['episodeNumber'] as num?)?.toDouble() ?? 0,
        );
      case P2PMessageType.mediaChange:
        onMediaChange?.call(
          message.senderId,
          (message.payload['anilistId'] as num?)?.toInt() ?? 0,
          message.payload['animeTitle'] as String? ?? '',
          (message.payload['episodeNumber'] as num?)?.toDouble() ?? 0,
        );
      case P2PMessageType.ready:
        onReadyToggle?.call(
          message.senderId,
          message.payload['ready'] as bool? ?? false,
        );
      case P2PMessageType.kick:
        final target = message.payload['targetUserId'] as String?;
        if (target != null) {
          onKick?.call(target);
        }
    }
  }

  void _handleSync(P2PMessage message) {
    final isPlaying = message.payload['isPlaying'] as bool? ?? false;
    final positionMs = message.payload['positionMs'] as int? ?? 0;

    // Only apply sync if we're not the host (host is authoritative).
    if (isHost) return;

    // Apply threshold — ignore small drifts.
    final delta = (positionMs - _positionMs).abs();
    if (delta < _syncThresholdMs && isPlaying == _isPlaying) return;

    onSyncState?.call(isPlaying, positionMs);
  }
}
