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
      onFailure: (error) => expect(error.code, 'player.no_playable_stream'),
      onSuccess: (_) => fail('expected failure'),
    );

    await orchestrator.dispose();
  });

  test('falls back to next candidate when first open fails', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.throwError('network fail'),
        const _OpenBehavior.success(),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/a.m3u8'),
          isHls: true,
        ),
        ResolvedStream(
          url: Uri.parse('https://cdn.example/b.m3u8'),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);
    expect(engine.openCalls, 2);
    expect(orchestrator.state.currentCandidateIndex, 1);

    await orchestrator.dispose();
  });

  test('returns all_candidates_failed when every candidate fails', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.throwError('fail-1'),
        const _OpenBehavior.throwError('fail-2'),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/a.m3u8'),
          isHls: true,
        ),
        ResolvedStream(
          url: Uri.parse('https://cdn.example/b.m3u8'),
          isHls: true,
        ),
      ],
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error.code, 'player.all_candidates_failed'),
      onSuccess: (_) => fail('expected failure'),
    );

    await orchestrator.dispose();
  });

  test(
    'returns open_timeout when candidate open exceeds timeout and no fallback',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: <_OpenBehavior>[
          const _OpenBehavior.delay(milliseconds: 200),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        openTimeout: const Duration(milliseconds: 50),
      );

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse('https://cdn.example/a.m3u8'),
            isHls: true,
          ),
        ],
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) => expect(error.code, 'player.open_timeout'),
        onSuccess: (_) => fail('expected failure'),
      );

      await orchestrator.dispose();
    },
  );

  test('buffering timeout triggers fallback to next candidate', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.success(bufferingStuck: true),
        const _OpenBehavior.success(),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      bufferingTimeout: const Duration(milliseconds: 50),
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/a.m3u8'),
          isHls: true,
        ),
        ResolvedStream(
          url: Uri.parse('https://cdn.example/b.m3u8'),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(engine.openCalls, 2);
    expect(orchestrator.state.currentCandidateIndex, 1);

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
}

final class _FakePlaybackEngine implements PlaybackEngine {
  _FakePlaybackEngine({List<_OpenBehavior>? openBehaviors})
    : _openBehaviors =
          openBehaviors ?? const <_OpenBehavior>[_OpenBehavior.success()];

  final List<_OpenBehavior> _openBehaviors;
  int _openBehaviorIndex = 0;

  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  int openCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;

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
    final behavior =
        _openBehaviors[_openBehaviorIndex.clamp(0, _openBehaviors.length - 1)];
    if (_openBehaviorIndex < _openBehaviors.length - 1) {
      _openBehaviorIndex++;
    }

    if (behavior.delayMs != null) {
      await Future<void>.delayed(Duration(milliseconds: behavior.delayMs!));
    }

    if (behavior.shouldThrow) {
      throw Exception(behavior.errorMessage ?? 'open fail');
    }

    _bufferingController.add(true);
    _playingController.add(true);
    if (!behavior.bufferingStuck) {
      _bufferingController.add(false);
    }
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
}

final class _OpenBehavior {
  const _OpenBehavior.success({this.bufferingStuck = false})
    : shouldThrow = false,
      delayMs = null,
      errorMessage = null;

  const _OpenBehavior.throwError(this.errorMessage)
    : shouldThrow = true,
      bufferingStuck = false,
      delayMs = null;

  const _OpenBehavior.delay({required int milliseconds})
    : shouldThrow = false,
      bufferingStuck = false,
      delayMs = milliseconds,
      errorMessage = null;

  final bool shouldThrow;
  final bool bufferingStuck;
  final int? delayMs;
  final String? errorMessage;
}
