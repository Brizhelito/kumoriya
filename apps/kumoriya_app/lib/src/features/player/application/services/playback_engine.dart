import 'dart:async';

import 'package:kumoriya_plugins/kumoriya_plugins.dart';

abstract interface class PlaybackEngine {
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<String> get errorStream;

  Future<void> open(ResolvedStream stream);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}
