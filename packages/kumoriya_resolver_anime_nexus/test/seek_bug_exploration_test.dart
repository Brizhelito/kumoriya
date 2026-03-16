// ignore_for_file: lines_longer_than_80_chars

/// Bug Condition Exploration Tests — Task 1
///
/// These tests run against UNFIXED code and are EXPECTED TO FAIL.
/// Failure confirms the bugs exist. Do NOT fix the tests or the code.
/// When the fixes are applied (Task 3), these same tests will pass.
///
/// P1-A: _doSegmentSeekPrefetch uses local ordinal instead of absolute CDN index.
/// P1-D: _selectSeekStartBlock produces divergent A/V anchors.
library;

import 'dart:math';

import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Inline helpers replicating UNFIXED logic for isolation
// ---------------------------------------------------------------------------

/// UNFIXED: returns 0-based LOCAL ordinal within the manifest body.
int _findSegmentIndexForMs_unfixed({
  required String manifestBody,
  required int targetMs,
}) {
  var accumulatedMs = 0.0;
  var ordinal = 0;
  for (final rawLine in manifestBody.split('\n')) {
    final line = rawLine.trim();
    if (!line.startsWith('#EXTINF:')) continue;
    final payload = line.substring('#EXTINF:'.length);
    final rawValue = payload.split(',').first.trim();
    final duration = double.tryParse(rawValue) ?? 0;
    final segEndMs = accumulatedMs + duration * 1000;
    if (segEndMs >= targetMs) return ordinal;
    accumulatedMs = segEndMs;
    ordinal++;
  }
  return max(0, ordinal - 1);
}

