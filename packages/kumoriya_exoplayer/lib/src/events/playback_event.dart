import '../models/audio_track.dart';
import '../models/diagnostics_snapshot.dart';
import '../models/subtitle_cue.dart';
import '../models/subtitle_track.dart';
import '../models/video_track.dart';
import 'cue_event.dart';

/// Playback events emitted by the native `dev.kumoriya.exoplayer/events/<id>`
/// channel, parsed from the raw `Map` payload sent by Kotlin.
abstract class PlaybackEvent {
  const PlaybackEvent();

  /// Decode a raw payload from the event channel. Returns `null` when the
  /// payload is malformed or refers to an unknown event name — the caller
  /// is expected to ignore those instead of crashing.
  static PlaybackEvent? tryParse(Object? payload) {
    if (payload is! Map) return null;
    final event = payload['event'];
    if (event is! String) return null;
    final value = payload['value'];
    switch (event) {
      case 'playing':
        if (value is! bool) return null;
        return PlayingChanged(value);
      case 'buffering':
        if (value is! bool) return null;
        return BufferingChanged(value);
      case 'position':
        if (value is! num) return null;
        return PositionTick(Duration(milliseconds: value.toInt()));
      case 'duration':
        if (value is! num) return null;
        return DurationResolved(Duration(milliseconds: value.toInt()));
      case 'completed':
        if (value != true) return null;
        return const Completed();
      case 'error':
        final code = payload['code'];
        final message = payload['message'];
        if (code is! String || message is! String) return null;
        return PlaybackErrorEvent(code: code, message: message);
      case 'log':
        if (value is! String) return null;
        return NativeLog(value);
      case 'videoSize':
        final width = payload['width'];
        final height = payload['height'];
        if (width is! num || height is! num) return null;
        final w = width.toDouble();
        final h = height.toDouble();
        if (w <= 0 || h <= 0) return null;
        return VideoSizeChanged(width: w, height: h);
      case 'audioTracks':
        if (value is! List) return null;
        final tracks = <AudioTrack>[];
        for (final entry in value) {
          final parsed = AudioTrack.tryParse(entry);
          if (parsed != null) tracks.add(parsed);
        }
        return AudioTracksChanged(List.unmodifiable(tracks));
      case 'subtitleTracks':
        if (value is! List) return null;
        final tracks = <SubtitleTrack>[];
        for (final entry in value) {
          final parsed = SubtitleTrack.tryParse(entry);
          if (parsed != null) tracks.add(parsed);
        }
        return SubtitleTracksChanged(List.unmodifiable(tracks));
      case 'videoTracks':
        if (value is! List) return null;
        final tracks = <VideoTrack>[];
        for (final entry in value) {
          final parsed = VideoTrack.tryParse(entry);
          if (parsed != null) tracks.add(parsed);
        }
        return VideoTracksChanged(List.unmodifiable(tracks));
      case 'diagnostics':
        final snapshot = DiagnosticsSnapshot.tryParse(value);
        if (snapshot == null) return null;
        return DiagnosticsReport(snapshot);
      case 'urlExpired':
        final url = payload['url'];
        final httpCode = payload['httpCode'];
        if (url is! String || url.isEmpty) return null;
        return UrlExpired(
          url: url,
          httpCode: httpCode is int ? httpCode : null,
        );
      case 'subtitleCue':
        if (value is! List) return null;
        final cues = <SubtitleCue>[];
        for (final entry in value) {
          if (entry is Map) {
            final parsed = SubtitleCue.tryParse(entry);
            cues.add(parsed);
          }
        }
        return CueEvent(List.unmodifiable(cues));
      default:
        return null;
    }
  }
}

class PlayingChanged extends PlaybackEvent {
  const PlayingChanged(this.isPlaying);
  final bool isPlaying;
}

class BufferingChanged extends PlaybackEvent {
  const BufferingChanged(this.isBuffering);
  final bool isBuffering;
}

class PositionTick extends PlaybackEvent {
  const PositionTick(this.position);
  final Duration position;
}

class DurationResolved extends PlaybackEvent {
  const DurationResolved(this.duration);
  final Duration duration;
}

class Completed extends PlaybackEvent {
  const Completed();
}

class PlaybackErrorEvent extends PlaybackEvent {
  const PlaybackErrorEvent({required this.code, required this.message});
  final String code;
  final String message;
}

