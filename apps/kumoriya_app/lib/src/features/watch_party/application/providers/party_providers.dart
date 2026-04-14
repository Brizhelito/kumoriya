import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';

import '../../../../shared/auth/auth_providers.dart';
import '../models/models.dart';
import '../party_sync_engine.dart';
import '../../infrastructure/party_api_client.dart';
import '../../infrastructure/signaling_client.dart';
import '../../infrastructure/webrtc_peer_manager.dart';

void _partyLog(String msg) => dev.log(msg, name: 'Party');

// ── API base URLs ──

const _apiBaseUrl = 'https://api.kumoriya.online';
const _wsBaseUrl = 'wss://api.kumoriya.online';

// ── Infrastructure providers ──

final partyApiClientProvider = Provider<PartyApiClient>((ref) {
  final httpClient = ref.watch(authenticatedHttpClientProvider);
  return PartyApiClient(httpClient: httpClient, baseUrl: _apiBaseUrl);
});

// ── Party session state ──

enum PartySessionStatus {
  idle,
  creating,
  joining,
  connecting,
  connected,
  error,
}

final class PartySessionState {
  const PartySessionState({
    this.status = PartySessionStatus.idle,
    this.room,
    this.error,
    this.reactions = const [],
    this.chatMessages = const [],
    this.readyStates = const {},
    this.connectedPeerIds = const {},
  });

  final PartySessionStatus status;
  final PartyRoom? room;
  final String? error;
  final List<PartyReaction> reactions;
  final List<PartyChatMessage> chatMessages;
  final Map<String, bool> readyStates;
  final Set<String> connectedPeerIds;

  bool get isActive =>
      status == PartySessionStatus.connected ||
      status == PartySessionStatus.connecting;

  PartySessionState copyWith({
    PartySessionStatus? status,
    PartyRoom? room,
    String? error,
    List<PartyReaction>? reactions,
    List<PartyChatMessage>? chatMessages,
    Map<String, bool>? readyStates,
    Set<String>? connectedPeerIds,
  }) =>
      PartySessionState(
        status: status ?? this.status,
        room: room ?? this.room,
        error: error,
        reactions: reactions ?? this.reactions,
        chatMessages: chatMessages ?? this.chatMessages,
        readyStates: readyStates ?? this.readyStates,
        connectedPeerIds: connectedPeerIds ?? this.connectedPeerIds,
      );
}

/// Lightweight reaction model for the UI overlay.
final class PartyReaction {
  const PartyReaction({
    required this.senderId,
    required this.senderName,
    required this.emoji,
    required this.timestamp,
  });
  final String senderId;
  final String senderName;
  final String emoji;
  final DateTime timestamp;
}

/// Chat message for the party chat overlay.
final class PartyChatMessage {
  const PartyChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
}

// ── Session notifier ──

final partySessionProvider =
    NotifierProvider<PartySessionNotifier, PartySessionState>(
  PartySessionNotifier.new,
);

/// Callback when the host changes the media (anime/episode).
typedef OnMediaChangeNavigation = void Function(
  int anilistId, String animeTitle, double episodeNumber,
);

class PartySessionNotifier extends Notifier<PartySessionState> {
  SignalingClient? _signaling;
  WebRtcPeerManager? _peerManager;
  PartySyncEngine? _syncEngine;

  PartySyncEngine? get syncEngine => _syncEngine;

  /// External callback for navigation when media changes (set by UI).
  /// Set this ONCE when navigating to the lobby or player, not on every rebuild.
  OnMediaChangeNavigation? onMediaChangeNavigation;

  @override
  PartySessionState build() => const PartySessionState();

