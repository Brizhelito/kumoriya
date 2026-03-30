import 'dart:async';

import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/embedded_tracks.dart';
import '../models/player_diagnostics.dart';

abstract interface class PlaybackEngine {
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();
  Stream<double> get bufferingPercentageStream => const Stream<double>.empty();

  /// Embedded audio/subtitle tracks discovered by the playback engine.
  /// Emitted whenever the demuxer reports a new track list (e.g. after open).
  Stream<EmbeddedTracks> get embeddedTracksStream =>
      const Stream<EmbeddedTracks>.empty();

  /// Periodic diagnostic snapshots (FPS, frame drops, codec info, buffer
  /// state).  Only expected to emit in debug builds.
  Stream<PlayerDiagnostics> get diagnosticsStream =>
      const Stream<PlayerDiagnostics>.empty();

  Future<void> open(ResolvedStream stream, {Duration? startPosition});
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {}
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track);
  Future<void> clearSubtitleTrack();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// Select an embedded audio track by id.
  Future<void> setEmbeddedAudioTrack(EmbeddedAudioTrack track) async {}

  /// Select an embedded subtitle track by id.
  Future<void> setEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) async {}

  /// Disable the embedded subtitle track.
  Future<void> clearEmbeddedSubtitleTrack() async {}

  /// Signals a best-effort, non-blocking prefetch for the segment region
  /// around [position].  Used by the orchestrator for predictive prewarm
  /// after a successful reopen seek.  Implementations that don't support
  /// prefetching may leave this as a no-op.
  Future<void> signalPredictivePrewarm(Duration position) async {}

  /// Completes when the video output renders its first frame after the
  /// most recent open.  Used by the orchestrator's visual gate to detect
  /// actual frame visibility instead of relying on position thresholds.
  /// Implementations that cannot detect first-frame may return a future
  /// that never completes (the gate will fall through on timeout).
  Future<void> get firstFrameRendered => Completer<void>().future;

  /// Enable or disable smart audio boost.  When [enabled] is true the
  /// engine should apply dynamic-range compression / loudness normalization
  /// so that volume above 100 % remains intelligible instead of clipping.
  Future<void> setSmartAudioBoost({required bool enabled}) async {}

  Future<void> dispose();
}
