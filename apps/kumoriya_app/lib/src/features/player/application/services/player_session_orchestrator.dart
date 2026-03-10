import 'dart:async';

import 'package:flutter/foundation.dart';
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
      _playbackEngine.completedStream.listen(_onCompletedChanged),
      _playbackEngine.errorStream.listen(_onPlaybackError),
      _playbackEngine.positionStream.listen(_onPositionChanged),
      _playbackEngine.durationStream.listen(_onDurationChanged),
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
  int _recoveriesForCurrentCandidate = 0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _lastKnownPosition = Duration.zero;
  Duration _lastKnownDuration = Duration.zero;
  Duration? _pendingTargetPosition;
  Duration? _lastRequestedSeekPosition;
  DateTime? _lastRequestedSeekAt;
  bool _isRecoveringCurrentCandidate = false;
  Timer? _bufferingTimer;

  Stream<PlayerSessionState> get states => _stateController.stream;
  PlayerSessionState get state => _state;

  Future<Result<ResolvedStream, KumoriyaError>> start({
    required List<ResolvedStream> streamCandidates,
    Duration? initialPosition,
  }) async {
    _log(
      'start candidates=${streamCandidates.length} initialPosition=$initialPosition',
    );
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
    _recoveriesForCurrentCandidate = 0;
    _pendingTargetPosition = _normalizeNullablePosition(initialPosition);
    _lastRequestedSeekPosition = _pendingTargetPosition;
    _lastRequestedSeekAt = _pendingTargetPosition != null
        ? DateTime.now()
        : null;
    return _openCurrentCandidate(startPosition: _pendingTargetPosition);
  }

  Future<Result<ResolvedStream, KumoriyaError>> retry() async {
    _log('retry pendingTarget=$_pendingTargetPosition');
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
    _recoveriesForCurrentCandidate = 0;
    return _openCurrentCandidate(startPosition: _pendingTargetPosition);
  }

  Future<void> seekTo(Duration position) async {
    final candidate = _state.selectedStream;
    if (candidate == null) {
      _log('seek ignored no-selected-stream target=$position');
      return;
    }

    final targetPosition = _normalizePosition(position);
    _pendingTargetPosition = targetPosition;
    _lastRequestedSeekPosition = targetPosition;
    _lastRequestedSeekAt = DateTime.now();
    _log(
      'seek requested target=$targetPosition current=$_lastKnownPosition hls=${candidate.isHls} candidateIndex=$_currentCandidateIndex',
    );

    if (_shouldReopenForSeek(candidate, targetPosition)) {
      await _recoverCurrentCandidate(
        errorCode: 'player.seek_recovery_failed',
        reason: 'Player could not seek current candidate in place.',
        recoveryPosition: targetPosition,
        force: true,
      );
      return;
    }

    await _playbackEngine.seekTo(targetPosition);
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

  Future<Result<ResolvedStream, KumoriyaError>> _openCurrentCandidate({
    Duration? startPosition,
  }) async {
    if (_currentCandidateIndex < 0 ||
        _currentCandidateIndex >= _rankedCandidates.length) {
      return _fail(
        code: 'player.all_candidates_failed',
        message: 'All playable stream candidates failed to open.',
        kind: KumoriyaErrorKind.transport,
      );
    }

    final candidate = _rankedCandidates[_currentCandidateIndex];
    _log(
      'openCurrentCandidate index=$_currentCandidateIndex/${_rankedCandidates.length} url=${candidate.url} startPosition=$startPosition',
    );
    _isRecoveringCurrentCandidate = false;
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
      await _playbackEngine
          .open(
            candidate,
            startPosition: _normalizeNullablePosition(startPosition),
          )
          .timeout(_openTimeoutFor(candidate, startPosition));
      _log(
        'openCurrentCandidate success index=$_currentCandidateIndex buffering=$_isBuffering playing=$_isPlaying pendingTarget=$_pendingTargetPosition',
      );
      final nextStatus = _isBuffering
          ? PlayerSessionStatus.buffering
          : (_isPlaying
                ? PlayerSessionStatus.playing
                : PlayerSessionStatus.paused);
      if (_isBuffering) {
        _startBufferingTimeoutWatch();
      }
      _pendingTargetPosition = null;
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
      _log('openCurrentCandidate timeout index=$_currentCandidateIndex');
      return _handleCandidateFailure(
        code: 'player.open_timeout',
        message: 'Timed out while opening playback candidate.',
      );
    } catch (error) {
      _log(
        'openCurrentCandidate error index=$_currentCandidateIndex error=$error',
      );
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
    _log(
      'handleCandidateFailure code=$code message=$message currentIndex=$_currentCandidateIndex total=${_rankedCandidates.length}',
    );
    final hasNext = (_currentCandidateIndex + 1) < _rankedCandidates.length;

    if (hasNext) {
      _currentCandidateIndex++;
      _runtimeErrorRetriesForCurrentCandidate = 0;
      _recoveriesForCurrentCandidate = 0;
      _isRecoveringCurrentCandidate = false;
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
    final wasPlaying = _isPlaying;
    _isPlaying = playing;
    _log('playingChanged playing=$playing buffering=$_isBuffering');
    if (_state.selectedStream == null) {
      return;
    }

    if (!playing &&
        wasPlaying &&
        _shouldRecoverFalseEof(_state.selectedStream!)) {
      _log(
        'playingChanged detected false-eof position=$_lastKnownPosition duration=$_lastKnownDuration lastSeek=$_lastRequestedSeekPosition',
      );
      unawaited(
        _recoverCurrentCandidate(
          errorCode: 'player.false_eof_recovery_failed',
          reason: 'Playback jumped to end unexpectedly after seek.',
          recoveryPosition: _lastRequestedSeekPosition,
          force: true,
        ),
      );
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
    _log(
      'bufferingChanged buffering=$buffering playing=$_isPlaying position=$_lastKnownPosition pendingTarget=$_pendingTargetPosition',
    );
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

  void _onPositionChanged(Duration position) {
    if (position < Duration.zero) {
      return;
    }
    final previousPosition = _lastKnownPosition;
    _lastKnownPosition = position;
    if (_shouldRecoverFalseEofFromPositionJump(previousPosition, position)) {
      _log(
        'positionChanged detected false-eof jump previous=$previousPosition current=$position duration=$_lastKnownDuration lastSeek=$_lastRequestedSeekPosition',
      );
      unawaited(
        _recoverCurrentCandidate(
          errorCode: 'player.false_eof_recovery_failed',
          reason: 'Playback jumped to end unexpectedly after seek.',
          recoveryPosition: _lastRequestedSeekPosition,
          force: true,
        ),
      );
      return;
    }
    if (_pendingTargetPosition != null || position.inSeconds % 30 == 0) {
      _log(
        'positionChanged position=$position pendingTarget=$_pendingTargetPosition',
      );
    }
    final pendingTargetPosition = _pendingTargetPosition;
    if (pendingTargetPosition != null &&
        _isPositionNearTarget(position, pendingTargetPosition)) {
      _pendingTargetPosition = null;
    }
  }

  void _onDurationChanged(Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }
    _lastKnownDuration = duration;
  }

  void _onCompletedChanged(bool completed) {
    _log(
      'completedChanged completed=$completed position=$_lastKnownPosition duration=$_lastKnownDuration lastSeek=$_lastRequestedSeekPosition',
    );
    final candidate = _state.selectedStream;
    if (!completed || candidate == null) {
      return;
    }
    if (!_shouldRecoverFalseEof(candidate)) {
      return;
    }
    unawaited(
      _recoverCurrentCandidate(
        errorCode: 'player.false_eof_recovery_failed',
        reason: 'Playback completed unexpectedly after seek.',
        recoveryPosition: _lastRequestedSeekPosition,
        force: true,
      ),
    );
  }

  void _onPlaybackError(String error) {
    _log(
      'playbackError error=$error buffering=$_isBuffering position=$_lastKnownPosition pendingTarget=$_pendingTargetPosition',
    );
    if (_shouldDeferRuntimeError(error)) {
      unawaited(
        _recoverCurrentCandidate(
          errorCode: 'player.seek_recovery_failed',
          reason: 'Runtime playback error while buffering: $error',
          recoveryPosition: _recoveryPosition,
        ),
      );
      return;
    }

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

  Future<void> _recoverCurrentCandidate({
    required String errorCode,
    required String reason,
    Duration? recoveryPosition,
    bool force = false,
  }) async {
    _log(
      'recoverCurrentCandidate force=$force recoveryPosition=$recoveryPosition currentIndex=$_currentCandidateIndex recoveries=$_recoveriesForCurrentCandidate pendingTarget=$_pendingTargetPosition',
    );
    if (_isRecoveringCurrentCandidate ||
        (!force && _recoveriesForCurrentCandidate >= 1) ||
        _currentCandidateIndex < 0 ||
        _currentCandidateIndex >= _rankedCandidates.length) {
      return;
    }

    _isRecoveringCurrentCandidate = true;
    if (!force) {
      _recoveriesForCurrentCandidate++;
    }
    final candidate = _rankedCandidates[_currentCandidateIndex];
    final targetPosition = _normalizePosition(
      recoveryPosition ?? _recoveryPosition,
    );
    _log(
      'recoverCurrentCandidate opening url=${candidate.url} target=$targetPosition hls=${candidate.isHls}',
    );
    _pendingTargetPosition = targetPosition > Duration.zero
        ? targetPosition
        : _pendingTargetPosition;
    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.buffering,
        infoMessage: 'player.fallback_in_progress',
        currentCandidateIndex: _currentCandidateIndex,
        totalCandidates: _rankedCandidates.length,
        clearError: true,
      ),
    );

    try {
      await _playbackEngine
          .open(
            candidate,
            startPosition: targetPosition > Duration.zero
                ? targetPosition
                : null,
          )
          .timeout(_openTimeoutFor(candidate, targetPosition));
      _log(
        'recoverCurrentCandidate open-success target=$targetPosition buffering=$_isBuffering playing=$_isPlaying',
      );
      if (!_shouldReopenForSeek(candidate, targetPosition) &&
          targetPosition > Duration.zero) {
        await _playbackEngine.seekTo(targetPosition);
        _log('recoverCurrentCandidate direct-seek target=$targetPosition');
      }
      _runtimeErrorRetriesForCurrentCandidate = 0;
      final nextStatus = _isBuffering
          ? PlayerSessionStatus.buffering
          : (_isPlaying
                ? PlayerSessionStatus.playing
                : PlayerSessionStatus.paused);
      if (_isBuffering) {
        _startBufferingTimeoutWatch();
      }
      _pendingTargetPosition = null;
      _emit(
        _state.copyWith(
          status: nextStatus,
          selectedStream: candidate,
          currentCandidateIndex: _currentCandidateIndex,
          totalCandidates: _rankedCandidates.length,
          clearInfo: true,
          clearError: true,
        ),
      );
      _log(
        'recoverCurrentCandidate completed status=$nextStatus pendingTarget=$_pendingTargetPosition position=$_lastKnownPosition',
      );
      _isRecoveringCurrentCandidate = false;
    } on TimeoutException {
      _isRecoveringCurrentCandidate = false;
      _log('recoverCurrentCandidate timeout target=$recoveryPosition');
      await _handleCandidateFailure(
        code: errorCode,
        message: 'Timed out while recovering current playback candidate.',
      );
    } catch (error) {
      _isRecoveringCurrentCandidate = false;
      _log(
        'recoverCurrentCandidate error target=$recoveryPosition error=$error',
      );
      await _handleCandidateFailure(
        code: errorCode,
        message: '$reason. Recovery failed: $error',
      );
    }
  }

  bool _shouldDeferRuntimeError(String error) {
    if (_state.selectedStream == null || !_isBuffering) {
      return false;
    }

    final message = error.toLowerCase();
    if (message.contains('ffurl_read') ||
        message.contains('tcp:') ||
        message.contains('tls:') ||
        message.contains('mbedtls')) {
      return false;
    }

    if (message.contains('seek') ||
        message.contains('buffer') ||
        message.contains('segment') ||
        message.contains('timeout') ||
        message.contains('network') ||
        message.contains('eof')) {
      return true;
    }

    return _state.selectedStream!.isHls;
  }

  void _startBufferingTimeoutWatch() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(_bufferingTimeout, () {
      _log(
        'bufferingTimeout fired status=${_state.status} recoveries=$_recoveriesForCurrentCandidate pendingTarget=$_pendingTargetPosition position=$_lastKnownPosition',
      );
      if (_state.status != PlayerSessionStatus.buffering) {
        return;
      }
      if (_recoveriesForCurrentCandidate < 1) {
        unawaited(
          _recoverCurrentCandidate(
            errorCode: 'player.buffering_recovery_failed',
            reason: 'Buffering took too long for current candidate.',
            recoveryPosition: _recoveryPosition,
          ),
        );
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
    _log(
      'emit status=${next.status} index=${next.currentCandidateIndex}/${next.totalCandidates} hasStream=${next.selectedStream != null} info=${next.infoMessage} error=${next.errorMessage}',
    );
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

  Duration get _recoveryPosition =>
      _normalizePosition(_pendingTargetPosition ?? _lastKnownPosition);

  bool _shouldReopenForSeek(ResolvedStream candidate, Duration position) {
    if (position <= Duration.zero) {
      return false;
    }
    return candidate.isHls;
  }

  Duration _normalizePosition(Duration? position) {
    if (position == null || position <= Duration.zero) {
      return Duration.zero;
    }
    return position;
  }

  Duration? _normalizeNullablePosition(Duration? position) {
    final normalized = _normalizePosition(position);
    return normalized > Duration.zero ? normalized : null;
  }

  Duration _openTimeoutFor(ResolvedStream candidate, Duration? startPosition) {
    if (candidate.isHls &&
        startPosition != null &&
        startPosition > Duration.zero) {
      return const Duration(seconds: 40);
    }
    return _openTimeout;
  }

  bool _isPositionNearTarget(Duration position, Duration target) {
    final delta = position - target;
    return delta.inSeconds.abs() <= 2;
  }

  bool _shouldRecoverFalseEof(ResolvedStream candidate) {
    if (!candidate.isHls) {
      return false;
    }
    if (_isBuffering || _isRecoveringCurrentCandidate) {
      return false;
    }
    final lastSeekPosition = _lastRequestedSeekPosition;
    final lastSeekAt = _lastRequestedSeekAt;
    if (lastSeekPosition == null || lastSeekAt == null) {
      return false;
    }
    if (DateTime.now().difference(lastSeekAt) > const Duration(seconds: 45)) {
      return false;
    }
    if (_lastKnownDuration <= const Duration(seconds: 5)) {
      return false;
    }
    if (!_isNearEnd(_lastKnownPosition, _lastKnownDuration)) {
      return false;
    }
    if (_isNearEnd(lastSeekPosition, _lastKnownDuration)) {
      return false;
    }
    return true;
  }

  bool _isNearEnd(Duration position, Duration duration) {
    if (duration <= Duration.zero) {
      return false;
    }
    return (duration - position).inSeconds.abs() <= 3;
  }

  bool _shouldRecoverFalseEofFromPositionJump(
    Duration previousPosition,
    Duration currentPosition,
  ) {
    final candidate = _state.selectedStream;
    if (candidate == null || !candidate.isHls) {
      return false;
    }
    if (_isRecoveringCurrentCandidate) {
      return false;
    }
    final lastSeekPosition = _lastRequestedSeekPosition;
    final lastSeekAt = _lastRequestedSeekAt;
    if (lastSeekPosition == null || lastSeekAt == null) {
      return false;
    }
    if (DateTime.now().difference(lastSeekAt) > const Duration(seconds: 45)) {
      return false;
    }
    if (_lastKnownDuration <= const Duration(seconds: 5)) {
      return false;
    }
    if (!_isNearEnd(currentPosition, _lastKnownDuration)) {
      return false;
    }
    if (_isNearEnd(lastSeekPosition, _lastKnownDuration)) {
      return false;
    }
    if (_isNearEnd(previousPosition, _lastKnownDuration)) {
      return false;
    }
    final jumpedForward = currentPosition - previousPosition;
    if (jumpedForward < const Duration(seconds: 30)) {
      return false;
    }
    return true;
  }

  void _log(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[player.orchestrator ${DateTime.now().toIso8601String()}] $message',
    );
  }
}
