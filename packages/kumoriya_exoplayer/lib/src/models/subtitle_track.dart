/// One subtitle (text) track surfaced by Media3's `Player.currentTracks`.
///
/// Identifiers follow the same opaque `"groupIndex:trackIndex"` encoding
/// as [AudioTrack.id] — pass them back verbatim to
/// `KumoriyaExoPlayerController.selectSubtitleTrack` to switch, or call
/// `clearSubtitleTrack` to disable rendering altogether.
final class SubtitleTrack {
  const SubtitleTrack({
    required this.id,
    this.label,
    this.language,
    this.codec,
    this.mimeType,
    this.selected = false,
  });

  final String id;
  final String? label;
  final String? language;
  final String? codec;
  final String? mimeType;
  final bool selected;

  /// Best-effort human-readable label for UI (label → language → id).
  String get displayLabel {
    final l = label;
    if (l != null && l.isNotEmpty) return l;
    final lang = language;
    if (lang != null && lang.isNotEmpty) return lang;
    return 'Subtitle $id';
  }

  static SubtitleTrack? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return SubtitleTrack(
      id: id,
      label: raw['label'] as String?,
      language: raw['language'] as String?,
      codec: raw['codec'] as String?,
      mimeType: raw['mimeType'] as String?,
      selected: raw['selected'] == true,
    );
  }
}
