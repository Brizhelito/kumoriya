/// One video track (HLS variant) advertised by Media3's
/// `Player.currentTracks` and surfaced to Dart via the `videoTracks`
/// event. Used by the quality picker on streams that use a single
/// HLS master manifest rather than multiple resolved URLs.
///
/// [id] is opaque — pass it back verbatim to
/// `KumoriyaExoPlayerController.selectVideoTrack` to pin this variant.
/// Encodes the `"groupIndex:trackIndex"` pair of the current `Tracks`
/// snapshot, stable while the media item is loaded.
final class VideoTrack {
  const VideoTrack({
    required this.id,
    this.label,
    this.codec,
    this.width,
    this.height,
    this.bitrate,
    this.frameRate,
    this.selected = false,
  });

  final String id;
  final String? label;
  final String? codec;
  final int? width;
  final int? height;
  final int? bitrate;
  final double? frameRate;
  final bool selected;

  /// Best-effort human-readable quality label for UI. Prefers the
  /// vertical resolution (e.g. `1080p`), then explicit label, then id.
  String get displayLabel {
    final h = height;
    if (h != null && h > 0) return '${h}p';
    final l = label;
    if (l != null && l.isNotEmpty) return l;
    return 'Track $id';
  }

  static VideoTrack? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return VideoTrack(
      id: id,
      label: raw['label'] as String?,
      codec: raw['codec'] as String?,
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
      bitrate: (raw['bitrate'] as num?)?.toInt(),
      frameRate: (raw['frameRate'] as num?)?.toDouble(),
      selected: raw['selected'] == true,
    );
  }
}
