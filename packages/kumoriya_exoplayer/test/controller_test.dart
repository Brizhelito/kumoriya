import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_exoplayer/kumoriya_exoplayer.dart';

class _FakePlatform extends KumoriyaExoPlayerPlatform {
  int _nextId = 10;
  final StreamController<PlaybackEvent> _eventController =
      StreamController<PlaybackEvent>.broadcast();

  final List<int> disposed = <int>[];
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  void emit(PlaybackEvent event) => _eventController.add(event);

  @override
  Future<String> ping() async => 'pong';

  @override
  Future<int> create() async {
    final id = _nextId++;
    calls.add({'op': 'create', 'textureId': id});
    return id;
  }

  @override
  Future<void> open(
    int textureId,
    String url, {
    Map<String, String> headers = const {},
    String? mimeType,
    Duration? startPosition,
  }) async {
    calls.add({
      'op': 'open',
      'textureId': textureId,
      'url': url,
      'headers': headers,
      'mimeType': mimeType,
      'startPositionMs': startPosition?.inMilliseconds,
    });
  }

  @override
  Future<void> openAnimeNexus(
    int textureId,
    String watchUrl, {
    Duration? startPosition,
  }) async {
    calls.add({
      'op': 'openNexus',
      'textureId': textureId,
      'watchUrl': watchUrl,
      'startPositionMs': startPosition?.inMilliseconds,
    });
  }

  @override
  Future<void> play(int textureId) async =>
      calls.add({'op': 'play', 'textureId': textureId});

  @override
  Future<void> pause(int textureId) async =>
      calls.add({'op': 'pause', 'textureId': textureId});

  @override
  Future<void> seek(int textureId, Duration position) async => calls.add({
    'op': 'seek',
    'textureId': textureId,
    'positionMs': position.inMilliseconds,
  });

  @override
  Future<void> setVolume(int textureId, double value) async =>
      calls.add({'op': 'setVolume', 'textureId': textureId, 'value': value});

  @override
  Future<void> setSpeed(int textureId, double rate) async =>
      calls.add({'op': 'setSpeed', 'textureId': textureId, 'rate': rate});

  @override
  Future<void> selectAudioTrack(int textureId, String trackId) async =>
      calls.add({
        'op': 'selectAudioTrack',
        'textureId': textureId,
        'trackId': trackId,
      });

  @override
  Future<void> selectVideoTrack(int textureId, String trackId) async =>
      calls.add({
        'op': 'selectVideoTrack',
        'textureId': textureId,
        'trackId': trackId,
      });

  @override
  Future<void> clearVideoTrackOverride(int textureId) async =>
      calls.add({'op': 'clearVideoTrackOverride', 'textureId': textureId});

  @override
  Future<void> selectSubtitleTrack(int textureId, String trackId) async =>
      calls.add({
        'op': 'selectSubtitleTrack',
        'textureId': textureId,
        'trackId': trackId,
      });

  @override
  Future<void> clearSubtitleTrack(int textureId) async =>
      calls.add({'op': 'clearSubtitleTrack', 'textureId': textureId});

  @override
  Future<void> setPreferredSubtitleLanguages(
    int textureId,
    List<String> languages,
  ) async => calls.add({
    'op': 'setPreferredSubtitleLanguages',
    'textureId': textureId,
    'languages': languages,
  });

  @override
  Future<void> addExternalSubtitle(
    int textureId, {
    required String uri,
    required String mimeType,
    String? language,
    String? label,
  }) async => calls.add({
    'op': 'addExternalSubtitle',
    'textureId': textureId,
    'uri': uri,
    'mimeType': mimeType,
    'language': language,
    'label': label,
  });

  @override
  Future<void> clearExternalSubtitles(int textureId) async =>
      calls.add({'op': 'clearExternalSubtitles', 'textureId': textureId});