  /// Create a new party room and connect.
  Future<void> createRoom({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
  }) async {
    state = state.copyWith(status: PartySessionStatus.creating);
    try {
      final api = ref.read(partyApiClientProvider);
      final room = await api.createRoom(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      );
      state = state.copyWith(
        status: PartySessionStatus.connecting,
        room: room,
      );
      await _connectP2P(room, isHost: true);
    } on PartyApiException catch (e) {
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Join an existing room by invite code and connect.
  Future<void> joinRoom(String inviteCode) async {
    state = state.copyWith(status: PartySessionStatus.joining);
    try {
      final api = ref.read(partyApiClientProvider);
      final room = await api.joinRoom(inviteCode);
      state = state.copyWith(
        status: PartySessionStatus.connecting,
        room: room,
      );
      await _connectP2P(room, isHost: false);
    } on PartyApiException catch (e) {
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Leave the current party and tear down connections.
  Future<void> leaveRoom() async {
    try {
      final api = ref.read(partyApiClientProvider);
      await api.leaveRoom();
    } catch (_) {
      // Best-effort — server will clean up on timeout anyway.
    }
    await _disconnect();
    state = const PartySessionState();
  }

  /// Send a reaction emoji to all peers.
  void sendReaction(String emoji) {
    _syncEngine?.sendReaction(emoji);
  }

  /// Send a chat message to all peers.
  void sendChat(String text) {
    _syncEngine?.sendChat(text);
  }

  /// Toggle ready state.
  void toggleReady(bool ready) {
    _syncEngine?.sendReady(ready);
  }

  /// Update local playback state for sync.
  void updatePlayback({required bool isPlaying, required int positionMs}) {
    _syncEngine?.updatePlaybackState(
      isPlaying: isPlaying,
      positionMs: positionMs,
    );
  }

  /// Immediately sync current playback state (on play/pause/seek).
  void syncNow() {
    _syncEngine?.broadcastSyncNow();
  }

  /// Request episode change (host only).
  void changeEpisode(double episodeNumber) {
    _syncEngine?.sendEpisodeChange(episodeNumber);
  }

  /// Change the current media (anime + episode) for the whole room (host only).
  /// Updates server state, broadcasts P2P, and triggers local navigation.
  Future<void> changeMedia({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
  }) async {
    final room = state.room;
    if (room == null) {
      _partyLog('changeMedia: no active room');
      return;
    }

    _partyLog('changeMedia: anilistId=$anilistId episode=$episodeNumber title=$animeTitle');

    // 1. Update local room state IMMEDIATELY (optimistic update).
    state = state.copyWith(
      room: room.copyWith(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      ),
    );

    // 2. Update server-side room metadata (best-effort).
    try {
      final api = ref.read(partyApiClientProvider);
      final updated = await api.updateRoom(
        room.id,
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      );
      state = state.copyWith(room: updated);
      _partyLog('changeMedia: server updated');
    } catch (e) {
      _partyLog('changeMedia: server update failed: $e');
      // Best-effort — P2P broadcast is the real source of truth.
    }

    // 3. Broadcast to all peers via P2P.
    _syncEngine?.sendMediaChange(
      anilistId: anilistId,
      animeTitle: animeTitle,
      episodeNumber: episodeNumber,
    );
  }

  /// Kick a member (host only).
  void kickMember(String userId) {
    _syncEngine?.kickMember(userId);
  }

  // ── Internal P2P lifecycle ──

  Future<void> _connectP2P(PartyRoom room, {required bool isHost}) async {
    _partyLog('_connectP2P: room=${room.id} isHost=$isHost members=${room.members.length}');
    final asyncAuth = ref.read(authStateProvider);
    final authState = asyncAuth.value;
    if (authState is! AuthenticatedAuthState) {
      _partyLog('_connectP2P: not authenticated');
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: 'Not authenticated',
      );
      return;
    }

    // Get token for WS auth.
    final tokenStore = ref.read(secureTokenStoreProvider);
    final tokens = await tokenStore.loadTokens();
    if (tokens == null) {
      _partyLog('_connectP2P: no auth tokens');
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: 'No auth tokens',
      );
      return;
    }

    final userId = room.members
        .firstWhere(
          (m) => m.role == (isHost ? PartyRole.host : PartyRole.member),
          orElse: () => room.members.first,
        )
        .userId;
    _partyLog('_connectP2P: userId=$userId');

    // 1. Create signaling client.
    _signaling = SignalingClient(
      wsUrl: _wsBaseUrl,
      accessToken: tokens.accessToken,
    );

    // 2. Create peer manager.
    _peerManager = WebRtcPeerManager(
      localUserId: userId,
      onPeerStateChange: _onPeerStateChange,
    );

    // 3. Create sync engine.
    _syncEngine = PartySyncEngine(
      peerManager: _peerManager!,
      localUserId: userId,
      localUserName: room.members
              .where((m) => m.userId == userId)
              .firstOrNull
              ?.displayName ??
          'User',
      isHost: isHost,
    );

    // Wire sync callbacks.
    _syncEngine!.onReaction = _onReaction;
    _syncEngine!.onChatMessage = _onChatMessage;
    _syncEngine!.onReadyToggle = _onReadyToggle;
    _syncEngine!.onKick = _onKick;
    _syncEngine!.onMediaChange = _onMediaChange;

    // 4. Connect: signaling → peer manager.
    _peerManager!.connect(_signaling!);
    _signaling!.connect(room.id);
    _partyLog('_connectP2P: signaling connected, room=$isHost');

    if (isHost) {
      _syncEngine!.startHostSync();
      _partyLog('_connectP2P: host sync started');
    }

    state = state.copyWith(status: PartySessionStatus.connected);
    _partyLog('_connectP2P: status=connected');
  }

  Future<void> _disconnect() async {
    _syncEngine?.dispose();
    _syncEngine = null;
    await _peerManager?.dispose();
    _peerManager = null;
    _signaling?.dispose();
    _signaling = null;
  }

  void _onPeerStateChange(String peerId, bool connected) {
    final current = Set<String>.from(state.connectedPeerIds);
    if (connected) {
      current.add(peerId);
    } else {
      current.remove(peerId);
    }
    state = state.copyWith(connectedPeerIds: current);
  }

  void _onReaction(String senderId, String senderName, String emoji) {
    final reactions = [
      ...state.reactions,
      PartyReaction(
        senderId: senderId,
        senderName: senderName,
        emoji: emoji,
        timestamp: DateTime.now(),
      ),
    ];
    // Keep last 50 reactions.
    final trimmed =
        reactions.length > 50 ? reactions.sublist(reactions.length - 50) : reactions;
    state = state.copyWith(reactions: trimmed);
  }

  void _onChatMessage(String senderId, String senderName, String text) {
    final messages = [
      ...state.chatMessages,
      PartyChatMessage(
        senderId: senderId,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
      ),
    ];
    // Keep last 100 messages.
    final trimmed =
        messages.length > 100 ? messages.sublist(messages.length - 100) : messages;
    state = state.copyWith(chatMessages: trimmed);
  }

  void _onReadyToggle(String senderId, bool ready) {
    final readyStates = Map<String, bool>.from(state.readyStates);
    readyStates[senderId] = ready;
    state = state.copyWith(readyStates: readyStates);
  }

  void _onKick(String targetUserId) {
    // If we are the kicked user, leave.
    if (_isLocalUser(targetUserId)) {
      leaveRoom();
    }
  }

  void _onMediaChange(
    String senderId,
    int anilistId,
    String animeTitle,
    double episodeNumber,
  ) {
    _partyLog('_onMediaChange: anilistId=$anilistId episode=$episodeNumber from=$senderId');
    // Update local room state.
    final room = state.room;
    if (room != null) {
      state = state.copyWith(
        room: room.copyWith(
          anilistId: anilistId,
          animeTitle: animeTitle,
          episodeNumber: episodeNumber,
        ),
      );
    }
    // Trigger navigation for non-host members.
    // Only call if set — the UI is responsible for setting this before media changes.
    if (onMediaChangeNavigation != null) {
      _partyLog('_onMediaChange: triggering navigation callback');
      onMediaChangeNavigation!(anilistId, animeTitle, episodeNumber);
    } else {
      _partyLog('_onMediaChange: no navigation callback set');
    }
  }

  bool _isLocalUser(String userId) {
    final room = state.room;
    if (room == null) return false;
    // Compare by checking if the peer manager's localUserId matches.
    return _peerManager?.localUserId == userId;
  }
}
