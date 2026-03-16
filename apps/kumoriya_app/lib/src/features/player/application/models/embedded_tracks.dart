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
  const EmbeddedSubtitleTrack({required this.id, this.title, this.language});

  final String id;
  final String? title;
  final String? language;

  String get displayLabel => title ?? language ?? 'Track $id';
}

final class EmbeddedTracks {
  const EmbeddedTracks({
    this.audio = const <EmbeddedAudioTrack>[],
    this.subtitle = const <EmbeddedSubtitleTrack>[],
  });

  final List<EmbeddedAudioTrack> audio;
  final List<EmbeddedSubtitleTrack> subtitle;

  bool get hasMultipleAudio => audio.length > 1;
  bool get hasSubtitles => subtitle.isNotEmpty;

  static const EmbeddedTracks empty = EmbeddedTracks();
}
