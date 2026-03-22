import 'dart:io';
import 'dart:math';

/// Adaptive concurrency controller that measures real throughput and adjusts
/// the number of parallel segment downloads to maximize bandwidth utilization.
///
/// ## Algorithm (AIMD-inspired)
/// Every [_probeIntervalMs] ms the controller samples the current throughput
/// (bytes/s) and compares it to the previous sample:
///
/// - **Ramp-up**: If throughput increased by ≥ [_gainThreshold] relative to
///   the previous sample, add [_additiveIncrease] slots (the pipe isn't full).
/// - **Plateau**: If throughput is within ±[_gainThreshold] of the previous
///   sample, hold steady — we're near saturation.
/// - **Backoff**: If throughput dropped by > [_lossThreshold] relative to the
///   previous sample, multiply slots by [_multiplicativeDecrease] — we're
///   overloading the connection or the server is throttling.
/// - **Stall detect**: If throughput is near-zero for [_stallCountThreshold]
///   consecutive probes, cut slots aggressively to let in-flights drain.
///
/// ## Bounds
/// Slots are always clamped to [[minConcurrent], [maxConcurrent]].
/// Platform-aware defaults keep Android more conservative than Windows.
///
/// ## Usage
/// The controller is designed to run *inside* the worker isolate. Each time
/// a segment completes, call [recordBytes]. Periodically (in the download
/// loop), call [probe] which returns the current optimal concurrency.
class AdaptiveConcurrencyController {
  AdaptiveConcurrencyController({
    required this.initialConcurrent,
    int? minConcurrent,
    int? maxConcurrent,
  }) : _currentConcurrent = initialConcurrent,
       minConcurrent = minConcurrent ?? _platformMinConcurrent(),
       maxConcurrent = maxConcurrent ?? _platformMaxConcurrent();

  /// Starting number of parallel slots.
  final int initialConcurrent;

  /// Absolute floor — never go below this.
  final int minConcurrent;

  /// Absolute ceiling — never go above this.
  final int maxConcurrent;

  // ── Tuning knobs ─────────────────────────────────────────────────────

  /// How often to sample throughput and possibly adjust concurrency (ms).
  static const _probeIntervalMs = 2000;

  /// Minimum relative throughput improvement to trigger ramp-up.
  /// 0.05 = 5% improvement required.
  static const _gainThreshold = 0.05;

  /// Relative throughput drop that triggers multiplicative decrease.
  /// 0.15 = 15% drop.
  static const _lossThreshold = 0.15;

  /// Slots to add during ramp-up phase.
  static const _additiveIncrease = 2;

  /// Multiplicative factor on backoff (0.75 = cut 25%).
  static const _multiplicativeDecrease = 0.75;

  /// Consecutive near-zero probes before stall recovery kicks in.
  static const _stallCountThreshold = 3;

  /// Bytes/s below which we consider the connection "stalled".
  static const _stallBytesPerSecond = 50 * 1024; // 50 KB/s

  // ── State ────────────────────────────────────────────────────────────

  int _currentConcurrent;
  int _totalBytesRecorded = 0;
  int _bytesAtLastProbe = 0;
  int _lastProbeMs = 0;
  int _previousThroughput = 0;
  int _stallCount = 0;
  bool _started = false;

  /// Current recommended concurrency.
  int get currentConcurrent => _currentConcurrent;

  /// Records bytes downloaded (call after each segment or chunk completes).
  void recordBytes(int bytes) {
    _totalBytesRecorded += bytes;
  }

  /// Probes throughput and returns the (possibly adjusted) concurrency.
  ///
  /// [elapsedMs] is the total elapsed time since the download started
  /// (from a [Stopwatch]).
  int probe(int elapsedMs) {
    if (!_started) {
      _started = true;
      _lastProbeMs = elapsedMs;
      _bytesAtLastProbe = _totalBytesRecorded;
      return _currentConcurrent;
    }

    final deltaMs = elapsedMs - _lastProbeMs;
    if (deltaMs < _probeIntervalMs) {
      return _currentConcurrent;
    }

    // Calculate throughput for this interval.
    final deltaBytes = _totalBytesRecorded - _bytesAtLastProbe;
    final throughput = deltaMs > 0 ? (deltaBytes * 1000 / deltaMs).round() : 0;

    _bytesAtLastProbe = _totalBytesRecorded;
    _lastProbeMs = elapsedMs;

    // Stall detection.
    if (throughput < _stallBytesPerSecond) {
      _stallCount++;
      if (_stallCount >= _stallCountThreshold) {
        // Aggressively cut — connections are probably stuck.
        _currentConcurrent = max(
          minConcurrent,
          (_currentConcurrent * 0.5).ceil(),
        );
        _stallCount = 0;
        _previousThroughput = throughput;
        return _currentConcurrent;
      }
      // Don't adjust on a single stall — could be transient.
      _previousThroughput = throughput;
      return _currentConcurrent;
    }

    _stallCount = 0;

    if (_previousThroughput == 0) {
      // First real sample — start ramping from initial.
      _previousThroughput = throughput;
      _currentConcurrent = min(
        maxConcurrent,
        _currentConcurrent + _additiveIncrease,
      );
      return _currentConcurrent;
    }

    final relativeChange =
        (throughput - _previousThroughput) / _previousThroughput;

    if (relativeChange >= _gainThreshold) {
      // Throughput is improving — add more workers.
      _currentConcurrent = min(
        maxConcurrent,
        _currentConcurrent + _additiveIncrease,
      );
    } else if (relativeChange < -_lossThreshold) {
      // Throughput dropped significantly — back off.
      _currentConcurrent = max(
        minConcurrent,
        (_currentConcurrent * _multiplicativeDecrease).ceil(),
      );
    }
    // Otherwise: plateau — hold steady.

    _previousThroughput = throughput;
    return _currentConcurrent;
  }

  /// Resets the controller to initial state (e.g., on resume).
  void reset() {
    _currentConcurrent = initialConcurrent;
    _totalBytesRecorded = 0;
    _bytesAtLastProbe = 0;
    _lastProbeMs = 0;
    _previousThroughput = 0;
    _stallCount = 0;
    _started = false;
  }

  // ── Platform defaults ────────────────────────────────────────────────

  static int _platformMinConcurrent() {
    if (Platform.isAndroid) return 4;
    if (Platform.isWindows) return 8;
    return 4;
  }

  static int _platformMaxConcurrent() {
    if (Platform.isAndroid) return 24;
    if (Platform.isWindows) return 96;
    return 24;
  }
}
