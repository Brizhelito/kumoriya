import 'dart:async';

import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/embedded_tracks.dart';

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

  Future<void> open(ResolvedStream stream, {Duration? startPosition});
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

  Future<void> dispose();
}
