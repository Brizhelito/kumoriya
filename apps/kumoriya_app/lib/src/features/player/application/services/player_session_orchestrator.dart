import 'dart:async';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/player_session_state.dart';
import 'playback_engine.dart';
import 'stream_selection_policy.dart';

final class PlayerSessionOrchestrator {
  PlayerSessionOrchestrator({
    required PlaybackEngine playbackEngine,
    StreamSelectionPolicy? selectionPolicy,
    Duration? openTimeout,
    Duration? bufferingTimeout,
  }) : _playbackEngine = playbackEngine,
       _selectionPolicy = selectionPolicy ?? const StreamSelectionPolicy(),
       _openTimeout = openTimeout ?? const Duration(seconds: 18),
       _bufferingTimeout = bufferingTimeout ?? const Duration(seconds: 25) {
    _subscriptions = <StreamSubscription<dynamic>>[
      _playbackEngine.playingStream.listen(_onPlayingChanged),
      _playbackEngine.bufferingStream.listen(_onBufferingChanged),
      _playbackEngine.errorStream.listen(_onPlaybackError),
    ];
  }

  final PlaybackEngine _playbackEngine;
  final StreamSelectionPolicy _selectionPolicy;
  final Duration _openTimeout;
  final Duration _bufferingTimeout;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  final _stateController = StreamController<PlayerSessionState>.broadcast();
  PlayerSessionState _state = const PlayerSessionState.idle();

  List<ResolvedStream> _rankedCandidates = const <ResolvedStream>[];
  int _currentCandidateIndex = -1;
  int _runtimeErrorRetriesForCurrentCandidate = 0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Timer? _bufferingTimer;

  Stream<PlayerSessionState> get states => _stateController.stream;
  PlayerSessionState get state => _state;

  Future<Result<ResolvedStream, KumoriyaError>> start({
    required List<ResolvedStream> streamCandidates,
  }) async {
    _rankedCandidates = _selectionPolicy
        .rankCandidates(streamCandidates)
        .where((candidate) => _isSupportedUrl(candidate.url))
        .toList(growable: false);

    if (_rankedCandidates.isEmpty) {
      return _fail(
        code: 'player.no_playable_stream',
        message: 'No playable stream candidates were provided to player.',
        kind: KumoriyaErrorKind.notFound,
      );
    }

    _currentCandidateIndex = 0;
    _runtimeErrorRetriesForCurrentCandidate = 0;
    return _openCurrentCandidate();
  }

