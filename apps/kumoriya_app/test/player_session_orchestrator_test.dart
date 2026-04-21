import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/player/application/models/embedded_tracks.dart';
import 'package:kumoriya_app/src/features/player/application/models/player_diagnostics.dart';
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
        ResolvedStream(url: Uri.parse('ftp://ftp.example.com/local.mp4')),
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
      expect(engine.invalidatePendingOpenCalls, 1);

      await orchestrator.dispose();
    },
  );

  test(
    'timeout cancels late open work so stale playing state never wins',
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
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(engine.invalidatePendingOpenCalls, 1);
      expect(orchestrator.state.status, PlayerSessionStatus.error);
      expect(orchestrator.state.errorMessage, isNotNull);

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

  test('recovery timeout invalidates pending open work', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.success(bufferingStuck: true),
        const _OpenBehavior.delay(milliseconds: 200),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      openTimeout: const Duration(milliseconds: 50),
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
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(engine.openCalls, greaterThanOrEqualTo(2));
    expect(engine.invalidatePendingOpenCalls, 1);
    expect(orchestrator.state.status, PlayerSessionStatus.error);

    await orchestrator.dispose();
  });

  test('initial non-nexus resume open gets extra open budget', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.delay(milliseconds: 120),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      openTimeout: const Duration(milliseconds: 50),
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/resume.m3u8'),
          isHls: true,
        ),
      ],
      initialPosition: const Duration(minutes: 5),
    );

    expect(result.isSuccess, isTrue);
    expect(engine.openCalls, 1);

    await orchestrator.dispose();
  });

  test('grants extra open budget to anime nexus initial opens', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.delay(milliseconds: 120),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      openTimeout: const Duration(milliseconds: 50),
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse(
            'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
          ),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);
    expect(engine.openCalls, 1);

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
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      seekVisualGateTimeout: Duration.zero,
    );

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

  test('keeps native seek for buffered forward HLS seeks', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);
    const currentPosition = Duration(minutes: 5);
    const bufferedAhead = Duration(seconds: 30);
    const targetPosition = Duration(minutes: 5, seconds: 10);

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/master.m3u8'),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);

    engine.emitPosition(currentPosition);
    engine.emitBuffer(bufferedAhead);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await orchestrator.seekTo(targetPosition);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.seekPositions, contains(targetPosition));
    expect(
      engine.openCalls,
      1,
      reason: 'buffered in-place seeks should not reopen the HLS stream',
    );

    await orchestrator.dispose();
  });

  test('loads preferred external subtitle track after opening', () async {
    final engine = _FakePlaybackEngine();
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);
    final subtitles = <ExternalSubtitleTrack>[
      ExternalSubtitleTrack(
        id: 'es',
        label: 'Spanish',
        language: 'es',
        uri: Uri.parse('https://cdn.example/subs/es.vtt'),
      ),
      ExternalSubtitleTrack(
        id: 'en',
        label: 'English',
        language: 'en',
        uri: Uri.parse('https://cdn.example/subs/en.vtt'),
        isDefault: true,
      ),
    ];

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/master.m3u8'),
          isHls: true,
        ),
      ],
      externalSubtitles: subtitles,
    );

    expect(result.isSuccess, isTrue);
    expect(engine.lastSubtitleTrack?.id, 'en');

    await orchestrator.dispose();
  });

  test('retry success clears stale all-candidates info message', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: <_OpenBehavior>[
        const _OpenBehavior.throwError('fail-1'),
        const _OpenBehavior.throwError('fail-2'),
        const _OpenBehavior.success(),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);
    final emittedStates = <PlayerSessionState>[];
    final sub = orchestrator.states.listen(emittedStates.add);

    final firstResult = await orchestrator.start(
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

    expect(firstResult.isFailure, isTrue);
    expect(orchestrator.state.infoMessage, 'player.tried_all_candidates');

    final retryResult = await orchestrator.retry();

    expect(retryResult.isSuccess, isTrue);
    expect(orchestrator.state.infoMessage, isNull);
    expect(orchestrator.state.errorMessage, isNull);

    final retryPlayingWithStaleInfo = emittedStates.any(
      (state) =>
          state.status == PlayerSessionStatus.playing &&
          state.infoMessage == 'player.tried_all_candidates',
    );
    expect(
      retryPlayingWithStaleInfo,
      isFalse,
      reason:
          'stable playback after retry must not retain stale candidate info',
    );

    await sub.cancel();
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

  test('reopens loopback HLS candidate for explicit seek', () async {
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
          url: Uri.parse(
            'http://127.0.0.1:63164/anime-nexus/session/master.m3u8',
          ),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);

    await orchestrator.seekTo(const Duration(minutes: 18, seconds: 30));

    expect(engine.openCalls, 1);
    expect(engine.seekCalls, 1);
    expect(engine.lastSeekPosition, const Duration(minutes: 18, seconds: 30));

    await orchestrator.dispose();
  });

  test(
    'native seek for anime nexus loopback HLS with initial position',
    () async {
      final engine = _FakePlaybackEngine();
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 5),
      );

      expect(result.isSuccess, isTrue);

      await orchestrator.seekTo(const Duration(minutes: 18, seconds: 30));

      expect(engine.openCalls, 1, reason: 'native seek, no reopen');
      expect(engine.seekCalls, 1, reason: 'native seek used');
      expect(engine.lastSeekPosition, const Duration(minutes: 18, seconds: 30));

      await orchestrator.dispose();
    },
  );

  test(
    'publishes raw timeline for anime nexus loopback without managed windows',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );
      var latestPosition = Duration.zero;
      var latestDuration = Duration.zero;
      final positionSub = orchestrator.positionStream.listen(
        (value) => latestPosition = value,
      );
      final durationSub = orchestrator.durationStream.listen(
        (value) => latestDuration = value,
      );

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 9, seconds: 0),
      );

      expect(result.isSuccess, isTrue);

      engine.emitDuration(const Duration(minutes: 14, seconds: 51));
      engine.emitPosition(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // No managed window → positions and durations pass through raw.
      expect(latestDuration, const Duration(minutes: 14, seconds: 51));
      expect(latestPosition, const Duration(seconds: 5));

      await positionSub.cancel();
      await durationSub.cancel();
      await orchestrator.dispose();
    },
  );

  test('retries native seek when stall detected for anime nexus', () async {
    final engine = _FakePlaybackEngine(
      openBehaviors: const <_OpenBehavior>[_OpenBehavior.success()],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      seekVisualGateTimeout: Duration.zero,
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse(
            'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
          ),
          isHls: true,
        ),
      ],
      initialPosition: const Duration(minutes: 2),
    );

    expect(result.isSuccess, isTrue);

    engine.emitDuration(const Duration(minutes: 23, seconds: 40));
    engine.emitPosition(const Duration(seconds: 17));

    // Prevent seekTo from immediately confirming the seek session.
    engine.emitPositionOnSeek = false;
    await orchestrator.seekTo(const Duration(minutes: 7, seconds: 34));

    // Native seek, no reopen.
    expect(engine.openCalls, 1);
    expect(engine.seekCalls, 1);

    // Simulate stall: position stuck far from target.
    engine.emitPlaying(true);
    engine.emitBuffering(false);
    engine.emitPosition(Duration.zero);
    // AN stall watch fires at 6s (reduced from 12s).
    await Future<void>.delayed(const Duration(seconds: 7));

    // Stall watch fires → native retry (not reopen).
    expect(engine.openCalls, 1, reason: 'no reopen for Anime Nexus');
    expect(engine.seekCalls, 2, reason: 'native retry after stall');
    expect(orchestrator.state.currentCandidateIndex, 0);
    expect(engine.lastSeekPosition, const Duration(minutes: 7, seconds: 34));

    await orchestrator.dispose();
  });

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
    'falls back to next candidate when buffering runtime error is codec-related',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(bufferingStuck: true),
          _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/4400/1.m3u8',
            ),
            qualityLabel: '720p',
            isHls: true,
          ),
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/1600/1.m3u8',
            ),
            qualityLabel: '480p',
            isHls: true,
          ),
        ],
      );

      expect(result.isSuccess, isTrue);
      expect(engine.openCalls, 1);

      engine.emitBuffering(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      engine.emitError('Could not open codec.');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(engine.openCalls, 2);
      expect(orchestrator.state.currentCandidateIndex, 1);
      expect(engine.openUrls.last.path, contains('/1600/'));

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

  test(
    'recovers same hls candidate when playback jumps to end after seek',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
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

      engine.emitDuration(const Duration(minutes: 23, seconds: 40));
      await orchestrator.seekTo(const Duration(seconds: 50));

      engine.emitPlaying(true);
      engine.emitBuffering(false);
      engine.emitPosition(const Duration(minutes: 23, seconds: 40));
      engine.emitPlaying(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.openCalls, 3);
      expect(engine.openStartPositions.last, const Duration(seconds: 50));
      expect(orchestrator.state.currentCandidateIndex, 0);

      await orchestrator.dispose();
    },
  );

  test(
    'recovers same hls candidate when initial resume jumps to end',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse('https://cdn.example/master.m3u8'),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 10, seconds: 33),
      );

      expect(result.isSuccess, isTrue);

      engine.emitDuration(const Duration(minutes: 23, seconds: 40));
      engine.emitPlaying(true);
      engine.emitBuffering(false);
      engine.emitPosition(const Duration(minutes: 23, seconds: 40));
      engine.emitCompleted(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.openCalls, 2);
      expect(
        engine.openStartPositions.last,
        const Duration(minutes: 10, seconds: 33),
      );
      expect(orchestrator.state.currentCandidateIndex, 0);

      await orchestrator.dispose();
    },
  );

  test('emits debug callback entries for start and seek flow', () async {
    final logs = <String>[];
    final engine = _FakePlaybackEngine(
      openBehaviors: const <_OpenBehavior>[
        _OpenBehavior.success(),
        _OpenBehavior.success(),
      ],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      onDebugLog: logs.add,
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse('https://cdn.example/master.m3u8'),
          isHls: true,
        ),
      ],
    );

    expect(result.isSuccess, isTrue);
    expect(logs.any((entry) => entry.contains('start candidates=')), isTrue);

    await orchestrator.seekTo(const Duration(minutes: 3, seconds: 15));

    expect(
      logs.any(
        (entry) => entry.contains('seek-phase start target=0:03:15.000000'),
      ),
      isTrue,
    );

    await orchestrator.dispose();
  });

  // ===== R1-R4 Seek Optimization Tests =====

  test(
    'Case A: seek within managed window uses native seek, not reopen',
    () async {
      final logs = <String>[];
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        onDebugLog: logs.add,
        seekVisualGateTimeout: Duration.zero,
      );

      // Open a managed window starting at 5:00.
      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 5),
      );
      expect(result.isSuccess, isTrue);
      expect(engine.openCalls, 1);

      // Simulate engine reporting local duration = 18:40 (window = 5:00..23:40).
      engine.emitDuration(const Duration(minutes: 18, seconds: 40));
      engine.emitPosition(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Seek to 10:00 — within the managed window [5:00..23:40].
      await orchestrator.seekTo(const Duration(minutes: 10));

      // Should NOT reopen — native seek should be used.
      expect(
        engine.openCalls,
        1,
        reason: 'should NOT reopen for in-window seek',
      );
      expect(engine.seekCalls, 1, reason: 'should use native seek');
      // No managed window → engine receives absolute position directly.
      expect(
        engine.lastSeekPosition,
        const Duration(minutes: 10),
        reason: 'engine gets absolute position (no managed window)',
      );
      expect(
        logs.any(
          (l) => l.contains('seekWindowHit') && l.contains('native-seek'),
        ),
        isTrue,
        reason: 'should log seekWindowHit',
      );

      await orchestrator.dispose();
    },
  );

  test('Case B: seek always uses native seek for anime nexus', () async {
    final logs = <String>[];
    final engine = _FakePlaybackEngine(
      openBehaviors: const <_OpenBehavior>[_OpenBehavior.success()],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      onDebugLog: logs.add,
      seekVisualGateTimeout: Duration.zero,
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse(
            'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
          ),
          isHls: true,
        ),
      ],
      initialPosition: const Duration(minutes: 5),
    );
    expect(result.isSuccess, isTrue);

    // Short window: local duration = 1:00.
    engine.emitDuration(const Duration(minutes: 1));
    engine.emitPosition(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Seek to 20:00 — would be outside old managed window, but native seek
    // is always used for Anime Nexus.
    await orchestrator.seekTo(const Duration(minutes: 20));

    expect(
      engine.openCalls,
      1,
      reason: 'native seek, no reopen for Anime Nexus',
    );
    expect(engine.seekCalls, 1, reason: 'native seek used');
    expect(engine.lastSeekPosition, const Duration(minutes: 20));
    expect(
      logs.any((l) => l.contains('seekWindowHit') && l.contains('native-seek')),
      isTrue,
      reason: 'should log seekWindowHit with native-seek action',
    );

    await orchestrator.dispose();
  });

  test('Case C: rapid double seek invalidates first seek', () async {
    final logs = <String>[];
    final engine = _FakePlaybackEngine(
      openBehaviors: const <_OpenBehavior>[_OpenBehavior.success()],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      onDebugLog: logs.add,
      seekVisualGateTimeout: Duration.zero,
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse(
            'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
          ),
          isHls: true,
        ),
      ],
      initialPosition: const Duration(minutes: 2),
    );
    expect(result.isSuccess, isTrue);

    engine.emitDuration(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Prevent immediate seek confirmation so the first seek session persists
    // until the second seek fires.
    engine.emitPositionOnSeek = false;

    // Seek A, then immediately seek B.
    unawaited(orchestrator.seekTo(const Duration(minutes: 7)));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await orchestrator.seekTo(const Duration(minutes: 14));

    // R4: Verify superseded log exists.
    expect(
      logs.any((l) => l.contains('seekGeneration superseded')),
      isTrue,
      reason: 'first seek session should be superseded',
    );

    await orchestrator.dispose();
  });

  test('Case D: native seek does not trigger predictive prewarm', () async {
    final logs = <String>[];
    final engine = _FakePlaybackEngine(
      openBehaviors: const <_OpenBehavior>[_OpenBehavior.success()],
    );
    final orchestrator = PlayerSessionOrchestrator(
      playbackEngine: engine,
      onDebugLog: logs.add,
      seekVisualGateTimeout: Duration.zero,
    );

    final result = await orchestrator.start(
      streamCandidates: <ResolvedStream>[
        ResolvedStream(
          url: Uri.parse(
            'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
          ),
          isHls: true,
        ),
      ],
      initialPosition: const Duration(minutes: 2),
    );
    expect(result.isSuccess, isTrue);

    engine.emitDuration(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await orchestrator.seekTo(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Native seek no longer calls signalPredictivePrewarm from the
    // orchestrator — the engine's seekTo fires its own prefetch internally.
    expect(engine.openCalls, 1, reason: 'native seek, no reopen');
    expect(engine.seekCalls, 1, reason: 'native seek used');
    expect(
      engine.predictivePrewarmCalls,
      0,
      reason: 'orchestrator no longer calls prewarm; engine does it internally',
    );
    expect(
      logs.any((l) => l.contains('predictivePrewarm scheduled')),
      isFalse,
      reason: 'scheduled prewarm is still windowed-only',
    );

    await orchestrator.dispose();
  });

  test(
    'Case E: raw positions without managed window after native seek',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[_OpenBehavior.success()],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );
      var latestPosition = Duration.zero;
      var latestDuration = Duration.zero;
      final positionSub = orchestrator.positionStream.listen(
        (value) => latestPosition = value,
      );
      final durationSub = orchestrator.durationStream.listen(
        (value) => latestDuration = value,
      );

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 5),
      );
      expect(result.isSuccess, isTrue);

      // No managed window → raw duration and position.
      engine.emitDuration(const Duration(minutes: 18, seconds: 40));
      engine.emitPosition(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Native seek to 12:00.
      await orchestrator.seekTo(const Duration(minutes: 12));

      // After native seek, engine reports position = 7:00 (simulated).
      engine.emitPosition(const Duration(minutes: 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // No managed window → position is raw 7:00, duration is raw 18:40.
      expect(latestPosition, const Duration(minutes: 7));
      expect(latestDuration, const Duration(minutes: 18, seconds: 40));

      await positionSub.cancel();
      await durationSub.cancel();
      await orchestrator.dispose();
    },
  );

  // ===== Timeline Domain Reset Tests =====

  test(
    'timeline domain: normal open without seek emits managed=false',
    () async {
      final engine = _FakePlaybackEngine();
      final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
      );
      expect(result.isSuccess, isTrue);
      expect(orchestrator.isManagedTimeline, isFalse);
      expect(orchestrator.timelineBase, Duration.zero);

      // Position from engine should pass through unmodified.
      var latestPosition = Duration.zero;
      final sub = orchestrator.positionStream.listen(
        (value) => latestPosition = value,
      );
      engine.emitPosition(const Duration(seconds: 42));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(latestPosition, const Duration(seconds: 42));

      await sub.cancel();
      await orchestrator.dispose();
    },
  );

  test(
    'timeline domain: initial position does not create managed window',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );

      var latestPosition = Duration.zero;
      var latestDuration = Duration.zero;
      final positionSub = orchestrator.positionStream.listen(
        (value) => latestPosition = value,
      );
      final durationSub = orchestrator.durationStream.listen(
        (value) => latestDuration = value,
      );

      // Open with initial position — no managed window should be created.
      final result = await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 5),
      );
      expect(result.isSuccess, isTrue);
      expect(orchestrator.isManagedTimeline, isFalse);
      expect(orchestrator.timelineBase, Duration.zero);

      engine.emitDuration(const Duration(minutes: 18, seconds: 40));
      engine.emitPosition(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Raw values — no offset.
      expect(latestPosition, const Duration(seconds: 10));
      expect(latestDuration, const Duration(minutes: 18, seconds: 40));

      // Retry — still unmanaged.
      await orchestrator.retry();
      expect(orchestrator.isManagedTimeline, isFalse);
      expect(orchestrator.timelineBase, Duration.zero);

      engine.emitDuration(const Duration(minutes: 23, seconds: 40));
      engine.emitPosition(const Duration(seconds: 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        latestPosition,
        const Duration(seconds: 7),
        reason: 'position must be raw without managed window',
      );
      expect(
        latestDuration,
        const Duration(minutes: 23, seconds: 40),
        reason: 'duration must reflect raw engine duration',
      );

      await positionSub.cancel();
      await durationSub.cancel();
      await orchestrator.dispose();
    },
  );

  test(
    'timeline domain: native seek cycles do not leak stale offsets',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[
          _OpenBehavior.success(),
          _OpenBehavior.success(),
          _OpenBehavior.success(),
        ],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );

      var latestPosition = Duration.zero;
      final positionSub = orchestrator.positionStream.listen(
        (value) => latestPosition = value,
      );

      // Cycle 1: Open with initial position — no managed window.
      await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 10),
      );
      expect(orchestrator.isManagedTimeline, isFalse);
      engine.emitDuration(const Duration(seconds: 30));
      engine.emitPosition(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Raw position — no offset.
      expect(latestPosition, const Duration(seconds: 3));

      // Cycle 2: Native seek (no reopen, no managed window).
      await orchestrator.seekTo(const Duration(minutes: 18));
      expect(orchestrator.isManagedTimeline, isFalse);
      expect(orchestrator.timelineBase, Duration.zero);

      engine.emitDuration(const Duration(minutes: 5, seconds: 40));
      engine.emitPosition(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Raw position — no stale offset.
      expect(
        latestPosition,
        const Duration(seconds: 2),
        reason: 'no stale managed offset should remain',
      );

      // Cycle 3: Retry — still no managed window.
      await orchestrator.retry();
      expect(orchestrator.isManagedTimeline, isFalse);
      expect(orchestrator.timelineBase, Duration.zero);
      engine.emitPosition(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        latestPosition,
        const Duration(seconds: 15),
        reason: 'no stale managed offset should remain',
      );

      await positionSub.cancel();
      await orchestrator.dispose();
    },
  );

  test(
    'timeline domain: position and duration share same domain per emission',
    () async {
      final engine = _FakePlaybackEngine(
        openBehaviors: const <_OpenBehavior>[_OpenBehavior.success()],
      );
      final orchestrator = PlayerSessionOrchestrator(
        playbackEngine: engine,
        seekVisualGateTimeout: Duration.zero,
      );

      final positions = <Duration>[];
      final durations = <Duration>[];
      final positionSub = orchestrator.positionStream.listen(positions.add);
      final durationSub = orchestrator.durationStream.listen(durations.add);

      await orchestrator.start(
        streamCandidates: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse(
              'http://127.0.0.1:63164/anime-nexus/session/master/5300/1.m3u8',
            ),
            isHls: true,
          ),
        ],
        initialPosition: const Duration(minutes: 7),
      );

      engine.emitDuration(const Duration(minutes: 16, seconds: 40));
      engine.emitPosition(const Duration(seconds: 5));
      engine.emitPosition(const Duration(seconds: 10));
      engine.emitPosition(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // No managed window → positions are raw from engine.
      for (final pos in positions) {
        expect(
          pos <= const Duration(minutes: 1),
          isTrue,
          reason: 'position $pos must be raw (no managed offset)',
        );
      }
      // Duration is raw from engine.
      for (final dur in durations) {
        expect(
          dur >= const Duration(minutes: 16),
          isTrue,
          reason: 'duration $dur must reflect raw engine duration',
        );
      }

      await positionSub.cancel();
      await durationSub.cancel();
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
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _bufferingPercentageController = StreamController<double>.broadcast();

  int openCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
  int clearSubtitleCalls = 0;
  int predictivePrewarmCalls = 0;
  int invalidatePendingOpenCalls = 0;
  Duration? lastSeekPosition;
  Duration? lastPrewarmPosition;
  int _issuedOpenToken = 0;
  int _invalidatedOpenToken = 0;
  final List<Duration> seekPositions = <Duration>[];
  ExternalSubtitleTrack? lastSubtitleTrack;
  final List<Duration?> openStartPositions = <Duration?>[];
  final List<Uri> openUrls = <Uri>[];

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferStream => _bufferController.stream;

  @override
  Stream<double> get bufferingPercentageStream =>
      _bufferingPercentageController.stream;

  @override
  Stream<EmbeddedTracks> get embeddedTracksStream =>
      const Stream<EmbeddedTracks>.empty();

  @override
  Stream<PlayerDiagnostics> get diagnosticsStream =>
      const Stream<PlayerDiagnostics>.empty();

  @override
  Future<void> get firstFrameRendered => Future<void>.value();

  /// When `false`, [seekTo] will NOT emit the position on the position stream.
  /// This allows tests to simulate stall scenarios where the engine does not
  /// immediately reach the target.
  bool emitPositionOnSeek = true;

  @override
  Future<void> seekTo(Duration position) async {
    seekCalls++;
    lastSeekPosition = position;
    seekPositions.add(position);
    if (emitPositionOnSeek) {
      _positionController.add(position);
    }
  }

  @override
  Future<void> signalPredictivePrewarm(Duration position) async {
    predictivePrewarmCalls++;
    lastPrewarmPosition = position;
  }

  @override
  Future<void> setSmartAudioBoost({required bool enabled}) async {}

  @override
  Future<void> clearSubtitleTrack() async {
    clearSubtitleCalls++;
    lastSubtitleTrack = null;
  }

  @override
  Future<void> setEmbeddedAudioTrack(EmbeddedAudioTrack track) async {}

  @override
  Future<void> setEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) async {}

  @override
  Future<void> setEmbeddedVideoTrack(EmbeddedVideoTrack track) async {}

  @override
  Future<void> clearEmbeddedVideoTrack() async {}

  @override
  Future<void> clearEmbeddedSubtitleTrack() async {}

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _bufferingController.close();
    await _completedController.close();
    await _errorController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferController.close();
    await _bufferingPercentageController.close();
  }

  @override
  Future<void> open(ResolvedStream stream, {Duration? startPosition}) async {
    openCalls++;
    final openToken = ++_issuedOpenToken;
    openStartPositions.add(startPosition);
    openUrls.add(stream.url);
    final behavior =
        _openBehaviors[_openBehaviorIndex.clamp(0, _openBehaviors.length - 1)];
    if (_openBehaviorIndex < _openBehaviors.length - 1) {
      _openBehaviorIndex++;
    }

    if (behavior.delayMs != null) {
      await Future<void>.delayed(Duration(milliseconds: behavior.delayMs!));
    }

    if (openToken <= _invalidatedOpenToken) {
      return;
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
  Future<void> invalidatePendingOpen({String reason = 'unknown'}) async {
    invalidatePendingOpenCalls++;
    _invalidatedOpenToken = _issuedOpenToken;
  }

  @override
  Future<void> setSubtitleTrack(ExternalSubtitleTrack track) async {
    lastSubtitleTrack = track;
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

  void emitCompleted(bool value) {
    _completedController.add(value);
  }

  void emitPosition(Duration value) {
    _positionController.add(value);
  }

  void emitDuration(Duration value) {
    _durationController.add(value);
  }

  void emitBuffer(Duration value) {
    _bufferController.add(value);
  }

  void emitBufferingPercentage(double value) {
    _bufferingPercentageController.add(value);
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
