import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/watch_party/application/models/voice_state.dart';

void main() {
  group('PartyVoiceState Model Tests', () {
    test('default state values are correct', () {
      const state = PartyVoiceState();
      expect(state.isInitialized, isFalse);
      expect(state.isMicEnabled, isFalse);
      expect(state.hasPermission, isFalse);
      expect(state.connectedVoicePeers, isEmpty);
      expect(state.speakingPeers, isEmpty);
      expect(state.isConnecting, isFalse);
      expect(state.isAvailable, isFalse);
    });

    test('copyWith updates fields correctly', () {
      const state = PartyVoiceState();
      final updated = state.copyWith(
        isInitialized: true,
        hasPermission: true,
        isMicEnabled: true,
        connectedVoicePeers: {'user-1'},
        speakingPeers: {'user-2'},
        isConnecting: true,
      );

      expect(updated.isInitialized, isTrue);
      expect(updated.hasPermission, isTrue);
      expect(updated.isMicEnabled, isTrue);
      expect(updated.connectedVoicePeers, contains('user-1'));
      expect(updated.speakingPeers, contains('user-2'));
      expect(updated.isConnecting, isTrue);
      expect(updated.isAvailable, isTrue);
    });

    test('equality and hashing work correctly', () {
      const s1 = PartyVoiceState(
        isInitialized: true,
        isMicEnabled: true,
        connectedVoicePeers: {'a'},
      );
      const s2 = PartyVoiceState(
        isInitialized: true,
        isMicEnabled: true,
        connectedVoicePeers: {'a'},
      );
      const s3 = PartyVoiceState(
        isInitialized: true,
        isMicEnabled: false,
        connectedVoicePeers: {'a'},
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
    });
  });
}
