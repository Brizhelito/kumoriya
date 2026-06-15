import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/watch_party/application/models/party_member.dart';
import 'package:kumoriya_app/src/features/watch_party/application/realtime_state.dart';

void main() {
  PartyMember member(
    String id, {
    PartyRole role = PartyRole.member,
    bool isReady = false,
  }) {
    return PartyMember(
      userId: id,
      displayName: id,
      role: role,
      joinedAt: DateTime.utc(2026, 1, 1),
      isReady: isReady,
    );
  }

  group('Watch Party Seek Barrier', () {
    test('simulates seek -> awaitReady -> ready transitions', () {
      final initial = PartyRealtimeState(
        roomId: 'room-1',
        hostId: 'host',
        inviteCode: 'ABC123',
        members: [
          member('host', role: PartyRole.host, isReady: true),
          member('member-1', isReady: true),
        ],
        readyStates: const {'host': true, 'member-1': true},
        playback: const PartyPlaybackState(
          status: 'playing',
          basePositionMs: 5000,
          effectiveAtMs: 1000,
          generation: 1,
          awaitReady: false,
        ),
      );

      // 1. Host seeks. Server pauses and sets awaitReady = true, resetting all ready states to false.
      var state = reducePartyRealtimeEvent(initial, 'playback_state_changed', {
        'status': 'paused',
        'basePositionMs': 10000,
        'effectiveAtMs': 2000,
        'generation': 2,
        'awaitReady': true,
      });

      expect(state.playback.status, 'paused');
      expect(state.playback.awaitReady, true);
      expect(state.playback.basePositionMs, 10000);
      expect(state.playback.generation, 2);

      // Server also sends ready changes for members.
      state = reducePartyRealtimeEvent(state, 'member_ready_changed', {
        'userId': 'host',
        'effectiveReady': false,
      });
      state = reducePartyRealtimeEvent(state, 'member_ready_changed', {
        'userId': 'member-1',
        'effectiveReady': false,
      });

      expect(state.readyStates['host'], false);
      expect(state.readyStates['member-1'], false);

      // 2. Host becomes ready.
      state = reducePartyRealtimeEvent(state, 'member_ready_changed', {
        'userId': 'host',
        'effectiveReady': true,
      });
      expect(state.readyStates['host'], true);
      expect(state.readyStates['member-1'], false);
      expect(state.playback.status, 'paused'); // Still waiting for member-1

      // 3. Member-1 becomes ready.
      state = reducePartyRealtimeEvent(state, 'member_ready_changed', {
        'userId': 'member-1',
        'effectiveReady': true,
      });
      expect(state.readyStates['host'], true);
      expect(state.readyStates['member-1'], true);

      // 4. Once all ready, server auto-resumes playback (status: playing, awaitReady: false).
      state = reducePartyRealtimeEvent(state, 'playback_state_changed', {
        'status': 'playing',
        'basePositionMs': 10000,
        'effectiveAtMs': 3000,
        'generation': 3,
        'awaitReady': false,
      });

      expect(state.playback.status, 'playing');
      expect(state.playback.awaitReady, false);
      expect(state.playback.basePositionMs, 10000);
    });
  });
}
