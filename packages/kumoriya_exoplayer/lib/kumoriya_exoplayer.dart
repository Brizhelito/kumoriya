/// Kumoriya ExoPlayer — Android-only native playback plugin.
///
/// iOS and desktop consumers get `UnimplementedError` stubs from the
/// platform interface. All public API lives under `src/`.
library;

export 'src/events/cue_event.dart';
export 'src/events/playback_event.dart';
export 'src/kumoriya_exoplayer_controller.dart';
export 'src/models/audio_track.dart';
export 'src/models/diagnostics_snapshot.dart';
export 'src/models/subtitle_track.dart';
export 'src/models/video_track.dart';
export 'src/platform_interface.dart';
