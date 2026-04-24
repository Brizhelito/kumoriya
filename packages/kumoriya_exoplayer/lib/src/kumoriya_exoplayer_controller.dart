import 'dart:async';

import 'events/cue_event.dart';
import 'events/playback_event.dart';
import 'models/audio_track.dart';
import 'models/diagnostics_snapshot.dart';
import 'models/subtitle_track.dart';
import 'models/video_track.dart';
import 'platform_interface.dart';

/// High-level Dart handle for a single native player.
///
/// Each controller owns one `textureId`, one Kotlin `PlayerInstance` and one
/// decoded event stream. Meant to be paired with a `Texture(textureId: …)`
/// widget on the render side.
class KumoriyaExoPlayerController {
  KumoriyaExoPlayerController._(this._platform, this.textureId) {
    _eventSub = _platform
        .events(textureId)
        .listen(_onEvent, onError: _onStreamError);
  }

  /// Creates and registers a new native player instance.
  static Future<KumoriyaExoPlayerController> create({
    KumoriyaExoPlayerPlatform? platform,
  }) async {
    final target = platform ?? KumoriyaExoPlayerPlatform.instance;
    final textureId = await target.create();
    return KumoriyaExoPlayerController._(target, textureId);
  }

  final KumoriyaExoPlayerPlatform _platform;

  /// Flutter texture id — use with a `Texture(textureId: ...)` widget.
  final int textureId;

  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _completedController = StreamController<void>.broadcast();
  final _errorController = StreamController<PlaybackErrorEvent>.broadcast();
  final _logController = StreamController<String>.broadcast();
  final _videoSizeController = StreamController<VideoSizeChanged>.broadcast();
  final _audioTracksController = StreamController<List<AudioTrack>>.broadcast();
  final _subtitleTracksController =
      StreamController<List<SubtitleTrack>>.broadcast();
  final _videoTracksController = StreamController<List<VideoTrack>>.broadcast();
  final _urlExpiredController = StreamController<UrlExpired>.broadcast();
  final _diagnosticsController =
      StreamController<DiagnosticsSnapshot>.broadcast();
  final _cueController = StreamController<CueEvent>.broadcast();

  late final StreamSubscription<PlaybackEvent> _eventSub;

  // Cached latest values so late subscribers and getters stay honest.
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  VideoSizeChanged? _videoSize;
  List<AudioTrack> _audioTracks = const <AudioTrack>[];
  List<SubtitleTrack> _subtitleTracks = const <SubtitleTrack>[];
  List<VideoTrack> _videoTracks = const <VideoTrack>[];
  bool _disposed = false;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;

  /// Most recent display-corrected video size, or `null` before the first
  /// `onVideoSizeChanged` from Media3 has been delivered.
  VideoSizeChanged? get videoSize => _videoSize;

  /// Last-known audio track inventory for the current media item. Empty
  /// until Media3 publishes its first `onTracksChanged` snapshot.
  List<AudioTrack> get audioTracks => _audioTracks;

  /// Last-known subtitle (text) track inventory — includes both
  /// embedded tracks and external ones merged via
  /// [addExternalSubtitle]. Empty until the first snapshot arrives.
  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;

  /// Last-known video track inventory (HLS variants). Empty until the
  /// first snapshot arrives, and also when the stream has a single
  /// rendition (progressive MP4, single-variant HLS).
  List<VideoTrack> get videoTracks => _videoTracks;

  bool get isDisposed => _disposed;

  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<void> get completedStream => _completedController.stream;
  Stream<PlaybackErrorEvent> get errorStream => _errorController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<VideoSizeChanged> get videoSizeStream => _videoSizeController.stream;
  Stream<List<AudioTrack>> get audioTracksStream =>
      _audioTracksController.stream;
  Stream<List<SubtitleTrack>> get subtitleTracksStream =>
      _subtitleTracksController.stream;
  Stream<List<VideoTrack>> get videoTracksStream =>
      _videoTracksController.stream;

  /// Fired when Media3 hits a 401/403/410 on the base stream. Consumers
  /// should re-resolve the stream and call [swapUrl] to recover.
  Stream<UrlExpired> get urlExpiredStream => _urlExpiredController.stream;

