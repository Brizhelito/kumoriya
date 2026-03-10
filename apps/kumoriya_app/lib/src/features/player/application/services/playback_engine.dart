import 'dart:async';

import 'package:kumoriya_plugins/kumoriya_plugins.dart';

abstract interface class PlaybackEngine {
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;

  Future<void> open(ResolvedStream stream, {Duration? startPosition});
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> dispose();
}
