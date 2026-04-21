import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

import '../../application/services/playback_engine.dart';
import '../../infrastructure/exoplayer_playback_engine.dart';
import '../../infrastructure/kumoriya_exoplayer_engine.dart';
import '../../infrastructure/media_kit_playback_engine.dart';

/// Renders the current video output for any [PlaybackEngine] implementation.
///
/// Dispatches on the concrete engine type because each backend owns its own
/// texture/controller:
/// - [MediaKitPlaybackEngine] → `Video` widget backed by mpv's
///   [VideoController], with the existing subtitle view configuration.
/// - [KumoriyaExoPlayerEngine] → plain [Texture] widget wired to the native
///   Media3 texture id exposed by the first-party plugin. Subtitles draw
///   from the page's overlay (embedded subs land in Fase 3b).
/// - [ExoPlayerPlaybackEngine] → `VideoPlayer` widget backed by
///   `video_player`'s [VideoPlayerController] (legacy Android engine,
///   kept for playground comparisons).
///
/// Falls back to an empty [SizedBox] when the engine has not yet produced a
/// controller (pre-first-open window) to avoid flicker.
class PlayerVideoSurface extends StatelessWidget {
  const PlayerVideoSurface({
    super.key,
    required this.engine,
    this.subtitleViewConfiguration,
    this.fit = BoxFit.contain,
  });

  final PlaybackEngine engine;
  final SubtitleViewConfiguration? subtitleViewConfiguration;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final e = engine;
    if (e is MediaKitPlaybackEngine) {
      return Video(
        controller: e.videoController,
        controls: NoVideoControls,
        fit: fit,
        subtitleViewConfiguration:
            subtitleViewConfiguration ?? const SubtitleViewConfiguration(),
      );
    }
    if (e is KumoriyaExoPlayerEngine) {
      final id = e.textureId;
      if (id == null) return const SizedBox.shrink();
      // Wrap in an AspectRatio driven by `onVideoSizeChanged` so the
      // texture never stretches to fill the parent. Falls back to 16:9
      // until Media3 delivers the first video size (matches what the
      // legacy `video_player` branch renders during init).
      return Center(
        child: ValueListenableBuilder<double?>(
          valueListenable: e.aspectRatio,
          builder: (context, ratio, _) {
            return AspectRatio(
              aspectRatio: ratio ?? 16 / 9,
              child: Texture(textureId: id),
            );
          },
        ),
      );
    }
    if (e is ExoPlayerPlaybackEngine) {
      final controller = e.videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const SizedBox.shrink();
      }
      return Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          // External subtitle overlay. VideoPlayerController is itself a
          // ValueListenable<VideoPlayerValue>, so we rebuild only when caption
          // text changes instead of on every frame tick.
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final text = value.caption.text;
              if (text.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ClosedCaption(text: text),
              );
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
