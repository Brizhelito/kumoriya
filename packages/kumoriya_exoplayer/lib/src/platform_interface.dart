import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'events/playback_event.dart';

/// Low level bridge between Dart and the native plugin.
///
/// Consumers should use `KumoriyaExoPlayerController` instead of talking to
/// this interface directly — it only exists to make the method channel
/// swappable in tests and to keep iOS/desktop stubs honest.
abstract class KumoriyaExoPlayerPlatform extends PlatformInterface {
  KumoriyaExoPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static KumoriyaExoPlayerPlatform _instance = MethodChannelKumoriyaExoPlayer();

  static KumoriyaExoPlayerPlatform get instance => _instance;

  static set instance(KumoriyaExoPlayerPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  /// Round trip used by tests and the host-app smoke check.
  Future<String> ping();

  /// Creates a native player instance and returns the Flutter texture id
  /// backing its surface.
  Future<int> create();

  /// Prepares the player for [url], optionally injecting HTTP [headers],
  /// a [mimeType] hint (e.g. `application/x-mpegURL` for HLS streams whose
  /// URL lacks a `.m3u8` extension), and starting from [startPosition].
  Future<void> open(
    int textureId,
    String url, {
    Map<String, String> headers = const {},
    String? mimeType,
    Duration? startPosition,
  });

  /// Opens an anime.nexus watch URL entirely natively — the Kotlin plugin
  /// runs the full bootstrap + WS handshake + signed CDN fetches. Replaces
  /// the legacy Dart loopback proxy.
  Future<void> openAnimeNexus(
    int textureId,
    String watchUrl, {
    Duration? startPosition,
  });

  Future<void> play(int textureId);
  Future<void> pause(int textureId);
  Future<void> seek(int textureId, Duration position);
  Future<void> setVolume(int textureId, double value);
  Future<void> setSpeed(int textureId, double rate);

  /// Switch the active embedded audio track for [textureId]. Callers pass
  /// the opaque id obtained from an `audioTracks` event payload.
  Future<void> selectAudioTrack(int textureId, String trackId);

  /// Pin the active video track (HLS variant) for [textureId]. Callers
  /// pass the opaque id obtained from a `videoTracks` event payload.
  /// Disables ABR for the video type until [clearVideoTrackOverride] is
  /// called.
  Future<void> selectVideoTrack(int textureId, String trackId);

  /// Drop the manual video-track override — hands quality selection
  /// back to Media3's ABR heuristics.
  Future<void> clearVideoTrackOverride(int textureId);

  /// Switch the active subtitle (text) track. Ids come from the
  /// `subtitleTracks` event payload and cover both embedded and merged
  /// external tracks.
  Future<void> selectSubtitleTrack(int textureId, String trackId);

  /// Disable subtitle rendering without unmounting the tracks — the
  /// inventory stays available; next `selectSubtitleTrack` re-enables.
  Future<void> clearSubtitleTrack(int textureId);

  /// Set the preferred subtitle languages for auto-selection.
  Future<void> setPreferredSubtitleLanguages(
    int textureId,
    List<String> languages,
  );

  /// Merge an external subtitle file ([uri]) on top of the current base
  /// stream, preserving playback position. [mimeType] must be one of
  /// `text/vtt`, `application/x-subrip`, `text/x-ssa` (or their
  /// commonly-used aliases).
  Future<void> addExternalSubtitle(
    int textureId, {
    required String uri,
    required String mimeType,
    String? language,
    String? label,
  });

  /// Drop every merged external subtitle and revert the player to the
  /// bare base stream. Embedded subtitles (inside the container) stay.
  Future<void> clearExternalSubtitles(int textureId);

  /// Apply a global [db] gain on top of the master volume. `0.0`
  /// disables the effect; negative values are clamped to `0.0` (use
  /// [setVolume] for attenuation).
  Future<void> setOverallGainDb(int textureId, double db);

  /// Apply the voice-clarity EQ preset at [strength] (0..1). `0`
  /// disables the effect. No-op on API < 28.
  Future<void> setVoiceClarity(int textureId, double strength);

  /// Toggle the diagnostics pipeline. When enabled the native side
  /// attaches an analytics listener and emits `diagnostics` events at
  /// ~1 Hz; when disabled the listener is removed and events stop.
  Future<void> setDiagnosticsEnabled(int textureId, bool enabled);

  /// Replace the current base stream with [url] preserving playback
  /// position (unless [startPosition] is passed, in which case that
  /// position is used). Used for URL-refresh recovery after an
  /// `urlExpired` event.
  Future<void> swapUrl(
    int textureId, {
    required String url,
    Map<String, String> headers = const <String, String>{},
    String? mimeType,
    Duration? startPosition,
  });

  /// Releases the native player for [textureId]. Returns `true` if the
  /// instance existed.
  Future<bool> dispose(int textureId);

  /// Stream of decoded playback events for [textureId]. Implementations must
  /// return a broadcast stream or equivalent — callers may subscribe more
  /// than once.
  Stream<PlaybackEvent> events(int textureId);
}

/// Default implementation backed by the `dev.kumoriya.exoplayer/methods`
/// [MethodChannel] — wired up by the native Android plugin.
class MethodChannelKumoriyaExoPlayer extends KumoriyaExoPlayerPlatform {
  MethodChannelKumoriyaExoPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_methodsChannel);

  static const String _methodsChannel = 'dev.kumoriya.exoplayer/methods';
  static const String _eventsChannelPrefix = 'dev.kumoriya.exoplayer/events/';

