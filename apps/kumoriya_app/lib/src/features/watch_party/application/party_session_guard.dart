import 'models/party_member.dart';
import 'providers/party_providers.dart';

/// Decides whether the local player must *hold* playback (keep the video
/// paused) given the current party session state.
///
/// Two distinct hold conditions:
///
/// 1. **Presence gate** — host cannot play until every connected member has
///    entered the player (status ≠ inLobby). Replaces the old ready-state
///    gate. The player page sends `PartyMemberStatus.inPlayer` on mount.
///
/// 2. **Non-host autoplay guard** — members never auto-play. Their player
///    mirrors the server's authoritative [PartyPlaybackState.isPlaying]:
///    until the server signals a `play` intent, the member stays paused
///    even after the presence-gate releases. Without this, a member joining
///    mid-session would start playing from 0 before the first
///    `playback_state_changed` sync arrives, causing a visible auto-play
///    glitch regardless of what the host is doing.
///
/// [isLocallyBoundToRoom] lets the caller pre-check that the current
/// player page corresponds to the party's episode; the guard is a no-op
/// otherwise.
bool shouldHoldPartyPlayback({
  required PartySessionState session,
  required bool isLocallyBoundToRoom,
  required bool isLocalHost,
  String? localUserId,
}) {
  if (!isLocallyBoundToRoom) {
    return false;
  }
  if (!partyAllMembersInPlayer(session, localUserId: localUserId)) {
    return true;
  }
  if (!isLocalHost && !session.playback.isPlaying) {
    return true;
  }
  return false;
}

/// Returns true when every connected member (excluding [localUserId]) has a
/// status other than [PartyMemberStatus.inLobby] — meaning they have entered
/// the player.
bool partyAllMembersInPlayer(PartySessionState session, {String? localUserId}) {
  final connected = session.connectedPeerIds;
  if (connected.isEmpty) return false;

  // If this is a solo room the gate passes immediately.
  if (connected.length == 1 && connected.contains(localUserId)) return true;

  for (final userId in connected) {
    if (userId == localUserId) continue;
    final status = session.memberStatuses[userId];
    if (status == null || status == PartyMemberStatus.inLobby) return false;
  }
  return true;
}

int partyConnectedMemberCount(
  PartySessionState session, {
  required String? localUserId,
}) {
  final room = session.room;
  if (room == null || room.members.isEmpty) {
    return 0;
  }
  final connected = <String>{
    for (final member in room.members)
      if (session.connectedPeerIds.contains(member.userId)) member.userId,
  };
  if (localUserId != null &&
      room.members.any((member) => member.userId == localUserId)) {
    connected.add(localUserId);
  }
  return connected.length;
}

double? partyLockedEpisodeNumberForAnime({
  required PartySessionState session,
  required bool isLocalHost,
  required int anilistId,
}) {
  final room = session.room;
  if (!session.isActive || isLocalHost || room == null) {
    return null;
  }
  if (room.anilistId != anilistId) {
    return null;
  }
  return room.episodeNumber;
}

bool isPartyEpisodeLocked({
  required PartySessionState session,
  required bool isLocalHost,
  required int anilistId,
  required double episodeNumber,
}) {
  final lockedEpisode = partyLockedEpisodeNumberForAnime(
    session: session,
    isLocalHost: isLocalHost,
    anilistId: anilistId,
  );
  if (lockedEpisode == null) {
    return false;
  }
  return (lockedEpisode - episodeNumber).abs() >= 0.001;
}
