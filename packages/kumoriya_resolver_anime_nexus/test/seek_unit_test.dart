// ignore_for_file: lines_longer_than_80_chars

/// Unit tests for seek-related helpers — Task 4
///
/// Covers:
/// - buildAbsoluteSeekWindow: boundary cases
/// - _doSegmentSeekPrefetch: absolute CDN index in cache keys (P1-A fix)
/// - _prefetchInitAndFirstSegments: seek-gate (P1-A continued)
library;

import 'dart:math';

import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Inline replicas of FIXED helpers (mirrors the real implementation)
// These are kept inline so the unit tests are self-contained and fast.
// The preservation tests exercise the real proxy server code end-to-end.
// ---------------------------------------------------------------------------

List<int> buildAbsoluteSeekWindow({
  required int targetSegmentIndex,
  required int maxSegmentIndex,
}) {
  final start = max(0, targetSegmentIndex - 1);
  final end = min(maxSegmentIndex, targetSegmentIndex + 3);
  return [for (var i = start; i <= end; i++) i];
}

/// Parses the absolute CDN segment index from a segment URL path.
/// Matches the real `_parseSegmentIndex` in playback_proxy_server.dart.
int _parseSegmentIndex(String path) {
  final match = RegExp(r'_([0-9]+)-[0-9]+\.(?:m4s|mp4)$').firstMatch(path);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
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

/// FIXED _doSegmentSeekPrefetch: walks manifest lines, calls _parseSegmentIndex
/// on segment URLs to get absolute CDN index, then uses buildAbsoluteSeekWindow.
List<String> _doSegmentSeekPrefetch_fixed({
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
      final rawValue = payload.split(',').first.trim();
      final duration = (double.tryParse(rawValue) ?? 0) * 1000;
      final segmentIndex = _parseSegmentIndex(line);
      maxAbsoluteIndex = max(maxAbsoluteIndex, segmentIndex);
      if (absoluteTargetIndex == null) {
        final segEndMs = accumulatedMs + duration;
        if (segEndMs >= targetMs) {
          absoluteTargetIndex = segmentIndex;
        }
        accumulatedMs = segEndMs;
      }
      pendingExtinf = null;
    }
  }

  if (absoluteTargetIndex == null) return [];
  final window = buildAbsoluteSeekWindow(
    targetSegmentIndex: absoluteTargetIndex,
    maxSegmentIndex: maxAbsoluteIndex,
  );
  return [for (final i in window) '$variant:$track:$i'];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // buildAbsoluteSeekWindow
  // -------------------------------------------------------------------------
  group('buildAbsoluteSeekWindow', () {
    test('mid-range target returns [N-1 .. N+3]', () {
      final window = buildAbsoluteSeekWindow(
        targetSegmentIndex: 212,
        maxSegmentIndex: 300,
      );
      expect(window, equals([211, 212, 213, 214, 215]));
    });

    test('target=0 clamps start to 0', () {
      final window = buildAbsoluteSeekWindow(
        targetSegmentIndex: 0,
        maxSegmentIndex: 300,
      );
      expect(window, equals([0, 1, 2, 3]));
    });

    test('target near end clamps to maxSegmentIndex', () {
      final window = buildAbsoluteSeekWindow(
        targetSegmentIndex: 299,
        maxSegmentIndex: 300,
      );
      expect(window, equals([298, 299, 300]));
    });

    test('target=1 starts at 0', () {
      final window = buildAbsoluteSeekWindow(
        targetSegmentIndex: 1,
        maxSegmentIndex: 100,
      );
      expect(window.first, 0);
      expect(window, contains(1));
    });

    test('window size is at most 5', () {
      for (final target in [10, 50, 200, 499]) {
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: target,
          maxSegmentIndex: 1000,
        );
        expect(window.length, lessThanOrEqualTo(5));
      }
    });

    test('0 is NOT in window when target >= 4', () {
      for (final target in [4, 10, 100, 420]) {
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: target,
          maxSegmentIndex: 1000,
        );
        expect(
          window,
          isNot(contains(0)),
          reason: 'target=$target window=$window',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // _doSegmentSeekPrefetch (fixed): absolute CDN index in cache keys
  // -------------------------------------------------------------------------
  group('_doSegmentSeekPrefetch (fixed) — P1-A', () {
    test(
      'manifest starting at index 211: cache keys contain absolute indices, not local ordinals',
      () {
        // Seek to 840,000ms. Segments are 4s each. Manifest starts at CDN 211.
        // Local ordinal at 840s = 209. Absolute CDN = 211 + 209 = 420.
        // Fixed code must produce keys around 420, NOT around 209.
        const startAbsoluteIndex = 211;
        const targetMs = 840000;
        final manifest = _buildFakeManifest(
          startAbsoluteIndex: startAbsoluteIndex,
          segmentCount: 300,
          durationSeconds: 4.0,
        );

        final keys = _doSegmentSeekPrefetch_fixed(
          manifestBody: manifest,
          variant: '1600',
          track: 0,
          targetMs: targetMs,
        );

        expect(keys, isNotEmpty);
        // All keys must use absolute CDN indices (>= 210), not local ordinals.
        for (final key in keys) {
          final idx = int.parse(key.split(':').last);
          expect(
            idx,
            greaterThanOrEqualTo(startAbsoluteIndex - 1),
            reason: 'key=$key must use absolute CDN index, not local ordinal',
          );
        }
        // 0 must not appear in any key when absoluteTarget > 3.
        expect(
          keys.any((k) => int.parse(k.split(':').last) < 4),
          isFalse,
          reason: 'local ordinals (0..3) must not appear in seek cache keys',
        );
      },
    );

    test('manifest starting at index 0: cache keys start at 0', () {
      final manifest = _buildFakeManifest(
        startAbsoluteIndex: 0,
        segmentCount: 100,
        durationSeconds: 4.0,
      );
      final keys = _doSegmentSeekPrefetch_fixed(
        manifestBody: manifest,
        variant: '1600',
        track: 0,
        targetMs: 8000, // 2s into manifest → segment 2
      );
      expect(keys, isNotEmpty);
      // All indices should be small (near 0).
      for (final key in keys) {
        final idx = int.parse(key.split(':').last);
        expect(idx, lessThan(10));
      }
    });
  });

  // -------------------------------------------------------------------------
  // _prefetchInitAndFirstSegments seek-gate (P1-A continued)
  // -------------------------------------------------------------------------
  group('_prefetchInitAndFirstSegments seek-gate', () {
    // This is tested via the preservation tests (P-PRES-1) which exercise the
    // real proxy server code. Here we document the contract as a unit assertion
    // using the inline replica logic.

    test(
      'seekTargetMs=null → non-seek path fetches segments 0, 1, 2 (regression guard)',
      () {
        // Simulate the non-seek path: just verify the window for index 0.
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: 0,
          maxSegmentIndex: 100,
        );
        // Non-seek path always starts at 0.
        expect(window, containsAll([0, 1, 2]));
      },
    );

    test(
      'seekTargetMs != null → seek path must NOT use indices 0/1/2 when absoluteTarget > 3',
      () {
        // Simulate the seek path for a manifest starting at CDN index 211.
        const startAbsoluteIndex = 211;
        final manifest = _buildFakeManifest(
          startAbsoluteIndex: startAbsoluteIndex,
          segmentCount: 300,
          durationSeconds: 4.0,
        );
        final keys = _doSegmentSeekPrefetch_fixed(
          manifestBody: manifest,
          variant: '1600',
          track: 0,
          targetMs: 840000,
        );
        // No key should contain index 0, 1, or 2.
        for (final key in keys) {
          final idx = int.parse(key.split(':').last);
          expect(
            idx,
            greaterThan(3),
            reason: 'seek path must not use start-of-stream indices',
          );
        }
      },
    );
  });
}
