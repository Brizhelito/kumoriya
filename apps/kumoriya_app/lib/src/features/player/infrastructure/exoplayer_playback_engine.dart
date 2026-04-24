import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:video_player/video_player.dart';

import '../application/models/embedded_tracks.dart';
import '../application/models/player_diagnostics.dart';
import '../application/services/playback_engine.dart';

/// A PlaybackEngine backed by the Android ExoPlayer/Media3 stack via Flutter's
/// official `video_player` package.
///
/// Scope: deliberately narrow. This engine is used by the Player Flow
/// Playground for side-by-side comparison against [MediaKitPlaybackEngine],
/// and as a targeted AV1 fast-path on Android where libmpv/libdav1d is the
/// bottleneck (see Zilla / anime.nexus probes). It intentionally does NOT
/// implement features outside the orchestrator's steady-state streaming
/// contract:
///
/// - Embedded audio/subtitle switching (no-op)
/// - External subtitle attach (no-op — rare on AV1 streams)
/// - Smart audio boost (no-op)
/// - Predictive prewarm (no-op)
///
/// For those features keep media_kit as the active engine.
final class ExoPlayerPlaybackEngine implements PlaybackEngine {
  ExoPlayerPlaybackEngine();

  VideoPlayerController? _controller;
  StreamSubscription<void>? _internalTicker;

  /// Expose the underlying controller so the surface widget can wire the
  /// texture. Null when no open call has succeeded yet.
  VideoPlayerController? get videoController => _controller;

  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffered =
      StreamController<Duration>.broadcast();

  Completer<void>? _firstFrameCompleter;

  bool _disposed = false;
  bool _lastPlaying = false;
  bool _lastBuffering = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  Duration _lastBuffered = Duration.zero;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<bool> get bufferingStream => _buffering.stream;

  @override
  Stream<bool> get completedStream => _completed.stream;

  @override
  Stream<String> get errorStream => _errors.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Stream<Duration> get bufferStream => _buffered.stream;

  @override
  Stream<EmbeddedTracks> get embeddedTracksStream =>
      const Stream<EmbeddedTracks>.empty();

  @override
  Stream<double> get bufferingPercentageStream => const Stream<double>.empty();

  @override
  Stream<PlayerDiagnostics> get diagnosticsStream =>
      const Stream<PlayerDiagnostics>.empty();

  @override
  Future<void> get firstFrameRendered =>
      (_firstFrameCompleter ?? Completer<void>()).future;

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    if (_disposed) return;
    await _disposeController();

    _firstFrameCompleter = Completer<void>();

    final headers = <String, String>{
      for (final entry in stream.headers.entries) entry.key: entry.value,
    };

    if (kDebugMode) {
      debugPrint(
        '[exoplayer] open host=${stream.url.host} '
        'scheme=${stream.url.scheme} isHls=${stream.isHls} '
        'headerKeys=${headers.keys.toList()} '
        'url=${stream.url}',
      );
    }

    final controller = VideoPlayerController.networkUrl(
      stream.url,
      httpHeaders: headers,
      formatHint: stream.isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
    );
    _controller = controller;

    controller.addListener(_handleControllerUpdate);

