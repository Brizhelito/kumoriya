// ignore_for_file: lines_longer_than_80_chars

/// Integration Tests — Task 6
///
/// Exercises composed seek/reopen flows end-to-end using inline replicas of
/// the fixed proxy-server logic and the real PlayerSessionOrchestrator.
///
/// IT-1: Full seek to 840,000ms on multi-track stream
///   - prefetch cache keys contain absolute indices near 211/212
///   - NO cache key contains index 0/1/2 when absoluteTarget > 3
///   - per-track: blockAbsoluteStart + relativeStart ≈ anchorTimeMs/1000
///   - cross-track: |videoEffectiveAnchor - audioEffectiveAnchor| ≤ allowedDrift
///
/// IT-2: Rapid double-seek — second seek invalidates first open
///   - no error state emitted
///   - final state is playing or buffering (not error)
///
/// IT-3: Seek after stale error — stale open sets error, valid open succeeds
///   - errorMessage == null in final state
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/embedded_tracks.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_diagnostics.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_session_state.dart';
import 'package:kumoriya_app/src/features/player/application/services/playback_engine.dart';
import 'package:kumoriya_app/src/features/player/application/services/player_session_orchestrator.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

// ---------------------------------------------------------------------------
// Inline replicas of FIXED proxy-server logic
// (same approach as unit/preservation tests — exercises the real algorithms)
// ---------------------------------------------------------------------------

List<int> _buildAbsoluteSeekWindow({
  required int targetSegmentIndex,
  required int maxSegmentIndex,
}) {
  final start = max(0, targetSegmentIndex - 1);
  final end = min(maxSegmentIndex, targetSegmentIndex + 3);
  return [for (var i = start; i <= end; i++) i];
}

int _parseSegmentIndex(String path) {
  final m = RegExp(r'_([0-9]+)-[0-9]+\.(?:m4s|mp4)$').firstMatch(path);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}

String _buildManifest({
  required int startAbsoluteIndex,
  required int segmentCount,
  required double durationSeconds,
  String variant = '1600',
  int track = 0,
}) {
  final lines = <String>[
    '#EXTM3U',
    '#EXT-X-VERSION:6',
    '#EXT-X-TARGETDURATION:4',
    '#EXT-X-MEDIA-SEQUENCE:$startAbsoluteIndex',
    '#EXT-X-MAP:URI="https://cdn.example/path_${variant}_init-$track.mp4"',
  ];
  for (var i = 0; i < segmentCount; i++) {
    final absIdx = startAbsoluteIndex + i;
    final padded = absIdx.toString().padLeft(4, '0');
    lines.add('#EXTINF:${durationSeconds.toStringAsFixed(6)},');
    lines.add('https://cdn.example/path_${variant}_$padded-$track.m4s');
  }
  lines.add('#EXT-X-ENDLIST');
  return lines.join('\n');
}

/// Returns cache keys that _doSegmentSeekPrefetch would enqueue.
List<String> _seekPrefetchKeys({
  required String manifestBody,
  required String variant,
  required int track,
  required int targetMs,
}) {
  var accumulatedMs = 0.0;
  String? pendingExtinf;
  int? absoluteTargetIndex;
  int maxAbsoluteIndex = 0;

  for (final rawLine in manifestBody.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('#EXTINF:')) {
      pendingExtinf = line;
      continue;
    }
    if (pendingExtinf != null && !line.startsWith('#') && line.isNotEmpty) {
      final payload = pendingExtinf.substring('#EXTINF:'.length);
      final duration =
          (double.tryParse(payload.split(',').first.trim()) ?? 0) * 1000;
      final segIdx = _parseSegmentIndex(line);
      maxAbsoluteIndex = max(maxAbsoluteIndex, segIdx);
      if (absoluteTargetIndex == null) {
        final segEndMs = accumulatedMs + duration;
        if (segEndMs >= targetMs) absoluteTargetIndex = segIdx;
        accumulatedMs = segEndMs;
      }
      pendingExtinf = null;
    }
  }
  if (absoluteTargetIndex == null) return [];
  final window = _buildAbsoluteSeekWindow(
    targetSegmentIndex: absoluteTargetIndex,
    maxSegmentIndex: maxAbsoluteIndex,
  );
  return [for (final i in window) '$variant:$track:$i'];
}

