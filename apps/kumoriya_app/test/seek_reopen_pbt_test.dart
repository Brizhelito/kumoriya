// ignore_for_file: lines_longer_than_80_chars

/// Property-Based Tests — Task 5 (app package)
///
/// Uses hand-rolled property loops with dart:math Random.
///
/// P-PBT-3: errorGeneration < openGeneration → success clears errorMessage
/// P-PBT-4: errorGeneration == openGeneration → success does NOT clear errorMessage
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_session_state.dart';

// ---------------------------------------------------------------------------
// Inline replica of the clearError decision logic from the orchestrator.
// Mirrors: shouldClearError = state.errorMessage != null &&
//                             state.errorGeneration < thisGeneration
// ---------------------------------------------------------------------------

/// Simulates the success-emit clearError decision.
/// Returns the resulting state after a successful open with [thisGeneration].
PlayerSessionState _applySuccessEmit({
  required PlayerSessionState state,
  required int thisGeneration,
}) {
  final shouldClearError =
      state.errorMessage != null && state.errorGeneration < thisGeneration;
  return state.copyWith(
    status: PlayerSessionStatus.playing,
    clearError: shouldClearError,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const seed = 42;
  const iterations = 500;

  // -------------------------------------------------------------------------
  // P-PBT-3: errorGeneration < openGeneration → success clears errorMessage
  // -------------------------------------------------------------------------
  group(
    'P-PBT-3: errorGeneration < openGeneration → success clears errorMessage',
    () {
      test('for random (errorGen, openGen) where errorGen < openGen: '
          'success emit clears errorMessage', () {
        final rng = Random(seed);
        for (var i = 0; i < iterations; i++) {
          final errorGen = rng.nextInt(100); // [0..99]
          final openGen = errorGen + 1 + rng.nextInt(50); // > errorGen

          final stateWithError = PlayerSessionState(
            status: PlayerSessionStatus.error,
            errorMessage: 'some error from generation $errorGen',
            errorGeneration: errorGen,
          );

          final result = _applySuccessEmit(
            state: stateWithError,
            thisGeneration: openGen,
          );

          expect(
            result.errorMessage,
            isNull,
            reason:
                'errorGen=$errorGen openGen=$openGen: '
                'success must clear stale errorMessage',
          );
          expect(
            result.errorGeneration,
            -1,
            reason:
                'errorGen=$errorGen openGen=$openGen: '
                'errorGeneration must reset to -1 after clear',
          );
          expect(result.status, PlayerSessionStatus.playing);
        }
      });

      test(
        'errorGeneration=0, openGeneration=1 (minimal stale case) → cleared',
        () {
          final state = const PlayerSessionState(
            status: PlayerSessionStatus.error,
            errorMessage: 'stale error',
            errorGeneration: 0,
          );
          final result = _applySuccessEmit(state: state, thisGeneration: 1);
          expect(result.errorMessage, isNull);
          expect(result.errorGeneration, -1);
        },
      );
    },
  );

  // -------------------------------------------------------------------------
  // P-PBT-4: errorGeneration == openGeneration → success does NOT clear
  // -------------------------------------------------------------------------
  group(
    'P-PBT-4: errorGeneration == openGeneration → success does NOT clear errorMessage',
    () {
      test('for random gen where errorGen == openGen: '
          'success emit preserves errorMessage', () {
        final rng = Random(seed);
        for (var i = 0; i < iterations; i++) {
          final gen = 1 + rng.nextInt(100); // [1..100]
          const errorMsg = 'concurrent error same generation';

          final stateWithError = PlayerSessionState(
            status: PlayerSessionStatus.error,
            errorMessage: errorMsg,
            errorGeneration: gen,
          );

          final result = _applySuccessEmit(
            state: stateWithError,
            thisGeneration: gen, // same generation
          );

          expect(
            result.errorMessage,
            equals(errorMsg),
            reason:
                'gen=$gen: same-generation error must NOT be cleared by success',
          );
          expect(
            result.errorGeneration,
            gen,
            reason: 'gen=$gen: errorGeneration must be preserved',
          );
        }
      });

      test(
        'no prior error (errorMessage==null) → success emit leaves errorMessage null',
        () {
          final rng = Random(seed);
          for (var i = 0; i < iterations; i++) {
            final gen = 1 + rng.nextInt(100);
            const state = PlayerSessionState.idle();
            final result = _applySuccessEmit(state: state, thisGeneration: gen);
            expect(
              result.errorMessage,
              isNull,
              reason: 'gen=$gen: clean state must stay clean after success',
            );
          }
        },
      );
    },
  );

  // -------------------------------------------------------------------------
  // P-PBT-5: copyWith clearError semantics — property check
  // -------------------------------------------------------------------------
  group('P-PBT-5: PlayerSessionState.copyWith clearError semantics', () {
    test('clearError=true always resets errorMessage and errorGeneration '
        'regardless of input values', () {
      final rng = Random(seed);
      for (var i = 0; i < iterations; i++) {
        final gen = rng.nextInt(200);
        final state = PlayerSessionState(
          status: PlayerSessionStatus.error,
          errorMessage: 'error $i',
          errorGeneration: gen,
        );
        final cleared = state.copyWith(clearError: true);
        expect(
          cleared.errorMessage,
          isNull,
          reason: 'gen=$gen: clearError=true must null errorMessage',
        );
        expect(
          cleared.errorGeneration,
          -1,
          reason: 'gen=$gen: clearError=true must reset errorGeneration to -1',
        );
      }
    });

    test(
      'clearError=false (default) preserves errorMessage and errorGeneration',
      () {
        final rng = Random(seed);
        for (var i = 0; i < iterations; i++) {
          final gen = rng.nextInt(200);
          const msg = 'preserved error';
          final state = PlayerSessionState(
            status: PlayerSessionStatus.error,
            errorMessage: msg,
            errorGeneration: gen,
          );
          final updated = state.copyWith(status: PlayerSessionStatus.buffering);
          expect(
            updated.errorMessage,
            equals(msg),
            reason:
                'gen=$gen: errorMessage must be preserved without clearError',
          );
          expect(
            updated.errorGeneration,
            gen,
            reason:
                'gen=$gen: errorGeneration must be preserved without clearError',
          );
        }
      },
    );
  });
}
