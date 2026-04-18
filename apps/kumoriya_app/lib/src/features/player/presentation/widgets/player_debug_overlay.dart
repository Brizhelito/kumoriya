import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/models/player_diagnostics.dart';

/// Translucent debug overlay showing real-time player performance metrics.
///
/// Only renders in debug builds ([kDebugMode]).  Positioned in the top-right
/// corner of the player Stack, above the video surface but below interactive
/// controls.
class PlayerDebugOverlay extends StatefulWidget {
  const PlayerDebugOverlay({
    super.key,
    required this.diagnosticsStream,
    this.seekLatencyMs,
  });

  final Stream<PlayerDiagnostics> diagnosticsStream;

  /// Externally provided seek latency (from orchestrator) — merged into
  /// the snapshot when available.
  final int? seekLatencyMs;

  @override
  State<PlayerDebugOverlay> createState() => _PlayerDebugOverlayState();
}

class _PlayerDebugOverlayState extends State<PlayerDebugOverlay> {
  StreamSubscription<PlayerDiagnostics>? _sub;
  PlayerDiagnostics? _latest;
  bool _expanded = true;

  // ── Compositor FPS probe (debug-only) ────────────────────────────────
  // Tracks Flutter's real render pipeline via SchedulerBinding timings,
  // independently of mpv's video-filter FPS. The two combined let us tell
  // render lag (low compositor FPS) apart from decode lag (low vf-fps).
  // Split by thread (build = UI, raster = GPU) so bottlenecks can be
  // attributed correctly.
  static const Duration _fpsWindow = Duration(seconds: 2);
  final Queue<_FrameSample> _frameSamples = Queue<_FrameSample>();
  TimingsCallback? _timingsCallback;
  Timer? _fpsRefreshTimer;
  double? _compositorFps;
  double _compositorAvgBuildMs = 0;
  double _compositorAvgRasterMs = 0;
  int _compositorWorstTotalMs = 0;
  int _compositorWorstBuildMs = 0;
  int _compositorWorstRasterMs = 0;
  int _compositorSlow16 = 0;
  int _compositorSlow33 = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.diagnosticsStream.listen((snap) {
      if (mounted) setState(() => _latest = snap);
    });
    _timingsCallback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
    // Refresh UI at 2 Hz — timings callbacks fire per-frame but we don't
    // want to setState 60×/s just to update a debug readout.
    _fpsRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _recomputeCompositorStats(),
    );
  }

  @override
  void didUpdateWidget(PlayerDebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diagnosticsStream != widget.diagnosticsStream) {
      _sub?.cancel();
      _sub = widget.diagnosticsStream.listen((snap) {
        if (mounted) setState(() => _latest = snap);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fpsRefreshTimer?.cancel();
    final cb = _timingsCallback;
    if (cb != null) {
      SchedulerBinding.instance.removeTimingsCallback(cb);
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    for (final timing in timings) {
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      _frameSamples.addLast(
        _FrameSample(
          arrivedAtMicros: nowMicros,
          buildMicros: buildMicros,
          rasterMicros: rasterMicros,
        ),
      );
    }
  }

  void _recomputeCompositorStats() {
    if (!mounted) return;
    final cutoff =
        DateTime.now().microsecondsSinceEpoch - _fpsWindow.inMicroseconds;
    while (_frameSamples.isNotEmpty &&
        _frameSamples.first.arrivedAtMicros < cutoff) {
      _frameSamples.removeFirst();
    }
    final count = _frameSamples.length;
    if (count == 0) {
      setState(() {
        _compositorFps = null;
        _compositorAvgBuildMs = 0;
        _compositorAvgRasterMs = 0;
        _compositorWorstTotalMs = 0;
        _compositorWorstBuildMs = 0;
        _compositorWorstRasterMs = 0;
        _compositorSlow16 = 0;
        _compositorSlow33 = 0;
      });
      return;
    }
    int sumBuild = 0;
    int sumRaster = 0;
    int worstBuild = 0;
    int worstRaster = 0;
    int worstTotal = 0;
    int slow16 = 0;
    int slow33 = 0;
    for (final s in _frameSamples) {
      // Per-frame wall-clock work ≈ max(build, raster) since the two threads
      // pipeline across frames. Vsync pacing is gated by whichever is slower.
      final perFrameMicros = s.buildMicros > s.rasterMicros
          ? s.buildMicros
          : s.rasterMicros;
      sumBuild += s.buildMicros;
      sumRaster += s.rasterMicros;
      if (s.buildMicros > worstBuild) worstBuild = s.buildMicros;
      if (s.rasterMicros > worstRaster) worstRaster = s.rasterMicros;
      if (perFrameMicros > worstTotal) worstTotal = perFrameMicros;
      if (perFrameMicros > 16000) slow16++;
      if (perFrameMicros > 33000) slow33++;
    }
    setState(() {
      _compositorFps = count / _fpsWindow.inMilliseconds * 1000.0;
      _compositorAvgBuildMs = (sumBuild / count) / 1000.0;
      _compositorAvgRasterMs = (sumRaster / count) / 1000.0;
      _compositorWorstBuildMs = worstBuild ~/ 1000;
      _compositorWorstRasterMs = worstRaster ~/ 1000;
      _compositorWorstTotalMs = worstTotal ~/ 1000;
      _compositorSlow16 = slow16;
      _compositorSlow33 = slow33;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final d = _latest;

    return Positioned(
      right: 8,
      top: 8 + MediaQuery.of(context).padding.top,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: _expanded ? _buildExpanded(d) : _buildCollapsed(d),
        ),
      ),
    );
  }

  Widget _buildCollapsed(PlayerDiagnostics? d) {
    final videoFps = d?.estimatedVfFps;
    final videoLabel = videoFps != null
        ? '${videoFps.toStringAsFixed(1)} vf'
        : '-- vf';
    final uiLabel = _compositorFps != null
        ? '${_compositorFps!.toStringAsFixed(0)} ui'
        : '-- ui';
    return Text('$uiLabel / $videoLabel', style: _style);
  }

  Widget _buildExpanded(PlayerDiagnostics? d) {
    final lines = <String>[
      // Compositor (Flutter render pipeline) FPS — independent of mpv.
      'UI FPS: ${_fmtDouble(_compositorFps)}  '
          'worst=${_compositorWorstTotalMs}ms',
      'build: avg=${_compositorAvgBuildMs.toStringAsFixed(1)}ms  '
          'worst=${_compositorWorstBuildMs}ms',
      'raster: avg=${_compositorAvgRasterMs.toStringAsFixed(1)}ms  '
          'worst=${_compositorWorstRasterMs}ms',
      'UI slow: >16ms=$_compositorSlow16  >33ms=$_compositorSlow33',
      if (d != null) ...<String>[
        // mpv video-filter FPS (decode/filter throughput, not render).
        'VF FPS: ${_fmtDouble(d.estimatedVfFps)} '
            '(display: ${_fmtDouble(d.displayFps)})',
        'Drops: render=${d.frameDropCount ?? 0} '
            'decode=${d.decoderFrameDropCount ?? 0}',
        'VO: ${d.videoOutput ?? "?"}',
        'Codec: ${d.decoderLabel}',
        'Res: ${d.resolutionLabel ?? "?"}  fmt=${d.videoFormat ?? "?"}',
        'Buffer: ${_fmtDouble(d.demuxerCacheDuration)}s '
            '(${_fmtBytes(d.demuxerCacheBytes)})',
        'Seek: ${_seekLabel(d)}',
      ] else
        'Waiting for mpv metrics…',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lines
          .map((line) => Text(line, style: _style))
          .toList(growable: false),
    );
  }

  String _seekLabel(PlayerDiagnostics d) {
    final ms = widget.seekLatencyMs ?? d.lastSeekLatencyMs;
    if (ms == null) return '--';
    return '${ms}ms';
  }

  static String _fmtDouble(double? v) =>
      v != null ? v.toStringAsFixed(1) : '--';

  static String _fmtBytes(int? bytes) {
    if (bytes == null) return '?';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  static const TextStyle _style = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    color: Color(0xCCFFFFFF),
    height: 1.4,
  );
}

/// Single frame timing sample kept in the rolling compositor FPS window.
class _FrameSample {
  const _FrameSample({
    required this.arrivedAtMicros,
    required this.buildMicros,
    required this.rasterMicros,
  });

  /// Wall-clock arrival time (microseconds since epoch) so samples older than
  /// the window can be dropped on each refresh tick.
  final int arrivedAtMicros;

  /// Time the UI thread spent building this frame, in microseconds.
  final int buildMicros;

  /// Time the raster thread spent rasterizing this frame, in microseconds.
  final int rasterMicros;
}
