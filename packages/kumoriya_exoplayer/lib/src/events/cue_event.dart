import '../models/subtitle_cue.dart';
import 'playback_event.dart';

/// Event emitted by Media3 when subtitle cues become active.
///
/// Fires when cue(s) should be displayed. An empty list means no active
/// cues (subtitles should be hidden). Media3 handles timing internally.
class CueEvent extends PlaybackEvent {
  final List<SubtitleCue> cues;

  const CueEvent(this.cues);

  /// Returns the first cue with non-empty text, or null if no active cue.
  SubtitleCue? get activeCue {
    for (final cue in cues) {
      if (cue.text != null && cue.text!.isNotEmpty) {
        return cue;
      }
    }
    return null;
  }
}
