import 'providers/party_providers.dart';

/// Decides whether the local player must *hold* playback (keep the video
/// paused) given the current party session state.
///
/// Two distinct hold conditions:
///
/// 1. **Ready gate** — any member (host or not) still loading the episode
///    holds everyone. Prevents the host from pulling ahead.
///
/// 2. **Non-host autoplay guard** — members never auto-play. Their player
///    mirrors the server's authoritative [PartyPlaybackState.isPlaying]:
///    until the server signals a `play` intent, the member stays paused
///    even after the ready-gate releases. Without this, a member joining
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
}) {
  if (!isLocallyBoundToRoom) {
    return false;
  }
  if (!partyHasAllMembersReady(session)) {
    return true;
  }
  if (!isLocalHost && !session.playback.isPlaying) {
    return true;
  }
  return false;
}

bool partyHasAllMembersReady(PartySessionState session) {
  final room = session.room;
  if (room == null || room.members.isEmpty) {
    return false;
  }
  final memberIds = <String>{
    for (final member in room.members)
      if (member.userId.trim().isNotEmpty) member.userId,
  };
  if (memberIds.isEmpty) {
    return false;
  }
  return memberIds.every((memberId) => session.readyStates[memberId] == true);
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