  /// Periodic stream of diagnostics snapshots once
  /// [setDiagnosticsEnabled] has been called with `true`. Idle stream
  /// otherwise.
  Stream<DiagnosticsSnapshot> get diagnosticsStream =>
      _diagnosticsController.stream;

  /// Subtitle cue events from Media3's TextRenderer. Each event carries
  /// one or more [Cue]s that should be displayed at their respective timestamps.
  Stream<CueEvent> get cueStream => _cueController.stream;

  /// Prepare the native player to play [url] with optional HTTP [headers],
  /// an optional [mimeType] hint (e.g. `application/x-mpegURL` for HLS),
  /// and an optional [startPosition].
  ///
  /// The [mimeType] hint is required for HLS streams whose URL lacks a
  /// `.m3u8` extension — without it Media3's extractor auto-detection
  /// fails with `ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED`.
  Future<void> open(
    String url, {
    Map<String, String> headers = const {},
    String? mimeType,
    Duration? startPosition,
  }) {
    _ensureAlive();
    return _platform.open(
      textureId,
      url,
      headers: headers,
      mimeType: mimeType,
      startPosition: startPosition,
    );
  }

  /// Open an anime.nexus watch URL via the native pipeline (scraping +
  /// auth + WS token signing + HLS playback all in Kotlin). Equivalent
  /// to [open] for any other host.
  Future<void> openAnimeNexus(String watchUrl, {Duration? startPosition}) {
    _ensureAlive();
    return _platform.openAnimeNexus(
      textureId,
      watchUrl,
      startPosition: startPosition,
    );
  }

  Future<void> play() {
    _ensureAlive();
    return _platform.play(textureId);
  }

  Future<void> pause() {
    _ensureAlive();
    return _platform.pause(textureId);
  }

  Future<void> seekTo(Duration position) {
    _ensureAlive();
    return _platform.seek(textureId, position);
  }

  /// Sets the normalised output volume in [0..1]. Values outside the range
  /// are clamped by the native side.
  Future<void> setVolume(double value) {
    _ensureAlive();
    return _platform.setVolume(textureId, value);
  }

  /// Sets the playback speed in multiples of real-time (1.0 = normal).
  Future<void> setPlaybackSpeed(double rate) {
    _ensureAlive();
    return _platform.setSpeed(textureId, rate);
  }

  /// Switch to the embedded audio track identified by [trackId]. Pass the
  /// [AudioTrack.id] value published in [audioTracksStream]. The native
  /// side reuses the same media item, so playback position is preserved
  /// and no re-buffering is triggered beyond what Media3 naturally does
  /// when swapping the decoder input.
  Future<void> selectAudioTrack(String trackId) {
    _ensureAlive();
    return _platform.selectAudioTrack(textureId, trackId);
  }

  /// Pin the current HLS variant to the track identified by [trackId].
  /// Pass the [VideoTrack.id] value published in [videoTracksStream].
  /// Disables ABR until [clearVideoTrackOverride] is called.
  Future<void> selectVideoTrack(String trackId) {
    _ensureAlive();
    return _platform.selectVideoTrack(textureId, trackId);
  }

  /// Drop the manual video-track override — hands quality selection
  /// back to Media3's ABR heuristics.
  Future<void> clearVideoTrackOverride() {
    _ensureAlive();
    return _platform.clearVideoTrackOverride(textureId);
  }

  /// Switch to the subtitle track identified by [trackId]. Works for
  /// both embedded tracks and tracks attached through
  /// [addExternalSubtitle].
  Future<void> selectSubtitleTrack(String trackId) {
    _ensureAlive();
    return _platform.selectSubtitleTrack(textureId, trackId);
  }

  /// Stop rendering subtitles without dropping the track inventory.
  /// The next [selectSubtitleTrack] call re-enables rendering.
  Future<void> clearSubtitleTrack() {
    _ensureAlive();
    return _platform.clearSubtitleTrack(textureId);
  }

  /// Set the preferred subtitle languages for auto-selection.
  Future<void> setPreferredSubtitleLanguages(List<String> languages) {
    _ensureAlive();
    return _platform.setPreferredSubtitleLanguages(textureId, languages);
  }

