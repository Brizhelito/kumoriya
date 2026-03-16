// ignore_for_file: lines_longer_than_80_chars

/// Bug Condition Exploration Test — Task 1 (anime-nexus-double-seek-fix)
///
/// **Property 1: Bug Condition** - State Timing Issue in _recoverCurrentCandidate
///
/// **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists.
/// **DO NOT attempt to fix the test or the code when it fails.**
/// **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation.
/// **GOAL**: Surface counterexamples that demonstrate the ordering bug exists.
///
/// **Validates: Requirements 1.1, 2.1**
///
/// Bug Condition:
/// In _recoverCurrentCandidate, _shouldReopenForSeek() is evaluated BEFORE
/// _applyTimelineWindow() sets _isManagedTimelineWindow = true.
/// This causes the guard to use stale state (false) instead of current state (true),
/// allowing seekTo(target) to execute when it should be skipped.
///
/// Execution order (BUGGY):
/// 1. open() completes → _isManagedTimelineWindow still false (stale)
/// 2. _shouldReopenForSeek() evaluated → returns false (incorrect)
/// 3. seekTo(target) executed → adds target offset
/// 4. _applyTimelineWindow() called → sets _isManagedTimelineWindow = true (too late)
/// 5. Position remapping adds base → effective position ≈ 2 × target
///
/// Expected order (FIXED):
/// 1. open() completes
/// 2. _applyTimelineWindow() called → sets _isManagedTimelineWindow = true
/// 3. _shouldReopenForSeek() evaluated → returns true (correct)
/// 4. seekTo(target) NOT executed → no double offset
/// 5. Position remapping works correctly → effective position ≈ target
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/services/playback_engine.dart';
import 'package:kumoriya_app/src/features/player/application/services/player_session_orchestrator.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  group(
    'Property 1: Bug Condition - State Timing Issue in _recoverCurrentCandidate',
    () {
      test('EXPLORATION (expected to FAIL on unfixed code): '
          'seekTo must NOT be called after windowed reopen because guard should evaluate with fresh state', () async {
        // Arrange: Simulate a seek-driven windowed reopen scenario
        // Target: 0:11:44.051 (704051 ms)
        const targetPosition = Duration(milliseconds: 704051);
        const localPlaylistStartPosition = Duration(milliseconds: 724);

        // Create a fake engine that tracks seekTo calls
        final engine = _FakePlaybackEngineWithSeekTracking(
          localPlaylistStartPosition: localPlaylistStartPosition,
        );

        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

        // Act: Start with non-zero initialPosition to establish windowed mode
        // This sets _isManagedTimelineWindow = true in _openCurrentCandidate
        await orchestrator.start(
          streamCandidates: <ResolvedStream>[
            ResolvedStream(
              url: Uri.parse(
                'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
              ),
              isHls: true,
            ),
          ],
          initialPosition: const Duration(seconds: 1),
        );

        // Wait for initial open to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Now trigger a seek that will escalate to Level 2 (reopen)
        // because _isManagedTimelineWindow is now true
        await orchestrator.seekTo(targetPosition);

        // Wait for reopen and any post-open operations
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert: On UNFIXED code, the orchestrator executes seekTo(target)
        // after the windowed reopen completes, even though the playlist is
        // already anchored to the target via applyTimelineWindow.
        //
        // Expected behavior (FIXED code):
        // - No seekTo call after windowed reopen with managed timeline
        // - Only the initial Level 2 reopen happens, no post-open seekTo
        //
        // Actual behavior (UNFIXED code):
        // - _shouldReopenForSeek evaluated with stale state (managed=false)
        // - Guard returns false, allowing seekTo(target) to execute
        // - seekTo(704051) is called after open
        // - This causes double offset

        final seekCalls = engine.seekToCalls;

        // On UNFIXED code: seekTo is called with the target position after reopen
        // This assertion FAILS on unfixed code — that is the expected outcome.
        //
        // Note: We expect exactly 0 seekTo calls because:
        // - Level 1 seek is skipped (anime-nexus HLS with target > 0 goes straight to Level 2)
        // - Level 2 reopen should NOT call seekTo after open (but unfixed code does)
        expect(
          seekCalls,
          isEmpty,
          reason:
              'Counterexample: unfixed code executed ${seekCalls.length} seekTo call(s) '
              'after windowed reopen. seekTo calls: $seekCalls. '
              'This proves the state timing bug exists: _shouldReopenForSeek was evaluated '
              'BEFORE _applyTimelineWindow set _isManagedTimelineWindow=true, '
              'causing the guard to use stale state and incorrectly allow seekTo.',
        );

        await orchestrator.dispose();
      });

      test('EXPLORATION: documents the ordering bug with state inspection', () async {
        // This test documents the bug by showing that seekTo is called
        // when it should not be, due to state timing issues.
        const targetPosition = Duration(milliseconds: 704051);

        final engine = _FakePlaybackEngineWithSeekTracking(
          localPlaylistStartPosition: const Duration(milliseconds: 724),
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
          initialPosition: const Duration(seconds: 1),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await orchestrator.seekTo(targetPosition);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final seekCalls = engine.seekToCalls;

        // ignore: avoid_print
        print(
          'State timing bug counterexample: '
          'targetPosition=$targetPosition (${targetPosition.inMilliseconds}ms), '
          'seekToCalls=${seekCalls.length} $seekCalls. '
          'Expected: 0 seekTo calls (windowed reopen should skip post-open seekTo). '
          'Actual: ${seekCalls.length} seekTo call(s). '
          'Root cause: _shouldReopenForSeek evaluated with stale _isManagedTimelineWindow=false '
          'before _applyTimelineWindow set it to true.',
        );

        await orchestrator.dispose();
      });
    },
  );
}

// ---------------------------------------------------------------------------
// Fake engine that tracks seekTo calls and simulates windowed reopen behavior
// ---------------------------------------------------------------------------

final class _FakePlaybackEngineWithSeekTracking implements PlaybackEngine {
  _FakePlaybackEngineWithSeekTracking({
    required this.localPlaylistStartPosition,
  });

  final Duration localPlaylistStartPosition;
  final List<Duration> seekToCalls = <Duration>[];
  Duration lastEmittedPosition = Duration.zero;

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
    // Simulate windowed reopen: the playlist starts at local time near 0
    // (localPlaylistStartPosition), not at the requested startPosition.
    // The orchestrator will apply timeline remapping via applyTimelineWindow.
    _bufferingController.add(true);
    _playingController.add(true);

    // Emit the local playlist start position (simulates windowed playlist)
    lastEmittedPosition = localPlaylistStartPosition;
    _positionController.add(localPlaylistStartPosition);

    // Emit a reasonable duration
    _durationController.add(const Duration(minutes: 24));

    _bufferingController.add(false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    // Track all seekTo calls - this is what we're testing for
    seekToCalls.add(position);

    // Simulate seek: the position becomes the seek target
    // (in the real bug, this adds to the local position before timeline remapping)
    lastEmittedPosition = position;
    _positionController.add(lastEmittedPosition);
  }

  @override
  Future<void> play() async => _playingController.add(true);

  @override
  Future<void> signalPredictivePrewarm(Duration position) async {}

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