  @override
  Future<void> setOverallGainDb(int textureId, double db) async =>
      calls.add({'op': 'setOverallGainDb', 'textureId': textureId, 'db': db});

  @override
  Future<void> setVoiceClarity(int textureId, double strength) async =>
      calls.add({
        'op': 'setVoiceClarity',
        'textureId': textureId,
        'strength': strength,
      });

  @override
  Future<void> setDiagnosticsEnabled(int textureId, bool enabled) async =>
      calls.add({
        'op': 'setDiagnosticsEnabled',
        'textureId': textureId,
        'enabled': enabled,
      });

  @override
  Future<void> swapUrl(
    int textureId, {
    required String url,
    Map<String, String> headers = const <String, String>{},
    String? mimeType,
    Duration? startPosition,
  }) async => calls.add({
    'op': 'swapUrl',
    'textureId': textureId,
    'url': url,
    'headers': headers,
    'mimeType': mimeType,
    'startPositionMs': startPosition?.inMilliseconds,
  });

  @override
  Future<bool> dispose(int textureId) async {
    disposed.add(textureId);
    calls.add({'op': 'dispose', 'textureId': textureId});
    return true;
  }

  @override
  Stream<PlaybackEvent> events(int textureId) => _eventController.stream;
}

void main() {
  test('controller forwards imperative calls with the textureId', () async {
    final fake = _FakePlatform();
    final controller = await KumoriyaExoPlayerController.create(platform: fake);

    expect(controller.textureId, 10);

    await controller.open(
      'https://example.com/video.m3u8',
      headers: const {'X-Auth': 'abc'},
      startPosition: const Duration(seconds: 42),
    );
    await controller.play();
    await controller.pause();
    await controller.seekTo(const Duration(seconds: 12));
    await controller.setVolume(0.8);
    await controller.setPlaybackSpeed(1.5);

    expect(fake.calls.first, {'op': 'create', 'textureId': 10});
    expect(fake.calls.sublist(1).map((c) => c['op']).toList(), <String>[
      'open',
      'play',
      'pause',
      'seek',
      'setVolume',
      'setSpeed',
    ]);
    final openCall = fake.calls[1];
    expect(openCall['url'], 'https://example.com/video.m3u8');
    expect(openCall['headers'], {'X-Auth': 'abc'});
    expect(openCall['startPositionMs'], 42000);

    await controller.dispose();
    expect(controller.isDisposed, isTrue);
    expect(fake.disposed, <int>[10]);
  });

  test(
    'controller decodes events into typed streams and caches state',
    () async {
      final fake = _FakePlatform();
      final controller = await KumoriyaExoPlayerController.create(
        platform: fake,
      );

      final playing = <bool>[];
      final buffering = <bool>[];
      final positions = <Duration>[];
      final durations = <Duration>[];
      final errors = <PlaybackErrorEvent>[];
      final completed = <void>[];

      controller.playingStream.listen(playing.add);
      controller.bufferingStream.listen(buffering.add);
      controller.positionStream.listen(positions.add);
      controller.durationStream.listen(durations.add);
      controller.completedStream.listen(completed.add);
      controller.errorStream.listen(errors.add);

      fake.emit(const BufferingChanged(true));
      fake.emit(const DurationResolved(Duration(seconds: 120)));
      fake.emit(const BufferingChanged(false));
      fake.emit(const PlayingChanged(true));
      fake.emit(const PositionTick(Duration(milliseconds: 500)));
      fake.emit(const Completed());
      fake.emit(const PlaybackErrorEvent(code: 'ERROR_IO', message: 'boom'));

      // Let the broadcast streams deliver.
      await Future<void>.delayed(Duration.zero);

      expect(buffering, <bool>[true, false]);
      expect(playing, <bool>[true]);
      expect(positions, <Duration>[const Duration(milliseconds: 500)]);
      expect(durations, <Duration>[const Duration(seconds: 120)]);
      expect(completed.length, 1);
      expect(errors, hasLength(1));
      expect(errors.single.code, 'ERROR_IO');

      expect(controller.isPlaying, isTrue);
      expect(controller.isBuffering, isFalse);
      expect(controller.duration, const Duration(seconds: 120));
      expect(controller.position, const Duration(milliseconds: 500));

      await controller.dispose();
    },
  );

  test('calls after dispose throw StateError', () async {
    final fake = _FakePlatform();
    final controller = await KumoriyaExoPlayerController.create(platform: fake);
    await controller.dispose();

    expect(() => controller.play(), throwsStateError);
    expect(() => controller.open('https://x'), throwsStateError);
  });

  test('PlaybackEvent.tryParse maps every native payload', () {
    expect(
      PlaybackEvent.tryParse({'event': 'playing', 'value': true}),
      isA<PlayingChanged>(),
    );
    expect(
      PlaybackEvent.tryParse({'event': 'buffering', 'value': false}),
      isA<BufferingChanged>(),
    );
    expect(
      PlaybackEvent.tryParse({'event': 'position', 'value': 1500}),
      isA<PositionTick>(),
    );
    expect(
      PlaybackEvent.tryParse({'event': 'duration', 'value': 12345}),
      isA<DurationResolved>(),
    );
    expect(
      PlaybackEvent.tryParse({'event': 'completed', 'value': true}),
      isA<Completed>(),
    );
    expect(
      PlaybackEvent.tryParse({'event': 'error', 'code': 'X', 'message': 'y'}),
      isA<PlaybackErrorEvent>(),
    );
    final size = PlaybackEvent.tryParse({
      'event': 'videoSize',
      'width': 1920.0,
      'height': 1080.0,
    });
    expect(size, isA<VideoSizeChanged>());
    expect((size! as VideoSizeChanged).aspectRatio, closeTo(16 / 9, 1e-6));
    expect(
      PlaybackEvent.tryParse({'event': 'videoSize', 'width': 0, 'height': 1}),
      isNull,
    );
    expect(PlaybackEvent.tryParse(null), isNull);
    expect(PlaybackEvent.tryParse({'event': 'unknown', 'value': 1}), isNull);
  });

  test('controller fans out VideoSizeChanged events', () async {
    final fake = _FakePlatform();
    final controller = await KumoriyaExoPlayerController.create(platform: fake);

    final sizes = <VideoSizeChanged>[];
    controller.videoSizeStream.listen(sizes.add);

    fake.emit(const VideoSizeChanged(width: 1280, height: 720));
    await Future<void>.delayed(Duration.zero);

    expect(sizes, hasLength(1));
    expect(sizes.single.aspectRatio, closeTo(16 / 9, 1e-6));
    expect(controller.videoSize?.aspectRatio, closeTo(16 / 9, 1e-6));

    await controller.dispose();
  });

  test('PlaybackEvent.tryParse decodes audioTracks payload', () {
    final event = PlaybackEvent.tryParse({
      'event': 'audioTracks',
      'value': <Map<String, Object?>>[
        {
          'id': '0:0',
          'label': 'Japanese',
          'language': 'ja',
          'codec': 'mp4a',
          'channels': 2,
          'sampleRate': 48000,
          'bitrate': 128000,
          'selected': true,
        },
        {'id': '0:1', 'language': 'en', 'selected': false},
        {'id': '', 'language': 'bogus'}, // dropped
      ],
    });
    expect(event, isA<AudioTracksChanged>());
    final tracks = (event! as AudioTracksChanged).tracks;
    expect(tracks, hasLength(2));
    expect(tracks.first.id, '0:0');
    expect(tracks.first.displayLabel, 'Japanese');
    expect(tracks.first.selected, isTrue);
    expect(tracks[1].displayLabel, 'en');
  });

  test('controller fans out AudioTracksChanged and caches the list', () async {
    final fake = _FakePlatform();
    final controller = await KumoriyaExoPlayerController.create(platform: fake);

    final seen = <List<AudioTrack>>[];
    controller.audioTracksStream.listen(seen.add);

    fake.emit(
      const AudioTracksChanged(<AudioTrack>[
        AudioTrack(id: '0:0', label: 'JP', language: 'ja', selected: true),
        AudioTrack(id: '0:1', label: 'EN', language: 'en'),
      ]),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single.map((t) => t.id), <String>['0:0', '0:1']);
    expect(controller.audioTracks, hasLength(2));
    expect(controller.audioTracks.first.selected, isTrue);

    await controller.selectAudioTrack('0:1');
    expect(fake.calls.last, {
      'op': 'selectAudioTrack',
      'textureId': 10,
      'trackId': '0:1',
    });

    await controller.dispose();
  });

  test('PlaybackEvent.tryParse decodes subtitleTracks payload', () {
    final event = PlaybackEvent.tryParse({
      'event': 'subtitleTracks',
      'value': <Map<String, Object?>>[
        {
          'id': '1:0',
          'label': 'Español',
          'language': 'es',
          'mimeType': 'text/vtt',
          'selected': true,
        },
        {'id': '1:1', 'language': 'en'},
        {'id': ''},
      ],
    });
    expect(event, isA<SubtitleTracksChanged>());
    final tracks = (event! as SubtitleTracksChanged).tracks;
    expect(tracks, hasLength(2));
    expect(tracks.first.displayLabel, 'Español');
    expect(tracks.first.selected, isTrue);
    expect(tracks[1].displayLabel, 'en');
  });

  test(
    'controller fans out SubtitleTracksChanged, forwards select+clear',
    () async {
      final fake = _FakePlatform();
      final controller = await KumoriyaExoPlayerController.create(
        platform: fake,
      );

      final seen = <List<SubtitleTrack>>[];
      controller.subtitleTracksStream.listen(seen.add);

      fake.emit(
        const SubtitleTracksChanged(<SubtitleTrack>[
          SubtitleTrack(id: '1:0', label: 'ES', language: 'es', selected: true),
          SubtitleTrack(id: '1:1', label: 'EN', language: 'en'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen.single.map((t) => t.id), <String>['1:0', '1:1']);
      expect(controller.subtitleTracks.first.selected, isTrue);

      await controller.selectSubtitleTrack('1:1');
      expect(fake.calls.last, {
        'op': 'selectSubtitleTrack',
        'textureId': 10,
        'trackId': '1:1',
      });

      await controller.clearSubtitleTrack();
      expect(fake.calls.last, {'op': 'clearSubtitleTrack', 'textureId': 10});

      await controller.setPreferredSubtitleLanguages(<String>['es', 'en']);
      expect(fake.calls.last, {
        'op': 'setPreferredSubtitleLanguages',
        'textureId': 10,
        'languages': <String>['es', 'en'],
      });

      await controller.dispose();
    },
  );

  test('PlaybackEvent.tryParse decodes urlExpired payload', () {
    final event = PlaybackEvent.tryParse({
      'event': 'urlExpired',
      'url': 'https://cdn.example/segment.m3u8',
      'httpCode': 403,
    });
    expect(event, isA<UrlExpired>());
    final u = event! as UrlExpired;
    expect(u.url, 'https://cdn.example/segment.m3u8');
    expect(u.httpCode, 403);

    // empty url must be dropped
    expect(
      PlaybackEvent.tryParse({
        'event': 'urlExpired',
        'url': '',
        'httpCode': 410,
      }),
      isNull,
    );
  });

  test(
    'PlaybackEvent.tryParse decodes diagnostics payload + controller fans out',
    () async {
      final event = PlaybackEvent.tryParse({
        'event': 'diagnostics',
        'value': <String, Object?>{
          'droppedVideoFrames': 12,
          'renderedVideoFrames': 1200,
          'videoCodec': 'avc1.64001e',
          'videoDecoder': 'c2.android.avc.decoder',
          'videoBitrate': 2500000,
          'videoHardwareAccelerated': true,
          'audioCodec': 'mp4a.40.2',
          'audioSampleRate': 48000,
          'audioChannels': 2,
          'bandwidthBps': 5200000,
          'bufferedMs': 30000,
          'positionMs': 42000,
          'videoWidth': 1920.0,
          'videoHeight': 1080.0,
        },
      });
      expect(event, isA<DiagnosticsReport>());
      final s = (event! as DiagnosticsReport).snapshot;
      expect(s.droppedVideoFrames, 12);
      expect(s.videoCodec, 'avc1.64001e');
      expect(s.videoHardwareAccelerated, isTrue);
      expect(s.bufferedMs, 30000);

      final fake = _FakePlatform();
      final controller = await KumoriyaExoPlayerController.create(
        platform: fake,
      );

      final seen = <DiagnosticsSnapshot>[];
      controller.diagnosticsStream.listen(seen.add);

      await controller.setDiagnosticsEnabled(true);
      expect(fake.calls.last, {
        'op': 'setDiagnosticsEnabled',
        'textureId': 10,
        'enabled': true,
      });

      fake.emit(DiagnosticsReport(s));
      await Future<void>.delayed(Duration.zero);

      expect(seen.single.videoCodec, 'avc1.64001e');

      await controller.dispose();
    },
  );

  test('controller forwards setOverallGainDb + setVoiceClarity', () async {
    final fake = _FakePlatform();
    final controller = await KumoriyaExoPlayerController.create(platform: fake);

    await controller.setOverallGainDb(6.0);
    expect(fake.calls.last, {
      'op': 'setOverallGainDb',
      'textureId': 10,
      'db': 6.0,
    });

    await controller.setVoiceClarity(0.7);
    expect(fake.calls.last, {
      'op': 'setVoiceClarity',
      'textureId': 10,
      'strength': 0.7,
    });

    await controller.dispose();
  });

  test('controller fans out UrlExpired and forwards swapUrl', () async {
    final fake = _FakePlatform();
    final controller = await KumoriyaExoPlayerController.create(platform: fake);

    final seen = <UrlExpired>[];
    controller.urlExpiredStream.listen(seen.add);

    fake.emit(
      const UrlExpired(url: 'https://cdn.example/segment.m3u8', httpCode: 403),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single.httpCode, 403);

    await controller.swapUrl(
      'https://cdn.example/fresh.m3u8',
      headers: const {'Cookie': 'sid=abc'},
      mimeType: 'application/x-mpegURL',
      startPosition: const Duration(seconds: 42),
    );
    expect(fake.calls.last, {
      'op': 'swapUrl',
      'textureId': 10,
      'url': 'https://cdn.example/fresh.m3u8',
      'headers': {'Cookie': 'sid=abc'},
      'mimeType': 'application/x-mpegURL',
      'startPositionMs': 42000,
    });

    await controller.dispose();
  });

  test(
    'controller forwards addExternalSubtitle + clearExternalSubtitles',
    () async {
      final fake = _FakePlatform();
      final controller = await KumoriyaExoPlayerController.create(
        platform: fake,
      );

      await controller.addExternalSubtitle(
        uri: 'https://subs.example/es.vtt',
        mimeType: 'text/vtt',
        language: 'es',
        label: 'Español',
      );
      expect(fake.calls.last, {
        'op': 'addExternalSubtitle',
        'textureId': 10,
        'uri': 'https://subs.example/es.vtt',
        'mimeType': 'text/vtt',
        'language': 'es',
        'label': 'Español',
      });

      await controller.clearExternalSubtitles();
      expect(fake.calls.last, {
        'op': 'clearExternalSubtitles',
        'textureId': 10,
      });

      await controller.dispose();
    },
  );
}
