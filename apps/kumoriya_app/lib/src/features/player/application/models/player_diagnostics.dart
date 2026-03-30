/// Real-time diagnostic snapshot for the video player.
///
/// Populated by polling mpv properties through [NativePlayer.getProperty].
/// Only used in debug builds — the overlay and polling are gated behind
/// [kDebugMode].
final class PlayerDiagnostics {
  const PlayerDiagnostics({
    this.estimatedVfFps,
    this.displayFps,
    this.frameDropCount,
    this.decoderFrameDropCount,
    this.hwdecCurrent,
    this.videoFormat,
    this.videoCodec,
    this.videoWidth,
    this.videoHeight,
    this.demuxerCacheDuration,
    this.demuxerCacheBytes,
    this.lastSeekLatencyMs,
  });

  /// Estimated video filter-chain FPS (actual decode/display throughput).
  final double? estimatedVfFps;

  /// Display refresh rate reported by the OS / compositor.
  final double? displayFps;

  /// Cumulative count of frames dropped during rendering.
  final int? frameDropCount;

  /// Cumulative count of frames dropped by the decoder (too slow).
  final int? decoderFrameDropCount;

  /// Active hardware decoder name (e.g. "mediacodec", "d3d11va") or empty
  /// string when software decoding is in use.
  final String? hwdecCurrent;

  /// Pixel format string (e.g. "yuv420p", "nv12").
  final String? videoFormat;

  /// Codec name (e.g. "h264", "hevc", "av1").
  final String? videoCodec;

  /// Video frame width in pixels.
  final int? videoWidth;

  /// Video frame height in pixels.
  final int? videoHeight;

  /// Seconds of content buffered ahead in the demuxer cache.
  final double? demuxerCacheDuration;

  /// Bytes currently cached by the demuxer.
  final int? demuxerCacheBytes;

  /// Milliseconds of the last completed seek operation (request → first
  /// position change beyond the seek target).  Null until a seek completes.
  final int? lastSeekLatencyMs;

  /// Whether the engine is decoding in hardware.
  bool get isHardwareDecoding =>
      hwdecCurrent != null && hwdecCurrent!.isNotEmpty && hwdecCurrent != 'no';

  /// Resolution label like "1920×1080" or null.
  String? get resolutionLabel {
    if (videoWidth == null || videoHeight == null) return null;
    return '$videoWidth×$videoHeight';
  }

  /// Short codec + hw/sw label like "h264 (mediacodec)" or "hevc (sw)".
  String get decoderLabel {
    final codec = videoCodec ?? '?';
    final hw = isHardwareDecoding ? hwdecCurrent! : 'sw';
    return '$codec ($hw)';
  }
}
