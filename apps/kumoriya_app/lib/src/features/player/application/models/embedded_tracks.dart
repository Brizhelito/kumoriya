// Lightweight representations of embedded audio/subtitle tracks reported by
// the playback engine.  These are framework-agnostic — they do NOT depend on
// media_kit types — so the interface stays clean.

final class EmbeddedAudioTrack {
  const EmbeddedAudioTrack({required this.id, this.title, this.language});

  final String id;
  final String? title;
  final String? language;

  String get displayLabel => title ?? language ?? 'Track $id';
}

final class EmbeddedSubtitleTrack {
  const EmbeddedSubtitleTrack({
    required this.id,
    this.title,
    this.language,
    this.selected = false,
  });

  final String id;
  final String? title;
  final String? language;
  final bool selected;

  String get displayLabel => title ?? language ?? 'Track $id';
}

/// A single HLS video variant (quality ladder step) surfaced by the
/// playback engine. Framework-agnostic on purpose — the Media3-specific
/// metadata stays behind the plugin.
final class EmbeddedVideoTrack {
  const EmbeddedVideoTrack({
    required this.id,
    this.label,
    this.width,
    this.height,
    this.bitrate,
    this.frameRate,
    this.selected = false,
  });

  final String id;
  final String? label;
  final int? width;
  final int? height;
  final int? bitrate;
  final double? frameRate;
  final bool selected;

  /// Best-effort quality label for UI — prefers vertical resolution
  /// (`1080p`), then explicit label, then id.
  String get displayLabel {
    final h = height;
    if (h != null && h > 0) return '${h}p';
    final l = label;
    if (l != null && l.isNotEmpty) return l;
    return 'Track $id';
  }
}

final class EmbeddedTracks {
  const EmbeddedTracks({
    this.audio = const <EmbeddedAudioTrack>[],
    this.subtitle = const <EmbeddedSubtitleTrack>[],
    this.video = const <EmbeddedVideoTrack>[],
  });

  final List<EmbeddedAudioTrack> audio;
  final List<EmbeddedSubtitleTrack> subtitle;
  final List<EmbeddedVideoTrack> video;

  bool get hasMultipleAudio => audio.length > 1;
  bool get hasSubtitles => subtitle.isNotEmpty;
  bool get hasMultipleVideoVariants => video.length > 1;

  static const EmbeddedTracks empty = EmbeddedTracks();
}
