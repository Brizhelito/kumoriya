/// One audio track advertised by Media3's `Player.currentTracks` and
/// surfaced to Dart via the `audioTracks` event.
///
/// [id] is opaque — pass it back verbatim to
/// `KumoriyaExoPlayerController.selectAudioTrack` to pick this track.
/// Internally it encodes the `"groupIndex:trackIndex"` pair of the
/// current `Tracks` snapshot, stable for as long as the media item is
/// loaded.
final class AudioTrack {
  const AudioTrack({
    required this.id,
    this.label,
    this.language,
    this.codec,
    this.channels,
    this.sampleRate,
    this.bitrate,
    this.selected = false,
  });

  final String id;
  final String? label;
  final String? language;
  final String? codec;
  final int? channels;
  final int? sampleRate;
  final int? bitrate;
  final bool selected;

  /// Best-effort human-readable label for UI, falling back through the
  /// usual chain (explicit label → language → id).
  String get displayLabel {
    final l = label;
    if (l != null && l.isNotEmpty) return l;
    final lang = language;
    if (lang != null && lang.isNotEmpty) return lang;
    return 'Track $id';
  }

  static AudioTrack? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return AudioTrack(
      id: id,
      label: raw['label'] as String?,
      language: raw['language'] as String?,
      codec: raw['codec'] as String?,
      channels: (raw['channels'] as num?)?.toInt(),
      sampleRate: (raw['sampleRate'] as num?)?.toInt(),
      bitrate: (raw['bitrate'] as num?)?.toInt(),
      selected: raw['selected'] == true,
    );
  }
}
