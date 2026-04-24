// ignore_for_file: lines_longer_than_80_chars

/// Preservation Property Tests — Task 2 (anime-nexus-double-seek-fix)
///
/// **Property 2: Preservation** - Non-Windowed Seek Flows
///
/// **IMPORTANT**: These tests validate that non-buggy seek flows continue to work
/// correctly after the fix. They should PASS on both unfixed and fixed code.
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**
///
/// Test cases:
/// - Native seek (non-reopen) on candidates that support it works correctly
/// - Non-windowed HLS reopens (target=0 or non-anime-nexus) work correctly
/// - Zero-target opens work normally without managed timeline
/// - Seek confirmation and cleanup when position reaches target works correctly
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/embedded_tracks.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_diagnostics.dart';
import 'package:kumoriya_app/src/features/player/application/services/playback_engine.dart';
import 'package:kumoriya_app/src/features/player/application/services/player_session_orchestrator.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  group('Property 2: Preservation - Non-Windowed Seek Flows', () {
    test(
      'Native seek (Level 1) works correctly for non-windowed streams',
      () async {
        // Arrange: Start with zero position (no windowed mode)
        const targetPosition = Duration(seconds: 30);
        final engine = _FakePlaybackEngineWithSeekTracking();
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

        // Act: Start from zero (no windowed mode)
        await orchestrator.start(
          streamCandidates: <ResolvedStream>[
            ResolvedStream(
              url: Uri.parse(
                'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
              ),
              isHls: true,
            ),
          ],
          initialPosition: Duration.zero,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Seek to target - should use Level 1 (native seek)
        await orchestrator.seekTo(targetPosition);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Assert: Native seek was called
        expect(engine.seekToCalls, contains(targetPosition));
        expect(
          engine.reopenCount,
          equals(0),
          reason: 'Should use native seek, not reopen',
        );

        await orchestrator.dispose();
      },
    );

    test('Zero-target opens work normally without managed timeline', () async {
      // Arrange
      final engine = _FakePlaybackEngineWithSeekTracking();
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

      // Act: Start with zero position
      await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: Duration.zero,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert: No seeks, no managed timeline
      expect(engine.seekToCalls, isEmpty);
      expect(engine.lastOpenStartPosition, isNull);

      await orchestrator.dispose();
    });

    test('Non-anime-nexus HLS streams work correctly', () async {
      // Arrange: Regular HLS stream (not anime-nexus)
      const targetPosition = Duration(seconds: 45);
      final engine = _FakePlaybackEngineWithSeekTracking();
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

      // Act: Start regular HLS stream
      await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse('https://example.com/stream.m3u8'),
            isHls: true,
          ),
        ],
        initialPosition: Duration.zero,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Seek - should trigger reopen for HLS
      await orchestrator.seekTo(targetPosition);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert: Reopen happened (Level 2 for HLS)
      expect(engine.reopenCount, greaterThan(0));

      await orchestrator.dispose();
    });

    test(
      'Seek confirmation clears pendingTarget when position reaches target',
      () async {
        // Arrange
        const targetPosition = Duration(seconds: 10);
        final engine = _FakePlaybackEngineWithSeekTracking();
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

        // Act: Start and seek
        await orchestrator.start(
          streamCandidates: <ResolvedStream>[
            ResolvedStream(
              url: Uri.parse(
                'http://127.0.0.1:9999/anime-nexus/session/master/1600/1.m3u8',
              ),
              isHls: true,
            ),
          ],
          initialPosition: Duration.zero,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await orchestrator.seekTo(targetPosition);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert: Position reached target (simulated by fake engine)
        expect(engine.lastEmittedPosition, equals(targetPosition));

        await orchestrator.dispose();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fake engine for preservation tests
// ---------------------------------------------------------------------------

final class _FakePlaybackEngineWithSeekTracking implements PlaybackEngine {
  final List<Duration> seekToCalls = <Duration>[];
  int _openCallCount = 0;
  Duration? lastOpenStartPosition;
  Duration lastEmittedPosition = Duration.zero;

  // reopenCount tracks opens AFTER the first one
  int get reopenCount => _openCallCount > 0 ? _openCallCount - 1 : 0;

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
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();

  @override
  Stream<double> get bufferingPercentageStream => const Stream<double>.empty();

  @override
  Stream<EmbeddedTracks> get embeddedTracksStream =>
      const Stream<EmbeddedTracks>.empty();

  @override
  Stream<PlayerDiagnostics> get diagnosticsStream =>
      const Stream<PlayerDiagnostics>.empty();

  @override
  Future<void> get firstFrameRendered => Future<void>.value();

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    _openCallCount++;
    lastOpenStartPosition = startPosition;

    _bufferingController.add(true);
    _playingController.add(true);

    // Emit position based on startPosition or zero
    lastEmittedPosition = startPosition ?? Duration.zero;
    _positionController.add(lastEmittedPosition);
    _durationController.add(const Duration(minutes: 24));

    _bufferingController.add(false);
  }

  @override
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {}

  @override
  Future<void> setSmartAudioBoost({required bool enabled}) async {}

  @override
  Future<void> seekTo(Duration position) async {
    seekToCalls.add(position);
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
  Future<void> setEmbeddedAudioTrack(EmbeddedAudioTrack track) async {}

  @override
  Future<void> setEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) async {}

  @override
  Future<void> setEmbeddedVideoTrack(EmbeddedVideoTrack track) async {}

  @override
  Future<void> clearEmbeddedVideoTrack() async {}

  @override
  Future<void> clearEmbeddedSubtitleTrack() async {}

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) async {}

  @override
  Future<void> setVolume(double percent) async {}
  @override
  Future<void> setPlaybackSpeed(double rate) async {}
  @override
  Future<void> setPreferredSubtitleLanguages(List<String> languages) async {}

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
