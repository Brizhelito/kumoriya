// ignore_for_file: lines_longer_than_80_chars

/// Property-Based Tests — Task 5 (resolver package)
///
/// Uses hand-rolled property loops with dart:math Random.
/// No dedicated PBT library required.
///
/// P-PBT-1: buildAbsoluteSeekWindow — for random target in [4..500]:
///   - 0 NOT in window
///   - window size <= 5
///   - all indices in [max(0,target-1)..target+3]
///
/// P-PBT-2: _doSegmentSeekPrefetch — for random manifests starting at N > 3:
///   - all cache key indices >= N-1
library;

import 'dart:math';

import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Inline replicas of FIXED helpers (same as seek_unit_test.dart)
// ---------------------------------------------------------------------------

List<int> buildAbsoluteSeekWindow({
  required int targetSegmentIndex,
  required int maxSegmentIndex,
}) {
  final start = max(0, targetSegmentIndex - 1);
  final end = min(maxSegmentIndex, targetSegmentIndex + 3);
  return [for (var i = start; i <= end; i++) i];
}

int _parseSegmentIndex(String path) {
  final match = RegExp(r'_([0-9]+)-[0-9]+\.(?:m4s|mp4)$').firstMatch(path);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
}

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
  const seed = 42;
  const iterations = 500;

  // -------------------------------------------------------------------------
  // P-PBT-1: buildAbsoluteSeekWindow properties
  // -------------------------------------------------------------------------
  group('P-PBT-1: buildAbsoluteSeekWindow — random target in [4..500]', () {
    test('0 NOT in window for any target in [4..500]', () {
      final rng = Random(seed);
      for (var i = 0; i < iterations; i++) {
        final target = 4 + rng.nextInt(497); // [4..500]
        final maxIdx = target + rng.nextInt(501); // [target..target+500]
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: target,
          maxSegmentIndex: maxIdx,
        );
        expect(
          window,
          isNot(contains(0)),
          reason: 'target=$target maxIdx=$maxIdx window=$window',
        );
      }
    });

    test('window size <= 5 for any target', () {
      final rng = Random(seed);
      for (var i = 0; i < iterations; i++) {
        final target = rng.nextInt(1000);
        final maxIdx = target + rng.nextInt(1001);
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: target,
          maxSegmentIndex: maxIdx,
        );
        expect(
          window.length,
          lessThanOrEqualTo(5),
          reason: 'target=$target maxIdx=$maxIdx window=$window',
        );
      }
    });

    test('all indices in [max(0,target-1)..target+3] for any target', () {
      final rng = Random(seed);
      for (var i = 0; i < iterations; i++) {
        final target = rng.nextInt(1000);
        final maxIdx = target + rng.nextInt(1001);
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: target,
          maxSegmentIndex: maxIdx,
        );
        final expectedMin = max(0, target - 1);
        final expectedMax = min(maxIdx, target + 3);
        for (final idx in window) {
          expect(
            idx,
            greaterThanOrEqualTo(expectedMin),
            reason:
                'idx=$idx below expectedMin=$expectedMin '
                '(target=$target maxIdx=$maxIdx)',
          );
          expect(
            idx,
            lessThanOrEqualTo(expectedMax),
            reason:
                'idx=$idx above expectedMax=$expectedMax '
                '(target=$target maxIdx=$maxIdx)',
          );
        }
      }
    });

    test('window is contiguous (no gaps)', () {
      final rng = Random(seed);
      for (var i = 0; i < iterations; i++) {
        final target = rng.nextInt(1000);
        final maxIdx = target + rng.nextInt(1001);
        final window = buildAbsoluteSeekWindow(
          targetSegmentIndex: target,
          maxSegmentIndex: maxIdx,
        );
        for (var j = 1; j < window.length; j++) {
          expect(
            window[j],
            window[j - 1] + 1,
            reason:
                'gap at position $j in window=$window '
                '(target=$target maxIdx=$maxIdx)',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // P-PBT-2: _doSegmentSeekPrefetch — manifests starting at N > 3
  // -------------------------------------------------------------------------
  group(
    'P-PBT-2: _doSegmentSeekPrefetch — cache keys >= N-1 for manifests starting at N > 3',
    () {
      test(
        'all cache key indices >= startAbsoluteIndex-1 for random N in [4..300]',
        () {
          final rng = Random(seed);
          for (var i = 0; i < 200; i++) {
            final startN = 4 + rng.nextInt(297); // [4..300]
            final segmentCount = 50 + rng.nextInt(251); // [50..300]
            final durationSeconds = 2.0 + rng.nextDouble() * 4.0; // [2..6]s
            // Seek target somewhere in the middle of the manifest.
            final totalDurationMs = (segmentCount * durationSeconds * 1000)
                .toInt();
            final targetMs =
                (totalDurationMs * 0.3 +
                        rng.nextDouble() * totalDurationMs * 0.4)
                    .toInt();

            final manifest = _buildFakeManifest(
              startAbsoluteIndex: startN,
              segmentCount: segmentCount,
              durationSeconds: durationSeconds,
            );

            final keys = _doSegmentSeekPrefetch_fixed(
              manifestBody: manifest,
              variant: '1600',
              track: 0,
              targetMs: targetMs,
            );

            if (keys.isEmpty) continue; // targetMs beyond manifest — skip

            for (final key in keys) {
              final idx = int.parse(key.split(':').last);
              expect(
                idx,
                greaterThanOrEqualTo(startN - 1),
                reason:
                    'key=$key has idx=$idx < startN-1=${startN - 1} '
                    '(startN=$startN targetMs=$targetMs)',
              );
            }
          }
        },
      );

      test('0 never appears in cache keys when startAbsoluteIndex > 3', () {
        final rng = Random(seed);
        for (var i = 0; i < 200; i++) {
          final startN = 4 + rng.nextInt(297);
          final segmentCount = 50 + rng.nextInt(251);
          const durationSeconds = 4.0;
          final totalDurationMs = (segmentCount * durationSeconds * 1000)
              .toInt();
          final targetMs = (totalDurationMs * 0.5).toInt();

          final manifest = _buildFakeManifest(
            startAbsoluteIndex: startN,
            segmentCount: segmentCount,
            durationSeconds: durationSeconds,
          );

          final keys = _doSegmentSeekPrefetch_fixed(
            manifestBody: manifest,
            variant: '1600',
            track: 0,
            targetMs: targetMs,
          );

          for (final key in keys) {
            final idx = int.parse(key.split(':').last);
            expect(
              idx,
              isNot(0),
              reason: 'key=$key contains index 0 for startN=$startN',
            );
          }
        }
      });
    },
  );
}