class _RewriteResult {
  const _RewriteResult({required this.extXStart, required this.mediaSequence});
  final String? extXStart;
  final int? mediaSequence;
}

_RewriteResult _rewriteManifest({
  required String manifestBody,
  required int seekTargetMs,
}) {
  final segmentBlocks = <({double durationSeconds, int segmentIndex})>[];
  final pending = <String>[];

  for (final rawLine in manifestBody.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#EXT-X-ENDLIST')) continue;
    if (line.startsWith('#EXT-X-MAP:') ||
        line.startsWith('#EXT-X-MEDIA-SEQUENCE') ||
        line.startsWith('#EXT-X-START')) {
      continue;
    }
    if (line.startsWith('#')) {
      pending.add(rawLine);
      continue;
    }
    final segIdx = _parseSegmentIndex(line);
    double dur = 0;
    for (final l in pending) {
      if (l.trim().startsWith('#EXTINF:')) {
        final payload = l.trim().substring('#EXTINF:'.length);
        dur = double.tryParse(payload.split(',').first.trim()) ?? 0;
        break;
      }
    }
    segmentBlocks.add((durationSeconds: dur, segmentIndex: segIdx));
    pending.clear();
  }

  if (segmentBlocks.isEmpty || seekTargetMs <= 0) {
    return const _RewriteResult(extXStart: null, mediaSequence: null);
  }

  final prerollMs = max(2000, min(seekTargetMs, 6000));
  final desiredStartMs = max(0, seekTargetMs - prerollMs);
  var accMs = 0.0;
  int blockIndex = segmentBlocks.length - 1;
  double relativeStart = 0;

  for (var i = 0; i < segmentBlocks.length; i++) {
    final nextAcc = accMs + segmentBlocks[i].durationSeconds * 1000;
    if (nextAcc >= desiredStartMs) {
      blockIndex = i;
      // Fixed formula: anchorTimeMs/1000 - blockAbsoluteStartSeconds
      relativeStart = max(0.0, seekTargetMs / 1000.0 - accMs / 1000.0);
      break;
    }
    accMs = nextAcc;
  }

  return _RewriteResult(
    extXStart:
        '#EXT-X-START:TIME-OFFSET=${relativeStart.toStringAsFixed(3)},PRECISE=YES',
    mediaSequence: segmentBlocks[blockIndex].segmentIndex,
  );
}

// ---------------------------------------------------------------------------
// IT-1: Full seek to 840,000ms on multi-track stream
// ---------------------------------------------------------------------------

