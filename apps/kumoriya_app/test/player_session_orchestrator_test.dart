import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/services/playback_engine.dart';
import 'package:kumoriya_app/src/features/player/application/services/player_session_orchestrator.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  test('fails when no playable stream candidates are provided', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: const <ResolvedStream>[],
    );
    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error.code, 'player.no_playable_stream'),
      onSuccess: (_) => fail('expected failure'),
    );

    await orchestrator.dispose();
  });

  test('fails for unsupported stream URL', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(url: Uri.parse('file:///tmp/local.mp4')),
      ],
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error.code, 'player.unsupported_stream'),
      onSuccess: (_) => fail('expected failure'),
    );

    await orchestrator.dispose();
  });

  test('opens stream and toggles play/pause through engine', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/master.m3u8'),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);
    expect(engine.openCalls, 1);

    await orchestrator.togglePlayPause();
    expect(engine.pauseCalls, 1);

    engine.emitPlaying(false);
    await orchestrator.togglePlayPause();
    expect(engine.playCalls, 1);

    await orchestrator.dispose();
  });

  test('emits error state when playback engine reports error event', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(url: Uri.parse('https://cdn.example/video.mp4')),
      ],
    );
    expect(result.isSuccess, isTrue);

    engine.emitError('decoder failed');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(orchestrator.state.status.name, 'error');
    expect(orchestrator.state.errorMessage, contains('decoder failed'));

    await orchestrator.dispose();
  });
}

final class _FakePlaybackEngine implements PlaybackEngine {
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  int openCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;

  _FakePlaybackEngine() {
    _playingController.add(false);
    _bufferingController.add(false);
  }

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _bufferingController.close();
    await _errorController.close();
  }

  @override
  Future<void> open(ResolvedStream stream) async {
    openCalls++;
    _bufferingController.add(true);
    _playingController.add(true);
    _bufferingController.add(false);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playingController.add(false);
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playingController.add(true);
  }

  void emitPlaying(bool value) {
    _playingController.add(value);
  }

  void emitError(String message) {
    _errorController.add(message);
  }
}
