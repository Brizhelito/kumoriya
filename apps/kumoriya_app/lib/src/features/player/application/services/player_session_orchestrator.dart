import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/embedded_tracks.dart';
import '../models/player_session_state.dart';
import 'playback_engine.dart';
import 'stream_selection_policy.dart';

/// Represents an active seek operation with a sticky target that survives
/// candidate fallbacks, recovery attempts, and engine reopens.
class _SeekSession {
  _SeekSession({
    required this.generation,
    required this.targetPosition,
    required this.originCandidateIndex,
    required this.startedAt,
  });

  final int generation;
  final Duration targetPosition;
  final int originCandidateIndex;
  final DateTime startedAt;

  /// Current escalation level: 1=local seek, 2=reopen same candidate, 3=fallback.
  int currentLevel = 1;

  /// Number of reopen attempts at the current level before escalating.
  int reopenAttempts = 0;
}

final class PlayerSessionOrchestrator {
  static const Duration _seekReadyBudget = Duration(seconds: 8);
  static const Duration _seekVisualGateMax = Duration(seconds: 5);
  static const Duration _bufferedSeekSafetyMargin = Duration(seconds: 1);
  static const Duration _initialResumeOpenBudget = Duration(seconds: 50);
  static const Duration _animeNexusInitialOpenBudget = Duration(seconds: 50);
  // R2: Tightened auto-quality thresholds for faster reactions.
  // Old: 45s stable / 30s cooldown / 8s downshift.
  static const Duration _autoQualityStableFor = Duration(seconds: 25);
  static const Duration _autoQualityCooldown = Duration(seconds: 15);
  static const Duration _autoQualityDownshiftBuffering = Duration(seconds: 5);

  PlayerSessionOrchestrator({
    required PlaybackEngine playbackEngine,
    StreamSelectionPolicy? selectionPolicy,
    Duration? openTimeout,
    Duration? bufferingTimeout,
    Duration? seekVisualGateTimeout,
    void Function(String message)? onDebugLog,
  }) : _playbackEngine = playbackEngine,
       _selectionPolicy = selectionPolicy ?? const StreamSelectionPolicy(),
       _openTimeout = openTimeout ?? const Duration(seconds: 30),
       _bufferingTimeout = bufferingTimeout ?? const Duration(seconds: 18),
       _seekVisualGateTimeout = seekVisualGateTimeout ?? _seekVisualGateMax,
       _debugLogSink = onDebugLog {
    _subscriptions = <StreamSubscription<dynamic>>[
      _playbackEngine.playingStream.listen(_onPlayingChanged),
      _playbackEngine.bufferingStream.listen(_onBufferingChanged),
      _playbackEngine.completedStream.listen(_onCompletedChanged),
      _playbackEngine.errorStream.listen(_onPlaybackError),
      _playbackEngine.positionStream.listen(_onPositionChanged),
      _playbackEngine.durationStream.listen(_onDurationChanged),
      _playbackEngine.bufferStream.listen(_onBufferChanged),
      _playbackEngine.bufferingPercentageStream.listen(
        _onBufferingPercentageChanged,
      ),
    ];
  }

  final PlaybackEngine _playbackEngine;
  final StreamSelectionPolicy _selectionPolicy;
  final Duration _openTimeout;
  final Duration _bufferingTimeout;
  final Duration _seekVisualGateTimeout;
  final void Function(String message)? _debugLogSink;
  late final List<StreamSubscription<dynamic>> _subscriptions;
  late final String _instanceId = identityHashCode(this).toRadixString(16);

  final _stateController = StreamController<PlayerSessionState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _naturalCompletionController = StreamController<void>.broadcast();
  PlayerSessionState _state = const PlayerSessionState.idle();

  List<ResolvedStream> _rankedCandidates = const <ResolvedStream>[];
  List<ExternalSubtitleTrack> _externalSubtitles =
      const <ExternalSubtitleTrack>[];
  int _currentCandidateIndex = -1;
  int _runtimeErrorRetriesForCurrentCandidate = 0;
  int _recoveriesForCurrentCandidate = 0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _lastKnownPosition = Duration.zero;
  Duration _lastKnownDuration = Duration.zero;
  Duration _lastRawDurationFromEngine = Duration.zero;
  Duration? _pendingTargetPosition;
  Duration? _lastRequestedSeekPosition;
  DateTime? _lastRequestedSeekAt;
  String? _selectedExternalSubtitleId;
  bool _isRecoveringCurrentCandidate = false;
  bool _isDisposed = false;
  bool _hasStarted = false;
  Timer? _bufferingTimer;
  Timer? _autoQualityUpgradeTimer;
  Timer? _autoQualityDownshiftTimer;
  Timer? _seekStallTimer;
  DateTime? _lastBufferingAt;
  DateTime? _lastQualitySwitchAt;
  int? _lastStableCandidateIndex;
  bool _autoQualityEnabled = true;
  int? _manualQualityIndex;
  Duration _lastBufferedDuration = Duration.zero;
  double _lastBufferingPercentage = 0;
  final Map<String, double> _variantThroughputBps = <String, double>{};
  final Map<String, double> _variantRequiredBps = <String, double>{};
  Duration? _seekWatchTargetPosition;
  Duration? _seekWatchBaselinePosition;
  int _seekStallRecoveriesForCurrentTarget = 0;
  Duration _timelineBasePosition = Duration.zero;
  Duration _fullTimelineDurationHint = Duration.zero;
  bool _isManagedTimelineWindow = false;
  int _seekGeneration = 0;
  int _predictivePrewarmGeneration = 0;
  _SeekSession? _activeSeekSession;
  Timer? _seekPositionValidationTimer;

  /// Last confirmed seek latency in milliseconds.  Exposed for the
  /// diagnostics overlay.
  int? _lastConfirmedSeekLatencyMs;

  /// Last confirmed seek latency — null until the first seek completes.
  int? get lastSeekLatencyMs => _lastConfirmedSeekLatencyMs;

  /// Monotonically increasing counter incremented at the top of every
  /// [_openCurrentCandidate] call.  Used to detect stale errors: if
  /// [PlayerSessionState.errorGeneration] < [_openGeneration] at the time of
  /// a successful open, the error was produced by a superseded open and must
  /// be cleared.
  int _openGeneration = 0;

  Stream<PlayerSessionState> get states => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  /// Fires when the current media naturally reaches its end (not a false EOF).
  Stream<void> get naturalCompletionStream =>
      _naturalCompletionController.stream;
  PlayerSessionState get state => _state;
  bool get isAutoQualityEnabled => _autoQualityEnabled;
  List<ResolvedStream> get qualityCandidates =>
      List<ResolvedStream>.unmodifiable(_rankedCandidates);
  List<ExternalSubtitleTrack> get externalSubtitleTracks =>
      List<ExternalSubtitleTrack>.unmodifiable(_externalSubtitles);

  /// Embedded audio/subtitle tracks reported by the playback engine.
  Stream<EmbeddedTracks> get embeddedTracksStream =>
      _playbackEngine.embeddedTracksStream;

  /// Select an embedded audio track for the current playback session.
  Future<void> selectEmbeddedAudioTrack(EmbeddedAudioTrack track) async {
    _log('selectEmbeddedAudioTrack id=${track.id} label=${track.displayLabel}');
    await _playbackEngine.setEmbeddedAudioTrack(track);
  }

  /// Select an embedded subtitle track for the current playback session.
  Future<void> selectEmbeddedSubtitleTrack(EmbeddedSubtitleTrack track) async {
    _log(
      'selectEmbeddedSubtitleTrack id=${track.id} label=${track.displayLabel}',
    );
    await _playbackEngine.setEmbeddedSubtitleTrack(track);
  }

  /// Disable the currently active embedded subtitle track.
  Future<void> clearEmbeddedSubtitleTrack() async {
    _log('clearEmbeddedSubtitleTrack');
    await _playbackEngine.clearEmbeddedSubtitleTrack();
  }

  Future<void> selectExternalSubtitleTrack(ExternalSubtitleTrack track) async {
    _log('selectExternalSubtitleTrack id=${track.id} label=${track.label}');
    _selectedExternalSubtitleId = track.id;
    await _playbackEngine.setSubtitleTrack(track);
  }

  Future<void> clearExternalSubtitleTrack() async {
    _log('clearExternalSubtitleTrack');
    _selectedExternalSubtitleId = null;
    await _playbackEngine.clearSubtitleTrack();
  }

  Future<void> setAutoQualityEnabled(bool enabled) async {
    _autoQualityEnabled = enabled;
    if (enabled) {
      _manualQualityIndex = null;
      _log('qualityMode auto');
      _startAutoQualityUpgradeWatch();
      return;
    }
    _autoQualityUpgradeTimer?.cancel();
    _autoQualityDownshiftTimer?.cancel();
    _manualQualityIndex ??= _currentCandidateIndex >= 0
        ? _currentCandidateIndex
        : null;
    _log('qualityMode manual index=$_manualQualityIndex');
  }