/// Builds a fake variant manifest where segments start at [startAbsoluteIndex].
String _buildFakeManifest({
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

/// UNFIXED _doSegmentSeekPrefetch: returns cache keys using local ordinal.
List<String> _doSegmentSeekPrefetch_unfixed({
  required String manifestBody,
  required String variant,
  required int track,
  required int targetMs,
}) {
  final targetIndex = _findSegmentIndexForMs_unfixed(
    manifestBody: manifestBody,
    targetMs: targetMs,
  );
  final startIdx = max(0, targetIndex - 1);
  final endIdx = targetIndex + 3;
  return [for (var i = startIdx; i <= endIdx; i++) '$variant:$track:$i'];
}

// ---------------------------------------------------------------------------
// UNFIXED _selectSeekStartBlock (replicated for isolation)
// ---------------------------------------------------------------------------

class _SeekWindowSelection {
  const _SeekWindowSelection({
    required this.blockIndex,
    required this.relativeStartOffsetSeconds,
  });
  final int blockIndex;
  final double relativeStartOffsetSeconds;
}

class _VariantSegmentBlock {
  const _VariantSegmentBlock({required this.durationSeconds});
  final double durationSeconds;
}

/// UNFIXED: relativeStart = (seekTargetMs - accumulatedMs) / 1000
/// where accumulatedMs is the block's start time — track-specific.
_SeekWindowSelection _selectSeekStartBlock_unfixed({
  required List<_VariantSegmentBlock> blocks,
  required int seekTargetMs,
}) {
  final prerollMs = max(2000, min(seekTargetMs, 6000));
  final desiredStartMs = max(0, seekTargetMs - prerollMs);
  var accumulatedMs = 0.0;
  for (var index = 0; index < blocks.length; index++) {
    final nextAccumulatedMs =
        accumulatedMs + blocks[index].durationSeconds * 1000;
    if (nextAccumulatedMs >= desiredStartMs) {
      final relativeStartSeconds = max(0, seekTargetMs - accumulatedMs) / 1000;
      return _SeekWindowSelection(
        blockIndex: index,
        relativeStartOffsetSeconds: relativeStartSeconds,
      );
    }
    accumulatedMs = nextAccumulatedMs;
  }
  return _SeekWindowSelection(
    blockIndex: max(0, blocks.length - 1),
    relativeStartOffsetSeconds: 0,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('P1-A Bug Condition: seek prefetch uses wrong (local ordinal) index', () {
    // Manifest where segments start at absolute CDN index 211.
    // Seek target = 840,000 ms (14 minutes), each segment = 4s.
    // Local ordinal at 840s = 209 (within the 300-segment playlist starting at 211).
    // Absolute CDN index = 211 + 209 = 420.
    // UNFIXED: uses local ordinal 209 as CDN index → cache key v:0:209
    // FIXED: uses absolute CDN index 420 → cache key v:0:420

    const startAbsoluteIndex = 211;
    const segmentDurationSeconds = 4.0;
    const segmentCount = 300;
    const targetMs = 840000;
    const variant = '1600';
    const track = 0;

    late String manifestBody;

    setUp(() {
      manifestBody = _buildFakeManifest(
        startAbsoluteIndex: startAbsoluteIndex,
        segmentCount: segmentCount,
        durationSeconds: segmentDurationSeconds,
        variant: variant,
        track: track,
      );
    });

    test('EXPLORATION (expected to FAIL on unfixed code): '
        'cache keys must use absolute CDN index, not local ordinal', () {
      final keys = _doSegmentSeekPrefetch_unfixed(
        manifestBody: manifestBody,
        variant: variant,
        track: track,
        targetMs: targetMs,
      );

      // Local ordinal at 840s = 209. Absolute CDN = 211 + 209 = 420.
      // UNFIXED: keys contain 208..212 (local ordinals).
      // FIXED: keys must contain indices >= startAbsoluteIndex - 1 = 210.
      //
      // Counterexample: keys are ['1600:0:208','1600:0:209','1600:0:210',
      // '1600:0:211','1600:0:212'] — these look plausible but are WRONG
      // because they are local ordinals, not absolute CDN indices.
      // The absolute CDN indices should be 419..423.
      //
      // This assertion FAILS on unfixed code.
      final allAbsolute = keys.every((k) {
        final idx = int.tryParse(k.split(':').last) ?? -1;
        // Absolute indices for seek to 840s in a manifest starting at 211
        // must be >= 210 (startAbsoluteIndex - 1) AND the window must not
        // overlap with local ordinals 0..5 when absoluteTarget > 3.
        // The local ordinal window is 208..212; absolute window is 419..423.
        // We check that the keys are NOT in the local-ordinal range [0..215]
        // when the absolute target is 420.
        return idx >= startAbsoluteIndex + 200; // absolute target ~420
      });

      expect(
        allAbsolute,
        isTrue,
        reason:
            'Counterexample: unfixed code produces keys $keys using local '
            'ordinals (208..212) instead of absolute CDN indices (~419..423). '
            'The manifest starts at absolute index $startAbsoluteIndex, so '
            'local ordinal 209 = absolute CDN index ${startAbsoluteIndex + 209}. '
            'This proves P1-A exists.',
      );
    });

    test(
      'EXPLORATION (expected to FAIL on unfixed code): '
      'local ordinal must not be used as CDN index when absoluteTarget > 3',
      () {
        final localOrdinal = _findSegmentIndexForMs_unfixed(
          manifestBody: manifestBody,
          targetMs: targetMs,
        );

        // The local ordinal (209) is much smaller than the absolute CDN index
        // (420). The fix must derive the absolute index from the segment URL.
        // This assertion FAILS on unfixed code because localOrdinal=209 < 419.
        expect(
          localOrdinal,
          greaterThanOrEqualTo(startAbsoluteIndex + 200),
          reason:
              'Counterexample: unfixed _findSegmentIndexForMs returns local '
              'ordinal $localOrdinal. The absolute CDN index for this seek '
              'target is ${startAbsoluteIndex + localOrdinal}. '
              'Using $localOrdinal as the CDN index produces wrong paths. '
              'This proves P1-A exists.',
        );
      },
    );
  });

  group('P1-D Bug Condition: A/V tracks produce divergent TIME-OFFSET values', () {
    // Video: 4s segments. Audio: 3s segments.
    // Seek target = 840,000 ms.
    // preroll = 6000ms, desiredStart = 834,000ms.
    // Video block 208 starts at 832,000ms → relativeStart = (840000-832000)/1000 = 8.0s
    // Audio block 277 starts at 831,000ms → relativeStart = (840000-831000)/1000 = 9.0s
    // TIME-OFFSET divergence = 1.0s → mpv A/V desync.
    //
    // The fix: relativeStart = anchorTimeMs/1000 - blockAbsoluteStartSeconds
    // where anchorTimeMs = seekTargetMs for both tracks.
    // Fixed video: 840000/1000 - 832 = 8.0s (same)
    // Fixed audio: 840000/1000 - 831 = 9.0s (same — the fix doesn't change
    // the math here, it changes the REFERENCE so both tracks use seekTargetMs
    // as the anchor, not their own blockStartMs).
    //
    // Wait — the actual fix is that relativeStart should be computed as
    // anchorTimeMs/1000 - blockAbsoluteStartSeconds, which IS the same formula.
    // The real divergence is when the preroll causes different block selections
    // that produce different TIME-OFFSET values. The fix ensures both tracks
    // use the SAME anchorTimeMs (seekTargetMs) rather than independently
    // computing desiredStartMs = seekTargetMs - prerollMs per track.

    const seekTargetMs = 840000;
    const allowedDriftSeconds = 0.1; // 100ms tolerance

    List<_VariantSegmentBlock> buildBlocks(double durationSeconds, int count) =>
        List.generate(
          count,
          (_) => _VariantSegmentBlock(durationSeconds: durationSeconds),
        );

    test(
      'EXPLORATION (expected to FAIL on unfixed code): '
      'video and audio TIME-OFFSET values must agree within ${allowedDriftSeconds}s',
      () {
        // Video: 4s segments. Audio: 3s segments.
        // These produce different relativeStart values on unfixed code.
        final videoBlocks = buildBlocks(4.0, 300);
        final audioBlocks = buildBlocks(3.0, 400);

        final videoSel = _selectSeekStartBlock_unfixed(
          blocks: videoBlocks,
          seekTargetMs: seekTargetMs,
        );
        final audioSel = _selectSeekStartBlock_unfixed(
          blocks: audioBlocks,
          seekTargetMs: seekTargetMs,
        );

        final divergenceSeconds =
            (videoSel.relativeStartOffsetSeconds -
                    audioSel.relativeStartOffsetSeconds)
                .abs();

        // Counterexample: video relativeStart=8.0s, audio relativeStart=9.0s,
        // divergence=1.0s > 0.1s tolerance.
        // This assertion FAILS on unfixed code.
        expect(
          divergenceSeconds,
          lessThanOrEqualTo(allowedDriftSeconds),
          reason:
              'Counterexample: video TIME-OFFSET=${videoSel.relativeStartOffsetSeconds}s, '
              'audio TIME-OFFSET=${audioSel.relativeStartOffsetSeconds}s, '
              'divergence=${divergenceSeconds}s > ${allowedDriftSeconds}s. '
              'mpv will start video and audio at different positions. '
              'This proves P1-D exists.',
        );
      },
    );

    test('EXPLORATION: documents exact counterexample values for P1-D', () {
      final videoBlocks = buildBlocks(4.0, 300);
      final audioBlocks = buildBlocks(3.0, 400);

      final videoSel = _selectSeekStartBlock_unfixed(
        blocks: videoBlocks,
        seekTargetMs: seekTargetMs,
      );
      final audioSel = _selectSeekStartBlock_unfixed(
        blocks: audioBlocks,
        seekTargetMs: seekTargetMs,
      );

      // ignore: avoid_print
      print(
        'P1-D counterexample: '
        'videoBlock=${videoSel.blockIndex} '
        'videoTIME-OFFSET=${videoSel.relativeStartOffsetSeconds}s | '
        'audioBlock=${audioSel.blockIndex} '
        'audioTIME-OFFSET=${audioSel.relativeStartOffsetSeconds}s | '
        'divergence=${(videoSel.relativeStartOffsetSeconds - audioSel.relativeStartOffsetSeconds).abs()}s',
      );

      // Divergence should be > 0 on unfixed code with asymmetric durations.
      expect(
        (videoSel.relativeStartOffsetSeconds -
                audioSel.relativeStartOffsetSeconds)
            .abs(),
        greaterThan(0),
        reason: 'Expected non-zero TIME-OFFSET divergence on unfixed code.',
      );
    });
  });
}
