import 'package:kumoriya_app/src/features/downloads/application/adaptive_concurrency_controller.dart';
import 'package:test/test.dart';

void main() {
  group('AdaptiveConcurrencyController', () {
    late AdaptiveConcurrencyController ctrl;

    setUp(() {
      ctrl = AdaptiveConcurrencyController(
        initialConcurrent: 8,
        minConcurrent: 4,
        maxConcurrent: 32,
      );
    });

    test('starts at initialConcurrent', () {
      expect(ctrl.currentConcurrent, 8);
    });

    test('first probe returns initial and second ramps up', () {
      // First probe initializes — returns initial.
      final first = ctrl.probe(0);
      expect(first, 8);

      // Simulate 10 MB downloaded in 2s → 5 MB/s.
      ctrl.recordBytes(10 * 1024 * 1024);
      final second = ctrl.probe(2000);
      // First real sample → should ramp up by additive increase (2).
      expect(second, 10);
    });

    test('ramps up when throughput improves', () {
      // Init probe at t=0.
      ctrl.probe(0);

      // Probe 1: 10 MB in 2s → 5 MB/s. First real → ramp.
      ctrl.recordBytes(10 * 1024 * 1024);
      ctrl.probe(2000);
      expect(ctrl.currentConcurrent, 10);

      // Probe 2: another 12 MB in 2s → 6 MB/s. 20% gain → ramp.
      ctrl.recordBytes(12 * 1024 * 1024);
      final c = ctrl.probe(4000);
      expect(c, 12);
    });

    test('holds steady at plateau', () {
      ctrl.probe(0);

      // Probe 1: 10 MB in 2s → 5 MB/s.
      ctrl.recordBytes(10 * 1024 * 1024);
      ctrl.probe(2000);

      // Probe 2: ~10 MB in 2s → same 5 MB/s (within ±5%).
      ctrl.recordBytes(10 * 1024 * 1024);
      final c = ctrl.probe(4000);
      // Should hold — no gain, no loss.
      expect(c, ctrl.currentConcurrent);
    });

    test('backs off when throughput drops', () {
      ctrl.probe(0);

      // Build up a baseline.
      ctrl.recordBytes(20 * 1024 * 1024);
      ctrl.probe(2000); // ~10 MB/s
      // Now ramp up to 10.
      expect(ctrl.currentConcurrent, 10);

      // Throughput drops 50%: only 5 MB in 2s instead of 10.
      ctrl.recordBytes(5 * 1024 * 1024);
      ctrl.probe(4000);
      // 50% drop > 15% threshold → multiplicative decrease: ceil(10 * 0.75) = 8.
      expect(ctrl.currentConcurrent, 8);
    });

    test('never goes below minConcurrent', () {
      ctrl = AdaptiveConcurrencyController(
        initialConcurrent: 5,
        minConcurrent: 4,
        maxConcurrent: 32,
      );

      ctrl.probe(0);

      // Give just enough to not stall, then drop hard.
      ctrl.recordBytes(200 * 1024); // 100 KB/s — above stall threshold
      ctrl.probe(2000);
      expect(ctrl.currentConcurrent, greaterThanOrEqualTo(4));

      // Simulate extreme drops.
      for (var t = 4000; t <= 20000; t += 2000) {
        ctrl.recordBytes(100 * 1024); // Tiny throughput
        ctrl.probe(t);
      }
      expect(ctrl.currentConcurrent, greaterThanOrEqualTo(4));
    });

    test('never exceeds maxConcurrent', () {
      ctrl = AdaptiveConcurrencyController(
        initialConcurrent: 28,
        minConcurrent: 4,
        maxConcurrent: 32,
      );

      ctrl.probe(0);

      // Keep ramping with increasing throughput.
      var total = 0;
      for (var t = 2000; t <= 20000; t += 2000) {
        total += 50 * 1024 * 1024; // 50 MB every 2s → 25 MB/s, increasing
        ctrl.recordBytes(50 * 1024 * 1024);
        ctrl.probe(t);
      }
      expect(ctrl.currentConcurrent, lessThanOrEqualTo(32));
    });

    test('stall detection cuts aggressively after 3 probes', () {
      ctrl = AdaptiveConcurrencyController(
        initialConcurrent: 16,
        minConcurrent: 4,
        maxConcurrent: 32,
      );

      ctrl.probe(0);

      // Stall: < 50 KB/s for 3 consecutive probes.
      ctrl.recordBytes(10 * 1024); // ~5 KB/s
      ctrl.probe(2000);
      expect(ctrl.currentConcurrent, 16); // No change yet.

      ctrl.recordBytes(10 * 1024);
      ctrl.probe(4000);
      expect(ctrl.currentConcurrent, 16); // Still holding.

      ctrl.recordBytes(10 * 1024);
      ctrl.probe(6000);
      // Third stall → aggressive cut: ceil(16 * 0.5) = 8.
      expect(ctrl.currentConcurrent, 8);
    });

    test('does not probe before interval elapses', () {
      ctrl.probe(0);

      ctrl.recordBytes(10 * 1024 * 1024);
      final c1 = ctrl.probe(500); // Only 500ms — too early.
      expect(c1, 8); // No change.

      final c2 = ctrl.probe(1999); // Still too early.
      expect(c2, 8);

      final c3 = ctrl.probe(2000); // Now it fires.
      expect(c3, 10); // Ramped up.
    });

    test('reset restores initial state', () {
      ctrl.probe(0);
      ctrl.recordBytes(50 * 1024 * 1024);
      ctrl.probe(2000);
      expect(ctrl.currentConcurrent, isNot(8));

      ctrl.reset();
      expect(ctrl.currentConcurrent, 8);
    });
  });
}
