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

  group('partyHasAllMembersReady', () {
    test('returns true only when every room member is ready', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        readyStates: const <String, bool>{
          'host': true,
          'member-1': true,
          'member-2': true,
        },
      );

      expect(partyHasAllMembersReady(session), isTrue);
    });

    test('returns false when one member is still loading', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        readyStates: const <String, bool>{
          'host': true,
          'member-1': true,
          'member-2': false,
        },
      );

      expect(partyHasAllMembersReady(session), isFalse);
    });

    test('dedupes duplicated room members by user id', () {
      final duplicatedRoom = room().copyWith(
        members: <PartyMember>[
          member('host', role: PartyRole.host),
          member('member-1'),
          member('member-1'),
        ],
      );
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: duplicatedRoom,
        readyStates: const <String, bool>{'host': true, 'member-1': true},
      );

      expect(partyHasAllMembersReady(session), isTrue);
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
    test('keeps members paused until the room playback is playing', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        readyStates: const <String, bool>{
          'host': true,
          'member-1': true,
          'member-2': true,
        },
      );

      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: false,
        ),
        isTrue,
      );
    });

    test('releases members once the room playback is playing', () {
      final session = PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        readyStates: const <String, bool>{
          'host': true,
          'member-1': true,
          'member-2': true,
        },
        playback: const PartyPlaybackState(
          status: 'playing',
          basePositionMs: 0,
          effectiveAtMs: 0,
          generation: 1,
        ),
      );

      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: false,
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

  group('shouldHoldPartyPlayback', () {
    PartySessionState sessionWith({
      required Map<String, bool> readyStates,
      PartyPlaybackState playback = PartyPlaybackState.empty,
    }) {
      return PartySessionState(
        status: PartySessionStatus.connected,
        room: room(),
        readyStates: readyStates,
        playback: playback,
      );
    }

    const allReady = <String, bool>{
      'host': true,
      'member-1': true,
      'member-2': true,
    };
    const playing = PartyPlaybackState(
      status: 'playing',
      basePositionMs: 0,
      effectiveAtMs: 0,
      generation: 1,
    );

    test('is a no-op when the player is not bound to the party room', () {
      final session = sessionWith(readyStates: const <String, bool>{});
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: false,
          isLocalHost: false,
        ),
        isFalse,
      );
    });

    test('holds everyone while any member is still loading', () {
      final session = sessionWith(
        readyStates: const <String, bool>{
          'host': true,
          'member-1': true,
          'member-2': false,
        },
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: true,
        ),
        isTrue,
        reason: 'host must wait for members before playing',
      );
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: false,
        ),
        isTrue,
        reason: 'members must wait for each other before playing',
      );
    });

    test('lets the host play once all members are ready', () {
      final session = sessionWith(readyStates: allReady);
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: true,
        ),
        isFalse,
      );
    });

    test(
      'keeps members paused after ready-gate until the server signals play',
      () {
        final session = sessionWith(readyStates: allReady);
        // Regression: before the non-host autoplay guard, members would
        // auto-play the moment everyone was ready, regardless of the host's
        // actual playback state. Members must mirror the server's
        // authoritative PartyPlaybackState.isPlaying, which is paused until
        // the host explicitly plays.
        expect(
          shouldHoldPartyPlayback(
            session: session,
            isLocallyBoundToRoom: true,
            isLocalHost: false,
          ),
          isTrue,
          reason: 'member must not auto-play while server says paused',
        );
      },
    );

    test('releases member playback once server signals play', () {
      final session = sessionWith(readyStates: allReady, playback: playing);
      expect(
        shouldHoldPartyPlayback(
          session: session,
          isLocallyBoundToRoom: true,
          isLocalHost: false,
        ),
        isFalse,
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
