import 'models/party_member.dart';
import 'models/party_room.dart';

/// Playback state as advertised by the Party Realtime Worker.
final class PartyPlaybackState {
  const PartyPlaybackState({
    required this.status,
    required this.basePositionMs,
    required this.effectiveAtMs,
    required this.generation,
    this.awaitReady = false,
  });

  /// 'playing' | 'paused'
  final String status;
  final int basePositionMs;
  final int effectiveAtMs;
  final int generation;
  final bool awaitReady;

  static const empty = PartyPlaybackState(
    status: 'paused',
    basePositionMs: 0,
    effectiveAtMs: 0,
    generation: 0,
    awaitReady: false,
  );

  bool get isPlaying => status == 'playing';

  /// Expected local position in ms, given a server wall-clock offset.
  int projectedPositionMs({
    required int serverNowMs,
    required int clientServerOffsetMs,
  }) {
    if (!isPlaying) return basePositionMs;
    final nowOnServer =
        DateTime.now().millisecondsSinceEpoch + clientServerOffsetMs;
    final delta = nowOnServer - effectiveAtMs;
    return basePositionMs + (delta < 0 ? 0 : delta);
  }
}

/// Server-authoritative realtime state. Parallel to the legacy
/// [PartySessionState] used by the P2P flow so the lobby UI can render
/// both without forking.
final class PartyRealtimeState {
  const PartyRealtimeState({
    this.roomId,
    this.hostId,
    this.inviteCode,
    this.members = const <PartyMember>[],
    this.readyStates = const <String, bool>{},
    this.memberStatuses = const <String, PartyMemberStatus>{},
    this.connectedIds = const <String>{},
    this.playback = PartyPlaybackState.empty,
    this.roomVersion = 0,
    this.clientServerOffsetMs = 0,
    this.error,
  });

  final String? roomId;
  final String? hostId;
  final String? inviteCode;
  final List<PartyMember> members;

  /// effectiveReady as reported by the Worker.
  final Map<String, bool> readyStates;

  /// Activity status per member (derived from member_status_changed events).
  final Map<String, PartyMemberStatus> memberStatuses;

  /// Connected members (presence=connected).
  final Set<String> connectedIds;

  final PartyPlaybackState playback;
  final int roomVersion;

  /// Estimate of (server_time - client_time) inferred from last snapshot.
  final int clientServerOffsetMs;

  final String? error;

  PartyRealtimeState copyWith({
    String? roomId,
    String? hostId,
    String? inviteCode,
    List<PartyMember>? members,
    Map<String, bool>? readyStates,
    Map<String, PartyMemberStatus>? memberStatuses,
    Set<String>? connectedIds,
    PartyPlaybackState? playback,
    int? roomVersion,
    int? clientServerOffsetMs,
    String? error,
  }) => PartyRealtimeState(
    roomId: roomId ?? this.roomId,
    hostId: hostId ?? this.hostId,
    inviteCode: inviteCode ?? this.inviteCode,
    members: members ?? this.members,
    readyStates: readyStates ?? this.readyStates,
    memberStatuses: memberStatuses ?? this.memberStatuses,
    connectedIds: connectedIds ?? this.connectedIds,
    playback: playback ?? this.playback,
    roomVersion: roomVersion ?? this.roomVersion,
    clientServerOffsetMs: clientServerOffsetMs ?? this.clientServerOffsetMs,
    error: error,
  );

  /// Derive a "legacy" [PartyRoom] view so callers that still expect a
  /// `PartyRoom` can keep working during the migration.
  PartyRoom? toPartyRoom({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
    required DateTime createdAt,
    int maxMembers = 4,
  }) {
    final id = roomId;
    final host = hostId;
    if (id == null || host == null) return null;
    return PartyRoom(
      id: id,
      hostId: host,
      members: members,
      anilistId: anilistId,
      animeTitle: animeTitle,
      episodeNumber: episodeNumber,
      maxMembers: maxMembers,
      inviteCode: inviteCode ?? '',
      createdAt: createdAt,
    );
  }
}

