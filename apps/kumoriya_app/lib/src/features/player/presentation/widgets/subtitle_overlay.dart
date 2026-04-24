import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kumoriya_exoplayer/src/events/cue_event.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Renders subtitle cues as a positioned text overlay.
///
/// Listens to the cue stream from the native ExoPlayer and displays the
/// currently active cue text with styling from [SubtitleViewConfiguration].
/// Media3 handles cue timing internally - cues are delivered when active
/// and the list is cleared when no cues should display.
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({
    super.key,
    required this.cueStream,
    this.configuration,
  });

  /// Stream of subtitle cue events from the playback engine.
  final Stream<CueEvent> cueStream;

  /// Visual styling configuration (font, color, shadows, padding).
  /// If null, subtitles are not rendered.
  final SubtitleViewConfiguration? configuration;

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  StreamSubscription<CueEvent>? _cueSub;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _cueSub = widget.cueStream.listen(_onCueEvent);
  }

  @override
  void didUpdateWidget(SubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cueStream != oldWidget.cueStream) {
      _cueSub?.cancel();
      _cueSub = widget.cueStream.listen(_onCueEvent);
    }
  }

  @override
  void dispose() {
    _cueSub?.cancel();
    super.dispose();
  }

  void _onCueEvent(CueEvent event) {
    final newText = event.activeCue?.text;
    if (newText != _displayText) {
      setState(() => _displayText = newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration;
    final text = _displayText;

    // Don't render if disabled or no text
    if (config == null || text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: config.padding.bottom,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: config.padding.left),
        child: Text(
          text,
          style: config.style,
          textAlign: config.textAlign,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}
