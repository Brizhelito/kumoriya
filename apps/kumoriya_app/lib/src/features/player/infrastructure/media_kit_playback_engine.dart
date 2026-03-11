import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../application/services/playback_engine.dart';

final class MediaKitPlaybackEngine implements PlaybackEngine {
  static const List<Duration> _hlsPrerollWindows = <Duration>[
    Duration(seconds: 6),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  MediaKitPlaybackEngine()
    : player = Player(
        configuration: PlayerConfiguration(
          logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.error,
          bufferSize: 128 * 1024 * 1024,
        ),
      ) {
    videoController = VideoController(player);
    _attachNativeDebugStreams();
  }

  final Player player;
  late final VideoController videoController;
  bool _disposed = false;
  final List<StreamSubscription<dynamic>> _debugSubscriptions =
      <StreamSubscription<dynamic>>[];
  late final String _instanceId = identityHashCode(this).toRadixString(16);

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<bool> get completedStream => player.stream.completed;

  @override
  Stream<String> get errorStream => player.stream.error;

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<Duration> get durationStream => player.stream.duration;

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    _log(
      'open url=${stream.url} hls=${stream.isHls} start=$startPosition headers=${stream.headers.keys.join(",")}',
    );
    if (stream.isHls &&
        startPosition != null &&
        startPosition > Duration.zero) {
      await _openHlsAtPosition(stream, startPosition);
      return;
    }

    return player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: startPosition,
      ),
      play: true,
    );
  }

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) {
    if (track.uri != null) {
      return player.setSubtitleTrack(
        SubtitleTrack.uri(
          track.uri.toString(),
          title: track.label,
          language: track.language,
        ),
      );
    }

    return player.setSubtitleTrack(
      SubtitleTrack.data(
        track.data!,
        title: track.label,
        language: track.language,
      ),
    );
  }

  @override
  Future<void> clearSubtitleTrack() {
    return player.setSubtitleTrack(SubtitleTrack.no());
  }

  @override
  Future<void> pause() {
    _log('pause');
    return player.pause();
  }

  @override
  Future<void> play() {
    _log('play');
    return player.play();
  }

  @override
  Future<void> seekTo(Duration position) {
    _log('seekTo position=$position');
    return player.seek(position);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _debugSubscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
  }

  Future<void> _openHlsAtPosition(
    ResolvedStream stream,
    Duration startPosition,
  ) async {
    _log('hls-reopen start url=${stream.url} target=$startPosition');
    _throwIfDisposed();
    await player.stop();
    _log('hls-reopen stopped current media');
    _throwIfDisposed();
    await player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: startPosition,
      ),
      play: true,
    );
    _log(
      'hls-reopen opened playing buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
    _throwIfDisposed();
    await _waitUntilReady();
    _throwIfDisposed();
    final startApplied = await _waitForRequestedStartPosition(startPosition);
    _throwIfDisposed();
    if (startApplied) {
      final progressed = await _waitForPlaybackProgressFromTarget(
        startPosition,
      );
      _throwIfDisposed();
      if (progressed) {
        _log(
          'hls-reopen start-property progressed target=$startPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
        );
        return;
      }
      _log(
        'hls-reopen start-property stalled target=$startPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      for (final window in _hlsPrerollWindows) {
        final prerollStart = _computePrerollStart(startPosition, window);
        if (prerollStart < startPosition) {
          _throwIfDisposed();
          final recovered = await _openHlsFromPreroll(
            stream,
            requestedPosition: startPosition,
            prerollStart: prerollStart,
          );
          if (recovered) {
            return;
          }
        }
      }
    }

    _throwIfDisposed();
    await _waitForPlaybackWarmup();
    _log(
      'hls-reopen start-property fallback buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
    _throwIfDisposed();
    await _seekWhenReady(startPosition);
    _log(
      'hls-reopen seeked buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
    );
  }

  Future<void> _waitUntilReady() async {
    if (player.state.duration > Duration.zero) {
      _log(
        'waitUntilReady immediate buffering=${player.state.buffering} duration=${player.state.duration}',
      );
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<Duration> durationSub;
    late final StreamSubscription<bool> bufferingSub;
    Timer? timeoutTimer;
    bool sawBuffering = player.state.buffering;

    void complete() {
      if (completer.isCompleted) {
        return;
      }
      completer.complete();
    }

    durationSub = player.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        _log('waitUntilReady duration-ready duration=$duration');
        complete();
      }
    });

    bufferingSub = player.stream.buffering.listen((buffering) {
      if (buffering) {
        sawBuffering = true;
      }
      if (!buffering && sawBuffering && player.state.duration > Duration.zero) {
        _log(
          'waitUntilReady buffering-false duration=${player.state.duration}',
        );
        complete();
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 8), () {
      _log(
        'waitUntilReady timeout buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      complete();
    });

    try {
      await completer.future;
    } finally {
      timeoutTimer.cancel();
      await durationSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<void> _seekWhenReady(Duration targetPosition) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      _throwIfDisposed();
      await player.seek(targetPosition);
      _log(
        'seekWhenReady attempt=$attempt target=$targetPosition buffering=${player.state.buffering} duration=${player.state.duration} position=${player.state.position}',
      );
      final reached = await _waitForPosition(targetPosition);
      if (reached) {
        _log(
          'seekWhenReady reached target=$targetPosition on attempt=$attempt',
        );
        return;
      }
      await _waitUntilReady();
    }
  }

  Future<void> _waitForPlaybackWarmup() async {
    if (player.state.position > Duration.zero && !player.state.buffering) {
      _log(
        'waitForPlaybackWarmup immediate position=${player.state.position} buffering=${player.state.buffering}',
      );
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<Duration> positionSub;
    late final StreamSubscription<bool> bufferingSub;
    Timer? timeoutTimer;
    var buffering = player.state.buffering;

    void complete() {
      if (completer.isCompleted) {
        return;
      }
      completer.complete();
    }

    positionSub = player.stream.position.listen((position) {
      if (position > Duration.zero && !buffering) {
        _log('waitForPlaybackWarmup position=$position');
        complete();
      }
    });

    bufferingSub = player.stream.buffering.listen((next) {
      buffering = next;
      if (!next && player.state.position > Duration.zero) {
        _log(
          'waitForPlaybackWarmup buffering-false position=${player.state.position}',
        );
        complete();
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 3), () {
      _log(
        'waitForPlaybackWarmup timeout position=${player.state.position} buffering=${player.state.buffering}',
      );
      complete();
    });

    try {
      await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<bool> _waitForRequestedStartPosition(Duration targetPosition) async {
    if (_isPositionNear(player.state.position, targetPosition)) {
      _log(
        'waitForRequestedStartPosition immediate target=$targetPosition position=${player.state.position}',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    late final StreamSubscription<bool> bufferingSub;
    Timer? timeoutTimer;
    var buffering = player.state.buffering;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    bool looksLikePlaybackStartedFromBeginning(Duration position) {
      if (targetPosition <= const Duration(seconds: 15)) {
        return false;
      }
      if (buffering) {
        return false;
      }
      return position > Duration.zero && position < const Duration(seconds: 3);
    }

    positionSub = player.stream.position.listen((position) {
      if (_isPositionNear(position, targetPosition)) {
        _log(
          'waitForRequestedStartPosition reached target=$targetPosition position=$position',
        );
        complete(true);
        return;
      }
      if (looksLikePlaybackStartedFromBeginning(position)) {
        _log(
          'waitForRequestedStartPosition fallback-from-beginning target=$targetPosition position=$position',
        );
        complete(false);
      }
    });

    bufferingSub = player.stream.buffering.listen((next) {
      buffering = next;
      final position = player.state.position;
      if (_isPositionNear(position, targetPosition)) {
        _log(
          'waitForRequestedStartPosition buffering-update reached target=$targetPosition position=$position',
        );
        complete(true);
        return;
      }
      if (looksLikePlaybackStartedFromBeginning(position)) {
        _log(
          'waitForRequestedStartPosition buffering-update fallback-from-beginning target=$targetPosition position=$position',
        );
        complete(false);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 6), () {
      _log(
        'waitForRequestedStartPosition timeout target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} duration=${player.state.duration}',
      );
      complete(false);
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
      await bufferingSub.cancel();
    }
  }

  Future<bool> _waitForPlaybackProgressFromTarget(
    Duration targetPosition,
  ) async {
    if (player.state.position >
        targetPosition + const Duration(milliseconds: 400)) {
      _log(
        'waitForPlaybackProgressFromTarget immediate target=$targetPosition position=${player.state.position}',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    Timer? timeoutTimer;
    Timer? pollTimer;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    positionSub = player.stream.position.listen((position) {
      if (position > targetPosition + const Duration(milliseconds: 400)) {
        _log(
          'waitForPlaybackProgressFromTarget advanced target=$targetPosition position=$position',
        );
        complete(true);
      }
    });

    pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _log(
        'progress-poll playing=${player.state.playing} buffering=${player.state.buffering} completed=${player.state.completed} position=${player.state.position} duration=${player.state.duration} buffer=${player.state.buffer} percent=${player.state.bufferingPercentage}',
      );
    });

    timeoutTimer = Timer(const Duration(seconds: 6), () {
      _log(
        'waitForPlaybackProgressFromTarget timeout target=$targetPosition position=${player.state.position} buffering=${player.state.buffering} completed=${player.state.completed} buffer=${player.state.buffer} percent=${player.state.bufferingPercentage}',
      );
      complete(false);
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      pollTimer.cancel();
      await positionSub.cancel();
    }
  }

  Future<bool> _openHlsFromPreroll(
    ResolvedStream stream, {
    required Duration requestedPosition,
    required Duration prerollStart,
  }) async {
    _log(
      'hls-reopen preroll start requested=$requestedPosition preroll=$prerollStart',
    );
    _throwIfDisposed();
    await player.stop();
    _throwIfDisposed();
    await player.open(
      Media(
        stream.url.toString(),
        httpHeaders: stream.headers,
        start: prerollStart,
      ),
      play: true,
    );
    await _waitUntilReady();
    final prerollApplied = await _waitForRequestedStartPosition(prerollStart);
    if (!prerollApplied) {
      _log(
        'hls-reopen preroll failed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    final progressed = await _waitForPlaybackProgressFromTarget(prerollStart);
    if (!progressed) {
      _log(
        'hls-reopen preroll stalled requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    await _seekWhenReady(requestedPosition);
    final seekApplied = await _waitForPosition(requestedPosition);
    if (!seekApplied) {
      _log(
        'hls-reopen preroll seek-failed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
      );
      return false;
    }
    _log(
      'hls-reopen preroll completed requested=$requestedPosition preroll=$prerollStart position=${player.state.position}',
    );
    return true;
  }

  Duration _computePrerollStart(
    Duration targetPosition,
    Duration prerollWindow,
  ) {
    if (targetPosition <= prerollWindow) {
      return Duration.zero;
    }
    return targetPosition - prerollWindow;
  }

  Future<bool> _waitForPosition(Duration targetPosition) async {
    if (_isPositionNear(player.state.position, targetPosition)) {
      return true;
    }

    final completer = Completer<bool>();
    late final StreamSubscription<Duration> positionSub;
    Timer? timeoutTimer;

    void complete(bool value) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(value);
    }

    positionSub = player.stream.position.listen((position) {
      if (_isPositionNear(position, targetPosition)) {
        _log(
          'waitForPosition reached position=$position target=$targetPosition',
        );
        complete(true);
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 2), () {
      _log(
        'waitForPosition timeout position=${player.state.position} target=$targetPosition buffering=${player.state.buffering}',
      );
      complete(false);
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await positionSub.cancel();
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError(
        'MediaKitPlaybackEngine was disposed during hls-reopen sequence.',
      );
    }
  }

  bool _isPositionNear(Duration actual, Duration expected) {
    return (actual - expected).inSeconds.abs() <= 2;
  }

  void _attachNativeDebugStreams() {
    if (!kDebugMode) {
      return;
    }

    _debugSubscriptions.add(
      player.stream.log.listen((event) {
        final lower = '${event.prefix} ${event.level} ${event.text}'
            .toLowerCase();
        final shouldLog =
            event.level == 'error' ||
            event.level == 'warn' ||
            lower.contains('eof') ||
            lower.contains('cache') ||
            lower.contains('buffer') ||
            lower.contains('segment') ||
            lower.contains('hls') ||
            lower.contains('http') ||
            lower.contains('tcp') ||
            lower.contains('demux');
        if (!shouldLog) {
          return;
        }
        _log(
          'native-log prefix=${event.prefix} level=${event.level} text=${event.text}',
        );
      }),
    );

    _debugSubscriptions.add(
      player.stream.buffer.listen((buffer) {
        if (!player.state.buffering && buffer <= Duration.zero) {
          return;
        }
        _log(
          'native-buffer time=$buffer percent=${player.state.bufferingPercentage} position=${player.state.position} duration=${player.state.duration}',
        );
      }),
    );

    _debugSubscriptions.add(
      player.stream.bufferingPercentage.listen((percentage) {
        if (!player.state.buffering && percentage <= 0) {
          return;
        }
        _log(
          'native-buffering percent=$percentage buffer=${player.state.buffer} position=${player.state.position} duration=${player.state.duration}',
        );
      }),
    );
  }

  void _log(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[player.engine#$_instanceId ${DateTime.now().toIso8601String()}] $message',
    );
  }
}
