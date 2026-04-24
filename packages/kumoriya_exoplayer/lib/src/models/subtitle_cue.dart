/// A single subtitle cue (text segment) decoded by Media3.
///
/// Carries the display text and optional positioning hints from the
/// source subtitle format (SSA/ASS/SRT/WebVTT).
///
/// Note: Media3 does not expose cue timestamps through [onCues]. Timing
/// is handled by Media3 internally - cues are delivered when active
/// and cleared automatically when the next cue arrives or when the
/// overlay receives an empty cue list.
class SubtitleCue {
  final String? text;
  final double? line;
  final int lineType;
  final double position;

  const SubtitleCue({
    this.text,
    this.line,
    required this.lineType,
    required this.position,
  });

  factory SubtitleCue.tryParse(Map<dynamic, dynamic> json) {
    return SubtitleCue(
      text: json['text'] as String?,
      line: (json['line'] as num?)?.toDouble(),
      lineType: (json['lineType'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
