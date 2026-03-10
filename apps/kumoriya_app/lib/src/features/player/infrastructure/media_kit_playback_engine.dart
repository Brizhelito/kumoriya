import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../application/services/playback_engine.dart';

final class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine() : player = Player() {
    videoController = VideoController(player);
  }

  final Player player;
  late final VideoController videoController;

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<String> get errorStream => player.stream.error;

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<Duration> get durationStream => player.stream.duration;

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) {
    return player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: startPosition,
      ),
      play: true,
    );
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> play() => player.play();

  @override
  Future<void> seekTo(Duration position) => player.seek(position);

  @override
  Future<void> dispose() async {
    await player.dispose();
  }
}