  /// Attach an external subtitle file to the currently playing stream.
  /// Position is preserved across the attach. [mimeType] must be one of
  /// `text/vtt`, `application/x-subrip`, `text/x-ssa` (aliases accepted).
  Future<void> addExternalSubtitle({
    required String uri,
    required String mimeType,
    String? language,
    String? label,
  }) {
    _ensureAlive();
    return _platform.addExternalSubtitle(
      textureId,
      uri: uri,
      mimeType: mimeType,
      language: language,
      label: label,
    );
  }

  /// Detach every external subtitle previously attached via
  /// [addExternalSubtitle], reverting the player to the bare base
  /// stream. Embedded subtitles are unaffected.
  Future<void> clearExternalSubtitles() {
    _ensureAlive();
    return _platform.clearExternalSubtitles(textureId);
  }

  /// Apply a global gain in decibels on top of the master volume.
  /// `0.0` disables the boost; negative values are clamped to 0 (use
  /// [setVolume] for attenuation).
  Future<void> setOverallGainDb(double db) {
    _ensureAlive();
    return _platform.setOverallGainDb(textureId, db);
  }

  /// Apply the voice-clarity EQ preset at [strength] (0..1). No-op on
  /// API < 28 devices; the call still succeeds silently.
  Future<void> setVoiceClarity(double strength) {
    _ensureAlive();
    return _platform.setVoiceClarity(textureId, strength);
  }

  /// Toggle the diagnostics pipeline on ([enabled]=true) or off
  /// ([enabled]=false). See [diagnosticsStream].
  Future<void> setDiagnosticsEnabled(bool enabled) {
    _ensureAlive();
    return _platform.setDiagnosticsEnabled(textureId, enabled);
  }

  /// Swap the currently playing base URL for a freshly-resolved one,
  /// preserving playback position (or using [startPosition] when
  /// provided). Intended as the recovery action for an [UrlExpired]
  /// event.
  Future<void> swapUrl(
    String url, {
    Map<String, String> headers = const <String, String>{},
    String? mimeType,
    Duration? startPosition,
  }) {
    _ensureAlive();
    return _platform.swapUrl(
      textureId,
      url: url,
      headers: headers,
      mimeType: mimeType,
      startPosition: startPosition,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSub.cancel();
    await _platform.dispose(textureId);
    await _playingController.close();
    await _bufferingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
    await _errorController.close();
    await _logController.close();
    await _videoSizeController.close();
    await _audioTracksController.close();
    await _subtitleTracksController.close();
    await _videoTracksController.close();
    await _urlExpiredController.close();
    await _diagnosticsController.close();
    await _cueController.close();
  }

  // --- Internals -----------------------------------------------------

  void _onEvent(PlaybackEvent event) {
    switch (event) {
      case PlayingChanged(:final isPlaying):
        _isPlaying = isPlaying;
        _playingController.add(isPlaying);
      case BufferingChanged(:final isBuffering):
        _isBuffering = isBuffering;
        _bufferingController.add(isBuffering);
      case PositionTick(:final position):
        _position = position;
        _positionController.add(position);
      case DurationResolved(:final duration):
        _duration = duration;
        _durationController.add(duration);
      case Completed():
        _completedController.add(null);
      case PlaybackErrorEvent():
        _errorController.add(event);
      case NativeLog(:final message):
        _logController.add(message);
      case VideoSizeChanged():
        _videoSize = event;
        _videoSizeController.add(event);
      case AudioTracksChanged(:final tracks):
        _audioTracks = tracks;
        _audioTracksController.add(tracks);
      case SubtitleTracksChanged(:final tracks):
        _subtitleTracks = tracks;
        _subtitleTracksController.add(tracks);
      case VideoTracksChanged(:final tracks):
        _videoTracks = tracks;
        _videoTracksController.add(tracks);
      case UrlExpired():
        _urlExpiredController.add(event);
      case DiagnosticsReport(:final snapshot):
        _diagnosticsController.add(snapshot);
      case CueEvent(:final cues):
        _cueController.add(CueEvent(cues));
    }
  }

  void _onStreamError(Object error, StackTrace stack) {
    _errorController.add(
      PlaybackErrorEvent(
        code: 'event_channel_error',
        message: error.toString(),
      ),
    );
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('KumoriyaExoPlayerController($textureId) is disposed');
    }
  }
}
