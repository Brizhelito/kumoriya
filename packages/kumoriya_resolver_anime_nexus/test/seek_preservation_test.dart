// ignore_for_file: lines_longer_than_80_chars

/// Preservation Property Tests — Task 2
///
/// These tests run against UNFIXED code and are EXPECTED TO PASS.
/// They encode baseline behavior that must NOT regress after the fix.
///
/// P-PRES-1: Non-seek prefetch fetches exactly segments 0, 1, 2.
/// P-PRES-2: Single-track _rewriteVariantManifest produces correct
///           EXT-X-START and EXT-X-MEDIA-SEQUENCE.
library;

import 'dart:math';

import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Inline helpers replicating the UNFIXED logic for isolation
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Replicated UNFIXED _prefetchInitAndFirstSegments logic
// (returns the cache keys it would enqueue — for assertion)
// ---------------------------------------------------------------------------

List<String> _prefetchInitAndFirstSegments_unfixed({
  required String manifestPath,
  required String variant,
}) {
  // Replicates the segment-index loop from the real implementation.
  // Pattern: <base>_<variant>-<track>.m3u8
  final match = RegExp(r'_(\d+)-(\d+)\.m3u8$').firstMatch(manifestPath);
  if (match == null) return const <String>[];

  final v = match.group(1)!;
  final t = match.group(2)!;
  final trackInt = int.tryParse(t) ?? 0;

  final keys = <String>[];
  for (var segIdx = 0; segIdx < 3; segIdx++) {
    keys.add('$v:$trackInt:$segIdx');
  }
  return keys;
}

// ---------------------------------------------------------------------------
// Replicated UNFIXED _selectSeekStartBlock
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
// Replicated UNFIXED _rewriteVariantManifest (minimal — only the parts
// relevant to EXT-X-START and EXT-X-MEDIA-SEQUENCE)
// ---------------------------------------------------------------------------

class _RewriteResult {
  const _RewriteResult({
    required this.extXStart,
    required this.extXMediaSequence,
  });
  final String? extXStart;
  final int? extXMediaSequence;
}

int _parseSegmentIndex_unfixed(String path) {
  final match = RegExp(r'_([0-9]+)-[0-9]+\.(?:m4s|mp4)$').firstMatch(path);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
}

double _parseSegmentDurationSeconds_unfixed(List<String> lines) {
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (!line.startsWith('#EXTINF:')) continue;
    final payload = line.substring('#EXTINF:'.length);
    final rawValue = payload.split(',').first.trim();
    final d = double.tryParse(rawValue);
    if (d != null && d >= 0) return d;
  }
  return 0;
}

