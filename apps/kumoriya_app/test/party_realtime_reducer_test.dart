import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/watch_party/application/realtime_state.dart';
import 'package:kumoriya_app/src/features/watch_party/infrastructure/party_realtime_client.dart';

/// Helper to quickly reduce a sequence of `(type, payload)` events.
PartyRealtimeState applyAll(
  PartyRealtimeState initial,
  List<(String, Map<String, dynamic>)> events, {
  int? roomVersionStart,
}) {
  var state = initial;
  var v = roomVersionStart ?? 0;
  for (final e in events) {
    v += 1;
    state = reducePartyRealtimeEvent(state, e.$1, e.$2, roomVersion: v);
  }
  return state;
}

void main() {
  group('PartyEventEnvelope.tryParse', () {
    test('parses a well-formed envelope', () {
      final raw = jsonEncode({
        'type': 'member_joined',
        'sentAt': 1000,
        'roomId': 'room-1',
        'roomVersion': 7,
        'sender': 'user-1',
        'messageId': 'abc',
        'payload': {'member': {'userId': 'user-2', 'name': 'Bob'}},
      });
      final env = PartyEventEnvelope.tryParse(raw);
      expect(env, isNotNull);
      expect(env!.type, 'member_joined');
      expect(env.roomId, 'room-1');
      expect(env.roomVersion, 7);
      expect(env.messageId, 'abc');
      expect(env.payload['member'], isA<Map<String, dynamic>>());
    });

    test('returns null on invalid JSON', () {
      expect(PartyEventEnvelope.tryParse('not-json'), isNull);
      expect(PartyEventEnvelope.tryParse('[1,2,3]'), isNull);
    });

    test('returns null when type is missing', () {
      final raw = jsonEncode({'payload': {}});
      expect(PartyEventEnvelope.tryParse(raw), isNull);
    });
  });

  group('reducePartyRealtimeEvent', () {
    const empty = PartyRealtimeState();

    test('room_snapshot populates roomId, host, members, ready and playback', () {
      final state = reducePartyRealtimeEvent(empty, 'room_snapshot', {
        'roomId': 'room-1',
        'hostId': 'user-1',
        'inviteCode': 'ABCDEF',
        'roomVersion': 3,
        'serverTimeMs': DateTime.now().millisecondsSinceEpoch + 1234,
        'members': [
          {
            'userId': 'user-1',
            'name': 'Alice',
            'presence': 'connected',
            'effectiveReady': true,
            'joinedAtMs': 1,
          },
          {
            'userId': 'user-2',
            'name': 'Bob',
            'presence': 'disconnected',
            'effectiveReady': false,
            'joinedAtMs': 2,
          },
        ],
        'playback': {
          'status': 'playing',
          'basePositionMs': 5000,
          'effectiveAtMs': 10000,
          'generation': 4,
        },
      });

      expect(state.roomId, 'room-1');
      expect(state.hostId, 'user-1');
      expect(state.inviteCode, 'ABCDEF');
      expect(state.roomVersion, 3);
      expect(state.members.map((m) => m.userId), ['user-1', 'user-2']);
      expect(state.connectedIds, {'user-1'});
      expect(state.readyStates['user-1'], true);
      expect(state.readyStates['user-2'], false);
      expect(state.playback.isPlaying, true);
      expect(state.playback.basePositionMs, 5000);
      expect(state.clientServerOffsetMs, greaterThan(0));
    });

    test('member_joined adds member and marks connected', () {
      final state = reducePartyRealtimeEvent(empty, 'member_joined', {
        'member': {
          'userId': 'user-2',
          'name': 'Bob',
          'effectiveReady': false,
        },
      }, roomVersion: 2);

      expect(state.members.map((m) => m.userId), ['user-2']);
      expect(state.connectedIds, {'user-2'});
      expect(state.readyStates['user-2'], false);
      expect(state.roomVersion, 2);
    });

    test('member_left removes and updates host if provided', () {
      final initial = PartyRealtimeState(
        hostId: 'user-1',
        roomVersion: 1,
        connectedIds: const {'user-1', 'user-2'},
        readyStates: const {'user-1': true, 'user-2': true},
      );

      final state = reducePartyRealtimeEvent(initial, 'member_left', {
        'userId': 'user-1',
        'newHostId': 'user-2',
      }, roomVersion: 2);

      expect(state.hostId, 'user-2');
      expect(state.connectedIds, {'user-2'});
      expect(state.readyStates.containsKey('user-1'), false);
    });

    test('presence change to disconnected resets ready to false', () {
      final initial = PartyRealtimeState(
        connectedIds: const {'user-1'},
        readyStates: const {'user-1': true},
      );
      final state = reducePartyRealtimeEvent(initial, 'member_presence_changed', {
        'userId': 'user-1',
        'presence': 'disconnected',
      });
      expect(state.connectedIds, isEmpty);
      expect(state.readyStates['user-1'], false);
    });

    test('ready_changed updates only the specified user', () {
      final initial = PartyRealtimeState(
        readyStates: const {'user-1': true, 'user-2': false},
      );
      final state = reducePartyRealtimeEvent(initial, 'member_ready_changed', {
        'userId': 'user-2',
        'effectiveReady': true,
      });
      expect(state.readyStates, {'user-1': true, 'user-2': true});
    });

    test('playback_state_changed replaces playback', () {
      final state = reducePartyRealtimeEvent(PartyRealtimeState(), 'playback_state_changed', {
        'status': 'paused',
        'basePositionMs': 9_000,
        'effectiveAtMs': 42_000,
        'generation': 11,
      });
      expect(state.playback.isPlaying, false);
      expect(state.playback.basePositionMs, 9_000);
      expect(state.playback.generation, 11);
    });

    test('host_transferred updates hostId', () {
      final state = reducePartyRealtimeEvent(
        PartyRealtimeState(hostId: 'user-1'),
        'host_transferred',
        {'oldHostId': 'user-1', 'newHostId': 'user-2'},
      );
      expect(state.hostId, 'user-2');
    });

    test('room_closed clears the room', () {
      final initial = PartyRealtimeState(
        roomId: 'room-1',
        hostId: 'user-1',
        members: const [],
      );
      final state = reducePartyRealtimeEvent(initial, 'room_closed', {});
      expect(state.roomId, isNull);
      expect(state.hostId, isNull);
    });

    test('unknown events are no-ops', () {
      const initial = PartyRealtimeState(roomId: 'room-1', roomVersion: 5);
      final state = reducePartyRealtimeEvent(initial, 'no_such_event', {'x': 1});
      expect(identical(state, initial), true);
    });

    test('applying a full lifecycle converges to expected shape', () {
      final state = applyAll(const PartyRealtimeState(), [
        (
          'room_snapshot',
          {
            'roomId': 'room-1',
            'hostId': 'user-1',
            'inviteCode': 'AAA111',
            'members': [
              {'userId': 'user-1', 'name': 'Alice', 'presence': 'connected', 'effectiveReady': false},
            ],
            'playback': {'status': 'paused', 'basePositionMs': 0, 'effectiveAtMs': 0, 'generation': 0},
          },
        ),
        (
          'member_joined',
          {'member': {'userId': 'user-2', 'name': 'Bob', 'effectiveReady': false}},
        ),
        ('member_ready_changed', {'userId': 'user-1', 'effectiveReady': true}),
        ('member_ready_changed', {'userId': 'user-2', 'effectiveReady': true}),
        ('playback_state_changed', {
          'status': 'playing',
          'basePositionMs': 0,
          'effectiveAtMs': DateTime.now().millisecondsSinceEpoch,
          'generation': 1,
        }),
      ]);

      expect(state.readyStates.values.every((r) => r), true);
      expect(state.connectedIds, {'user-1', 'user-2'});
      expect(state.playback.isPlaying, true);
    });
  });
}
