import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_session_state.dart';
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
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(engine.openCalls, 3);
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

  test('starts HLS candidate at initial resume position', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/master.m3u8'),
          isHls: true,
        ),
      ],
      initialPosition: const Duration(minutes: 12, seconds: 5),
    );

    expect(result.isSuccess, isTrue);
    expect(engine.openCalls, 1);
    expect(
      engine.openStartPositions.single,
      const Duration(minutes: 12, seconds: 5),
    );

    await orchestrator.dispose();
  });

  test(
    'reopens HLS candidate instead of direct seek for explicit seek',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
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

      await orchestrator.seekTo(const Duration(minutes: 18, seconds: 30));

      expect(engine.seekCalls, 0);
      expect(engine.openCalls, 2);
      expect(
        engine.openStartPositions.last,
        const Duration(minutes: 18, seconds: 30),
      );

      await orchestrator.dispose();
    },
  );

  test(
    'keeps candidate while buffering when runtime seek-like error is emitted',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
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
      engine.emitPosition(const Duration(minutes: 7));

      engine.emitBuffering(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      engine.emitError('seek failed while loading segment');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(engine.openCalls, 2);
      expect(engine.seekCalls, 0);
      expect(engine.openStartPositions.last, const Duration(minutes: 7));
      expect(orchestrator.state.currentCandidateIndex, 0);
      expect(orchestrator.state.status, isNot(PlayerSessionStatus.error));

      await orchestrator.dispose();
    },
  );

  test(
    'single candidate buffering timeout attempts in-place recovery',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(bufferingStuck: true),
          _OpenBehavior.success(),
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
        ],
      );

      expect(result.isSuccess, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(engine.openCalls, 2);
      expect(orchestrator.state.currentCandidateIndex, 0);
      expect(orchestrator.state.status, isNot(PlayerSessionStatus.error));

      await orchestrator.dispose();
    },
  );
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
  final _positionController = StreamController<Duration>.broadcast();

  int openCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
  Duration? lastSeekPosition;
  final List<Duration?> openStartPositions = <Duration?>[];

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Future<void> seekTo(Duration position) async {
    seekCalls++;
    lastSeekPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _bufferingController.close();
    await _errorController.close();
    await _positionController.close();
  }

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    openCalls++;
    openStartPositions.add(startPosition);
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

  void emitBuffering(bool value) {
    _bufferingController.add(value);
  }

  void emitError(String value) {
    _errorController.add(value);
  }

  void emitPosition(Duration value) {
    _positionController.add(value);
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