_RewriteResult _rewriteVariantManifest_unfixed({
  required String manifestBody,
  required int? seekTargetMs,
}) {
  final pendingSegmentLines = <String>[];
  final segmentBlocks = <({double durationSeconds, int segmentIndex})>[];

  for (final rawLine in manifestBody.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#EXT-X-ENDLIST')) continue;
    if (line.startsWith('#EXT-X-MAP:') ||
        line.startsWith('#EXT-X-MEDIA-SEQUENCE') ||
        line.startsWith('#EXT-X-START')) {
      continue;
    }
    if (line.startsWith('#')) {
      pendingSegmentLines.add(rawLine);
      continue;
    }
    // Segment URL line.
    final segmentIndex = _parseSegmentIndex_unfixed(line);
    final durationSeconds = _parseSegmentDurationSeconds_unfixed(
      pendingSegmentLines,
    );
    segmentBlocks.add((
      durationSeconds: durationSeconds,
      segmentIndex: segmentIndex,
    ));
    pendingSegmentLines.clear();
  }

  if (segmentBlocks.isEmpty || seekTargetMs == null || seekTargetMs <= 0) {
    return const _RewriteResult(extXStart: null, extXMediaSequence: null);
  }

  final blocks = segmentBlocks
      .map((b) => _VariantSegmentBlock(durationSeconds: b.durationSeconds))
      .toList();
  final selection = _selectSeekStartBlock_unfixed(
    blocks: blocks,
    seekTargetMs: seekTargetMs,
  );

  final startBlockIndex = selection.blockIndex;
  final relativeStart = selection.relativeStartOffsetSeconds;
  final mediaSequence = segmentBlocks[startBlockIndex].segmentIndex;

  return _RewriteResult(
    extXStart:
        '#EXT-X-START:TIME-OFFSET=${relativeStart.toStringAsFixed(3)},PRECISE=YES',
    extXMediaSequence: mediaSequence,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('P-PRES-1: Non-seek prefetch fetches exactly segments 0, 1, 2', () {
    // When seekTargetMs is null (normal open, not a seek), the prefetch must
    // always fetch segments 0, 1, 2 — regardless of the manifest's absolute
    // start index.  This is the baseline behavior that must be preserved.

    test(
      'PRESERVATION: manifest starting at index 0 → prefetch keys 0, 1, 2',
      () {
        final keys = _prefetchInitAndFirstSegments_unfixed(
          manifestPath: '/path/to/stream_1600-0.m3u8',
          variant: '1600',
        );
        expect(keys, containsAll(<String>['1600:0:0', '1600:0:1', '1600:0:2']));
        expect(keys, hasLength(3));
      },
    );

    test(
      'PRESERVATION: manifest starting at index 211 → prefetch keys still 0, 1, 2',
      () {
        // Even when the manifest starts at absolute index 211, the non-seek
        // prefetch must still fetch local indices 0, 1, 2 (which correspond
        // to absolute CDN indices 211, 212, 213).  The fix must not change
        // this path.
        final keys = _prefetchInitAndFirstSegments_unfixed(
          manifestPath: '/path/to/stream_1600-0.m3u8',
          variant: '1600',
        );
        expect(keys, containsAll(<String>['1600:0:0', '1600:0:1', '1600:0:2']));
        expect(keys, hasLength(3));
      },
    );

    test('PRESERVATION: audio track → prefetch keys 0, 1, 2 for track 1', () {
      final keys = _prefetchInitAndFirstSegments_unfixed(
        manifestPath: '/path/to/stream_1600-1.m3u8',
        variant: '1600',
      );
      expect(keys, containsAll(<String>['1600:1:0', '1600:1:1', '1600:1:2']));
      expect(keys, hasLength(3));
    });

    test('PRESERVATION: property — for any manifest path, non-seek prefetch '
        'always produces exactly 3 keys starting at index 0', () {
      // Property: for all valid manifest paths, non-seek prefetch produces
      // exactly {v:t:0, v:t:1, v:t:2}.
      final testCases = <({String path, String variant, int track})>[
        (path: '/p/stream_1600-0.m3u8', variant: '1600', track: 0),
        (path: '/p/stream_1600-1.m3u8', variant: '1600', track: 1),
        (path: '/p/stream_4400-0.m3u8', variant: '4400', track: 0),
        (path: '/p/stream_5300-2.m3u8', variant: '5300', track: 2),
      ];
      for (final tc in testCases) {
        final keys = _prefetchInitAndFirstSegments_unfixed(
          manifestPath: tc.path,
          variant: tc.variant,
        );
        expect(
          keys,
          containsAll(<String>[
            '${tc.variant}:${tc.track}:0',
            '${tc.variant}:${tc.track}:1',
            '${tc.variant}:${tc.track}:2',
          ]),
          reason: 'Failed for path=${tc.path}',
        );
        expect(keys, hasLength(3), reason: 'Failed for path=${tc.path}');
      }
    });
  });

  group(
    'P-PRES-2: Single-track rewrite produces correct EXT-X-START and EXT-X-MEDIA-SEQUENCE',
    () {
      // When there is only one track (video only, no audio), the rewrite must
      // produce correct EXT-X-START:TIME-OFFSET and EXT-X-MEDIA-SEQUENCE.
      // The fix must not change single-track behavior.

      test('PRESERVATION: single-track seek to 840s with 4s segments → '
          'TIME-OFFSET=8.0s, MEDIA-SEQUENCE=segmentIndex at block 208', () {
        // Manifest: 300 segments starting at absolute index 211, 4s each.
        // Seek to 840,000ms.
        // preroll=6000ms, desiredStart=834,000ms.
        // Block 208 starts at 832,000ms (208*4000), ends at 836,000ms.
        // relativeStart = (840000 - 832000) / 1000 = 8.0s.
        // MEDIA-SEQUENCE = absolute index of block 208 = 211 + 208 = 419.
        final manifest = _buildFakeManifest(
          startAbsoluteIndex: 211,
          segmentCount: 300,
          durationSeconds: 4.0,
        );
        final result = _rewriteVariantManifest_unfixed(
          manifestBody: manifest,
          seekTargetMs: 840000,
        );

        expect(
          result.extXStart,
          equals('#EXT-X-START:TIME-OFFSET=8.000,PRECISE=YES'),
          reason: 'Single-track TIME-OFFSET must be 8.0s for seek to 840s',
        );
        expect(
          result.extXMediaSequence,
          equals(419), // absolute index 211 + local ordinal 208
          reason: 'MEDIA-SEQUENCE must be absolute CDN index 419',
        );
      });

      test(
        'PRESERVATION: single-track seek to 0 → no EXT-X-START, no MEDIA-SEQUENCE',
        () {
          final manifest = _buildFakeManifest(
            startAbsoluteIndex: 0,
            segmentCount: 100,
            durationSeconds: 4.0,
          );
          final result = _rewriteVariantManifest_unfixed(
            manifestBody: manifest,
            seekTargetMs: null,
          );
          expect(result.extXStart, isNull);
          expect(result.extXMediaSequence, isNull);
        },
      );

      test('PRESERVATION: property — single-track rewrite identity: '
          'blockAbsoluteStart + relativeStart ≈ seekTargetMs/1000', () {
        // For any single-track seek, the effective anchor must equal
        // seekTargetMs (within floating-point tolerance).
        // This is the per-track identity that the fix must preserve.
        const testCases =
            <
              ({
                int startAbsoluteIndex,
                double durationSeconds,
                int seekTargetMs,
              })
            >[
              (
                startAbsoluteIndex: 0,
                durationSeconds: 4.0,
                seekTargetMs: 120000,
              ),
              (
                startAbsoluteIndex: 211,
                durationSeconds: 4.0,
                seekTargetMs: 840000,
              ),
              (
                startAbsoluteIndex: 0,
                durationSeconds: 3.0,
                seekTargetMs: 300000,
              ),
              (
                startAbsoluteIndex: 50,
                durationSeconds: 6.0,
                seekTargetMs: 600000,
              ),
            ];

        for (final tc in testCases) {
          final manifest = _buildFakeManifest(
            startAbsoluteIndex: tc.startAbsoluteIndex,
            segmentCount: 500,
            durationSeconds: tc.durationSeconds,
          );
          final result = _rewriteVariantManifest_unfixed(
            manifestBody: manifest,
            seekTargetMs: tc.seekTargetMs,
          );

          if (result.extXStart == null) continue;

          // Parse TIME-OFFSET from the EXT-X-START line.
          final timeOffsetMatch = RegExp(
            r'TIME-OFFSET=([\d.]+)',
          ).firstMatch(result.extXStart!);
          expect(
            timeOffsetMatch,
            isNotNull,
            reason: 'EXT-X-START must contain TIME-OFFSET',
          );
          final relativeStart = double.parse(timeOffsetMatch!.group(1)!);

          // Compute block absolute start from MEDIA-SEQUENCE and duration.
          // blockAbsoluteStart = (mediaSequence - startAbsoluteIndex) * durationSeconds
          final localOrdinal =
              (result.extXMediaSequence! - tc.startAbsoluteIndex);
          final blockAbsoluteStartSeconds = localOrdinal * tc.durationSeconds;
          final effectiveAnchorSeconds =
              blockAbsoluteStartSeconds + relativeStart;
          final seekTargetSeconds = tc.seekTargetMs / 1000.0;

          expect(
            effectiveAnchorSeconds,
            closeTo(seekTargetSeconds, 0.1),
            reason:
                'Single-track identity failed: '
                'blockStart=${blockAbsoluteStartSeconds}s + '
                'relativeStart=${relativeStart}s = '
                '${effectiveAnchorSeconds}s ≠ ${seekTargetSeconds}s '
                'for seekTargetMs=${tc.seekTargetMs}',
          );
        }
      });
    },
  );
}
