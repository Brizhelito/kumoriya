/// One-sample snapshot of the native diagnostics pipeline (Fase 5).
///
/// Emitted on the controller's `diagnosticsStream` at roughly 1 Hz
/// while diagnostics are enabled. All fields are best-effort — most
/// come from Media3's `AnalyticsListener` and stay `null`/`0` until
/// Media3 has published the first sample of the corresponding kind.
final class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    this.droppedVideoFrames = 0,
    this.renderedVideoFrames = 0,
    this.videoCodec,
    this.videoDecoder,
    this.videoBitrate = 0,
    this.videoHardwareAccelerated,
    this.audioCodec,
    this.audioSampleRate = 0,
    this.audioChannels = 0,
    this.bandwidthBps = 0,
    this.bufferedMs = 0,
    this.positionMs = 0,
    this.videoWidth = 0,
    this.videoHeight = 0,
  });

  /// Cumulative dropped video frames since diagnostics were enabled.
  final int droppedVideoFrames;

  /// Count of `onRenderedFirstFrame` events seen — not a frame rate,
  /// used as a liveness hint.
  final int renderedVideoFrames;

  /// Human-readable video codec (`"avc1.64001e"`, `"video/avc"` fallback).
  final String? videoCodec;

  /// Decoder name from `MediaCodec.getName()` — e.g. `"c2.android.avc.decoder"`.
  final String? videoDecoder;

  /// Video bitrate from the active track's `Format.bitrate`, in bps.
  final int videoBitrate;

  /// `true` when the decoder is vendor/hardware, `false` when it's a
  /// known software fallback, `null` until Media3 has negotiated one.
  final bool? videoHardwareAccelerated;

  final String? audioCodec;
  final int audioSampleRate;
  final int audioChannels;

  /// Estimated bandwidth in bits per second (from `onBandwidthEstimate`).
  final int bandwidthBps;

  /// Total buffered duration ahead of the play-head, in milliseconds.
  final int bufferedMs;

  /// Current play-head position in milliseconds.
  final int positionMs;

  /// Display-corrected video dimensions (pixel-aspect-ratio applied).
  final double videoWidth;
  final double videoHeight;

  /// Decode a snapshot payload produced by the Kotlin side's
  /// `diagnostics` event. Returns `null` when the payload is malformed.
  static DiagnosticsSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return DiagnosticsSnapshot(
      droppedVideoFrames: _asInt(raw['droppedVideoFrames']),
      renderedVideoFrames: _asInt(raw['renderedVideoFrames']),
      videoCodec: raw['videoCodec'] as String?,
      videoDecoder: raw['videoDecoder'] as String?,
      videoBitrate: _asInt(raw['videoBitrate']),
      videoHardwareAccelerated: raw['videoHardwareAccelerated'] as bool?,
      audioCodec: raw['audioCodec'] as String?,
      audioSampleRate: _asInt(raw['audioSampleRate']),
      audioChannels: _asInt(raw['audioChannels']),
      bandwidthBps: _asInt(raw['bandwidthBps']),
      bufferedMs: _asInt(raw['bufferedMs']),
      positionMs: _asInt(raw['positionMs']),
      videoWidth: _asDouble(raw['videoWidth']),
      videoHeight: _asDouble(raw['videoHeight']),
    );
  }

  static int _asInt(Object? v) => v is num ? v.toInt() : 0;
  static double _asDouble(Object? v) => v is num ? v.toDouble() : 0.0;
}