/// Free-form diagnostic log line emitted by the native side (e.g. the
/// anime.nexus bootstrap chain). Surfaced mainly for the playground so the
/// device log and the Flutter UI see the same pipeline.
class NativeLog extends PlaybackEvent {
  const NativeLog(this.message);
  final String message;
}

/// Display-corrected video dimensions emitted every time Media3's
/// `Player.Listener#onVideoSizeChanged` fires.
///
/// The Kotlin side pre-multiplies [width] by the stream's pixel aspect
/// ratio, so consumers can feed [aspectRatio] straight into an
/// `AspectRatio` widget without dealing with anamorphic pixels.
class VideoSizeChanged extends PlaybackEvent {
  const VideoSizeChanged({required this.width, required this.height});

  final double width;
  final double height;

  double get aspectRatio {
    if (height <= 0) return 16 / 9;
    return width / height;
  }
}

/// Emitted whenever Media3 publishes a new `Tracks` snapshot. Carries
/// the full audio-track inventory — consumers can swap to a specific
/// track by feeding [AudioTrack.id] back into
/// `KumoriyaExoPlayerController.selectAudioTrack`.
class AudioTracksChanged extends PlaybackEvent {
  const AudioTracksChanged(this.tracks);

  final List<AudioTrack> tracks;

  /// Currently selected track, or `null` when Media3 hasn't picked one
  /// yet (pre-ready state) or the stream has no audio.
  AudioTrack? get selected =>
      tracks.where((t) => t.selected).cast<AudioTrack?>().firstOrNull;
}

extension on Iterable<AudioTrack?> {
  AudioTrack? get firstOrNull => isEmpty ? null : first;
}

/// Emitted whenever Media3 publishes a new `Tracks` snapshot carrying
/// text-type tracks. Use [SubtitleTrack.id] with
/// `KumoriyaExoPlayerController.selectSubtitleTrack` to switch tracks,
/// or `clearSubtitleTrack` to disable rendering.
class SubtitleTracksChanged extends PlaybackEvent {
  const SubtitleTracksChanged(this.tracks);

  final List<SubtitleTrack> tracks;

  /// Currently selected track, or `null` when nothing is rendered
  /// (either the user disabled subs, or the stream has none).
  SubtitleTrack? get selected =>
      tracks.where((t) => t.selected).cast<SubtitleTrack?>().firstOrNull;
}

extension on Iterable<SubtitleTrack?> {
  SubtitleTrack? get firstOrNull => isEmpty ? null : first;
}

/// Emitted whenever Media3 publishes a new `Tracks` snapshot carrying
/// video-type tracks (HLS variants). Feed [VideoTrack.id] back into
/// `KumoriyaExoPlayerController.selectVideoTrack` to pin a quality,
/// or call `clearVideoTrackOverride` to return to ABR.
class VideoTracksChanged extends PlaybackEvent {
  const VideoTracksChanged(this.tracks);

  final List<VideoTrack> tracks;

  /// Currently selected variant, or `null` when Media3 hasn't picked
  /// one yet or the stream has a single variant (ABR no-op).
  VideoTrack? get selected =>
      tracks.where((t) => t.selected).cast<VideoTrack?>().firstOrNull;
}

extension on Iterable<VideoTrack?> {
  VideoTrack? get firstOrNull => isEmpty ? null : first;
}

/// Periodic diagnostics snapshot, emitted roughly every second while
/// diagnostics are enabled on the controller. Callers typically forward
/// [snapshot] straight into the diagnostics overlay widget.
class DiagnosticsReport extends PlaybackEvent {
  const DiagnosticsReport(this.snapshot);

  final DiagnosticsSnapshot snapshot;
}

/// Emitted when Media3 fails a base-source fetch with an HTTP status
/// that almost always means the signed URL has been rotated or revoked
/// (401, 403, 410). Consumers are expected to re-resolve the stream and
/// call `swapUrl` to recover without bouncing through the full open
/// pipeline. A subsequent `error` event is still emitted so callers that
/// don't handle [UrlExpired] keep seeing the terminal failure.
class UrlExpired extends PlaybackEvent {
  const UrlExpired({required this.url, this.httpCode});

  /// The URL Media3 was trying to fetch when the auth/expiry status
  /// arrived — matches whatever was last passed to `open` or `swapUrl`.
  final String url;

  /// HTTP response code that triggered the hint (401, 403, 410). `null`
  /// when Kotlin could not extract it from the cause chain.
  final int? httpCode;
}