  final MethodChannel _channel;

  @override
  Future<String> ping() async {
    final result = await _channel.invokeMethod<String>('ping');
    return result ?? '';
  }

  @override
  Future<int> create() async {
    final result = await _channel.invokeMapMethod<String, Object?>('create');
    final textureId = result?['textureId'];
    if (textureId is! int) {
      throw StateError(
        'KumoriyaExoPlayer.create returned invalid payload: $result',
      );
    }
    return textureId;
  }

  @override
  Future<void> open(
    int textureId,
    String url, {
    Map<String, String> headers = const {},
    String? mimeType,
    Duration? startPosition,
  }) {
    return _channel.invokeMethod<void>('open', {
      'textureId': textureId,
      'url': url,
      'headers': headers,
      'mimeType': ?mimeType,
      if (startPosition != null)
        'startPositionMs': startPosition.inMilliseconds,
    });
  }

  @override
  Future<void> openAnimeNexus(
    int textureId,
    String watchUrl, {
    Duration? startPosition,
  }) {
    return _channel.invokeMethod<void>('openNexus', {
      'textureId': textureId,
      'watchUrl': watchUrl,
      if (startPosition != null)
        'startPositionMs': startPosition.inMilliseconds,
    });
  }

  @override
  Future<void> play(int textureId) =>
      _channel.invokeMethod<void>('play', {'textureId': textureId});

  @override
  Future<void> pause(int textureId) =>
      _channel.invokeMethod<void>('pause', {'textureId': textureId});

  @override
  Future<void> seek(int textureId, Duration position) {
    return _channel.invokeMethod<void>('seek', {
      'textureId': textureId,
      'positionMs': position.inMilliseconds,
    });
  }

  @override
  Future<void> setVolume(int textureId, double value) {
    return _channel.invokeMethod<void>('setVolume', {
      'textureId': textureId,
      'value': value,
    });
  }

  @override
  Future<void> setSpeed(int textureId, double rate) {
    return _channel.invokeMethod<void>('setSpeed', {
      'textureId': textureId,
      'rate': rate,
    });
  }

  @override
  Future<void> selectAudioTrack(int textureId, String trackId) {
    return _channel.invokeMethod<void>('selectAudioTrack', {
      'textureId': textureId,
      'trackId': trackId,
    });
  }

  @override
  Future<void> selectVideoTrack(int textureId, String trackId) {
    return _channel.invokeMethod<void>('selectVideoTrack', {
      'textureId': textureId,
      'trackId': trackId,
    });
  }

  @override
  Future<void> clearVideoTrackOverride(int textureId) {
    return _channel.invokeMethod<void>('clearVideoTrackOverride', {
      'textureId': textureId,
    });
  }

  @override
  Future<void> selectSubtitleTrack(int textureId, String trackId) {
    return _channel.invokeMethod<void>('selectSubtitleTrack', {
      'textureId': textureId,
      'trackId': trackId,
    });
  }

  @override
  Future<void> clearSubtitleTrack(int textureId) {
    return _channel.invokeMethod<void>('clearSubtitleTrack', {
      'textureId': textureId,
    });
  }

  @override
  Future<void> setPreferredSubtitleLanguages(
    int textureId,
    List<String> languages,
  ) {
    return _channel.invokeMethod<void>('setPreferredSubtitleLanguages', {
      'textureId': textureId,
      'languages': languages,
    });
  }

  @override
  Future<void> addExternalSubtitle(
    int textureId, {
    required String uri,
    required String mimeType,
    String? language,
    String? label,
  }) {
    return _channel.invokeMethod<void>('addExternalSubtitle', {
      'textureId': textureId,
      'uri': uri,
      'mimeType': mimeType,
      'language': language,
      'label': label,
    });
  }

  @override
  Future<void> clearExternalSubtitles(int textureId) {
    return _channel.invokeMethod<void>('clearExternalSubtitles', {
      'textureId': textureId,
    });
  }

  @override
  Future<void> setOverallGainDb(int textureId, double db) {
    return _channel.invokeMethod<void>('setOverallGainDb', {
      'textureId': textureId,
      'db': db,
    });
  }

  @override
  Future<void> setVoiceClarity(int textureId, double strength) {
    return _channel.invokeMethod<void>('setVoiceClarity', {
      'textureId': textureId,
      'strength': strength,
    });
  }

  @override
  Future<void> setDiagnosticsEnabled(int textureId, bool enabled) {
    return _channel.invokeMethod<void>('setDiagnosticsEnabled', {
      'textureId': textureId,
      'enabled': enabled,
    });
  }

  @override
  Future<void> swapUrl(
    int textureId, {
    required String url,
    Map<String, String> headers = const <String, String>{},
    String? mimeType,
    Duration? startPosition,
  }) {
    return _channel.invokeMethod<void>('swapUrl', {
      'textureId': textureId,
      'url': url,
      'headers': headers,
      'mimeType': mimeType,
      'startPositionMs': startPosition?.inMilliseconds,
    });
  }

  @override
  Future<bool> dispose(int textureId) async {
    final result = await _channel.invokeMethod<bool>('dispose', {
      'textureId': textureId,
    });
    return result ?? false;
  }

  @override
  Stream<PlaybackEvent> events(int textureId) {
    final channel = EventChannel('$_eventsChannelPrefix$textureId');
    return channel
        .receiveBroadcastStream()
        .map(PlaybackEvent.tryParse)
        .where((event) => event != null)
        .cast<PlaybackEvent>();
  }
}
