import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';

import '../../../../shared/auth/auth_providers.dart';
import '../models/models.dart';
import '../party_sync_engine.dart';
import '../realtime_state.dart';
import '../../infrastructure/party_api_client.dart';
import '../../infrastructure/party_realtime_client.dart';
import '../../infrastructure/signaling_client.dart';
import '../../infrastructure/webrtc_peer_manager.dart';
import '../../infrastructure/party_debug_logger.dart';
import 'voice_providers.dart';

const bool _watchPartyVerboseLogs = bool.fromEnvironment(
  'WATCH_PARTY_VERBOSE_LOGS',
  defaultValue: false,
);

void _partyLog(String msg) {
  if (!_watchPartyVerboseLogs) return;
  dev.log(msg, name: 'Party');
}

void _partyDebug(String msg) {
  if (!_watchPartyVerboseLogs) return;
  PartyDebugLogger.log('Provider', msg);
}

// ── API base URLs ──

const _apiBaseUrl = 'https://api.kumoriya.online';
const _wsBaseUrl = 'wss://api.kumoriya.online';

/// Compile-time flag that switches the notifier between the legacy P2P path
/// and the brokered realtime v2 path. v2 is the default once the backend
/// (kumoriya-api + Cloudflare Worker) has been deployed with the v2 stack.
/// To force a rollback build that uses the legacy P2P flow:
/// `flutter build ... --dart-define=WATCH_PARTY_REALTIME_V2=false`.
const bool kWatchPartyRealtimeV2 = bool.fromEnvironment(
  'WATCH_PARTY_REALTIME_V2',
  defaultValue: true,
);

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
    this.readyStates = const {},
    this.memberStatuses = const <String, PartyMemberStatus>{},
    this.connectedPeerIds = const {},
    this.playback = PartyPlaybackState.empty,
  });

  final PartySessionStatus status;
  final PartyRoom? room;
  final String? error;
  final List<PartyReaction> reactions;
  final Map<String, bool> readyStates;
  final Map<String, PartyMemberStatus> memberStatuses;
  final Set<String> connectedPeerIds;
  final PartyPlaybackState playback;

  bool get isActive =>
      status == PartySessionStatus.connected ||
      status == PartySessionStatus.connecting;

  PartySessionState copyWith({
    PartySessionStatus? status,
    PartyRoom? room,
    String? error,
    List<PartyReaction>? reactions,
    Map<String, bool>? readyStates,
    Map<String, PartyMemberStatus>? memberStatuses,
    Set<String>? connectedPeerIds,
    PartyPlaybackState? playback,
  }) => PartySessionState(
    status: status ?? this.status,
    room: room ?? this.room,
    error: error,
    reactions: reactions ?? this.reactions,
    readyStates: readyStates ?? this.readyStates,
    memberStatuses: memberStatuses ?? this.memberStatuses,
    connectedPeerIds: connectedPeerIds ?? this.connectedPeerIds,
    playback: playback ?? this.playback,
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

// ── Session notifier ──

final partySessionProvider =
    NotifierProvider<PartySessionNotifier, PartySessionState>(
      PartySessionNotifier.new,
    );

/// Callback when the host changes the media (anime/episode).
typedef OnMediaChangeNavigation =
    void Function(int anilistId, String animeTitle, double episodeNumber);

/// Callback used by the player to react to authoritative playback updates.
/// `positionMs` is the already-projected position at the moment of dispatch.
typedef PartyOnSyncState = void Function(bool isPlaying, int positionMs);

class PartySessionNotifier extends Notifier<PartySessionState> {
  // Legacy P2P plumbing (used when kWatchPartyRealtimeV2 is false).
  SignalingClient? _signaling;
  WebRtcPeerManager? _peerManager;
  PartySyncEngine? _syncEngine;

  // Realtime v2 plumbing (used when kWatchPartyRealtimeV2 is true).
  PartyRealtimeClient? _realtime;
  StreamSubscription<PartyEventEnvelope>? _realtimeEventsSub;
  StreamSubscription<PartyRealtimeStatus>? _realtimeStatusSub;
  PartyRealtimeState _realtimeState = const PartyRealtimeState();

  PartyRealtimeClient? get realtimeClient => _realtime;

  PartySyncEngine? get syncEngine => _syncEngine;

  /// Id of the locally authenticated user. Derived from [authStateProvider]
  /// so it is available both in the legacy P2P path (v1) and the brokered
  /// realtime path (v2), which previously forced callers to reach into
  /// [syncEngine] — a v1-only field.
  String? get localUserId {
    final auth = ref.read(authStateProvider).value;
    if (auth is AuthenticatedAuthState) return auth.user.id;
    return null;
  }

  /// True when the locally authenticated user is the host of the active
  /// room. Works for both v1 and v2 because it reads [localUserId] against
  /// [PartyRoom.hostId] instead of the v1-only [PartySyncEngine].
  bool get isLocalHost {
    final uid = localUserId;
    final room = state.room;
    if (uid == null || room == null) return false;
    return uid == room.hostId;
  }

  /// External callback for navigation when media changes (set by UI).
  /// Set this ONCE when navigating to the lobby or player, not on every rebuild.
  OnMediaChangeNavigation? onMediaChangeNavigation;

  /// Playback sync callback. In v1 the player reads this from the sync engine
  /// directly; in v2 it is set here and invoked when the Worker sends
  /// `playback_state_changed`.
  PartyOnSyncState? onSyncState;

  /// Callback invoked on the victim's side when the host kicks them out
  /// of the room (v2). Receives the host id and optional reason so the
  /// UI can distinguish a kick from a generic disconnect. Fires BEFORE
  /// the local session is torn down so the UI can, e.g., show a dialog.
  void Function(String byUserId, String? reason)? onKickedOut;

  @override
  PartySessionState build() => const PartySessionState();

  /// Create a new party room and connect.
  Future<void> createRoom({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
  }) async {
    _partyDebug(
      'createRoom: anilistId=$anilistId title=$animeTitle ep=$episodeNumber',
    );
    state = state.copyWith(status: PartySessionStatus.creating);
    try {
      final api = ref.read(partyApiClientProvider);
      _partyDebug('createRoom: calling API (v2=$kWatchPartyRealtimeV2)...');
      if (kWatchPartyRealtimeV2) {
        final bundle = await api.createRoomV2(
          anilistId: anilistId,
          animeTitle: animeTitle,
          episodeNumber: episodeNumber,
        );
        _partyDebug(
          'createRoom[v2]: room=${bundle.room.id} exp=${bundle.session.expiresAt.toIso8601String()}',
        );
        state = state.copyWith(
          status: PartySessionStatus.connecting,
          room: bundle.room,
        );
        await _connectRealtime(bundle.room, bundle.session);
        return;
      }
      final room = await api.createRoom(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      );
      _partyDebug(
        'createRoom: API returned room=${room.id} hostId=${room.hostId} members=${room.members.map((m) => '${m.userId}(${m.role.name})').join(", ")}',
      );
      state = state.copyWith(status: PartySessionStatus.connecting, room: room);
      await _connectP2P(room, isHost: true);
    } on PartyApiException catch (e) {
      _partyDebug('createRoom: API exception: $e');
      if (e.statusCode == 409) {
        _partyDebug(
          'createRoom: 409 Conflict. Leaving existing room and retrying...',
        );
        try {
          final api = ref.read(partyApiClientProvider);
          await api.leaveRoom();
          _partyDebug(
            'createRoom: Left existing room successfully. Retrying original operation...',
          );
          if (kWatchPartyRealtimeV2) {
            final bundle = await api.createRoomV2(
              anilistId: anilistId,
              animeTitle: animeTitle,
              episodeNumber: episodeNumber,
            );
            _partyDebug(
              'createRoom[v2] (retry): room=${bundle.room.id} exp=${bundle.session.expiresAt.toIso8601String()}',
            );
            state = state.copyWith(
              status: PartySessionStatus.connecting,
              room: bundle.room,
            );
            await _connectRealtime(bundle.room, bundle.session);
            return;
          } else {
            final room = await api.createRoom(
              anilistId: anilistId,
              animeTitle: animeTitle,
              episodeNumber: episodeNumber,
            );
            _partyDebug(
              'createRoom (retry): API returned room=${room.id} hostId=${room.hostId}',
            );
            state = state.copyWith(
              status: PartySessionStatus.connecting,
              room: room,
            );
            await _connectP2P(room, isHost: true);
            return;
          }
        } catch (retryError) {
          _partyDebug('createRoom: retry failed: $retryError');
          state = state.copyWith(
            status: PartySessionStatus.error,
            error: retryError is PartyApiException
                ? retryError.message
                : retryError.toString(),
          );
          return;
        }
      }
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.message,
      );
    } catch (e) {
      _partyDebug('createRoom: unexpected exception: $e');
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Join an existing room by invite code and connect.
  Future<void> joinRoom(String inviteCode) async {
    _partyDebug('joinRoom: code=$inviteCode (v2=$kWatchPartyRealtimeV2)');
    state = state.copyWith(status: PartySessionStatus.joining);
    try {
      final api = ref.read(partyApiClientProvider);
      if (kWatchPartyRealtimeV2) {
        final bundle = await api.joinRoomV2(inviteCode);
        _partyDebug(
          'joinRoom[v2]: room=${bundle.room.id} exp=${bundle.session.expiresAt.toIso8601String()}',
        );
        state = state.copyWith(
          status: PartySessionStatus.connecting,
          room: bundle.room,
        );
        await _connectRealtime(bundle.room, bundle.session);
        return;
      }
      _partyDebug('joinRoom: calling API...');
      final room = await api.joinRoom(inviteCode);
      _partyDebug(
        'joinRoom: API returned room=${room.id} hostId=${room.hostId} members=${room.members.map((m) => '${m.userId}(${m.role.name})').join(", ")}',
      );
      state = state.copyWith(status: PartySessionStatus.connecting, room: room);
      await _connectP2P(room, isHost: false);
    } on PartyApiException catch (e) {
      _partyDebug('joinRoom: API exception: $e');
      if (e.statusCode == 409) {
        _partyDebug(
          'joinRoom: 409 Conflict. Leaving existing room and retrying...',
        );
        try {
          final api = ref.read(partyApiClientProvider);
          await api.leaveRoom();
          _partyDebug(
            'joinRoom: Left existing room successfully. Retrying original operation...',
          );
          if (kWatchPartyRealtimeV2) {
            final bundle = await api.joinRoomV2(inviteCode);
            _partyDebug(
              'joinRoom[v2] (retry): room=${bundle.room.id} exp=${bundle.session.expiresAt.toIso8601String()}',
            );
            state = state.copyWith(
              status: PartySessionStatus.connecting,
              room: bundle.room,
            );
            await _connectRealtime(bundle.room, bundle.session);
            return;
          } else {
            final room = await api.joinRoom(inviteCode);
            _partyDebug(
              'joinRoom (retry): API returned room=${room.id} hostId=${room.hostId}',
            );
            state = state.copyWith(
              status: PartySessionStatus.connecting,
              room: room,
            );
            await _connectP2P(room, isHost: false);
            return;
          }
        } catch (retryError) {
          _partyDebug('joinRoom: retry failed: $retryError');
          state = state.copyWith(
            status: PartySessionStatus.error,
            error: retryError is PartyApiException
                ? retryError.message
                : retryError.toString(),
          );
          return;
        }
      }
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.message,
      );
    } catch (e) {
      _partyDebug('joinRoom: unexpected exception: $e');
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Leave the current party and tear down connections.
  Future<void> leaveRoom() async {
    final roomId = state.room?.id;
    try {
      // In v2 the realtime client sends a `leave_room` over the WS so the
      // Worker can update presence immediately; the REST call is best-effort
      // and forwards the roomId so the API can call the broker.
      _realtime?.sendLeaveRoom();
      final api = ref.read(partyApiClientProvider);
      await api.leaveRoom(roomId: kWatchPartyRealtimeV2 ? roomId : null);
    } catch (_) {
      // Best-effort — server will clean up on timeout anyway.
    }
    await _disconnect();
    state = const PartySessionState();
  }

  /// Send a reaction emoji to all peers.
  void sendReaction(String emoji) {
    if (kWatchPartyRealtimeV2) {
      _realtime?.sendReaction(emoji);
      return;
    }
    _syncEngine?.sendReaction(emoji);
  }

  /// Toggle ready state.
  void toggleReady(bool ready) {
    if (kWatchPartyRealtimeV2) {
      _realtime?.sendSetReady(ready);
      return;
    }
    _syncEngine?.sendReady(ready);
  }

  /// Update the member's activity status. Broadcasts to the room so
  /// everyone sees what every member is doing. V2-only; v1 clients
  /// silently ignore.
  void sendStatus(PartyMemberStatus status) {
    if (kWatchPartyRealtimeV2) {
      _realtime?.sendSetStatus(status);
    }
  }

  /// Update local playback state for sync. In v2 this is a no-op: the Worker
  /// is authoritative and drives everyone via `playback_state_changed`.
  /// The host signals changes through [syncNow]/[changeEpisode]/[changeMedia].
  void updatePlayback({required bool isPlaying, required int positionMs}) {
    if (kWatchPartyRealtimeV2) return;
    _syncEngine?.updatePlaybackState(
      isPlaying: isPlaying,
      positionMs: positionMs,
    );
  }

  /// Immediately sync current playback state. Host only.
  ///
  /// In v2 this sends a `play`/`pause` intent; the Worker treats `positionMs`
  /// as an implicit seek before applying the status transition so members do
  /// not rewind when the host pauses away from `basePositionMs=0`.
  ///
  /// In v1 the positional data is already kept by [PartySyncEngine] via the
  /// periodic `updatePlaybackState` calls, so the optional argument is
  /// ignored there.
  void syncNow({bool isPlaying = true, int positionMs = 0}) {
    if (kWatchPartyRealtimeV2) {
      _realtime?.sendPlaybackIntent(
        action: isPlaying ? 'play' : 'pause',
        positionMs: positionMs,
      );
      return;
    }
    _syncEngine?.broadcastSyncNow();
  }

  /// Send an explicit seek to the party (host only, v2-only). The Worker
  /// updates `basePositionMs` and echoes `playback_state_changed` so members
  /// project the new timeline.
  void seekTo(int positionMs) {
    if (!kWatchPartyRealtimeV2) return;
    _realtime?.sendPlaybackIntent(action: 'seek', positionMs: positionMs);
  }

  /// Request the Worker to re-broadcast the current playback state.
  ///
  /// The periodic server-side resync alarm was intentionally removed to stay
  /// inside the Cloudflare free tier (Durable Object requests). Drift
  /// correction is now client-driven: [PlayerPage] compares its actual
  /// playback position against the projected server position every 30s and
  /// calls this only when the gap exceeds its tolerance band.
  ///
  /// Rate-limited server-side by the `playback_intent` bucket (6/10s).
  void requestResync() {
    if (!kWatchPartyRealtimeV2) return;
    _realtime?.sendRequestSnapshot();
  }

  /// Host-only: ask every client to transition from the lobby to the player
  /// for the current media. The Worker broadcasts `start_watching`; each
  /// client reacts by invoking [onMediaChangeNavigation].
  ///
  /// v1 has no brokered counterpart — the legacy P2P path relies on media
  /// change events to drive navigation and is a no-op here.
  void startWatching() {
    if (!kWatchPartyRealtimeV2) return;
    // Navigate the host optimistically before sending the brokered intent.
    // In some deployments the Worker fan-out reaches members but does not
    // echo `start_watching` back to the initiating host, which leaves the
    // host stranded on the lobby. Triggering the local callback first keeps
    // the host aligned with the rest of the room. Once the lobby route is
    // replaced, it clears [onMediaChangeNavigation], so a later echoed event
    // will not double-push.
    final room = state.room;
    if (room != null) {
      onMediaChangeNavigation?.call(
        room.anilistId,
        room.animeTitle,
        room.episodeNumber,
      );
    }
    _realtime?.sendPlaybackIntent(action: 'start_watching');
  }

  /// Request episode change (host only).
  ///
  /// Immediately sets the local member's status to [PartyMemberStatus.loading]
  /// so the lobby shows the host is transitioning, closing the gap between
  /// the media change intent and the new player mounting.
  void changeEpisode(double episodeNumber) {
    // Optimistic local update so the host UI reflects the new episode immediately.
    final room = state.room;
    if (room != null) {
      state = state.copyWith(room: room.copyWith(episodeNumber: episodeNumber));
    }
    // Transition own status to loading immediately so the lobby reflects
    // the pending episode change before the new player mounts.
    sendStatus(PartyMemberStatus.loading);
    if (kWatchPartyRealtimeV2) {
      _realtime?.sendPlaybackIntent(
        action: 'episode_change',
        animeTitle: room?.animeTitle,
        episodeNumber: episodeNumber,
      );
      return;
    }
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

    _partyLog(
      'changeMedia: anilistId=$anilistId episode=$episodeNumber title=$animeTitle',
    );

    // 1. Update local room state IMMEDIATELY (optimistic update).
    state = state.copyWith(
      room: room.copyWith(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      ),
    );

    // Transition own status to loading immediately so the lobby reflects
    // the pending media change before the new player mounts.
    sendStatus(PartyMemberStatus.loading);

    if (kWatchPartyRealtimeV2) {
      // In v2 the Worker owns room state: send the intent and let the
      // broadcast of `media_changed` drive other clients. The REST PATCH
      // is intentionally skipped — it is rejected by the API (410 Gone).
      _realtime?.sendPlaybackIntent(
        action: 'media_change',
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      );
      return;
    }

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

  /// Kick a member (host only). The Worker validates authority and echoes
  /// `member_left` to everyone; the victim receives a targeted `kicked`
  /// event before their socket is closed.
  void kickMember(String userId, {String? reason}) {
    if (kWatchPartyRealtimeV2) {
      _realtime?.sendKickMember(targetUserId: userId, reason: reason);
      return;
    }
    _syncEngine?.kickMember(userId);
  }

  /// Transfer host authority to another connected member (host only,
  /// v2-only). The Worker broadcasts `host_transferred` so every client
  /// aligns on the new `hostId`.
  void transferHost(String targetUserId) {
    if (!kWatchPartyRealtimeV2) {
      _partyLog('transferHost: not supported on legacy P2P');
      return;
    }
    _realtime?.sendTransferHost(targetUserId: targetUserId);
  }

  // ── Internal P2P lifecycle ──

  Future<void> _connectP2P(PartyRoom room, {required bool isHost}) async {
    _partyLog(
      '_connectP2P: room=${room.id} isHost=$isHost members=${room.members.length}',
    );
    _partyDebug(
      '_connectP2P: START — room=${room.id} isHost=$isHost members=${room.members.length}',
    );
    _partyDebug(
      '_connectP2P: room members detail: ${room.members.map((m) => 'userId=${m.userId} role=${m.role.name} name=${m.displayName}').join(" | ")}',
    );
    final asyncAuth = ref.read(authStateProvider);
    final authState = asyncAuth.value;
    if (authState is! AuthenticatedAuthState) {
      _partyLog('_connectP2P: not authenticated');
      _partyDebug(
        '_connectP2P: FAIL — not authenticated, authState type: ${authState.runtimeType}',
      );
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
      _partyDebug('_connectP2P: FAIL — no auth tokens');
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: 'No auth tokens',
      );
      return;
    }

    // FIX: Use the authenticated user's ID from auth state, NOT from room members.
    // The previous logic used firstWhere by role which could return the host's ID
    // when a member joined (since host is first in the members list).
    // The authState has the actual local user's ID.
    final localUser = authState.user;
    final userId = localUser.id;
    _partyLog('_connectP2P: localUserId=$userId (from auth state)');
    _partyDebug(
      '_connectP2P: localUserId=$userId displayName=${localUser.displayName}',
    );

    // Verify that the local user is actually a member of this room.
    final localMember = room.members
        .where((m) => m.userId == userId)
        .firstOrNull;
    if (localMember == null) {
      _partyLog('_connectP2P: local user $userId is not a member of this room');
      _partyDebug(
        '_connectP2P: FAIL — userId $userId not found in room members',
      );
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: 'Not a member of this room',
      );
      return;
    }

    // Determine if we're the host by checking our role in the room.
    // This is the actual role from room data and is the source of truth.
    final actualIsHost = localMember.role == PartyRole.host;

    // Defensive check: verify role consistency between parameter and room data.
    // If they mismatch, log a warning to catch role detection bugs early.
    if (actualIsHost != isHost) {
      _partyLog(
        '_connectP2P: WARNING — Role mismatch detected! '
        'Parameter isHost=$isHost but room data shows actualIsHost=$actualIsHost. '
        'Using actual role from room data.',
      );
      _partyDebug(
        '_connectP2P: ROLE_MISMATCH — param=$isHost actual=$actualIsHost '
        'userId=$userId role=${localMember.role.name} '
        'This indicates a role detection bug in the calling code.',
      );
    }

    _partyDebug(
      '_connectP2P: Role verified — actualIsHost=$actualIsHost '
      'localMemberName=${localMember.displayName} role=${localMember.role.name}',
    );

    // Enhanced diagnostic logging for peer identification (Task 3.3)
    _partyDebug(
      '_connectP2P: PEER_IDENTIFICATION_SUMMARY — '
      'authUserId=$userId '
      'localMemberUserId=${localMember.userId} '
      'displayName=${localMember.displayName} '
      'actualRole=${localMember.role.name} '
      'actualIsHost=$actualIsHost '
      'paramIsHost=$isHost '
      'roleMatch=${actualIsHost == isHost}',
    );
    _partyDebug(
      '_connectP2P: FULL_MEMBER_LIST — '
      'totalMembers=${room.members.length} '
      'members=[${room.members.map((m) => '{userId:${m.userId}, name:${m.displayName}, role:${m.role.name}}').join(', ')}]',
    );

    // 1. Create signaling client.
    _signaling = SignalingClient(
      wsUrl: _wsBaseUrl,
      accessToken: tokens.accessToken,
    );
    _partyDebug('_connectP2P: signaling client created');

    // 2. Create peer manager.
    _peerManager = WebRtcPeerManager(
      localUserId: userId,
      onPeerStateChange: _onPeerStateChange,
    );
    _partyDebug('_connectP2P: peer manager created');

    // 3. Create sync engine — use actual role from room membership.
    _syncEngine = PartySyncEngine(
      peerManager: _peerManager!,
      localUserId: userId,
      localUserName: localMember.displayName,
      isHost: actualIsHost,
    );
    _partyDebug('_connectP2P: sync engine created (isHost=$actualIsHost)');

    // Wire sync callbacks.
    // NOTE: onSyncState is intentionally NOT set here — it's set by the
    // PlayerPage in _wirePartySyncCallbacks so it can control playback.
    // Setting it here would conflict with the player's handler.
    _syncEngine!.onReaction = _onReaction;
    _syncEngine!.onReadyToggle = _onReadyToggle;
    _syncEngine!.onKick = _onKick;
    _syncEngine!.onMediaChange = _onMediaChange;
    _partyDebug('_connectP2P: sync callbacks wired');

    // 4. Connect: signaling → peer manager.
    _peerManager!.connect(_signaling!);
    _signaling!.connect(room.id);
    _partyLog('_connectP2P: signaling connected, actualIsHost=$actualIsHost');
    _partyDebug(
      '_connectP2P: signaling WS connected, peerManager.connect called',
    );

    if (actualIsHost) {
      _syncEngine!.startHostSync();
      _partyLog('_connectP2P: host sync started');
      _partyDebug('_connectP2P: host sync timer started (broadcast every 2s)');
    }

    state = state.copyWith(status: PartySessionStatus.connected);
    _partyLog('_connectP2P: status=connected');
    _partyDebug('_connectP2P: STATUS=CONNECTED — waiting for WebRTC peers');
  }

  Future<void> _disconnect() async {
    _syncEngine?.dispose();
    _syncEngine = null;
    await _peerManager?.dispose();
    _peerManager = null;
    _signaling?.dispose();
    _signaling = null;
    await _realtimeEventsSub?.cancel();
    _realtimeEventsSub = null;
    await _realtimeStatusSub?.cancel();
    _realtimeStatusSub = null;
    await _realtime?.dispose();
    _realtime = null;
    _realtimeState = const PartyRealtimeState();
    ref.invalidate(voiceSessionProvider);
  }

  // ── Internal realtime v2 lifecycle ──

  Future<void> _connectRealtime(
    PartyRoom room,
    PartyRealtimeSession session,
  ) async {
    _partyLog('_connectRealtime: room=${room.id}');
    _partyDebug('_connectRealtime: START — room=${room.id}');

    final asyncAuth = ref.read(authStateProvider);
    final authState = asyncAuth.value;
    if (authState is! AuthenticatedAuthState) {
      _partyDebug('_connectRealtime: FAIL — not authenticated');
      state = state.copyWith(
        status: PartySessionStatus.error,
        error: 'Not authenticated',
      );
      return;
    }
    // `authState.user.id` is useful for future reducer role projection; the
    // server-driven view currently derives roles from `hostId`.

    // Tear down anything left from a previous session.
    await _disconnect();

    final api = ref.read(partyApiClientProvider);
    final client = PartyRealtimeClient(
      session: session,
      sessionRefresher: () async {
        try {
          final fresh = await api.refreshSession(room.id);
          _partyDebug('_connectRealtime: session refreshed');
          return fresh;
        } catch (e) {
          _partyDebug('_connectRealtime: session refresh failed: $e');
          return null;
        }
      },
    );
    _realtime = client;
    _realtimeState = const PartyRealtimeState();

    _realtimeEventsSub = client.events.listen(
      _onRealtimeEvent,
      onError: (Object err) {
        _partyDebug('_connectRealtime: stream error $err');
      },
    );
    _realtimeStatusSub = client.statusChanges.listen((status) {
      _partyDebug('_connectRealtime: status → $status');
      switch (status) {
        case PartyRealtimeStatus.connected:
          if (state.status != PartySessionStatus.connected) {
            state = state.copyWith(status: PartySessionStatus.connected);
          }
          break;
        case PartyRealtimeStatus.expiredSession:
          state = state.copyWith(
            status: PartySessionStatus.error,
            error: 'Party session expired. Please rejoin.',
          );
          break;
        case PartyRealtimeStatus.error:
          state = state.copyWith(
            status: PartySessionStatus.error,
            error: 'Lost connection to party server.',
          );
          break;
        case PartyRealtimeStatus.reconnecting:
        case PartyRealtimeStatus.connecting:
        case PartyRealtimeStatus.closed:
        case PartyRealtimeStatus.idle:
          break;
      }
    });

    client.connect();
  }

  void _onRealtimeEvent(PartyEventEnvelope env) {
    // Structural events are handled by the pure reducer; overlay / navigation
    // events are handled inline here.
    switch (env.type) {
      case 'room_snapshot':
        _handleRealtimeSnapshotMedia(env.payload);
        break;
      case 'reaction_broadcast':
        _handleRealtimeReaction(env.payload);
        return;
      case 'media_changed':
        _handleRealtimeMediaChanged(env.payload);
        break;
      case 'episode_changed':
        _handleRealtimeEpisodeChanged(env.payload);
        break;
      case 'playback_state_changed':
        _handleRealtimePlayback(env.payload);
        break;
      case 'start_watching':
        _handleRealtimeStartWatching(env.payload);
        return;
      case 'kicked':
        _handleRealtimeKicked(env.payload);
        return;
      case 'room_closed':
        _partyLog('room_closed: ${env.payload['reason']}');
        leaveRoom();
        return;
      case 'error':
      case 'ack':
        // Correlated per-message responses — not relevant for state here.
        return;
    }

    // Apply the structural event to the reducer state and project it back
    // onto PartySessionState.
    _realtimeState = reducePartyRealtimeEvent(
      _realtimeState,
      env.type,
      env.payload,
      roomVersion: env.roomVersion,
    );
    _projectRealtimeState();
  }

  void _handleRealtimeSnapshotMedia(Map<String, dynamic> payload) {
    final media = payload['media'];
    if (media is! Map<String, dynamic>) return;
    final anilistId = (media['anilistId'] as num?)?.toInt();
    final animeTitle = media['animeTitle'] as String?;
    final episodeNumber = (media['episodeNumber'] as num?)?.toDouble();
    if (anilistId == null || animeTitle == null || episodeNumber == null) {
      return;
    }
    final room = state.room;
    if (room == null) {
      return;
    }
    state = state.copyWith(
      room: room.copyWith(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
      ),
    );
  }

  void _handleRealtimeReaction(Map<String, dynamic> payload) {
    final senderId = payload['senderId'] as String?;
    final senderName = payload['senderName'] as String?;
    final emoji = payload['reaction'] as String?;
    if (senderId == null || senderName == null || emoji == null) return;
    final reactions = [
      ...state.reactions,
      PartyReaction(
        senderId: senderId,
        senderName: senderName,
        emoji: emoji,
        timestamp: DateTime.now(),
      ),
    ];
    final trimmed = reactions.length > 50
        ? reactions.sublist(reactions.length - 50)
        : reactions;
    state = state.copyWith(reactions: trimmed);
  }

  void _handleRealtimeMediaChanged(Map<String, dynamic> payload) {
    final media = payload['media'];
    if (media is! Map<String, dynamic>) return;
    final anilistId = (media['anilistId'] as num?)?.toInt();
    final animeTitle = media['animeTitle'] as String?;
    final episodeNumber = (media['episodeNumber'] as num?)?.toDouble();
    if (anilistId == null || animeTitle == null || episodeNumber == null) {
      return;
    }
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
    onMediaChangeNavigation?.call(anilistId, animeTitle, episodeNumber);
  }

  void _handleRealtimeEpisodeChanged(Map<String, dynamic> payload) {
    final episodeNumber = (payload['episodeNumber'] as num?)?.toDouble();
    if (episodeNumber == null) return;
    final room = state.room;
    if (room != null) {
      state = state.copyWith(room: room.copyWith(episodeNumber: episodeNumber));
      onMediaChangeNavigation?.call(
        room.anilistId,
        room.animeTitle,
        episodeNumber,
      );
    }
  }

  /// Target-only broadcast: the local user has been kicked. We notify
  /// the UI first (so it can show a dialog/snackbar) and then tear the
  /// session down, mirroring what the server-side close would do a
  /// moment later anyway.
  void _handleRealtimeKicked(Map<String, dynamic> payload) {
    final byUserId = payload['byUserId'] as String? ?? '';
    final reason = payload['reason'] as String?;
    _partyLog('kicked by=$byUserId reason=${reason ?? '-'}');
    try {
      onKickedOut?.call(byUserId, reason);
    } catch (e) {
      _partyLog('onKickedOut callback threw: $e');
    }
    // Proactively clean up so the UI does not have to wait for the
    // server-initiated close to propagate.
    leaveRoom();
  }

  /// Host broadcast: everyone (host included) should now navigate to the
  /// player for the current media. Does not touch realtime state — it is a
  /// notification, not a state mutation.
  void _handleRealtimeStartWatching(Map<String, dynamic> payload) {
    final media = payload['media'];
    if (media is! Map<String, dynamic>) return;
    final playback = payload['playback'];
    final anilistId = (media['anilistId'] as num?)?.toInt();
    final episodeNumber = (media['episodeNumber'] as num?)?.toDouble();
    if (anilistId == null || episodeNumber == null) return;
    if (playback is Map<String, dynamic>) {
      final parsedPlayback = PartyPlaybackState(
        status: (playback['status'] as String?) ?? 'paused',
        basePositionMs: (playback['basePositionMs'] as num?)?.toInt() ?? 0,
        effectiveAtMs: (playback['effectiveAtMs'] as num?)?.toInt() ?? 0,
        generation: (playback['generation'] as num?)?.toInt() ?? 0,
      );
      _realtimeState = _realtimeState.copyWith(playback: parsedPlayback);
      state = state.copyWith(playback: parsedPlayback);
    }
    // The Worker does not echo the anime title — fall back to whatever the
    // client already has in its room state.
    final title = state.room?.animeTitle ?? '';
    onMediaChangeNavigation?.call(anilistId, title, episodeNumber);
  }

  void _handleRealtimePlayback(Map<String, dynamic> payload) {
    _realtimeState = reducePartyRealtimeEvent(
      _realtimeState,
      'playback_state_changed',
      payload,
    );
    final pb = _realtimeState.playback;
    // Project the server position to the local clock so the player can seek
    // directly to the right timestamp.
    final projected = pb.projectedPositionMs(
      serverNowMs:
          DateTime.now().millisecondsSinceEpoch +
          _realtimeState.clientServerOffsetMs,
      clientServerOffsetMs: _realtimeState.clientServerOffsetMs,
    );
    final current = state.playback;
    final playbackChanged =
        current.status != pb.status ||
        current.basePositionMs != pb.basePositionMs ||
        current.effectiveAtMs != pb.effectiveAtMs ||
        current.generation != pb.generation;
    if (playbackChanged) {
      state = state.copyWith(playback: pb);
    }
    if (!isLocalHost) {
      onSyncState?.call(pb.isPlaying, projected);
    }
  }

  /// Fold the pure realtime state back onto the legacy [PartySessionState]
  /// shape so the existing lobby / overlay widgets keep working unchanged.
  void _projectRealtimeState() {
    final rt = _realtimeState;
    final room = state.room;
    if (room == null) return;

    // Rebuild members so their role reflects the current hostId.
    final rebuiltMembers = rt.members
        .map(
          (m) => PartyMember(
            userId: m.userId,
            displayName: m.displayName,
            role: m.userId == rt.hostId ? PartyRole.host : PartyRole.member,
            joinedAt: m.joinedAt,
            isReady: rt.readyStates[m.userId] ?? false,
            status: rt.memberStatuses[m.userId] ?? m.status,
          ),
        )
        .toList(growable: false);

    state = state.copyWith(
      room: room.copyWith(
        hostId: rt.hostId ?? room.hostId,
        inviteCode: rt.inviteCode ?? room.inviteCode,
        members: rebuiltMembers.isEmpty ? room.members : rebuiltMembers,
      ),
      readyStates: rt.readyStates,
      memberStatuses: rt.memberStatuses,
      connectedPeerIds: rt.connectedIds,
      playback: rt.playback,
    );
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
    // Guard: don't update state if the notifier is being disposed.
    if (_syncEngine == null && _signaling == null) return;
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
    final trimmed = reactions.length > 50
        ? reactions.sublist(reactions.length - 50)
        : reactions;
    state = state.copyWith(reactions: trimmed);
  }

  void _onReadyToggle(String senderId, bool ready) {
    if (_syncEngine == null && _signaling == null) return;
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
    _partyLog(
      '_onMediaChange: anilistId=$anilistId episode=$episodeNumber from=$senderId',
    );
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
