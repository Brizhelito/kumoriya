import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/watch_party/application/models/party_member.dart';
import 'package:kumoriya_app/src/features/watch_party/application/models/party_room.dart';
import 'package:kumoriya_app/src/features/watch_party/application/party_session_guard.dart';
import 'package:kumoriya_app/src/features/watch_party/application/providers/party_providers.dart';
import 'package:kumoriya_app/src/features/watch_party/application/realtime_state.dart';

void main() {
  PartyMember member(String id, {PartyRole role = PartyRole.member}) {
    return PartyMember(
      userId: id,
      displayName: id,
      role: role,
      joinedAt: DateTime.utc(2026, 1, 1),
      isReady: false,
    );
  }

  PartyRoom room({double episodeNumber = 3}) {
    return PartyRoom(
      id: 'room-1',
      hostId: 'host',
      members: <PartyMember>[
        member('host', role: PartyRole.host),
        member('member-1'),
        member('member-2'),
      ],
      anilistId: 42,
      animeTitle: 'Test Anime',
      episodeNumber: episodeNumber,
      maxMembers: 4,
      inviteCode: 'ABC123',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  group('partyAllMembersInPlayer', () {
    test('returns true when all connected members are in the player', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        connectedPeerIds: const <String>{'host', 'member-1', 'member-2'},
        memberStatuses: const <String, PartyMemberStatus>{
          'host': PartyMemberStatus.watching,
          'member-1': PartyMemberStatus.inPlayer,
          'member-2': PartyMemberStatus.inPlayer,
        },
      );

      expect(partyAllMembersInPlayer(session, localUserId: 'host'), isTrue);
    });

    test('returns false when a connected member is still in lobby', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        connectedPeerIds: const <String>{'host', 'member-1', 'member-2'},
        memberStatuses: const <String, PartyMemberStatus>{
          'host': PartyMemberStatus.watching,
          'member-1': PartyMemberStatus.inPlayer,
          'member-2': PartyMemberStatus.inLobby,
        },
      );

      expect(partyAllMembersInPlayer(session, localUserId: 'host'), isFalse);
    });

    test('returns false when no members are connected', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
      );

      expect(partyAllMembersInPlayer(session, localUserId: 'host'), isFalse);
    });

    test('returns true for solo room (only self connected)', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: PartyRoom(
          id: 'room-solo',
          hostId: 'host',
          members: <PartyMember>[member('host', role: PartyRole.host)],
          anilistId: 42,
          animeTitle: 'Test Anime',
          episodeNumber: 1,
          maxMembers: 1,
          inviteCode: 'SOLO',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        connectedPeerIds: const <String>{'host'},
      );

      expect(partyAllMembersInPlayer(session, localUserId: 'host'), isTrue);
    });
  });

  group('partyConnectedMemberCount', () {
    test('counts local member once in legacy v1 shape', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        connectedPeerIds: const <String>{'member-1'},
      );

      expect(partyConnectedMemberCount(session, localUserId: 'host'), 2);
    });

    test('does not double count local member in realtime v2 shape', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        connectedPeerIds: const <String>{'host', 'member-1'},
      );

      expect(partyConnectedMemberCount(session, localUserId: 'host'), 2);
    });
  });

  group('shouldHoldPartyPlayback', () {
    PartySessionState sessionWith({
      required Set<String> connectedPeerIds,
      required Map<String, PartyMemberStatus> memberStatuses,
      PartyPlaybackState playback = PartyPlaybackState.empty,
    }) {
      return PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        connectedPeerIds: connectedPeerIds,
        memberStatuses: memberStatuses,
        playback: playback,
      );
    }

    const allInPlayer = <String, PartyMemberStatus>{
      'host': PartyMemberStatus.watching,
      'member-1': PartyMemberStatus.inPlayer,
      'member-2': PartyMemberStatus.inPlayer,
    };
    const playing = PartyPlaybackState(
      status: 'playing',
      basePositionMs: 0,
      effectiveAtMs: 0,
      generation: 1,
    );

    test('is a no-op when the player is not bound to the party room', () {
      final session = sessionWith(
        connectedPeerIds: <String>{'host', 'member-1', 'member-2'},
        memberStatuses: allInPlayer,
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: false,
          isLocalHost: false,
          localUserId: 'host',
        ),
        isFalse,
      );
    });

    test('holds everyone while a connected member is still in lobby', () {
      final session = sessionWith(
        connectedPeerIds: <String>{'host', 'member-1', 'member-2'},
        memberStatuses: <String, PartyMemberStatus>{
          'host': PartyMemberStatus.watching,
          'member-1': PartyMemberStatus.inPlayer,
          'member-2': PartyMemberStatus.inLobby,
        },
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: true,
          localUserId: 'host',
        ),
        isTrue,
        reason: 'host must wait for members to enter player',
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: false,
          localUserId: 'member-1',
        ),
        isTrue,
        reason: 'members must wait for each other before playing',
      );
    });

    test('lets the host play once all members are in the player', () {
      final session = sessionWith(
        connectedPeerIds: <String>{'host', 'member-1', 'member-2'},
        memberStatuses: allInPlayer,
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: true,
          localUserId: 'host',
        ),
        isFalse,
      );
    });

    test(
      'keeps members paused after presence-gate until the server signals play',
      () {
        final session = sessionWith(
          connectedPeerIds: <String>{'host', 'member-1', 'member-2'},
          memberStatuses: allInPlayer,
        );
        expect(
          shouldHoldPartyPlayback(
            session: session,
            isLocallyBoundToRoom: true,
            isLocalHost: false,
            localUserId: 'member-1',
          ),
          isTrue,
          reason: 'member must not auto-play while server says paused',
        );
      },
    );

    test('releases member playback once server signals play', () {
      final session = sessionWith(
        connectedPeerIds: <String>{'host', 'member-1', 'member-2'},
        memberStatuses: allInPlayer,
        playback: playing,
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: false,
          localUserId: 'member-1',
        ),
        isFalse,
      );
    });
  });

  group('partyLockedEpisodeNumberForAnime', () {
    test('locks members to the host episode on the same anime', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(episodeNumber: 7),
      );

      expect(
        partyLockedEpisodeNumberForAnime(
          session: session,
          isLocalHost: false,
          anilistId: 42,
        ),
        7,
      );
    });

    test('does not lock the host or a different anime page', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(episodeNumber: 7),
      );

      expect(
        partyLockedEpisodeNumberForAnime(
          session: session,
          isLocalHost: true,
          anilistId: 42,
        ),
        isNull,
      );
      expect(
        partyLockedEpisodeNumberForAnime(
          session: session,
          isLocalHost: false,
          anilistId: 99,
        ),
        isNull,
      );
    });
  });

  group('isPartyEpisodeLocked', () {
    test('blocks episodes that differ from the host selection', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(episodeNumber: 5),
      );

      expect(
        isPartyEpisodeLocked(
          session: session,
          isLocalHost: false,
          anilistId: 42,
          episodeNumber: 4,
        ),
        isTrue,
      );
      expect(
        isPartyEpisodeLocked(
          session: session,
          isLocalHost: false,
          anilistId: 42,
          episodeNumber: 5,
        ),
        isFalse,
      );
    });
  });
}