    try {
      await controller.initialize();
      if (_disposed) return;
      if (startPosition != null && startPosition > Duration.zero) {
        await controller.seekTo(startPosition);
      }
      _lastDuration = controller.value.duration;
      _duration.add(_lastDuration);
      await controller.play();
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[exoplayer] open failed: $error\n$stack');
      }
      if (!_errors.isClosed) {
        _errors.add('exoplayer.open_failed: $error');
      }
      rethrow;
    }
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (controller == null || _disposed) return;
    final value = controller.value;

    // Surface initialization errors.
    final error = value.errorDescription;
    if (error != null && error.isNotEmpty) {
      if (!_errors.isClosed) _errors.add(error);
    }

    // Position.
    if (value.position != _lastPosition) {
      _lastPosition = value.position;
      if (!_position.isClosed) _position.add(value.position);
      // First-frame heuristic: ExoPlayer's Flutter surface doesn't expose a
      // first-frame callback, so use position > 0 as a proxy. For the
      // playground's open/observe flow this is equivalent — the caller only
      // needs to know that the decoder has produced displayable output.
      if (value.position > Duration.zero &&
          _firstFrameCompleter != null &&
          !_firstFrameCompleter!.isCompleted) {
        _firstFrameCompleter!.complete();
      }
    }

    // Duration.
    if (value.duration != _lastDuration && value.duration > Duration.zero) {
      _lastDuration = value.duration;
      if (!_duration.isClosed) _duration.add(value.duration);
    }

    // Buffered (use the end of the last buffered range).
    final ranges = value.buffered;
    if (ranges.isNotEmpty) {
      final end = ranges.last.end;
      if (end != _lastBuffered) {
        _lastBuffered = end;
        if (!_buffered.isClosed) _buffered.add(end);
      }
    }

    // Buffering state.
    final buffering = value.isBuffering;
    if (buffering != _lastBuffering) {
      _lastBuffering = buffering;
      if (!_buffering.isClosed) _buffering.add(buffering);
    }

    // Playing state.
    final playing = value.isPlaying;
    if (playing != _lastPlaying) {
      _lastPlaying = playing;
      if (!_playing.isClosed) _playing.add(playing);
    }

    // Completed.
    if (value.isCompleted) {
      if (!_completed.isClosed) _completed.add(true);
    }
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> setVolume(double percent) async {
    // video_player accepts 0..1. Clamp the 0..300 boost range media_kit
    // exposes — ExoPlayer has no equivalent post-gain and would NaN-out.
    final clamped = (percent / 100.0).clamp(0.0, 1.0);
    await _controller?.setVolume(clamped);
  }

  @override
  Future<void> setPlaybackSpeed(double rate) async {
    await _controller?.setPlaybackSpeed(rate);
  }

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) async {
    final controller = _controller;
    debugPrint(
      '[exoplayer.subs] setSubtitleTrack id=${track.id} label=${track.label} '
      'hasData=${track.data != null} hasUri=${track.uri != null} '
      'controllerNull=${controller == null} disposed=$_disposed',
    );
    if (controller == null || _disposed) return;
    try {
      final text = await _loadSubtitleText(track);
      if (text == null || text.isEmpty) {
        debugPrint('[exoplayer.subs] subtitle text empty/null — aborting');
        return;
      }
      final trimmed = text.trimLeft();
      final head = trimmed.substring(
        0,
        trimmed.length < 80 ? trimmed.length : 80,
      );
      final isWebVtt = head.startsWith('WEBVTT');
      debugPrint(
        '[exoplayer.subs] loaded textLen=${text.length} isWebVtt=$isWebVtt '
        'head="${head.replaceAll('\n', '\\n')}"',
      );
      final ClosedCaptionFile file = isWebVtt
          ? WebVTTCaptionFile(text)
          : SubRipCaptionFile(text);
      debugPrint(
        '[exoplayer.subs] parsed captionCount=${file.captions.length} '
        'first=${file.captions.isEmpty ? "<none>" : "${file.captions.first.start}-${file.captions.first.end} ${file.captions.first.text}"}',
      );
      await controller.setClosedCaptionFile(
        Future<ClosedCaptionFile>.value(file),
      );
      debugPrint('[exoplayer.subs] setClosedCaptionFile done');
    } catch (error, stack) {
      debugPrint('[exoplayer.subs] setSubtitleTrack FAILED: $error\n$stack');
    }
  }

  @override
  Future<void> clearSubtitleTrack() async {
    final controller = _controller;
    if (controller == null || _disposed) return;
    await controller.setClosedCaptionFile(null);
  }

  /// Loads the raw subtitle text from either [ExternalSubtitleTrack.data] or
  /// [ExternalSubtitleTrack.uri]. Returns `null` on failure so the caller can
  /// short-circuit without throwing.
  Future<String?> _loadSubtitleText(ExternalSubtitleTrack track) async {
    final inline = track.data;
    if (inline != null && inline.isNotEmpty) return inline;
    final uri = track.uri;
    if (uri == null) return null;
    if (uri.scheme == 'data') {
      // data:text/vtt;charset=utf-8,WEBVTT%0A...
      return Uri.decodeComponent(uri.data?.contentText ?? '');
    }
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      return await resp.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> setEmbeddedAudioTrack(EmbeddedAudioTrack track) async {}

  @override
  Future<void> setEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) async {}

  @override
  Future<void> clearEmbeddedSubtitleTrack() async {}

  @override
  Future<void> setPreferredSubtitleLanguages(List<String> languages) async {}

  @override
  Future<void> setEmbeddedVideoTrack(EmbeddedVideoTrack track) async {}

  @override
  Future<void> clearEmbeddedVideoTrack() async {}

  @override
  Future<void> signalPredictivePrewarm(Duration position) async {}

  @override
  Future<void> setSmartAudioBoost({required bool enabled}) async {}

  @override
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {}

  Future<void> _disposeController() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.removeListener(_handleControllerUpdate);
    try {
      await controller.dispose();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _internalTicker?.cancel();
    await _disposeController();
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _errors.close();
    await _position.close();
    await _duration.close();
    await _buffered.close();
  }
}