/// Reducer: applies a single WS event to the previous state.
///
/// Kept pure so the mapping can be unit-tested without an actual socket.
PartyRealtimeState reducePartyRealtimeEvent(
  PartyRealtimeState prev,
  String type,
  Map<String, dynamic> payload, {
  int? roomVersion,
}) {
  switch (type) {
    case 'room_snapshot':
      return _applySnapshot(prev, payload);
    case 'member_joined':
      return _applyMemberJoined(prev, payload, roomVersion);
    case 'member_left':
      return _applyMemberLeft(prev, payload, roomVersion);
    case 'member_presence_changed':
      return _applyPresence(prev, payload, roomVersion);
    case 'member_ready_changed':
      return _applyReady(prev, payload, roomVersion);
    case 'member_status_changed':
      return _applyMemberStatus(prev, payload, roomVersion);
    case 'playback_state_changed':
      return _applyPlayback(prev, payload, roomVersion);
    case 'media_changed':
    case 'episode_changed':
      // Media/episode changes are projected onto the lobby room metadata by
      // the notifier (not the reducer) since they also affect navigation.
      return prev.copyWith(roomVersion: roomVersion ?? prev.roomVersion);
    case 'host_transferred':
      final newHost = payload['newHostId'];
      if (newHost is String) {
        return prev.copyWith(
          hostId: newHost,
          roomVersion: roomVersion ?? prev.roomVersion,
        );
      }
      return prev;
    case 'room_closed':
      // Return a fresh state so nullable fields are explicitly cleared
      // (copyWith cannot distinguish "omitted" from "null" here).
      return PartyRealtimeState(
        roomId: null,
        hostId: null,
        inviteCode: null,
        members: const <PartyMember>[],
        readyStates: const <String, bool>{},
        connectedIds: const <String>{},
        playback: PartyPlaybackState.empty,
        roomVersion: roomVersion ?? prev.roomVersion,
        clientServerOffsetMs: prev.clientServerOffsetMs,
      );
    default:
      return prev;
  }
}

PartyRealtimeState _applySnapshot(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
) {
  final members = (payload['members'] as List?) ?? const [];
  final parsedMembers = members
      .whereType<Map<String, dynamic>>()
      .map(_parseMember)
      .toList(growable: false);
  final connected = <String>{
    for (final m in members.whereType<Map<String, dynamic>>())
      if (m['presence'] == 'connected') (m['userId'] as String?) ?? '',
  }..removeWhere((id) => id.isEmpty);
  final ready = <String, bool>{
    for (final m in members.whereType<Map<String, dynamic>>())
      if (m['userId'] is String)
        m['userId'] as String: (m['effectiveReady'] as bool? ?? false),
  };
  final statuses = <String, PartyMemberStatus>{
    for (final m in members.whereType<Map<String, dynamic>>())
      if (m['userId'] is String)
        m['userId'] as String: PartyMemberStatus.fromJson(
          m['status'] as String?,
        ),
  };
  final playback = payload['playback'];
  final parsedPlayback = playback is Map<String, dynamic>
      ? PartyPlaybackState(
          status: (playback['status'] as String?) ?? 'paused',
          basePositionMs: (playback['basePositionMs'] as num?)?.toInt() ?? 0,
          effectiveAtMs: (playback['effectiveAtMs'] as num?)?.toInt() ?? 0,
          generation: (playback['generation'] as num?)?.toInt() ?? 0,
          awaitReady: playback['awaitReady'] == true,
        )
      : PartyPlaybackState.empty;
  final serverNowMs = (payload['serverTimeMs'] as num?)?.toInt();
  final offsetMs = serverNowMs == null
      ? 0
      : serverNowMs - DateTime.now().millisecondsSinceEpoch;
  return prev.copyWith(
    roomId: payload['roomId'] as String? ?? prev.roomId,
    hostId: payload['hostId'] as String? ?? prev.hostId,
    inviteCode: payload['inviteCode'] as String? ?? prev.inviteCode,
    members: parsedMembers,
    readyStates: ready,
    memberStatuses: statuses,
    connectedIds: connected,
    playback: parsedPlayback,
    roomVersion: (payload['roomVersion'] as num?)?.toInt() ?? prev.roomVersion,
    clientServerOffsetMs: offsetMs,
  );
}

