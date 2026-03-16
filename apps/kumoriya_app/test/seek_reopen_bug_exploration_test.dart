// ignore_for_file: lines_longer_than_80_chars

/// Bug Condition Exploration Tests — Task 1 (orchestrator side)
///
/// These tests run against UNFIXED code and are EXPECTED TO FAIL.
/// Failure confirms the bugs exist. Do NOT fix the tests or the code.
/// When the fixes are applied (Task 3), these same tests will pass.
///
/// P1-B: _isEngineDisposedError matches 'invalidated' → stale open emits error.
/// P1-C: success emit does not clear residual errorMessage from prior generation.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_session_state.dart';
import 'package:kumoriya_app/src/features/player/application/services/playback_engine.dart';
import 'package:kumoriya_app/src/features/player/application/services/player_session_orchestrator.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  group('P1-B Bug Condition: stale-generation open emits error state', () {
    test(
      'EXPLORATION (expected to FAIL on unfixed code): '
      'StateError("open invalidated") must NOT emit PlayerSessionStatus.error',
      () async {
        // Arrange: first open throws 'invalidated' immediately (simulates a
        // stale-generation open — the engine was superseded before it could
        // complete).  This is the exact StateError the engine emits when a
        // newer generation invalidates an in-flight open.
        //
        // On UNFIXED code: _isEngineDisposedError matches 'invalidated',
        // so _fail() is called and PlayerSessionStatus.error is emitted.
        // On FIXED code: _isStaleGenerationError detects 'invalidated' and
        // returns a silent no-op — no error state is emitted.
        final engine = _FakePlaybackEngine(
          openBehaviors: <_OpenBehavior>[
            const _OpenBehavior.throwStateError('open invalidated'),
          ],
        );
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

        // Collect all emitted states.
        final emittedStates = <PlayerSessionState>[];
        final sub = orchestrator.states.listen(emittedStates.add);

        // Start — the single open throws 'invalidated'.
        await orchestrator.start(
          streamCandidates: <ResolvedStream>[
            ResolvedStream(
              url: Uri.parse(
                'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
              ),
              isHls: true,
            ),
          ],
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await sub.cancel();
        await orchestrator.dispose();

        // On UNFIXED code: _isEngineDisposedError matches 'invalidated',
        // so _fail() is called and PlayerSessionStatus.error is emitted.
        // This assertion FAILS on unfixed code — that is the expected outcome.
        //
        // Counterexample: emittedStates contains a state with status=error
        // and errorMessage='Playback engine was disposed during open sequence.'
        final errorStates = emittedStates
            .where((s) => s.status == PlayerSessionStatus.error)
            .toList();

        expect(
          errorStates,
          isEmpty,
          reason:
              'Counterexample: unfixed code emits ${errorStates.length} error '
              'state(s) for a stale-generation open. '
              'errorMessages: ${errorStates.map((s) => s.errorMessage).toList()}. '
              'This proves P1-B exists.',
        );
      },
    );
  });

  group(
    'P1-C Bug Condition: residual errorMessage persists after successful open',
    () {
      test('EXPLORATION (expected to FAIL on unfixed code): '
          'errorMessage must be null after a successful open', () async {
        // Arrange: first open throws 'invalidated' (stale), second open succeeds.
        // On unfixed code: first open sets errorMessage, second open does NOT
        // clear it because clearError is not passed in the success emit.
        final engine = _FakePlaybackEngine(
          openBehaviors: <_OpenBehavior>[
            const _OpenBehavior.throwStateError('open invalidated'),
            const _OpenBehavior.success(),
          ],
        );
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

        // Start — first open throws 'invalidated', falls back to second open.
        // (On unfixed code, the 'invalidated' error triggers _fail() which
        // sets errorMessage, then the fallback succeeds but doesn't clear it.)
        await orchestrator.start(
          streamCandidates: <ResolvedStream>[
            ResolvedStream(
              url: Uri.parse(
                'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
              ),
              isHls: true,
            ),
            ResolvedStream(
              url: Uri.parse(
                'http://127.0.0.1:9999/anime-nexus/session/master/1600/2.m3u8',
              ),
              isHls: true,
            ),
          ],
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // On UNFIXED code: errorMessage persists from the stale open.
        // This assertion FAILS on unfixed code — that is the expected outcome.
        //
        // Counterexample: state.errorMessage = 'Playback engine was disposed
        // during open sequence.' even though the second open succeeded.
        expect(
          orchestrator.state.errorMessage,
          isNull,
          reason:
              'Counterexample: unfixed code leaves errorMessage='
              '"${orchestrator.state.errorMessage}" '
              'after a successful open. This proves P1-C exists.',
        );

        await orchestrator.dispose();
      });

      test(
        'EXPLORATION: documents that clearError=true is missing in success emit',
        () async {
          // This test documents the bug by verifying the state after a
          // successful open still has a non-null errorMessage on unfixed code.
          // It always passes on unfixed code (documents the counterexample).
          final engine = _FakePlaybackEngine(
            openBehaviors: <_OpenBehavior>[
              const _OpenBehavior.throwStateError('open invalidated'),
              const _OpenBehavior.success(),
            ],
          );
          final orchestrator = PlayerSessionOrchestrator(
            playbackEngine: engine,
          );

          await orchestrator.start(
            streamCandidates: <ResolvedStream>[
              ResolvedStream(
                url: Uri.parse(
                  'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
                ),
                isHls: true,
              ),
              ResolvedStream(
                url: Uri.parse(
                  'http://127.0.0.1:9999/anime-nexus/session/master/1600/2.m3u8',
                ),
                isHls: true,
              ),
            ],
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          // ignore: avoid_print
          print(
            'P1-C counterexample: '
            'status=${orchestrator.state.status} '
            'errorMessage="${orchestrator.state.errorMessage}"',
          );

          await orchestrator.dispose();
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fake engine that supports throwing StateError
// ---------------------------------------------------------------------------

final class _FakePlaybackEngine implements PlaybackEngine {
  _FakePlaybackEngine({required List<_OpenBehavior> openBehaviors})
    : _openBehaviors = openBehaviors;

  final List<_OpenBehavior> _openBehaviors;
  int _openBehaviorIndex = 0;

  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;
  @override
  Stream<String> get errorStream => _errorController.stream;
  @override
  Stream<bool> get completedStream => _completedController.stream;
  @override
  Stream<bool> get playingStream => _playingController.stream;
  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    final behavior =
        _openBehaviors[_openBehaviorIndex.clamp(0, _openBehaviors.length - 1)];
    if (_openBehaviorIndex < _openBehaviors.length - 1) {
      _openBehaviorIndex++;
    }

    if (behavior.stateErrorMessage != null) {
      throw StateError(behavior.stateErrorMessage!);
    }

    if (behavior.shouldThrow) {
      throw Exception(behavior.errorMessage ?? 'open fail');
    }

    _bufferingController.add(true);
    _playingController.add(true);
    _bufferingController.add(false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> signalPredictivePrewarm(Duration position) async {}

  @override
  Future<void> play() async => _playingController.add(true);

  @override
  Future<void> pause() async => _playingController.add(false);

  @override
  Future<void> clearSubtitleTrack() async {}

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) async {}

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _bufferingController.close();
    await _completedController.close();
    await _errorController.close();
    await _positionController.close();
    await _durationController.close();
  }
}

final class _OpenBehavior {
  const _OpenBehavior.success()
    : shouldThrow = false,
      errorMessage = null,
      stateErrorMessage = null;

  const _OpenBehavior.throwStateError(this.stateErrorMessage)
    : shouldThrow = false,
      errorMessage = null;

  final bool shouldThrow;
  final String? errorMessage;
  final String? stateErrorMessage;
}