  Future<void> selectQualityByIndex(int index) async {
    if (index < 0 || index >= _rankedCandidates.length) {
      return;
    }
    _manualQualityIndex = index;
    _autoQualityEnabled = false;
    _autoQualityUpgradeTimer?.cancel();
    _autoQualityDownshiftTimer?.cancel();

    if (index == _currentCandidateIndex) {
      _log('qualityManual unchanged index=$index');
      return;
    }

    final resumeFrom = _lastKnownPosition > Duration.zero
        ? _lastKnownPosition
        : null;
    _currentCandidateIndex = index;
    _runtimeErrorRetriesForCurrentCandidate = 0;
    _recoveriesForCurrentCandidate = 0;
    _lastQualitySwitchAt = DateTime.now();
    _log(
      'qualityManual switch toIndex=$index '
      'variant=${_variantFromUrl(_rankedCandidates[index].url)} '
      'resumeFrom=$resumeFrom',
    );
    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.fallbacking,
        infoMessage: 'player.manual_quality_switch',
        currentCandidateIndex: _currentCandidateIndex,
        totalCandidates: _rankedCandidates.length,
        clearError: true,
      ),
    );
    await _openCurrentCandidate(startPosition: resumeFrom);
  }

  /// Whether the orchestrator is operating in a managed timeline window.
  ///
  /// Exposed for UI instrumentation only — the UI must NOT use this to derive
  /// slider/label values; it should use [positionStream] and [durationStream].
  bool get isManagedTimeline => _isManagedTimelineWindow;

  /// The base offset of the current managed timeline window.
  ///
  /// Zero when [isManagedTimeline] is `false`.
  Duration get timelineBase => _timelineBasePosition;

  Future<Result<ResolvedStream, KumoriyaError>> start({
    required List<ResolvedStream> streamCandidates,
    List<ExternalSubtitleTrack> externalSubtitles =
        const <ExternalSubtitleTrack>[],
    Duration? initialPosition,
  }) async {
    if (_hasStarted && _state.status != PlayerSessionStatus.idle) {
      _log(
        'duplicate start ignored incoming=${streamCandidates.length} existing=${_rankedCandidates.length} status=${_state.status} candidates=${_candidateSummary(streamCandidates)}',
      );
      final existingCandidate =
          _state.selectedStream ??
          (_rankedCandidates.isNotEmpty ? _rankedCandidates.first : null);
      if (existingCandidate != null) {
        return Success(existingCandidate);
      }
      return _fail(
        code: 'player.duplicate_start',
        message: 'Duplicate player start was ignored.',
        kind: KumoriyaErrorKind.unexpected,
      );
    }

    _log(
      'start candidates=${streamCandidates.length} initialPosition=$initialPosition candidateUrls=${_candidateSummary(streamCandidates)}',
    );
    _hasStarted = true;
    _rankedCandidates = _selectionPolicy
        .rankCandidates(streamCandidates)
        .where((candidate) => _isSupportedUrl(candidate.url))
        .toList(growable: false);
    _variantThroughputBps.clear();
    _variantRequiredBps.clear();

    if (_rankedCandidates.isEmpty) {
      return _fail(
        code: 'player.no_playable_stream',
        message: 'No playable stream candidates were provided to player.',
        kind: KumoriyaErrorKind.notFound,
      );
    }

    _currentCandidateIndex = await _pickInitialCandidateIndex();
    _externalSubtitles = externalSubtitles;
    _runtimeErrorRetriesForCurrentCandidate = 0;
    _recoveriesForCurrentCandidate = 0;
    _resetSeekRecoveryTracking();
    _cancelSeekSession('new-start');
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

    _currentCandidateIndex = await _pickInitialCandidateIndex();
    _runtimeErrorRetriesForCurrentCandidate = 0;
    _recoveriesForCurrentCandidate = 0;
    _resetSeekRecoveryTracking();
    _cancelSeekSession('retry');
    return _openCurrentCandidate(startPosition: _pendingTargetPosition);
  }

  Future<void> seekTo(Duration position) async {
    final candidate = _state.selectedStream;
    if (candidate == null) {
      _log('seek ignored no-selected-stream target=$position');
      return;
    }

    final targetPosition = _normalizePosition(position);
    final seekGen = ++_seekGeneration;
    final seekStartTime = DateTime.now();

    // R4: Cancel all stale seek operations before setting up new session.
    _cancelStaleSeekOperations(seekGen);

    _activeSeekSession = _SeekSession(
      generation: seekGen,
      targetPosition: targetPosition,
      originCandidateIndex: _currentCandidateIndex,
      startedAt: seekStartTime,
    );
    _pendingTargetPosition = targetPosition;
    _lastRequestedSeekPosition = targetPosition;
    _lastRequestedSeekAt = seekStartTime;
    _resetSeekRecoveryTracking();
    _log(
      'seek-phase start target=$targetPosition generation=$seekGen '
      'candidateIndex=$_currentCandidateIndex hls=${candidate.isHls}',
    );
    _log(
      'seekQuality start currentVariant=${_variantFromUrl(candidate.url)} '
      'candidateIndex=$_currentCandidateIndex',
    );

    // Level 1: Try native seek if the candidate/manifest supports it.
    if (!_shouldReopenForSeek(candidate, targetPosition)) {
      _activeSeekSession!.currentLevel = 1;

      // Managed-window escape: if a previous code path left us in a managed
      // window and the target is outside that window, reopen with the full
      // manifest first, then native-seek.  This is the safety net — under
      // normal operation managed windows are no longer created.
      if (_isManagedTimelineWindow &&
          _isAnimeNexusLoopbackHls(candidate.url) &&
          !_isTargetInCurrentWindow(targetPosition)) {
        _log(
          'seek managed-window-escape target=$targetPosition '
          'window=[$_timelineBasePosition .. '
          '${_timelineBasePosition + _lastRawDurationFromEngine}]',
        );
        await _reopenFullManifestThenSeek(
          candidate,
          targetPosition,
          seekStartTime: seekStartTime,
        );
        return;
      }

      // R1: Convert absolute target to local position for managed windows.
      final engineTarget = _isManagedTimelineWindow
          ? targetPosition - _timelineBasePosition
          : targetPosition;
      _log(
        'seekWindowHit target=$targetPosition '
        'windowStart=$_timelineBasePosition '
        'windowEnd=${_timelineBasePosition + _lastRawDurationFromEngine} '
        'action=native-seek localTarget=$engineTarget',
      );

      // Guard: if another seek superseded ours during the async gap, bail.
      if (seekGen != _seekGeneration) return;

      await _playbackEngine.seekTo(engineTarget);

      // Guard: another seek may have arrived while the engine was seeking.
      if (seekGen != _seekGeneration) return;

      final elapsed = DateTime.now().difference(seekStartTime);
      _log('seek-phase native-seek-done elapsed=${elapsed.inMilliseconds}ms');
      _startSeekStallWatch(
        candidate: candidate,
        targetPosition: targetPosition,
      );
      return;
    }

    // Level 2: Reopen same candidate with windowed HLS anchored to target.
    _activeSeekSession!.currentLevel = 2;
    _log(
      'seekWindowMiss target=$targetPosition '
      'windowStart=$_timelineBasePosition '
      'windowEnd=${_timelineBasePosition + _lastRawDurationFromEngine} '
      'action=reopen',
    );
    await _recoverCurrentCandidate(
      errorCode: 'player.seek_recovery_failed',
      reason: 'Player could not seek current candidate in place.',
      recoveryPosition: targetPosition,
      force: true,
    );
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _playbackEngine.pause();
      return;
    }

    await _playbackEngine.play();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _bufferingTimer?.cancel();
    _autoQualityUpgradeTimer?.cancel();
    _autoQualityDownshiftTimer?.cancel();
    _seekStallTimer?.cancel();
    _seekPositionValidationTimer?.cancel();
    _abrHttpClient?.close(force: true);
    _abrHttpClient = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _playbackEngine.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _naturalCompletionController.close();
  }

  Future<Result<ResolvedStream, KumoriyaError>> _openCurrentCandidate({
    Duration? startPosition,
  }) async {
    if (_isDisposed) {
      return const Failure(
        SimpleError(
          code: 'player.engine_disposed',
          message: 'Playback engine was disposed during open sequence.',
          kind: KumoriyaErrorKind.cancelled,
        ),
      );
    }

    // Capture this open's generation before any await so that concurrent opens
    // can be detected in the catch block and in the success emit.
    final thisGeneration = ++_openGeneration;
    final openStartTime = DateTime.now(); // Pass 5: Track open start time

    if (_currentCandidateIndex < 0 ||
        _currentCandidateIndex >= _rankedCandidates.length) {
      return _fail(
        code: 'player.all_candidates_failed',
        message: 'All playable stream candidates failed to open.',
        kind: KumoriyaErrorKind.transport,
        errorGeneration: thisGeneration,
      );
    }

    final candidate = _rankedCandidates[_currentCandidateIndex];
    final openCandidate = _prepareCandidateForOpen(
      candidate,
      startPosition: startPosition,
    );
    final openTimeout = _openTimeoutFor(candidate, startPosition);
    _log(
      'seek-phase open-start generation=$thisGeneration '
      'index=$_currentCandidateIndex/${_rankedCandidates.length} '
      'url=${openCandidate.url} startPosition=$startPosition '
      'timeout=$openTimeout',
    );
    _isRecoveringCurrentCandidate = false;
    _resetTimelineDomainForNewOpen();
    _emit(
      _state.copyWith(
        status: _state.status == PlayerSessionStatus.fallbacking
            ? PlayerSessionStatus.fallbacking
            : PlayerSessionStatus.opening,
        selectedStream: candidate,
        infoMessage: _state.status == PlayerSessionStatus.fallbacking
            ? 'player.fallback_in_progress'
            : null,
        currentCandidateIndex: _currentCandidateIndex,
        totalCandidates: _rankedCandidates.length,
        clearError: true,
        clearInfo: _state.status != PlayerSessionStatus.fallbacking,
      ),
    );

    try {
      await _playbackEngine
          .open(
            openCandidate,
            startPosition: _normalizeNullablePosition(startPosition),
          )
          .timeout(openTimeout);
      final openElapsed = DateTime.now().difference(openStartTime);
      _log(
        'seek-phase open-done generation=$thisGeneration elapsed=${openElapsed.inMilliseconds}ms buffering=$_isBuffering playing=$_isPlaying pendingTarget=$_pendingTargetPosition',
      );
      _log('seekLatency phase=open-success ms=${openElapsed.inMilliseconds}');

      _applyTimelineWindow(
        candidate: candidate,
        openCandidate: openCandidate,
        requestedStartPosition: startPosition,
      );

      final timelineReadyElapsed = DateTime.now().difference(openStartTime);
      _log(
        'seekLatency phase=timeline-ready ms=${timelineReadyElapsed.inMilliseconds}',
      );

      // Fix 2: Visual gate - wait for usable frame before emitting success
      // Only apply for HLS with non-zero startPosition (seek scenarios)
      if (candidate.isHls &&
          startPosition != null &&
          startPosition > Duration.zero) {
        final isWindows = defaultTargetPlatform == TargetPlatform.windows;
        final gateStartTime = DateTime.now();
        final gateTimeout = _seekVisualGateTimeoutFrom(openStartTime);
        _log(
          'seek-phase visual-gate-start windows=$isWindows target=$startPosition timeout=$gateTimeout',
        );
        final frameReady = await _waitForUsableFrame(timeout: gateTimeout);
        final gateElapsed = DateTime.now().difference(gateStartTime);
        if (frameReady) {
          _log(
            'seek-phase visual-gate-done windows=$isWindows elapsed=${gateElapsed.inMilliseconds}ms '
            'position=$_lastKnownPosition duration=$_lastKnownDuration',
          );
        } else {
          _log(
            'seek-phase visual-gate-timeout windows=$isWindows elapsed=${gateElapsed.inMilliseconds}ms '
            'position=$_lastKnownPosition duration=$_lastKnownDuration '
            'buffering=$_isBuffering',
          );
        }
      }

      final nextStatus = _isBuffering
          ? PlayerSessionStatus.buffering
          : (_isPlaying
                ? PlayerSessionStatus.playing
                : PlayerSessionStatus.paused);
      if (_isBuffering) {
        _startBufferingTimeoutWatch();
      }
      _startSeekStallWatch(candidate: candidate, targetPosition: startPosition);
      await _applySubtitleTrack();
      if (_activeSeekSession != null) {
        _log(
          'pendingTarget preserved seekSession.target=${_activeSeekSession!.targetPosition}',
        );
        _log('seek-phase validation-start');
        _startSeekPositionValidation();
      }
      // Task 3.4: Do NOT clear pendingTarget here - only clear in _confirmSeekSuccess()
      // Clear a stale error only when the error was produced by a prior
      // generation.  If errorGeneration == thisGeneration the error is
      // concurrent and must be preserved.
      final shouldClearError =
          _state.errorMessage != null &&
          _state.errorGeneration < thisGeneration;
      if (shouldClearError) {
        _log(
          'openCurrentCandidate clearing stale error '
          'previousGeneration=${_state.errorGeneration} thisGeneration=$thisGeneration',
        );
      }
      _lastStableCandidateIndex = _currentCandidateIndex;
      _emit(
        _state.copyWith(
          status: nextStatus,
          selectedStream: candidate,
          currentCandidateIndex: _currentCandidateIndex,
          totalCandidates: _rankedCandidates.length,
          clearInfo: true,
          clearError: shouldClearError,
        ),
      );
      final totalElapsed = DateTime.now().difference(openStartTime);
      _log('seek-phase completed total=${totalElapsed.inMilliseconds}ms');
      return Success(candidate);
    } on TimeoutException {
      await _invalidatePendingEngineOpen(
        reason: 'open-timeout generation=$thisGeneration index=$_currentCandidateIndex',
      );
      _log(
        'openCurrentCandidate timeout generation=$thisGeneration index=$_currentCandidateIndex',
      );
      return _handleCandidateFailure(
        code: 'player.open_timeout',
        message: 'Timed out while opening playback candidate.',
      );
    } catch (error) {
      _log(
        'openCurrentCandidate error generation=$thisGeneration index=$_currentCandidateIndex error=$error',
      );
      if (_isStaleGenerationError(error)) {
        // A newer open generation superseded this one — total silent no-op.
        // Must NOT: call _fail(), touch errorMessage, emit any state, or
        // trigger any fallback.  The only allowed side-effect is this log.
        _log(
          'openCurrentCandidate stale-generation silent no-op '
          'generation=$thisGeneration error=$error',
        );
        return Success(_rankedCandidates[_currentCandidateIndex]);
      }
      if (_isEngineDisposedError(error)) {
        _log(
          'openCurrentCandidate engine-disposed generation=$thisGeneration — stopping cascade',
        );
        // Engine disposal during an active open is a genuine error that must
        // be surfaced so the UI can react (e.g. show an error banner).
        return _fail(
          code: 'player.engine_disposed',
          message: 'Playback engine was disposed during open sequence.',
          kind: KumoriyaErrorKind.cancelled,
          errorGeneration: thisGeneration,
        );
      }
      if (_isProxyRuntimeUnavailableError(error)) {
        _log(
          'openCurrentCandidate proxy-runtime-unavailable generation=$thisGeneration — quarantining anime-nexus family',
        );
        return _handleAnimeNexusFamilyFailure(
          code: 'player.proxy_auth_failed',
          message: 'Anime Nexus proxy runtime unavailable: $error',
        );
      }
      return _handleCandidateFailure(
        code: _classifyOpenFailureCode(error.toString()),
        message: 'Player failed to open candidate: $error',
      );
    }
  }

  Future<void> _invalidatePendingEngineOpen({required String reason}) async {
    try {
      await _playbackEngine.invalidatePendingOpen(reason: reason);
    } catch (error) {
      _log('invalidatePendingEngineOpen failed reason=$reason error=$error');
    }
  }

  Future<Result<ResolvedStream, KumoriyaError>> _handleCandidateFailure({
    required String code,
    required String message,
  }) async {
    _log(
      'handleCandidateFailure code=$code message=$message currentIndex=$_currentCandidateIndex total=${_rankedCandidates.length}',
    );
    final manualLocked = !_autoQualityEnabled && _manualQualityIndex != null;
    if (manualLocked) {
      _log(
        'handleCandidateFailure manual-lock active index=$_currentCandidateIndex '
        'message=$message',
      );
      _cancelSeekSession('manual-quality-failed');
      return _fail(
        code: code,
        message: message,
        kind: KumoriyaErrorKind.transport,
        infoMessage: 'player.manual_quality_failed',
      );
    }

    final hasNext = (_currentCandidateIndex + 1) < _rankedCandidates.length;

    if (hasNext) {
      _currentCandidateIndex++;
      _runtimeErrorRetriesForCurrentCandidate = 0;
      _recoveriesForCurrentCandidate = 0;
      _isRecoveringCurrentCandidate = false;
      _resetSeekRecoveryTracking();
      _log(
        'seekQuality fallback reason=candidate-failure '
        'fromVariant=${_variantFromUrl(_rankedCandidates[_currentCandidateIndex - 1].url)} '
        'toVariant=${_variantFromUrl(_rankedCandidates[_currentCandidateIndex].url)}',
      );
      // Inherit seek target from active seek session, pending target,
      // last-requested seek, or current known position.  When a seek was
      // confirmed but the player is still buffering at that position, both
      // _activeSeekSession and _pendingTargetPosition are already cleared.
      // _lastRequestedSeekPosition survives confirmation and is never
      // cleared, so it acts as a durable fallback that prevents position
      // loss during candidate failover.
      final seekTarget =
          _activeSeekSession?.targetPosition ??
          _pendingTargetPosition ??
          _lastRequestedSeekPosition ??
          (_lastKnownPosition > Duration.zero ? _lastKnownPosition : null);
      _log(
        'handleCandidateFailure seekTarget=$seekTarget '
        'activeSeek=${_activeSeekSession?.targetPosition} '
        'pending=$_pendingTargetPosition '
        'lastRequestedSeek=$_lastRequestedSeekPosition '
        'lastKnown=$_lastKnownPosition',
      );
      if (_activeSeekSession != null) {
        _activeSeekSession!.currentLevel = 3;
        _log(
          'seekFallbackNextCandidate from=${_currentCandidateIndex - 1} '
          'to=$_currentCandidateIndex target=${_activeSeekSession!.targetPosition}',
        );
      }
      _emit(
        _state.copyWith(
          status: PlayerSessionStatus.fallbacking,
          infoMessage: 'player.fallback_in_progress',
          currentCandidateIndex: _currentCandidateIndex,
          totalCandidates: _rankedCandidates.length,
          clearError: true,
        ),
      );
      return _openCurrentCandidate(startPosition: seekTarget);
    }

    if (_rankedCandidates.length <= 1) {
      _cancelSeekSession('all-candidates-exhausted');
      return _fail(
        code: code,
        message: message,
        kind: KumoriyaErrorKind.transport,
      );
    }

    _cancelSeekSession('all-candidates-exhausted');
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
      _emit(
        _state.copyWith(
          status: PlayerSessionStatus.buffering,
          infoMessage: _state.infoMessage,
        ),
      );
      return;
    }

    // Fix B: Clear stale error when playback has recovered successfully.
    // If we're transitioning to playing/paused and there's a residual error
    // from a previous failed/stale open, clear it now.
    final shouldClearStaleError = _state.errorMessage != null;
    _log(
      'playingChanged before-emit playing=$playing currentError=${_state.errorMessage} willClearError=$shouldClearStaleError',
    );
    if (shouldClearStaleError) {
      _log(
        'stale error cleared on successful recovery playing=$playing error=${_state.errorMessage}',
      );
    }

    _emit(
      _state.copyWith(
        status: playing
            ? PlayerSessionStatus.playing
            : PlayerSessionStatus.paused,
        clearError: shouldClearStaleError,
        clearInfo: true,
      ),
    );

    _log(
      'playingChanged after-emit playing=$playing newError=${_state.errorMessage}',
    );

    if (playing && !_isBuffering) {
      _startAutoQualityUpgradeWatch();
    } else {
      _autoQualityUpgradeTimer?.cancel();
    }
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
      _lastBufferingAt = DateTime.now();
      _scheduleAutoQualityDownshiftIfNeeded();
      _emit(
        _state.copyWith(
          status: PlayerSessionStatus.buffering,
          infoMessage: _activeSeekSession != null
              ? 'player.seek_in_progress'
              : _state.infoMessage,
        ),
      );
      _startBufferingTimeoutWatch();
      return;
    }

    _bufferingTimer?.cancel();
    _autoQualityDownshiftTimer?.cancel();
    if (_seekWatchTargetPosition == null) {
      _seekStallTimer?.cancel();
    }

    // Fix B: Clear stale error when exiting buffering successfully.
    // If we're transitioning out of buffering and there's a residual error
    // from a previous failed/stale open, clear it now.
    final shouldClearStaleError = _state.errorMessage != null;
    _log(
      'bufferingChanged before-emit buffering=$buffering playing=$_isPlaying currentError=${_state.errorMessage} willClearError=$shouldClearStaleError',
    );
    if (shouldClearStaleError) {
      _log(
        'stale error cleared on buffering exit playing=$_isPlaying error=${_state.errorMessage}',
      );
    }

    _emit(
      _state.copyWith(
        status: _isPlaying
            ? PlayerSessionStatus.playing
            : PlayerSessionStatus.paused,
        clearError: shouldClearStaleError,
        clearInfo: true,
      ),
    );

    _log(
      'bufferingChanged after-emit buffering=$buffering newError=${_state.errorMessage}',
    );

    if (_isPlaying) {
      _startAutoQualityUpgradeWatch();
    }
  }

  void _onPositionChanged(Duration rawPosition) {
    if (rawPosition < Duration.zero) {
      return;
    }
    final position = _effectivePosition(rawPosition);
    final previousPosition = _lastKnownPosition;
    _lastKnownPosition = position;
    _emitPosition(position);

    if (_isManagedTimelineWindow && position.inSeconds % 5 == 0) {
      final rawDuration = _lastKnownDuration - _timelineBasePosition;
      _log(
        'timelineDomain managed=$_isManagedTimelineWindow '
        'rawPosition=$rawPosition rawDuration=${rawDuration > Duration.zero ? rawDuration : Duration.zero} '
        'effectivePosition=$position effectiveDuration=$_lastKnownDuration',
      );
    }
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
    // Validate active seek session: confirm position reached target.
    final seekSession = _activeSeekSession;
    if (seekSession != null &&
        seekSession.generation == _seekGeneration &&
        _isPositionNearTarget(position, seekSession.targetPosition)) {
      _confirmSeekSuccess();
    }

    // Fix A: Confirm and clear pendingTarget when position reaches target,
    // even without active seek session (e.g., after seekStallWatch cleared).
    // CRITICAL: Never confirm pendingTarget at zero position for non-zero targets.
    final pendingTarget = _pendingTargetPosition;
    if (pendingTarget != null && _activeSeekSession == null) {
      // Fix A.1: Stricter guard - reject confirmation during transient reopen state
      // Block confirmation if:
      // - Target is non-zero but position is near zero (< 500ms)
      // - Timeline window is managed but not yet stable
      // - Visual gate may still be running
      final isTransientState =
          pendingTarget > Duration.zero &&
          position < const Duration(milliseconds: 500);

      if (isTransientState) {
        _log(
          'pendingTarget guard reject-zero-position target=$pendingTarget '
          'effectivePosition=$position reopenStable=false',
        );
        // Don't confirm - this is a transient state during reopen
      } else if (_isPositionNearTarget(position, pendingTarget)) {
        // Fix A.2: Only confirm when position is actually near target AND stable
        _log(
          'pendingTarget confirm-check effectivePosition=$position '
          'target=$pendingTarget reopenStable=true',
        );
        _log(
          'pendingTarget confirmed effectivePosition=$position '
          'target=$pendingTarget',
        );
        _log('pendingTarget cleared reason=position-reached-target-no-session');
        _pendingTargetPosition = null;
      }
    }

    _handleSeekProgress(position);
  }

  void _onDurationChanged(Duration rawDuration) {
    if (rawDuration <= Duration.zero) {
      return;
    }

    _lastRawDurationFromEngine = rawDuration;
    _recomputeTimelineDomain('onDurationChanged');
  }

  void _onBufferChanged(Duration buffer) {
    if (buffer < Duration.zero) {
      return;
    }
    _lastBufferedDuration = buffer;
  }

  void _onBufferingPercentageChanged(double percentage) {
    if (percentage.isNaN || percentage.isInfinite) {
      return;
    }
    _lastBufferingPercentage = percentage.clamp(0, 100).toDouble();
  }

  void _recomputeTimelineDomain(String reason) {
    Duration effective;
    if (_lastRawDurationFromEngine > Duration.zero) {
      effective = _effectiveDuration(_lastRawDurationFromEngine);
      if (!_isManagedTimelineWindow) {
        final selected = _state.selectedStream;
        final preserveAnimeNexusVodDuration =
            selected != null &&
            selected.isHls &&
            _isAnimeNexusLoopbackHls(selected.url);
        if (preserveAnimeNexusVodDuration &&
            _fullTimelineDurationHint > Duration.zero &&
            effective < _fullTimelineDurationHint) {
          // Seek opens on trimmed manifests may report only the remaining
          // window duration. Keep the largest known full-episode duration
          // so the timeline max does not collapse after a seek.
          _log(
            'timelineDomain preserve-duration hint=$_fullTimelineDurationHint '
            'rawEffective=$effective reason=$reason',
          );
          effective = _fullTimelineDurationHint;
        } else {
          _fullTimelineDurationHint = effective;
        }
      } else if (effective > _fullTimelineDurationHint) {
        _fullTimelineDurationHint = effective;
      }
    } else {
      effective = _fullTimelineDurationHint;
    }

    if (effective > Duration.zero) {
      _lastKnownDuration = effective;
      _emitDuration(effective);
    }

    _log(
      'timelineDomain recompute reason=$reason raw=$_lastRawDurationFromEngine '
      'effective=$effective managed=$_isManagedTimelineWindow',
    );
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
      // Not a false EOF — check whether this is a genuine natural completion.
      if (_lastKnownDuration > const Duration(seconds: 10) &&
          _isNearEnd(_lastKnownPosition, _lastKnownDuration)) {
        _log('naturalCompletion detected');
        _naturalCompletionController.add(null);
      }
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
    // Late runtime errors from a superseded open must not override a stream
    // that is already playing.
    if (_isPlaying && !_isBuffering) {
      _log('playbackError ignored while actively playing error=$error');
      return;
    }
    if (_isAnimeNexusSeekSessionActive) {
      _log(
        'playbackError anime-nexus-seek-session error=$error action=escalate-seek-session',
      );
      _escalateSeekSession();
      return;
    }
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
          code: _classifyRuntimeErrorCode(error),
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
    if (_isDisposed) {
      return;
    }

    _log(
      'recoverCurrentCandidate force=$force recoveryPosition=$recoveryPosition '
      'currentIndex=$_currentCandidateIndex recoveries=$_recoveriesForCurrentCandidate '
      'pendingTarget=$_pendingTargetPosition lastRequestedSeek=$_lastRequestedSeekPosition '
      'lastKnown=$_lastKnownPosition',
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
    final openCandidate = _prepareCandidateForOpen(
      candidate,
      startPosition: targetPosition,
    );
    final openTimeout = _openTimeoutFor(candidate, targetPosition);
    _log(
      'recoverCurrentCandidate opening url=${candidate.url} '
      'target=$targetPosition hls=${candidate.isHls} timeout=$openTimeout',
    );
    _pendingTargetPosition = targetPosition > Duration.zero
        ? targetPosition
        : _pendingTargetPosition;
    _resetTimelineDomainForNewOpen();
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
      final openStartTime = DateTime.now();
      await _playbackEngine
          .open(
            openCandidate,
            startPosition: targetPosition > Duration.zero
                ? targetPosition
                : null,
          )
          .timeout(openTimeout);

      final openElapsed = DateTime.now().difference(openStartTime);
      _log(
        'recoverCurrentCandidate open-success target=$targetPosition buffering=$_isBuffering playing=$_isPlaying',
      );
      _log(
        'seekLatency phase=reopen-open-done '
        'elapsed=${openElapsed.inMilliseconds}ms',
      );

      _applyTimelineWindow(
        candidate: candidate,
        openCandidate: openCandidate,
        requestedStartPosition: targetPosition,
      );

      final timelineReadyElapsed = DateTime.now().difference(openStartTime);
      _log(
        'seekLatency phase=timeline-ready ms=${timelineReadyElapsed.inMilliseconds}',
      );

      // Fix 2: Visual gate - wait for usable frame before emitting success
      // Only apply for HLS with non-zero targetPosition (seek scenarios)
      if (candidate.isHls && targetPosition > Duration.zero) {
        final isWindows = defaultTargetPlatform == TargetPlatform.windows;
        final gateTimeout = _seekVisualGateTimeoutFrom(openStartTime);
        _log(
          'reopen visual-gate waiting-first-frame windows=$isWindows target=$targetPosition timeout=$gateTimeout',
        );
        final frameReady = await _waitForUsableFrame(timeout: gateTimeout);
        final gateElapsed = DateTime.now().difference(openStartTime);
        if (frameReady) {
          _log(
            'reopen visual-gate frame-ready windows=$isWindows '
            'position=$_lastKnownPosition duration=$_lastKnownDuration',
          );
        } else {
          _log(
            'reopen visual-gate timeout windows=$isWindows '
            'position=$_lastKnownPosition duration=$_lastKnownDuration '
            'buffering=$_isBuffering',
          );
        }
        _log(
          'seekLatency phase=visual-gate-done '
          'elapsed=${gateElapsed.inMilliseconds}ms '
          'frameReady=$frameReady',
        );
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
      if (!_shouldReopenForSeek(candidate, targetPosition) &&
          targetPosition > Duration.zero) {
        await _playbackEngine.seekTo(targetPosition);
        _log('recoverCurrentCandidate direct-seek target=$targetPosition');
      }
      _startSeekStallWatch(
        candidate: candidate,
        targetPosition: targetPosition,
      );
      await _applySubtitleTrack();
      if (_activeSeekSession != null) {
        _log(
          'pendingTarget preserved seekSession.target=${_activeSeekSession!.targetPosition}',
        );
        _startSeekPositionValidation();
      }
      // Task 3.4: Do NOT clear pendingTarget here - only clear in _confirmSeekSuccess()
      _lastStableCandidateIndex = _currentCandidateIndex;
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
      _log(
        'seekQuality reopen openedVariant=${_variantFromUrl(candidate.url)} '
        'candidateIndex=$_currentCandidateIndex',
      );

      // R3: Predictive prewarm — after a successful reopen, schedule
      // background warmup for the next likely window so the second seek
      // in the same direction is near-instant.
      if (_isManagedTimelineWindow && targetPosition > Duration.zero) {
        _schedulePredictivePrewarm(targetPosition, seekGen: _seekGeneration);
      }

      _isRecoveringCurrentCandidate = false;
    } on TimeoutException {
      _isRecoveringCurrentCandidate = false;
      await _invalidatePendingEngineOpen(
        reason:
            'recover-timeout index=$_currentCandidateIndex target=$targetPosition',
      );
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
      if (_isStaleGenerationError(error)) {
        _log(
          'recoverCurrentCandidate stale-generation silent no-op error=$error',
        );
        return;
      }
      if (_isEngineDisposedError(error) || _isDisposed) {
        _log(
          'recoverCurrentCandidate engine-disposed — cancelling recovery without failure',
        );
        return;
      }
      if (_isProxyRuntimeUnavailableError(error)) {
        _log(
          'recoverCurrentCandidate proxy-runtime-unavailable — quarantining anime-nexus family',
        );
        await _handleAnimeNexusFamilyFailure(
          code: 'player.proxy_auth_failed',
          message:
              'Anime Nexus proxy runtime unavailable during recovery: $error',
        );
        return;
      }
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
    if (message.contains('codec') || message.contains('unsupported')) {
      return false;
    }

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

  bool get _isAnimeNexusSeekSessionActive {
    final session = _activeSeekSession;
    final candidate = _state.selectedStream;
    if (session == null || candidate == null) {
      return false;
    }
    return _isAnimeNexusLoopbackHls(candidate.url);
  }

  void _startBufferingTimeoutWatch() {
    final timerGeneration = _openGeneration;
    final timerCandidateIndex = _currentCandidateIndex;
    _bufferingTimer?.cancel();
    // P8: Dynamic buffering timeout — extend the budget when we have
    // throughput evidence that the network is slow but making progress.
    // Floor: _bufferingTimeout (18s default).  Ceiling: 45s.
    // Formula: max(baseline, estimatedSegmentFetchTime * 3).
    final effectiveTimeout = _dynamicBufferingTimeout();
    _bufferingTimer = Timer(effectiveTimeout, () {
      _log(
        'bufferingTimeout fired timeout=${effectiveTimeout.inSeconds}s status=${_state.status} recoveries=$_recoveriesForCurrentCandidate pendingTarget=$_pendingTargetPosition position=$_lastKnownPosition generation=$timerGeneration currentGeneration=$_openGeneration timerIndex=$timerCandidateIndex currentIndex=$_currentCandidateIndex',
      );
      if (timerGeneration != _openGeneration ||
          timerCandidateIndex != _currentCandidateIndex) {
        _log(
          'bufferingTimeout stale ignored generation=$timerGeneration currentGeneration=$_openGeneration timerIndex=$timerCandidateIndex currentIndex=$_currentCandidateIndex',
        );
        return;
      }
      if (_state.status != PlayerSessionStatus.buffering) {
        return;
      }
      if (_isAnimeNexusSeekSessionActive) {
        _log(
          'bufferingTimeout anime-nexus-seek-session action=escalate-seek-session',
        );
        _escalateSeekSession();
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

  /// P8: Computes a dynamic buffering timeout based on observed throughput.
  ///
  /// When throughput data is available (from variant ABR metrics), estimates
  /// how long a ~2MB segment fetch would take at 70% of observed capacity
  /// and returns 3x that as a timeout.  This prevents premature candidate
  /// failures on slow-but-functional connections while keeping the default
  /// tight timeout for unknown networks.
  Duration _dynamicBufferingTimeout() {
    if (_variantThroughputBps.isEmpty) return _bufferingTimeout;
    var maxBps = 0.0;
    for (final bps in _variantThroughputBps.values) {
      if (bps > maxBps) maxBps = bps;
    }
    if (maxBps <= 0) return _bufferingTimeout;
    // Estimate: ~2MB (typical HLS segment) at 70% capacity.
    const segmentBytes = 2 * 1024 * 1024;
    final segmentBits = segmentBytes * 8;
    final estimatedFetchSeconds = segmentBits / (maxBps * 0.70);
    final dynamic_ = Duration(
      seconds: (estimatedFetchSeconds * 3).ceil().clamp(
        _bufferingTimeout.inSeconds,
        45,
      ),
    );
    _log(
      'dynamicBufferingTimeout throughput=${maxBps.toStringAsFixed(0)}bps '
      'estimated=${estimatedFetchSeconds.toStringAsFixed(1)}s '
      'timeout=${dynamic_.inSeconds}s',
    );
    return dynamic_;
  }

  Result<ResolvedStream, KumoriyaError> _fail({
    required String code,
    required String message,
    required KumoriyaErrorKind kind,
    String? infoMessage,
    int errorGeneration = -1,
  }) {
    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.error,
        errorMessage: message,
        infoMessage: infoMessage,
        errorGeneration: errorGeneration,
      ),
    );

    return Failure(SimpleError(code: code, message: message, kind: kind));
  }

  void _emit(PlayerSessionState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    _log(
      'emit status=${next.status} index=${next.currentCandidateIndex}/${next.totalCandidates} hasStream=${next.selectedStream != null} info=${next.infoMessage} error=${next.errorMessage}',
    );
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  bool _isSupportedUrl(Uri url) {
    // Allow local file:// URIs for offline/downloaded playback.
    if (url.scheme == 'file') return true;

    if (!url.hasScheme || url.host.isEmpty) {
      return false;
    }

    return url.scheme == 'http' || url.scheme == 'https';
  }

  Future<int> _pickInitialCandidateIndex() async {
    if (_rankedCandidates.isEmpty) {
      return 0;
    }

    final remembered = _lastStableCandidateIndex;
    if (remembered != null &&
        remembered >= 0 &&
        remembered < _rankedCandidates.length) {
      _log('autoQuality startup remembered-index=$remembered');
      return remembered;
    }

    final first = _rankedCandidates.first;
    final isAnimeNexusHls = first.isHls && _isAnimeNexusLoopbackHls(first.url);

    // Throughput-based selection (Anime Nexus only — requires proxy ABR endpoint).
    if (isAnimeNexusHls) {
      await _refreshAbrMetricsFromProxy();
      final throughputIndex = _indexByThroughputEstimate();
      if (throughputIndex >= 0) {
        _log(
          'autoQuality startup throughput-index=$throughputIndex '
          'variant=${_variantFromUrl(_rankedCandidates[throughputIndex].url)}',
        );
        return throughputIndex;
      }
    }

    // Universal 720p-first heuristic: pick the candidate closest to 720p
    // (but not above) regardless of resolver.  This is the YouTube-like
    // "safe startup" behaviour — start at a moderate quality, then auto-
    // upgrade once playback is stable.
    //
    // When no candidate exposes a quality label we fall back to index 0
    // (highest-ranked by StreamSelectionPolicy) instead of the last index,
    // so the ranking order is always respected.
    var preferredIndex = 0;
    var bestDelta = 1 << 30;
    var anyQualityFound = false;
    for (var i = 0; i < _rankedCandidates.length; i++) {
      final score = _qualityScore(_rankedCandidates[i]);
      if (score == null) {
        continue;
      }
      anyQualityFound = true;
      final delta = (score - 720).abs();
      if (score <= 720 && delta < bestDelta) {
        preferredIndex = i;
        bestDelta = delta;
      }
    }
    // When quality labels exist but none is ≤720p, prefer the lowest
    // available quality (last in ranked order) for a safe startup.
    if (anyQualityFound && bestDelta == 1 << 30) {
      preferredIndex = _rankedCandidates.length - 1;
    }

    _log(
      'autoQuality startup selected-index=$preferredIndex '
      'variant=${_variantFromUrl(_rankedCandidates[preferredIndex].url)}',
    );
    return preferredIndex;
  }

  int _indexByThroughputEstimate() {
    if (_variantThroughputBps.isEmpty || _variantRequiredBps.isEmpty) {
      return -1;
    }

    var estimatedCapacityBps = 0.0;
    for (final bps in _variantThroughputBps.values) {
      if (bps > estimatedCapacityBps) {
        estimatedCapacityBps = bps;
      }
    }
    if (estimatedCapacityBps <= 0) {
      return -1;
    }

    final startupBudgetBps = estimatedCapacityBps * 0.70;
    var fallback = _rankedCandidates.length - 1;
    for (var i = _rankedCandidates.length - 1; i >= 0; i--) {
      final variant = _variantFromUrl(_rankedCandidates[i].url);
      final requiredBps = _variantRequiredBps[variant];
      if (requiredBps == null) {
        continue;
      }
      fallback = i;
      if (requiredBps <= startupBudgetBps) {
        _log(
          'autoQuality startup throughput-selected index=$i variant=$variant '
          'requiredBps=${requiredBps.toStringAsFixed(0)} '
          'budgetBps=${startupBudgetBps.toStringAsFixed(0)}',
        );
        return i;
      }
    }

    _log(
      'autoQuality startup throughput-fallback index=$fallback '
      'budgetBps=${startupBudgetBps.toStringAsFixed(0)}',
    );
    return fallback;
  }

  // R5: Reusable HttpClient for ABR metrics — avoids TCP connection setup
  // overhead on every quality decision.
  HttpClient? _abrHttpClient;
  HttpClient get _abrClient {
    return _abrHttpClient ??= (HttpClient()
      ..connectionTimeout = const Duration(seconds: 1));
  }

  Future<void> _refreshAbrMetricsFromProxy() async {
    final uri = _buildAbrMetricsUri();
    if (uri == null) {
      return;
    }

    try {
      final request = await _abrClient
          .getUrl(uri)
          .timeout(const Duration(milliseconds: 900));
      final response = await request.close().timeout(
        const Duration(milliseconds: 900),
      );
      if (response.statusCode != HttpStatus.ok) {
        return;
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final nextThroughput = <String, double>{};
      final nextRequired = <String, double>{};
      for (final entry in decoded.entries) {
        final payload = entry.value;
        if (payload is! Map<String, dynamic>) {
          continue;
        }
        final rawMeasured = payload['measuredNetworkBitsPerSecond'];
        final measured = rawMeasured is num
            ? rawMeasured.toDouble()
            : double.tryParse('$rawMeasured');
        if (measured != null && measured > 0) {
          nextThroughput[entry.key] = measured;
        }

        final rawRequired = payload['declaredBitsPerSecond'];
        final required = rawRequired is num
            ? rawRequired.toDouble()
            : double.tryParse('$rawRequired');
        if (required != null && required > 0) {
          nextRequired[entry.key] = required;
        }
      }
      if (nextThroughput.isNotEmpty) {
        _variantThroughputBps
          ..clear()
          ..addAll(nextThroughput);
      }
      if (nextRequired.isNotEmpty) {
        _variantRequiredBps
          ..clear()
          ..addAll(nextRequired);
      }
      if (nextThroughput.isNotEmpty || nextRequired.isNotEmpty) {
        _log(
          'autoQuality abrMetrics throughput=${nextThroughput.length} '
          'required=${nextRequired.length} uri=$uri',
        );
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  Uri? _buildAbrMetricsUri() {
    if (_rankedCandidates.isEmpty) {
      return null;
    }
    final anchor = _rankedCandidates.first;
    if (!_isAnimeNexusLoopbackHls(anchor.url)) {
      return null;
    }
    final segments = anchor.url.pathSegments;
    final idx = segments.indexOf('anime-nexus');
    if (idx < 0 || idx + 1 >= segments.length) {
      return null;
    }
    return anchor.url.replace(
      pathSegments: <String>['anime-nexus', segments[idx + 1], 'abr-metrics'],
      queryParameters: const <String, String>{},
    );
  }

  int? _qualityScore(ResolvedStream stream) {
    final quality = (stream.qualityLabel ?? '').toLowerCase();
    if (!quality.endsWith('p')) {
      return null;
    }
    return int.tryParse(quality.substring(0, quality.length - 1));
  }

  bool _isEngineDisposedError(Object error) {
    return error is StateError &&
        error.message.contains('disposed') &&
        !error.message.contains('invalidated');
  }

  /// Returns true when the engine threw because a newer open generation
  /// superseded this one.  This is a normal race condition during rapid seeks
  /// and must be handled as a total silent no-op — no error state, no fallback.
  bool _isStaleGenerationError(Object error) {
    return error is StateError && error.message.contains('invalidated');
  }

  /// Detects errors from the proxy's circuit breaker or ensure-playable
  /// endpoint indicating persistent auth failure.
  bool _isProxyRuntimeUnavailableError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('proxy runtime not playable') ||
        msg.contains('circuit-breaker active') ||
        msg.contains('ensureplayable failed');
  }

  /// Quarantines the entire anime-nexus candidate family when auth fails.
  ///
  /// When the proxy runtime is unavailable (persistent auth failure), all
  /// anime-nexus candidates share the same broken session — cycling through
  /// bitrate variants (5300 → 4400 → 1600) doesn't help.  This method
  /// skips all anime-nexus candidates and jumps to the first non-anime-nexus
  /// candidate, or emits a terminal error if none exist.
  Future<Result<ResolvedStream, KumoriyaError>> _handleAnimeNexusFamilyFailure({
    required String code,
    required String message,
  }) async {
    _log(
      'handleAnimeNexusFamilyFailure quarantining from index '
      '$_currentCandidateIndex total=${_rankedCandidates.length}',
    );

    // Skip all anime-nexus candidates.
    while (_currentCandidateIndex < _rankedCandidates.length &&
        _isAnimeNexusLoopbackHls(
          _rankedCandidates[_currentCandidateIndex].url,
        )) {
      _log(
        'handleAnimeNexusFamilyFailure skip index=$_currentCandidateIndex '
        'url=${_rankedCandidates[_currentCandidateIndex].url}',
      );
      _currentCandidateIndex++;
    }

    if (_currentCandidateIndex < _rankedCandidates.length) {
      _runtimeErrorRetriesForCurrentCandidate = 0;
      _recoveriesForCurrentCandidate = 0;
      _isRecoveringCurrentCandidate = false;
      _resetSeekRecoveryTracking();
      _emit(
        _state.copyWith(
          status: PlayerSessionStatus.fallbacking,
          infoMessage: 'player.proxy_family_quarantined',
          currentCandidateIndex: _currentCandidateIndex,
          totalCandidates: _rankedCandidates.length,
          clearError: true,
        ),
      );
      return _openCurrentCandidate(
        startPosition:
            _activeSeekSession?.targetPosition ??
            _pendingTargetPosition ??
            _lastRequestedSeekPosition ??
            (_lastKnownPosition > Duration.zero ? _lastKnownPosition : null),
      );
    }

    _cancelSeekSession('proxy-family-exhausted');
    return _fail(
      code: code,
      message: message,
      kind: KumoriyaErrorKind.transport,
      infoMessage: 'player.proxy_family_quarantined',
    );
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

  String _classifyRuntimeErrorCode(String error) {
    final value = error.toLowerCase();
    if (value.contains('unsupported') || value.contains('codec')) {
      return 'player.unsupported_stream';
    }
    if (value.contains('network') ||
        value.contains('http') ||
        value.contains('ffurl_read') ||
        value.contains('tcp:') ||
        value.contains('tls:')) {
      return 'player.network_failure';
    }
    return 'player.candidate_failed';
  }

  Duration get _recoveryPosition => _normalizePosition(
    _activeSeekSession?.targetPosition ??
        _pendingTargetPosition ??
        _lastRequestedSeekPosition ??
        _lastKnownPosition,
  );

  bool _shouldReopenForSeek(ResolvedStream candidate, Duration position) {
    if (position <= Duration.zero) {
      return false;
    }
    if (_isTargetInsideBufferedAhead(position)) {
      _log(
        'seekBufferedHit target=$position '
        'position=$_lastKnownPosition bufferedAhead=$_lastBufferedDuration '
        'action=native-seek',
      );
      return false;
    }
    // Anime Nexus: always native-seek, never reopen.  The full manifest is
    // kept loaded in mpv the same way hls.js works in the browser.  Native
    // seeking is handled by ffmpeg's HLS demuxer which finds the right
    // segment in the already-parsed manifest.  This eliminates the ~3-8 s
    // stream teardown/rebuild overhead of the old windowed-manifest path.
    if (_isAnimeNexusLoopbackHls(candidate.url)) {
      return false;
    }
    // R1: If the target falls within the currently open managed window,
    // native seek is safe (convert absolute → local in seekTo).
    if (_isTargetInCurrentWindow(position)) {
      return false;
    }
    // R5: Non-AN HLS — prefer native seek over stop/reopen.  With
    // demuxer-seekable-cache=yes the HLS demuxer keeps the parsed manifest
    // in memory and can locate the correct segment for any position without
    // tearing down the stream.  This preserves the demuxer cache (both
    // forward and backward buffered content) and avoids the 3-8s overhead
    // of a full stop → open → waitReady → visual-gate cycle.
    //
    // The seek-stall watch (startSeekStallWatch) provides a safety net: if
    // the native seek doesn't make progress within a few seconds, the
    // orchestrator will escalate to a reopen recovery automatically.
    if (candidate.isHls) {
      _log(
        'seekNativeHls target=$position '
        'position=$_lastKnownPosition action=native-seek-first',
      );
      return false;
    }
    return false;
  }

  bool _isTargetInsideBufferedAhead(Duration absoluteTarget) {
    if (_lastBufferedDuration <= Duration.zero) {
      return false;
    }

    final bufferedEnd = _lastKnownPosition + _lastBufferedDuration;
    final safeBufferedEnd = bufferedEnd - _bufferedSeekSafetyMargin;
    final effectiveBufferedEnd = safeBufferedEnd > _lastKnownPosition
        ? safeBufferedEnd
        : bufferedEnd;

    return absoluteTarget > _lastKnownPosition &&
        absoluteTarget <= effectiveBufferedEnd;
  }

  /// R1: Returns `true` when [absoluteTarget] falls within the absolute
  /// range of the currently loaded managed HLS window.
  ///
  /// The window range is `[base, base + rawDuration]` where `base` is the
  /// `_timelineBasePosition` set at open time and `rawDuration` is the
  /// local duration reported by the engine.
  bool _isTargetInCurrentWindow(Duration absoluteTarget) {
    if (!_isManagedTimelineWindow) return false;
    if (_lastRawDurationFromEngine <= Duration.zero) return false;
    final windowStart = _timelineBasePosition;
    final windowEnd = _timelineBasePosition + _lastRawDurationFromEngine;
    return absoluteTarget >= windowStart && absoluteTarget <= windowEnd;
  }

  /// R4: Cancels all stale seek-related operations when a new seek begins.
  ///
  /// Ensures that only the most recent seek's timers, sessions, and
  /// predictive prewarms survive.
  void _cancelStaleSeekOperations(int newGeneration) {
    _seekStallTimer?.cancel();
    _seekPositionValidationTimer?.cancel();
    _bufferingTimer?.cancel();
    if (_activeSeekSession != null) {
      _log(
        'seekGeneration superseded '
        'old=${_activeSeekSession!.generation} new=$newGeneration',
      );
    }
    _activeSeekSession = null;
    // Invalidate any pending predictive prewarm.
    _predictivePrewarmGeneration = newGeneration;
  }

  /// R3: Schedules a best-effort background warmup for the next probable
  /// window after a successful reopen seek.
  ///
  /// The next window is estimated as starting at `currentTarget + rawDuration`.
  /// If the user seeks again before the prewarm completes, the generation
  /// check silently discards the stale prewarm.
  void _schedulePredictivePrewarm(
    Duration currentTarget, {
    required int seekGen,
  }) {
    if (_lastRawDurationFromEngine <= Duration.zero) return;
    final nextWindowStart = currentTarget + _lastRawDurationFromEngine;
    if (_fullTimelineDurationHint > Duration.zero &&
        nextWindowStart > _fullTimelineDurationHint) {
      _log('predictivePrewarm skip — already near end');
      return;
    }
    _log(
      'predictivePrewarm scheduled fromTarget=$currentTarget '
      'nextWindowStart=$nextWindowStart',
    );
    _predictivePrewarmGeneration = seekGen;
    unawaited(
      _playbackEngine
          .signalPredictivePrewarm(nextWindowStart)
          .then((_) {
            if (_predictivePrewarmGeneration != seekGen) {
              _log(
                'predictivePrewarm cancelled reason=stale-seek generation=$seekGen',
              );
              return;
            }
            _log(
              'predictivePrewarm completed nextWindowStart=$nextWindowStart',
            );
          })
          .catchError((_) {}),
    );
  }

  /// Escapes a managed timeline window by reopening with the full manifest,
  /// then performing a native seek to [targetPosition].
  ///
  /// This is the safety-net path for the rare case where a prior code path
  /// left the player in a managed (windowed) HLS manifest and the user now
  /// seeks to a position outside that window.  Under normal operation (after
  /// the native-seek-always change) managed windows are never created.
  Future<void> _reopenFullManifestThenSeek(
    ResolvedStream candidate,
    Duration targetPosition, {
    required DateTime seekStartTime,
  }) async {
    _log(
      'reopenFullManifestThenSeek begin '
      'target=$targetPosition generation=$_seekGeneration',
    );

    // Pre-warm segments around the target position.
    unawaited(_playbackEngine.signalPredictivePrewarm(targetPosition));

    _resetTimelineDomainForNewOpen();
    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.buffering,
        infoMessage: 'player.seek_in_progress',
        clearError: true,
      ),
    );

    try {
      // Open with full manifest (no seekNonce, no startPosition) so mpv
      // loads every segment entry.  The engine will hit _openHlsAtPosition
      // which passes start: targetPosition to mpv's Media constructor.
      await _playbackEngine
          .open(candidate, startPosition: targetPosition)
          .timeout(const Duration(seconds: 12));

      _applyTimelineWindow(
        candidate: candidate,
        openCandidate: candidate,
        requestedStartPosition: targetPosition,
      );

      _startSeekStallWatch(
        candidate: candidate,
        targetPosition: targetPosition,
      );
      if (_activeSeekSession != null) {
        _startSeekPositionValidation();
      }

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
          clearError: true,
        ),
      );

      final totalElapsed = DateTime.now().difference(seekStartTime);
      _log(
        'reopenFullManifestThenSeek completed '
        'total=${totalElapsed.inMilliseconds}ms',
      );
    } on TimeoutException {
      _log('reopenFullManifestThenSeek timeout target=$targetPosition');
      await _handleCandidateFailure(
        code: 'player.open_timeout',
        message: 'Timed out reopening full manifest for seek.',
      );
    } catch (error) {
      _log('reopenFullManifestThenSeek error=$error');
      if (_isEngineDisposedError(error) || _isDisposed) return;
      await _handleCandidateFailure(
        code: 'player.seek_recovery_failed',
        message: 'Failed to reopen full manifest for seek: $error',
      );
    }
  }

  /// Prepares a candidate for opening.
  ///
  /// For Anime Nexus loopback HLS, the candidate is returned unchanged —
  /// **no seekNonce is injected**.  Instead of tearing down the stream and
  /// re-opening with a windowed playlist (the old approach), we rely on the
  /// full manifest + native mpv seeking the same way hls.js works in the
  /// browser.  The engine's `open()` uses `start:` to hint the position,
  /// and the proxy's `/warmup-seek-window` pre-caches the target segments.
  ResolvedStream _prepareCandidateForOpen(
    ResolvedStream candidate, {
    Duration? startPosition,
  }) {
    // Anime Nexus: keep the original URL (full manifest).  The engine will
    // use _openHlsAtPosition() which passes `start: position` to mpv.
    return candidate;
  }

  bool _isAnimeNexusLoopbackHls(Uri url) {
    if (!(url.host == '127.0.0.1' || url.host == 'localhost')) {
      return false;
    }
    final segments = url.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.contains('anime-nexus');
  }

  /// Extracts the variant from an anime-nexus proxy URL for logging.
  ///
  /// URL format: /anime-nexus/{playbackId}/master/{variant}/{track}.m3u8
  String _variantFromUrl(Uri url) {
    final segments = url.pathSegments;
    final idx = segments.indexOf('master');
    if (idx < 0 || idx + 1 >= segments.length) return 'unknown';
    return segments[idx + 1];
  }

  bool _isAutoQualityEligible() {
    if (!_autoQualityEnabled) {
      return false;
    }
    final candidate = _state.selectedStream;
    if (candidate == null) {
      return false;
    }
    if (!candidate.isHls || !_isAnimeNexusLoopbackHls(candidate.url)) {
      return false;
    }
    if (_rankedCandidates.length <= 1) {
      return false;
    }
    if (_activeSeekSession != null || _pendingTargetPosition != null) {
      return false;
    }
    if (_isRecoveringCurrentCandidate || !_isPlaying || _isBuffering) {
      return false;
    }
    return true;
  }

  void _startAutoQualityUpgradeWatch() {
    _autoQualityUpgradeTimer?.cancel();
    if (!_isAutoQualityEligible()) {
      return;
    }
    _autoQualityUpgradeTimer = Timer(const Duration(seconds: 10), () {
      unawaited(_maybeAutoQualityUpshift());
    });
  }

  void _scheduleAutoQualityDownshiftIfNeeded() {
    _autoQualityDownshiftTimer?.cancel();
    final candidate = _state.selectedStream;
    if (candidate == null ||
        !candidate.isHls ||
        !_isAnimeNexusLoopbackHls(candidate.url) ||
        _activeSeekSession != null ||
        _pendingTargetPosition != null ||
        _isRecoveringCurrentCandidate ||
        _currentCandidateIndex >= _rankedCandidates.length - 1) {
      return;
    }

    _autoQualityDownshiftTimer = Timer(_autoQualityDownshiftBuffering, () {
      if (_state.status != PlayerSessionStatus.buffering ||
          _activeSeekSession != null ||
          _pendingTargetPosition != null ||
          _isRecoveringCurrentCandidate ||
          _currentCandidateIndex >= _rankedCandidates.length - 1) {
        return;
      }
      // Don't downshift if the demuxer hasn't parsed content yet — the player
      // is still loading manifests/init segments and the buffering is expected.
      if (_lastKnownDuration <= Duration.zero) {
        _log(
          'autoQuality downshift skip reason=no-duration-yet '
          'index=$_currentCandidateIndex',
        );
        return;
      }
      final lowOccupancy =
          _lastBufferedDuration <= const Duration(seconds: 2) ||
          _lastBufferingPercentage <= 20;
      if (!lowOccupancy) {
        _log(
          'autoQuality downshift skip reason=occupancy-not-low '
          'buffer=$_lastBufferedDuration percent=$_lastBufferingPercentage',
        );
        return;
      }
      _lastQualitySwitchAt = DateTime.now();
      _log(
        'autoQuality downshift trigger index=$_currentCandidateIndex '
        'variant=${_variantFromUrl(_rankedCandidates[_currentCandidateIndex].url)}',
      );
      unawaited(
        _handleCandidateFailure(
          code: 'player.auto_quality_downshift',
          message:
              'Auto quality lowered due to sustained buffering on current variant.',
        ),
      );
    });
  }

  Future<void> _maybeAutoQualityUpshift() async {
    if (_isDisposed || !_isAutoQualityEligible()) {
      return;
    }
    if (_currentCandidateIndex <= 0) {
      return;
    }

    final now = DateTime.now();
    final sinceBuffering = _lastBufferingAt == null
        ? _autoQualityStableFor
        : now.difference(_lastBufferingAt!);
    if (sinceBuffering < _autoQualityStableFor) {
      _log(
        'autoQuality upshift skip reason=not-stable '
        'sinceBuffering=${sinceBuffering.inSeconds}s',
      );
      return;
    }

    final sinceSwitch = _lastQualitySwitchAt == null
        ? _autoQualityCooldown
        : now.difference(_lastQualitySwitchAt!);
    if (sinceSwitch < _autoQualityCooldown) {
      _log(
        'autoQuality upshift skip reason=cooldown '
        'sinceSwitch=${sinceSwitch.inSeconds}s',
      );
      return;
    }

    if (_lastKnownPosition < const Duration(seconds: 20)) {
      _log(
        'autoQuality upshift skip reason=insufficient-playtime '
        'position=$_lastKnownPosition',
      );
      return;
    }

    final highOccupancy =
        _lastBufferedDuration >= const Duration(seconds: 12) &&
        _lastBufferingPercentage >= 85;
    if (!highOccupancy) {
      _log(
        'autoQuality upshift skip reason=occupancy-not-high '
        'buffer=$_lastBufferedDuration percent=$_lastBufferingPercentage',
      );
      return;
    }

    final targetIndex = _currentCandidateIndex - 1;
    final target = _rankedCandidates[targetIndex];
    if (!_isAnimeNexusLoopbackHls(target.url)) {
      return;
    }

    final resumeFrom = _lastKnownPosition;
    _currentCandidateIndex = targetIndex;
    _runtimeErrorRetriesForCurrentCandidate = 0;
    _recoveriesForCurrentCandidate = 0;
    _lastQualitySwitchAt = now;

    _log(
      'autoQuality upshift trigger fromIndex=${targetIndex + 1} '
      'toIndex=$targetIndex resumeFrom=$resumeFrom '
      'toVariant=${_variantFromUrl(target.url)}',
    );

    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.fallbacking,
        infoMessage: 'player.auto_quality_upshift',
        currentCandidateIndex: _currentCandidateIndex,
        totalCandidates: _rankedCandidates.length,
        clearError: true,
      ),
    );

    await _openCurrentCandidate(startPosition: resumeFrom);
  }

  void _startSeekStallWatch({
    required ResolvedStream candidate,
    required Duration? targetPosition,
  }) {
    _seekStallTimer?.cancel();
    final normalizedTarget = _normalizePosition(targetPosition);
    if (!candidate.isHls || normalizedTarget <= Duration.zero) {
      _seekWatchTargetPosition = null;
      _seekWatchBaselinePosition = null;
      return;
    }

    _seekWatchTargetPosition = normalizedTarget;
    _seekWatchBaselinePosition = _lastKnownPosition;
    _log(
      'seekStallWatch start target=$normalizedTarget baseline=$_seekWatchBaselinePosition recoveries=$_seekStallRecoveriesForCurrentTarget',
    );
    // Anime Nexus streams use a shorter timeout because the proxy pre-warms
    // segments and the robust engine seekTo retries 3 times internally.
    // 6s is enough to detect a genuine stall without the 12s latency.
    final stallTimeout =
        (_state.selectedStream != null &&
            _isAnimeNexusLoopbackHls(_state.selectedStream!.url))
        ? const Duration(seconds: 6)
        : const Duration(seconds: 12);
    _seekStallTimer = Timer(stallTimeout, () {
      final watchTarget = _seekWatchTargetPosition;
      if (watchTarget == null ||
          _state.selectedStream == null ||
          !_state.selectedStream!.isHls ||
          _isRecoveringCurrentCandidate) {
        return;
      }

      // Position already past target → seek succeeded, nothing to do.
      if (_lastKnownPosition >
          watchTarget + const Duration(milliseconds: 500)) {
        return;
      }

      // Position far from target (e.g., opened at 0 instead of target).
      // Use seek escalation if there's an active session.
      if (!_isPositionNearTarget(_lastKnownPosition, watchTarget)) {
        if (_activeSeekSession != null &&
            _activeSeekSession!.generation == _seekGeneration) {
          _log(
            'seekStallWatch position-far-from-target '
            'target=$watchTarget position=$_lastKnownPosition',
          );
          _escalateSeekSession();
        }
        return;
      }

      // Position near target but not progressing — classic stall.
      if (_isBuffering ||
          !_isPlaying ||
          _seekStallRecoveriesForCurrentTarget >= 2) {
        return;
      }

      _seekStallRecoveriesForCurrentTarget++;
      _log(
        'seekStallWatch stalled target=$watchTarget '
        'position=$_lastKnownPosition '
        'recoveries=$_seekStallRecoveriesForCurrentTarget',
      );
      unawaited(
        _recoverCurrentCandidate(
          errorCode: 'player.seek_stalled_recovery_failed',
          reason: 'Playback stalled after seek without buffer progress.',
          recoveryPosition: watchTarget,
          force: true,
        ),
      );
    });
  }

  void _handleSeekProgress(Duration position) {
    final watchTarget = _seekWatchTargetPosition;
    if (watchTarget == null) {
      return;
    }

    if (position >= watchTarget + const Duration(seconds: 2)) {
      _log(
        'seekStallWatch cleared target=$watchTarget position=$position recoveries=$_seekStallRecoveriesForCurrentTarget',
      );
      _resetSeekRecoveryTracking();

      // Fix A: Clear pendingTarget when seekStallWatch clears successfully
      // (position progressed past target), even without active seek session.
      // CRITICAL: Never confirm at zero position for non-zero targets.
      final pendingTarget = _pendingTargetPosition;
      if (pendingTarget != null && _activeSeekSession == null) {
        // Fix A.1: Stricter guard - reject confirmation during transient state
        final isTransientState =
            pendingTarget > Duration.zero &&
            position < const Duration(milliseconds: 500);

        if (isTransientState) {
          _log(
            'pendingTarget guard reject-zero-position target=$pendingTarget '
            'effectivePosition=$position source=seekStallWatch reopenStable=false',
          );
          // Don't confirm - this is a transient state
        } else {
          _log(
            'pendingTarget confirm-check effectivePosition=$position '
            'target=$pendingTarget source=seekStallWatch reopenStable=true',
          );
          _log(
            'pendingTarget confirmed effectivePosition=$position '
            'target=$pendingTarget',
          );
          _log(
            'pendingTarget cleared reason=seekStallWatch-cleared-successfully',
          );
          _pendingTargetPosition = null;
        }
      }
    }
  }

  void _resetSeekRecoveryTracking() {
    _seekStallTimer?.cancel();
    _seekWatchTargetPosition = null;
    _seekWatchBaselinePosition = null;
    _seekStallRecoveriesForCurrentTarget = 0;
  }

  /// Confirms the seek reached the target position and cleans up the session.
  void _confirmSeekSuccess() {
    final session = _activeSeekSession;
    if (session == null) return;
    _seekPositionValidationTimer?.cancel();
    _seekStallTimer?.cancel();
    final totalElapsed = DateTime.now().difference(session.startedAt);
    _log(
      'seekOpen accepted target=${session.targetPosition} '
      'actual=$_lastKnownPosition '
      'delta=${(_lastKnownPosition - session.targetPosition).inMilliseconds}ms '
      'generation=${session.generation}',
    );
    _log(
      'seekLatency phase=seek-confirmed '
      'total=${totalElapsed.inMilliseconds}ms '
      'level=${session.currentLevel}',
    );
    // Propagate seek latency to the diagnostics overlay.
    _lastConfirmedSeekLatencyMs = totalElapsed.inMilliseconds;
    final activeCandidate = _state.selectedStream;
    _log(
      'seekQuality final activeVariant=${activeCandidate != null ? _variantFromUrl(activeCandidate.url) : "null"} '
      'candidateIndex=$_currentCandidateIndex',
    );
    _log('pendingTarget cleared reason=seek-confirmed');
    _pendingTargetPosition = null;
    _log('seek-phase completed total=${totalElapsed.inMilliseconds}ms');
    _activeSeekSession = null;
  }

  /// P5: Visual gate — waits for a real first-frame-rendered signal from
  /// the playback engine instead of guessing readiness from position
  /// thresholds.  Falls back to a position+playing heuristic if the engine
  /// does not support first-frame detection (future never completes).
  ///
  /// On all platforms the primary signal is `PlaybackEngine.firstFrameRendered`.
  /// The position/playing heuristic acts as a secondary signal to avoid
  /// hanging indefinitely if the engine implementation doesn't fire it.
  Future<bool> _waitForUsableFrame({required Duration timeout}) async {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    // Secondary heuristic thresholds (fallback if first-frame signal
    // is not supported by the engine implementation).
    final positionThreshold = isWindows
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 1);

    // Check immediate state — position may already be past threshold
    // after a very fast open.
    final immediateReady =
        _lastKnownDuration > Duration.zero &&
        _lastKnownPosition > positionThreshold &&
        _isPlaying;

    if (immediateReady) {
      _log(
        'waitForUsableFrame immediate windows=$isWindows '
        'duration=$_lastKnownDuration position=$_lastKnownPosition '
        'buffering=$_isBuffering playing=$_isPlaying',
      );
      return true;
    }

    final completer = Completer<bool>();
    late final Timer timeoutTimer;

    void completeOnce(bool value, String reason) {
      if (completer.isCompleted) return;
      _log(
        'waitForUsableFrame $reason windows=$isWindows '
        'duration=$_lastKnownDuration position=$_lastKnownPosition '
        'buffering=$_isBuffering playing=$_isPlaying',
      );
      completer.complete(value);
    }

    // P5: Primary signal — real first-frame from the video output.
    // This is the most reliable signal that a frame is actually visible.
    unawaited(
      _playbackEngine.firstFrameRendered.then((_) {
        completeOnce(true, 'first-frame-rendered');
      }).catchError((_) {}),
    );

    // Secondary signal — position + playing heuristic as fallback.
    void checkHeuristic() {
      if (completer.isCompleted) return;
      final signalReady =
          _lastKnownDuration > Duration.zero &&
          _lastKnownPosition > positionThreshold &&
          _isPlaying;
      if (signalReady) {
        completeOnce(true, 'heuristic-ready');
      }
    }

    final durationSub = _durationController.stream.listen((_) {
      checkHeuristic();
    });
    final positionSub = _positionController.stream.listen((_) {
      checkHeuristic();
    });

    timeoutTimer = Timer(timeout, () {
      completeOnce(false, 'timeout');
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await durationSub.cancel();
      await positionSub.cancel();
    }
  }

  /// Cancels the active seek session without confirming success.
  ///
  /// Also cancels buffering and stall timers to prevent stale callbacks
  /// from firing after the session is cleared (which would fall through
  /// to [_handleCandidateFailure] and cause a quality downgrade).
  void _cancelSeekSession(String reason) {
    final session = _activeSeekSession;
    if (session == null) return;
    _seekPositionValidationTimer?.cancel();
    _bufferingTimer?.cancel();
    _seekStallTimer?.cancel();
    _log(
      'seekSession cancelled reason=$reason '
      'target=${session.targetPosition} generation=${session.generation}',
    );
    _activeSeekSession = null;
  }

  /// Starts a timer-based position validation after a seek-driven open.
  ///
  /// If the position has not reached the target within the timeout,
  /// the seek session is escalated to the next level.
  void _startSeekPositionValidation() {
    _seekPositionValidationTimer?.cancel();
    final session = _activeSeekSession;
    if (session == null) return;
    final seekGen = session.generation;

    // Task 3.3: Check effective absolute position immediately.
    // _lastKnownPosition is already remapped by _effectivePosition in
    // _onPositionChanged, so it represents the absolute timeline position.
    // If position already matches target within tolerance, confirm seek
    // success immediately (no artificial latency).
    if (_isPositionNearTarget(_lastKnownPosition, session.targetPosition)) {
      _log(
        'seekValidation immediate-success '
        'effectivePosition=$_lastKnownPosition '
        'target=${session.targetPosition}',
      );
      _confirmSeekSuccess();
      return;
    }

    // Task 3.3: If position does NOT match target, start validation timer
    // as fallback mechanism. Timer validates periodically until position
    // reaches target or timeout occurs.
    _log(
      'seekValidation start-timer '
      'effectivePosition=$_lastKnownPosition '
      'target=${session.targetPosition}',
    );
    _seekPositionValidationTimer = Timer(const Duration(seconds: 6), () {
      if (_activeSeekSession == null ||
          _activeSeekSession!.generation != seekGen) {
        return;
      }

      final delta = (_lastKnownPosition - session.targetPosition).inSeconds
          .abs();
      _log(
        'seekOpen validate target=${session.targetPosition} '
        'actual=$_lastKnownPosition delta=${delta}s '
        'level=${session.currentLevel}',
      );

      if (_isPositionNearTarget(_lastKnownPosition, session.targetPosition)) {
        _confirmSeekSuccess();
        return;
      }

      _log(
        'seekOpen rejected out-of-target '
        'target=${session.targetPosition} actual=$_lastKnownPosition '
        'delta=${delta}s',
      );
      _escalateSeekSession();
    });
  }

  /// Escalates the active seek session to the next recovery level.
  ///
  /// **Anime Nexus** streams retry native seeking (re-prefetch + re-seek)
  /// up to 3 times before giving up.  This avoids the costly stream
  /// teardown/rebuild that the old windowed-manifest path required.
  ///
  /// **Other HLS** sources still follow the legacy path:
  /// Level 1 (local seek) → Level 2 (reopen same candidate).
  /// Level 2 (reopen) → retry up to 2 times, then accept current position.
  ///
  /// IMPORTANT: Seek position failures do NOT trigger quality downgrade.
  /// Quality downgrade via [_handleCandidateFailure] is reserved for real
  /// transport failures (open timeout, segment fetch 4xx/5xx, proxy
  /// unavailable).  A seek that can't land on the exact target is not a
  /// reason to drop from 5300 → 4400 → 1600.
  void _escalateSeekSession() {
    final session = _activeSeekSession;
    if (session == null) return;
    final candidate = _state.selectedStream;
    if (candidate == null) return;

    // ── Anime Nexus: retry native seek (never reopen with windowed manifest)
    if (_isAnimeNexusLoopbackHls(candidate.url)) {
      session.reopenAttempts++;
      if (session.reopenAttempts < 3) {
        _log(
          'seekNativeRetry attempt=${session.reopenAttempts} '
          'target=${session.targetPosition} '
          'actual=$_lastKnownPosition',
        );
        // Retry the native seek in place. The engine owns any internal
        // prefetching required for robust seek recovery.
        unawaited(
          Future<void>(() async {
            final engineTarget = _isManagedTimelineWindow
                ? session.targetPosition - _timelineBasePosition
                : session.targetPosition;
            await _playbackEngine.seekTo(engineTarget);
            _startSeekStallWatch(
              candidate: candidate,
              targetPosition: session.targetPosition,
            );
          }),
        );
      } else {
        _log(
          'seekQuality preserved — native seek retries exhausted '
          'candidateIndex=$_currentCandidateIndex '
          'target=${session.targetPosition} '
          'actual=$_lastKnownPosition',
        );
        // Cancel all watchers so they cannot fire after the seek session
        // is cleared.  Without this, a stale _bufferingTimer or
        // _seekStallTimer would fall through to _handleCandidateFailure
        // and trigger an unnecessary quality downgrade.
        _bufferingTimer?.cancel();
        _seekStallTimer?.cancel();
        _cancelSeekSession('native-seek-retries-exhausted');
      }
      return;
    }

    // ── Non-Anime-Nexus: legacy escalation path.
    if (session.currentLevel <= 1) {
      // Level 1 → Level 2: reopen same candidate with windowed HLS.
      session.currentLevel = 2;
      session.reopenAttempts = 0;
      _log(
        'seekLocal failed reason=position-out-of-target '
        'target=${session.targetPosition} actual=$_lastKnownPosition',
      );
      _log('seekReopenSameCandidate target=${session.targetPosition}');
      unawaited(
        _recoverCurrentCandidate(
          errorCode: 'player.seek_position_validation_failed',
          reason: 'Seek landed out of target position.',
          recoveryPosition: session.targetPosition,
          force: true,
        ),
      );
    } else if (session.currentLevel == 2) {
      session.reopenAttempts++;
      if (session.reopenAttempts < 2) {
        _log(
          'seekReopenSameCandidate retry=${session.reopenAttempts} '
          'target=${session.targetPosition}',
        );
        unawaited(
          _recoverCurrentCandidate(
            errorCode: 'player.seek_position_validation_failed',
            reason: 'Reopen same candidate landed out of target.',
            recoveryPosition: session.targetPosition,
            force: true,
          ),
        );
      } else {
        // Level 2 exhausted → Accept current position, do NOT drop quality.
        _log(
          'seekQuality preserved — seek position exhausted but quality locked '
          'candidateIndex=$_currentCandidateIndex '
          'target=${session.targetPosition} '
          'actual=$_lastKnownPosition',
        );
        _cancelSeekSession('seek-position-exhausted-quality-preserved');
        _pendingTargetPosition = null;
      }
    }
  }

  /// Resets timeline domain to a clean unmanaged state.
  ///
  /// Must be called **before** `engine.open()` in every code path that opens
  /// a new candidate ([_openCurrentCandidate], [_recoverCurrentCandidate]).
  /// This guarantees that any position/duration events that fire between
  /// `engine.open()` and the subsequent [_applyTimelineWindow] are processed
  /// with a sane default (managed=false, base=0) instead of stale values
  /// from a previous session.
  void _resetTimelineDomainForNewOpen() {
    final wasManaged = _isManagedTimelineWindow;
    _isManagedTimelineWindow = false;
    _timelineBasePosition = Duration.zero;
    _lastRawDurationFromEngine = Duration.zero;
    _log(
      'timelineDomain reset-for-new-open '
      'wasManaged=$wasManaged',
    );
  }

  void _applyTimelineWindow({
    required ResolvedStream candidate,
    required ResolvedStream openCandidate,
    required Duration? requestedStartPosition,
  }) {
    final normalizedStart = _normalizePosition(requestedStartPosition);
    final managedWindow =
        _isAnimeNexusLoopbackHls(openCandidate.url) &&
        openCandidate.url.queryParameters.containsKey('seekNonce') &&
        normalizedStart > Duration.zero;
    _isManagedTimelineWindow = managedWindow;
    _timelineBasePosition = managedWindow ? normalizedStart : Duration.zero;
    _log(
      'applyTimelineWindow managed=$managedWindow base=$_timelineBasePosition '
      'durationHint=$_fullTimelineDurationHint',
    );
    if (!managedWindow && _lastKnownDuration > _fullTimelineDurationHint) {
      _fullTimelineDurationHint = _lastKnownDuration;
    }
    if (managedWindow) {
      _lastKnownPosition = normalizedStart;
      _emitPosition(_lastKnownPosition);
      _recomputeTimelineDomain('applyTimelineWindow-managed');
    } else if (!candidate.isHls) {
      _fullTimelineDurationHint = Duration.zero;
      _recomputeTimelineDomain('applyTimelineWindow-unmanaged');
    } else {
      _recomputeTimelineDomain('applyTimelineWindow-unmanaged-hls');
    }
  }

  Duration _effectivePosition(Duration rawPosition) {
    if (!_isManagedTimelineWindow) {
      return rawPosition;
    }
    return _timelineBasePosition + rawPosition;
  }

  Duration _effectiveDuration(Duration rawDuration) {
    if (!_isManagedTimelineWindow) {
      return rawDuration;
    }

    final absoluteWindowDuration = _timelineBasePosition + rawDuration;
    return absoluteWindowDuration > _fullTimelineDurationHint
        ? absoluteWindowDuration
        : _fullTimelineDurationHint;
  }

  void _emitPosition(Duration position) {
    // Pass 5: Log position emission with context for timeline debugging
    if (_isManagedTimelineWindow || position.inSeconds % 30 == 0) {
      _log(
        'emitPosition position=$position managed=$_isManagedTimelineWindow '
        'base=$_timelineBasePosition',
      );
    }
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
  }

  void _emitDuration(Duration duration) {
    // Pass 5: Log duration emission with context for timeline debugging
    if (_isManagedTimelineWindow) {
      _log(
        'emitDuration duration=$duration managed=$_isManagedTimelineWindow '
        'base=$_timelineBasePosition hint=$_fullTimelineDurationHint',
      );
    }
    if (!_durationController.isClosed) {
      _durationController.add(duration);
    }
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
    final normalizedStart = _normalizePosition(startPosition);

    if (_activeSeekSession != null &&
        candidate.isHls &&
        normalizedStart > Duration.zero) {
      return _seekReadyBudget;
    }

    if (candidate.isHls &&
        normalizedStart > Duration.zero &&
        _initialResumeOpenBudget > _openTimeout) {
      return _initialResumeOpenBudget;
    }

    if (_isAnimeNexusLoopbackHls(candidate.url) &&
        _animeNexusInitialOpenBudget > _openTimeout) {
      return _animeNexusInitialOpenBudget;
    }

    return _openTimeout;
  }

  Duration _seekVisualGateTimeoutFrom(DateTime openStartTime) {
    if (_seekVisualGateTimeout <= Duration.zero) return Duration.zero;
    final elapsed = DateTime.now().difference(openStartTime);
    final remaining = _seekReadyBudget - elapsed;
    if (remaining <= Duration.zero) {
      return const Duration(milliseconds: 100);
    }
    return remaining < _seekVisualGateTimeout
        ? remaining
        : _seekVisualGateTimeout;
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
    final formatted =
        '[player.orchestrator#$_instanceId ${DateTime.now().toIso8601String()}] '
        '$message';
    debugPrint(formatted);
    _debugLogSink?.call(formatted);
  }

  String _candidateSummary(List<ResolvedStream> candidates) {
    return candidates.map((candidate) => candidate.url.toString()).join(' | ');
  }

  Future<void> _applySubtitleTrack() async {
    final track = _preferredSubtitleTrack;
    if (track == null) {
      await _playbackEngine.clearSubtitleTrack();
      return;
    }

    await _playbackEngine.setSubtitleTrack(track);
  }

  ExternalSubtitleTrack? get _preferredSubtitleTrack {
    if (_externalSubtitles.isEmpty) {
      return null;
    }

    final selectedId = _selectedExternalSubtitleId;
    if (selectedId != null) {
      for (final track in _externalSubtitles) {
        if (track.id == selectedId) {
          return track;
        }
      }
    }

    for (final track in _externalSubtitles) {
      if (track.isDefault) {
        return track;
      }
    }

    return _externalSubtitles.first;
  }
}