PartyMember _parseMember(Map<String, dynamic> raw) {
  // Role is derived against the room's hostId, which is not available at
  // the per-member level here; consumers recompute role with the room state.
  return PartyMember(
    userId: raw['userId'] as String? ?? '',
    displayName: raw['name'] as String? ?? raw['displayName'] as String? ?? '',
    role: PartyRole.member,
    joinedAt: DateTime.fromMillisecondsSinceEpoch(
      (raw['joinedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    ),
    isReady: raw['effectiveReady'] as bool? ?? false,
    status: PartyMemberStatus.fromJson(raw['status'] as String?),
  );
}

PartyRealtimeState _applyMemberJoined(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
  int? roomVersion,
) {
  final raw = payload['member'];
  if (raw is! Map<String, dynamic>) return prev;
  final userId = raw['userId'] as String? ?? '';
  if (userId.isEmpty) return prev;
  final members = [
    ...prev.members.where((m) => m.userId != userId),
    _parseMember(raw),
  ];
  final connected = Set<String>.from(prev.connectedIds)..add(userId);
  final ready = Map<String, bool>.from(prev.readyStates);
  ready[userId] = raw['effectiveReady'] as bool? ?? false;
  final statuses = Map<String, PartyMemberStatus>.from(prev.memberStatuses);
  statuses[userId] = PartyMemberStatus.fromJson(raw['status'] as String?);
  return prev.copyWith(
    members: members,
    connectedIds: connected,
    readyStates: ready,
    memberStatuses: statuses,
    roomVersion: roomVersion ?? prev.roomVersion,
  );
}

PartyRealtimeState _applyMemberLeft(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
  int? roomVersion,
) {
  final userId = payload['userId'] as String?;
  if (userId == null) return prev;
  final members = prev.members.where((m) => m.userId != userId).toList();
  final connected = Set<String>.from(prev.connectedIds)..remove(userId);
  final ready = Map<String, bool>.from(prev.readyStates)..remove(userId);
  final statuses = Map<String, PartyMemberStatus>.from(prev.memberStatuses)
    ..remove(userId);
  final newHostId = payload['newHostId'] as String?;
  return prev.copyWith(
    members: members,
    connectedIds: connected,
    readyStates: ready,
    memberStatuses: statuses,
    hostId: newHostId ?? prev.hostId,
    roomVersion: roomVersion ?? prev.roomVersion,
  );
}

PartyRealtimeState _applyPresence(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
  int? roomVersion,
) {
  final userId = payload['userId'] as String?;
  final presence = payload['presence'] as String?;
  if (userId == null || presence == null) return prev;
  final connected = Set<String>.from(prev.connectedIds);
  final ready = Map<String, bool>.from(prev.readyStates);
  if (presence == 'connected') {
    connected.add(userId);
  } else {
    connected.remove(userId);
    // effectiveReady goes false on disconnect per spec.
    ready[userId] = false;
  }
  return prev.copyWith(
    connectedIds: connected,
    readyStates: ready,
    roomVersion: roomVersion ?? prev.roomVersion,
  );
}

PartyRealtimeState _applyReady(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
  int? roomVersion,
) {
  final userId = payload['userId'] as String?;
  if (userId == null) return prev;
  final ready = Map<String, bool>.from(prev.readyStates);
  ready[userId] = payload['effectiveReady'] as bool? ?? false;
  return prev.copyWith(
    readyStates: ready,
    roomVersion: roomVersion ?? prev.roomVersion,
  );
}

PartyRealtimeState _applyMemberStatus(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
  int? roomVersion,
) {
  final userId = payload['userId'] as String?;
  final statusRaw = payload['status'] as String?;
  if (userId == null || statusRaw == null) return prev;
  final status = PartyMemberStatus.fromJson(statusRaw);
  final statuses = Map<String, PartyMemberStatus>.from(prev.memberStatuses);
  statuses[userId] = status;
  // Also update the status on the member in the members list
  final members = prev.members
      .map((m) {
        if (m.userId == userId) return m.copyWith(status: status);
        return m;
      })
      .toList(growable: false);
  return prev.copyWith(
    members: members,
    memberStatuses: statuses,
    roomVersion: roomVersion ?? prev.roomVersion,
  );
}

PartyRealtimeState _applyPlayback(
  PartyRealtimeState prev,
  Map<String, dynamic> payload,
  int? roomVersion,
) {
  final status = payload['status'] as String?;
  if (status == null) return prev;

  // ── Clock-offset refresh (Sync Prop-2) ─────────────────────────────────
  //
  // Every `playback_state_changed` carries the server wall-clock at the
  // moment of the broadcast. Using it to re-estimate `clientServerOffsetMs`
  // keeps the host↔member timeline aligned as network conditions drift,
  // without any explicit ping/pong round-trip.
  //
  // The estimator is a one-way measurement so it also absorbs half the
  // uplink latency. We compensate by pushing samples through a low-pass
  // EWMA (α = 0.25), which dampens jitter from transient network spikes
  // while still reacting to persistent drift inside ~5 samples. The very
  // first sample is taken verbatim so members who join mid-session do not
  // have to wait for several resync cycles before their projection is
  // usable.
  final serverTimeMs = (payload['serverTimeMs'] as num?)?.toInt();
  int nextOffset = prev.clientServerOffsetMs;
  if (serverTimeMs != null) {
    final clientNowMs = DateTime.now().millisecondsSinceEpoch;
    final rawOffset = serverTimeMs - clientNowMs;
    if (prev.clientServerOffsetMs == 0) {
      nextOffset = rawOffset;
    } else {
      const alpha = 0.25;
      nextOffset = (prev.clientServerOffsetMs * (1 - alpha) + rawOffset * alpha)
          .round();
    }
  }

  return prev.copyWith(
    playback: PartyPlaybackState(
      status: status,
      basePositionMs: (payload['basePositionMs'] as num?)?.toInt() ?? 0,
      effectiveAtMs: (payload['effectiveAtMs'] as num?)?.toInt() ?? 0,
      generation: (payload['generation'] as num?)?.toInt() ?? 0,
      awaitReady: payload['awaitReady'] == true,
    ),
    roomVersion: roomVersion ?? prev.roomVersion,
    clientServerOffsetMs: nextOffset,
  );
}