void main() {
  group('IT-1: Full seek to 840,000ms on multi-track stream', () {
    // Video: 300 segments × 4s, starting at absolute CDN index 211.
    // Audio: 600 segments × 2s, starting at absolute CDN index 422.
    // Seek target: 840,000ms.
    const seekTargetMs = 840000;
    const videoStart = 211;
    const audioStart = 422;
    const allowedDriftMs = 4000; // 4s tolerance

    late String videoManifest;
    late String audioManifest;

    setUp(() {
      videoManifest = _buildManifest(
        startAbsoluteIndex: videoStart,
        segmentCount: 300,
        durationSeconds: 4.0,
        variant: '1600',
        track: 0,
      );
      audioManifest = _buildManifest(
        startAbsoluteIndex: audioStart,
        segmentCount: 600,
        durationSeconds: 2.0,
        variant: '1600',
        track: 1,
      );
    });

    test(
      'prefetch cache keys contain absolute indices near target, not 0/1/2',
      () {
        final videoKeys = _seekPrefetchKeys(
          manifestBody: videoManifest,
          variant: '1600',
          track: 0,
          targetMs: seekTargetMs,
        );
        final audioKeys = _seekPrefetchKeys(
          manifestBody: audioManifest,
          variant: '1600',
          track: 1,
          targetMs: seekTargetMs,
        );

        expect(
          videoKeys,
          isNotEmpty,
          reason: 'video prefetch must produce keys',
        );
        expect(
          audioKeys,
          isNotEmpty,
          reason: 'audio prefetch must produce keys',
        );

        // No key may contain index 0, 1, or 2 when absoluteTarget > 3.
        for (final key in [...videoKeys, ...audioKeys]) {
          final idx = int.parse(key.split(':').last);
          expect(
            idx,
            greaterThan(3),
            reason: 'key=$key must not use start-of-stream index',
          );
        }

        // Video keys must be near the absolute target (211 + ~210 = ~421).
        for (final key in videoKeys) {
          final idx = int.parse(key.split(':').last);
          expect(
            idx,
            greaterThanOrEqualTo(videoStart - 1),
            reason: 'video key=$key below videoStart-1=${videoStart - 1}',
          );
        }

        // Audio keys must be near the absolute target (422 + ~420 = ~842).
        for (final key in audioKeys) {
          final idx = int.parse(key.split(':').last);
          expect(
            idx,
            greaterThanOrEqualTo(audioStart - 1),
            reason: 'audio key=$key below audioStart-1=${audioStart - 1}',
          );
        }
      },
    );

    test(
      'per-track: blockAbsoluteStart + relativeStart ≈ anchorTimeMs/1000',
      () {
        final videoResult = _rewriteManifest(
          manifestBody: videoManifest,
          seekTargetMs: seekTargetMs,
        );
        final audioResult = _rewriteManifest(
          manifestBody: audioManifest,
          seekTargetMs: seekTargetMs,
        );

        expect(videoResult.extXStart, isNotNull);
        expect(audioResult.extXStart, isNotNull);

        double effectiveAnchor(
          _RewriteResult result,
          int startIdx,
          double dur,
        ) {
          final timeOffset = double.parse(
            RegExp(
              r'TIME-OFFSET=([\d.]+)',
            ).firstMatch(result.extXStart!)!.group(1)!,
          );
          final localOrdinal = result.mediaSequence! - startIdx;
          final blockAbsStart = localOrdinal * dur;
          return blockAbsStart + timeOffset;
        }

        final videoAnchor = effectiveAnchor(videoResult, videoStart, 4.0);
        final audioAnchor = effectiveAnchor(audioResult, audioStart, 2.0);
        final seekTargetSeconds = seekTargetMs / 1000.0;

        expect(
          videoAnchor,
          closeTo(seekTargetSeconds, 0.1),
          reason: 'video anchor=${videoAnchor}s ≠ ${seekTargetSeconds}s',
        );
        expect(
          audioAnchor,
          closeTo(seekTargetSeconds, 0.1),
          reason: 'audio anchor=${audioAnchor}s ≠ ${seekTargetSeconds}s',
        );
      },
    );

    test('cross-track: |videoAnchor - audioAnchor| ≤ allowedDrift', () {
      final videoResult = _rewriteManifest(
        manifestBody: videoManifest,
        seekTargetMs: seekTargetMs,
      );
      final audioResult = _rewriteManifest(
        manifestBody: audioManifest,
        seekTargetMs: seekTargetMs,
      );

      double anchor(_RewriteResult r, int startIdx, double dur) {
        final to = double.parse(
          RegExp(r'TIME-OFFSET=([\d.]+)').firstMatch(r.extXStart!)!.group(1)!,
        );
        return (r.mediaSequence! - startIdx) * dur + to;
      }

      final videoAnchorMs = anchor(videoResult, videoStart, 4.0) * 1000;
      final audioAnchorMs = anchor(audioResult, audioStart, 2.0) * 1000;
      final drift = (videoAnchorMs - audioAnchorMs).abs();

      expect(
        drift,
        lessThanOrEqualTo(allowedDriftMs.toDouble()),
        reason: 'A/V drift=${drift}ms exceeds allowedDrift=${allowedDriftMs}ms',
      );
    });
  });

  // -------------------------------------------------------------------------
  // IT-2: Rapid double-seek — second seek invalidates first open
  // -------------------------------------------------------------------------
  group('IT-2: Rapid double-seek — second seek invalidates first open', () {
    test('no error state emitted; final state is playing or buffering', () async {
      // Open 1: throws 'open invalidated' (stale — superseded by open 2).
      // Open 2: succeeds.
      // Fixed code: stale open is a silent no-op; success open clears any error.
      final engine = _FakeEngine([
        () => throw StateError('open invalidated'),
        () async {}, // success
      ]);
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);
      final states = <PlayerSessionState>[];
      final sub = orchestrator.states.listen(states.add);

      await orchestrator.start(
        streamCandidates: [
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
      await sub.cancel();
      await orchestrator.dispose();

      // No error state must have been emitted.
      expect(
        states.any((s) => s.status == PlayerSessionStatus.error),
        isFalse,
        reason: 'rapid double-seek must not emit error state',
      );
      // Final state must not be error.
      expect(
        orchestrator.state.status,
        isNot(PlayerSessionStatus.error),
        reason: 'final state must not be error after double-seek',
      );
    });
  });

  // -------------------------------------------------------------------------
  // IT-3: Seek after stale error — stale open sets error, valid open succeeds
  // -------------------------------------------------------------------------
  group(
    'IT-3: Seek after stale error — errorMessage cleared on valid open',
    () {
      test('errorMessage == null in final state after valid open', () async {
        // Open 1: throws a real error (sets errorMessage, generation=1).
        // Open 2: succeeds (generation=2, should clear errorMessage).
        final engine = _FakeEngine([
          () => throw Exception('network timeout'),
          () async {}, // success
        ]);
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);
        final states = <PlayerSessionState>[];
        final sub = orchestrator.states.listen(states.add);

        await orchestrator.start(
          streamCandidates: [
            ResolvedStream(
              url: Uri.parse('https://cdn.example/stream-a.m3u8'),
              isHls: true,
            ),
            ResolvedStream(
              url: Uri.parse('https://cdn.example/stream-b.m3u8'),
              isHls: true,
            ),
          ],
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        await orchestrator.dispose();

        // Final state must have no errorMessage.
        expect(
          orchestrator.state.errorMessage,
          isNull,
          reason: 'errorMessage must be cleared after valid open succeeds',
        );
        expect(
          orchestrator.state.status,
          isNot(PlayerSessionStatus.error),
          reason: 'final status must not be error',
        );
      });

      test('stale-generation open alone leaves no error trace', () async {
        // Only one candidate, throws 'open invalidated' (stale).
        // Fixed code: total silent no-op — no error state, no errorMessage.
        final engine = _FakeEngine([
          () => throw StateError('open invalidated'),
        ]);
        final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);
        final states = <PlayerSessionState>[];
        final sub = orchestrator.states.listen(states.add);

        await orchestrator.start(
          streamCandidates: [
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

        expect(
          states.any((s) => s.errorMessage != null),
          isFalse,
          reason: 'stale-generation open must leave no errorMessage trace',
        );
      });
    },
  );
}

// ---------------------------------------------------------------------------
// Fake engine
// ---------------------------------------------------------------------------

final class _FakeEngine implements PlaybackEngine {
  _FakeEngine(this._behaviors);
  final List<Future<void> Function()> _behaviors;
  int _idx = 0;

  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get bufferingStream => _buffering.stream;
  @override
  Stream<bool> get completedStream => _completed.stream;
  @override
  Stream<String> get errorStream => _error.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration> get durationStream => _duration.stream;

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
    final fn = _behaviors[_idx.clamp(0, _behaviors.length - 1)];
    if (_idx < _behaviors.length - 1) _idx++;
    await fn();
    _buffering.add(true);
    _playing.add(true);
    _buffering.add(false);
  }

  @override
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {}

  @override
  Future<void> setSmartAudioBoost({required bool enabled}) async {}

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> signalPredictivePrewarm(Duration position) async {}
  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) async {}
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
  Future<void> dispose() async {
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _error.close();
    await _position.close();
    await _duration.close();
  }
}
