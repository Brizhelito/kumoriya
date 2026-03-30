import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _sub = widget.diagnosticsStream.listen((snap) {
      if (mounted) setState(() => _latest = snap);
    });
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
    super.dispose();
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
    final fps = d?.estimatedVfFps;
    final label = fps != null ? '${fps.toStringAsFixed(1)} fps' : '-- fps';
    return Text(label, style: _style);
  }

  Widget _buildExpanded(PlayerDiagnostics? d) {
    if (d == null) {
      return Text('Waiting for metrics…', style: _style);
    }

    final lines = <String>[
      // FPS
      'FPS: ${_fmtDouble(d.estimatedVfFps)} '
          '(display: ${_fmtDouble(d.displayFps)})',
      // Frame drops
      'Drops: render=${d.frameDropCount ?? 0} '
          'decode=${d.decoderFrameDropCount ?? 0}',
      // Decoder
      'Codec: ${d.decoderLabel}',
      // Resolution
      'Res: ${d.resolutionLabel ?? "?"}  fmt=${d.videoFormat ?? "?"}',
      // Buffer
      'Buffer: ${_fmtDouble(d.demuxerCacheDuration)}s '
          '(${_fmtBytes(d.demuxerCacheBytes)})',
      // Seek
      'Seek: ${_seekLabel(d)}',
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