  Future<Result<ResolvedStream, KumoriyaError>> retry() async {
    if (_rankedCandidates.isEmpty) {
      return const Failure(
        SimpleError(
          code: 'player.no_playable_stream',
          message: 'No playable stream candidates were provided to player.',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }

    _currentCandidateIndex = 0;
    _runtimeErrorRetriesForCurrentCandidate = 0;
    return _openCurrentCandidate();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _playbackEngine.pause();
      return;
    }

    await _playbackEngine.play();
  }

  Future<void> dispose() async {
    _bufferingTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _playbackEngine.dispose();
    await _stateController.close();
  }

  Future<Result<ResolvedStream, KumoriyaError>> _openCurrentCandidate() async {
    if (_currentCandidateIndex < 0 ||
        _currentCandidateIndex >= _rankedCandidates.length) {
      return _fail(
        code: 'player.all_candidates_failed',
        message: 'All playable stream candidates failed to open.',
        kind: KumoriyaErrorKind.transport,
      );
    }

    final candidate = _rankedCandidates[_currentCandidateIndex];
    _emit(
      _state.copyWith(
        status: _state.status == PlayerSessionStatus.fallbacking
            ? PlayerSessionStatus.fallbacking
            : PlayerSessionStatus.opening,
        selectedStream: candidate,
        currentCandidateIndex: _currentCandidateIndex,
        totalCandidates: _rankedCandidates.length,
        clearError: true,
      ),
    );

    try {
      await _playbackEngine.open(candidate).timeout(_openTimeout);
      final nextStatus = _isBuffering
          ? PlayerSessionStatus.buffering
          : (_isPlaying
                ? PlayerSessionStatus.playing
                : PlayerSessionStatus.paused);
      if (_isBuffering) {
        _startBufferingTimeoutWatch();
      }
      _emit(
        _state.copyWith(
          status: nextStatus,
          selectedStream: candidate,
          currentCandidateIndex: _currentCandidateIndex,
          totalCandidates: _rankedCandidates.length,
          clearInfo: true,
        ),
      );
      return Success(candidate);
    } on TimeoutException {
      return _handleCandidateFailure(
        code: 'player.open_timeout',
        message: 'Timed out while opening playback candidate.',
      );
    } catch (error) {
      return _handleCandidateFailure(
        code: _classifyOpenFailureCode(error.toString()),
        message: 'Player failed to open candidate: $error',
      );
    }
  }

  Future<Result<ResolvedStream, KumoriyaError>> _handleCandidateFailure({
    required String code,
    required String message,
  }) async {
    final hasNext = (_currentCandidateIndex + 1) < _rankedCandidates.length;

    if (hasNext) {
      _currentCandidateIndex++;
      _runtimeErrorRetriesForCurrentCandidate = 0;
      _emit(
        _state.copyWith(
          status: PlayerSessionStatus.fallbacking,
          infoMessage: 'player.fallback_in_progress',
          currentCandidateIndex: _currentCandidateIndex,
          totalCandidates: _rankedCandidates.length,
          clearError: true,
        ),
      );
      return _openCurrentCandidate();
    }

    if (_rankedCandidates.length <= 1) {
      return _fail(
        code: code,
        message: message,
        kind: KumoriyaErrorKind.transport,
      );
    }

    return _fail(
      code: 'player.all_candidates_failed',
      message: 'All playback candidates failed. Last error: $message',
      kind: KumoriyaErrorKind.transport,
      infoMessage: 'player.tried_all_candidates',
    );
  }

  void _onPlayingChanged(bool playing) {
    _isPlaying = playing;
    if (_state.selectedStream == null) {
      return;
    }

    if (_isBuffering) {
      _emit(_state.copyWith(status: PlayerSessionStatus.buffering));
      return;
    }

    _emit(
      _state.copyWith(
        status: playing
            ? PlayerSessionStatus.playing
            : PlayerSessionStatus.paused,
      ),
    );
  }

  void _onBufferingChanged(bool buffering) {
    _isBuffering = buffering;
    if (_state.selectedStream == null) {
      return;
    }

    if (buffering) {
      _emit(_state.copyWith(status: PlayerSessionStatus.buffering));
      _startBufferingTimeoutWatch();
      return;
    }

    _bufferingTimer?.cancel();
    _emit(
      _state.copyWith(
        status: _isPlaying
            ? PlayerSessionStatus.playing
            : PlayerSessionStatus.paused,
      ),
    );
  }

  void _onPlaybackError(String error) {
    if (_runtimeErrorRetriesForCurrentCandidate < 1) {
      _runtimeErrorRetriesForCurrentCandidate++;
      unawaited(
        _handleCandidateFailure(
          code: 'player.candidate_failed',
          message: 'Runtime playback error: $error',
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(status: PlayerSessionStatus.error, errorMessage: error),
    );
  }

  void _startBufferingTimeoutWatch() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(_bufferingTimeout, () {
      if (_state.status != PlayerSessionStatus.buffering) {
        return;
      }
      unawaited(
        _handleCandidateFailure(
          code: 'player.buffering_timeout',
          message: 'Buffering took too long for current candidate.',
        ),
      );
    });
  }

  Result<ResolvedStream, KumoriyaError> _fail({
    required String code,
    required String message,
    required KumoriyaErrorKind kind,
    String? infoMessage,
  }) {
    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.error,
        errorMessage: message,
        infoMessage: infoMessage,
      ),
    );

    return Failure(SimpleError(code: code, message: message, kind: kind));
  }

  void _emit(PlayerSessionState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  bool _isSupportedUrl(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    return url.scheme == 'http' || url.scheme == 'https';
  }

  String _classifyOpenFailureCode(String error) {
    final value = error.toLowerCase();
    if (value.contains('unsupported') || value.contains('codec')) {
      return 'player.unsupported_stream';
    }
    if (value.contains('network') || value.contains('http')) {
      return 'player.network_failure';
    }
    return 'player.open_failed';
  }
}
