// ignore_for_file: lines_longer_than_80_chars

/// Preservation Property Tests — Task 2 (orchestrator side)
///
/// These tests run against UNFIXED code and are EXPECTED TO PASS.
/// They encode baseline behavior that must NOT regress after the fix.
///
/// P-PRES-3: StateError('engine disposed') (without 'invalidated') still
///           calls _fail() and emits PlayerSessionStatus.error.
/// P-PRES-4: Same-generation error is NOT cleared by a success emit
///           (no errorGeneration field yet — baseline: clearError=false
///           in success emit means errorMessage is never cleared there).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_session_state.dart';
import 'package:kumoriya_app/src/features/player/application/services/playback_engine.dart';
import 'package:kumoriya_app/src/features/player/application/services/player_session_orchestrator.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  group('P-PRES-3: Genuine engine disposal still emits error state', () {
    test('PRESERVATION: StateError("engine disposed") must emit '
        'PlayerSessionStatus.error (genuine disposal, not stale)', () async {
      // A genuine engine disposal (message contains 'disposed' but NOT
      // 'invalidated') must still call _fail() and emit error state.
      // The fix must NOT change this behavior.
      final engine = _FakePlaybackEngine(
        openBehaviors: <_OpenBehavior>[
          const _OpenBehavior.throwStateError('engine disposed'),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

      final emittedStates = <PlayerSessionState>[];
      final sub = orchestrator.states.listen(emittedStates.add);

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

      // Genuine disposal MUST emit error state — this is preserved behavior.
      final errorStates = emittedStates
          .where((s) => s.status == PlayerSessionStatus.error)
          .toList();

      expect(
        errorStates,
        isNotEmpty,
        reason:
            'Genuine engine disposal must emit error state. '
            'The fix must not suppress real disposal errors.',
      );
      expect(
        errorStates.first.errorMessage,
        isNotNull,
        reason: 'Error state must carry an errorMessage.',
      );
    });

    test('PRESERVATION: StateError("media player disposed") must emit error '
        '(another genuine disposal variant)', () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: <_OpenBehavior>[
          const _OpenBehavior.throwStateError('media player disposed'),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

      final emittedStates = <PlayerSessionState>[];
      final sub = orchestrator.states.listen(emittedStates.add);

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

      final errorStates = emittedStates
          .where((s) => s.status == PlayerSessionStatus.error)
          .toList();

      expect(
        errorStates,
        isNotEmpty,
        reason:
            'StateError with "disposed" (no "invalidated") must still '
            'emit error state after the fix.',
      );
    });
  });

  group('P-PRES-4: Success emit does not clear errorMessage on unfixed code '
      '(baseline: no clearError in success path)', () {
    test('PRESERVATION (baseline): on unfixed code, success emit after error '
        'does NOT clear errorMessage — this is the bug we are fixing in P1-C, '
        'but we document it here as the observed baseline', () async {
      // This test documents the CURRENT (unfixed) behavior:
      // success emit does not pass clearError=true, so errorMessage persists.
      // After the fix, this test will need to be updated — but for now
      // it confirms the baseline we are starting from.
      //
      // NOTE: This test is intentionally documenting the buggy baseline.
      // It will be superseded by the P1-C exploration test after the fix.
      final engine = _FakePlaybackEngine(
        openBehaviors: <_OpenBehavior>[
          const _OpenBehavior.throwStateError('open invalidated'),
          const _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

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

      // On unfixed code: errorMessage is NOT null (the bug).
      // We document this as the observed baseline.
      // ignore: avoid_print
      print(
        'P-PRES-4 baseline: '
        'status=${orchestrator.state.status} '
        'errorMessage="${orchestrator.state.errorMessage}"',
      );

      // The baseline observation: on unfixed code, errorMessage persists.
      // This is the bug P1-C fixes. We don't assert here — just document.
      // The real assertion is in the P1-C exploration test.
      await orchestrator.dispose();
    });

    test(
      'PRESERVATION: a successful open from idle (no prior error) '
      'produces null errorMessage — this must hold before and after fix',
      () async {
        // A clean start with no prior errors must always produce
        // errorMessage=null after success. This is preserved behavior.
        final engine = _FakePlaybackEngine(
          openBehaviors: <_OpenBehavior>[const _OpenBehavior.success()],
        );
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

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

        expect(
          orchestrator.state.errorMessage,
          isNull,
          reason:
              'Clean start with no prior errors must produce null errorMessage.',
        );
        expect(
          orchestrator.state.status,
          isNot(PlayerSessionStatus.error),
          reason: 'Clean start must not produce error status.',
        );

        await orchestrator.dispose();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fake engine
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

    _bufferingController.add(true);
    _playingController.add(true);
    _bufferingController.add(false);
  }

  @override
  Future<void> seekTo(Duration position) async =>
      _positionController.add(position);

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
  const _OpenBehavior.success() : stateErrorMessage = null;
  const _OpenBehavior.throwStateError(this.stateErrorMessage);
  final String? stateErrorMessage;
}
