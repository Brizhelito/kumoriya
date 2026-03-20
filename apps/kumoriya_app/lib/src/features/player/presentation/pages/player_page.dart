import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../anime_catalog/presentation/pages/episode_list_page.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../application/models/subtitle_settings.dart';
import '../../application/models/embedded_tracks.dart';
import '../../../anime_catalog/application/services/mal_metadata_bridge_service.dart';
import '../../application/models/player_session_state.dart';
import '../../application/services/player_session_orchestrator.dart';
import '../../application/use_cases/clear_playback_preference_use_case.dart';
import '../../application/use_cases/save_playback_preference_use_case.dart';
import '../../application/use_cases/save_progress_use_case.dart';
import '../../infrastructure/media_kit_playback_engine.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    required this.episodeNumber,
    this.episodeTitle,
    required this.sourcePluginId,
    required this.serverName,
    this.persistSelection = true,
    this.preferredAudioPreference,
    required this.resolved,
  });

  final int anilistId;
  final String animeTitle;
  final String episodeNumber;
  final String? episodeTitle;
  final String sourcePluginId;
  final String serverName;
  final bool persistSelection;
  final PlaybackAudioPreference? preferredAudioPreference;
  final ResolvedServerLinkResult resolved;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  MediaKitPlaybackEngine? _engine;
  PlayerSessionOrchestrator? _orchestrator;
  late final SaveProgressUseCase _saveProgress;
  late final SavePlaybackPreferenceUseCase _savePlaybackPreference;
  late final ClearPlaybackPreferenceUseCase _clearPlaybackPreference;

  StreamSubscription<PlayerSessionState>? _sessionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completionSub;
  Timer? _periodicSaveTimer;
  Future<void>? _pendingProgressFlush;
  bool _isExiting = false;
  bool _historyWrittenForSession = false;
  bool _forceSoftwareVideoOutput = false;
  bool _isWindowsFullscreen = false;
  bool? _windowsFullscreenBeforePlayback;
  bool _autoNextTriggeredByEndingResidual = false;
  List<AniSkipSegment> _aniSkipSegments = const <AniSkipSegment>[];
  Future<void>? _pendingAniSkipLoad;

  PlayerSessionState _state = const PlayerSessionState.idle();
  String? _startError;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration? _resumePosition;
  bool _isScrubbing = false;
  double? _scrubPositionMs;
  EmbeddedTracks _embeddedTracks = EmbeddedTracks.empty;
  StreamSubscription<EmbeddedTracks>? _tracksSub;
  EmbeddedAudioTrack? _activeAudioTrack;
  EmbeddedSubtitleTrack? _activeEmbeddedSubtitleTrack;
  ExternalSubtitleTrack? _activeExternalSubtitleTrack;
  late final String _instanceId = identityHashCode(this).toRadixString(16);

  // Debounces orientation restoration so that pushReplacement to a new
  // PlayerPage can cancel it in initState, preventing a portrait flash.
  static Timer? _orientationRestoreTimer;

  double get _episodeNumberDouble =>
      double.tryParse(widget.episodeNumber) ?? 0.0;

  @override
  void initState() {
    super.initState();
    _saveProgress = SaveProgressUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _savePlaybackPreference = SavePlaybackPreferenceUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _clearPlaybackPreference = ClearPlaybackPreferenceUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _log(
      'init resolver=${widget.resolved.resolverId} server=${widget.serverName} streams=${widget.resolved.streams.map((stream) => stream.url.toString()).join(" | ")}',
    );
    unawaited(_initializeRuntimeAndStartPlayback());
    unawaited(_enterWindowsFullscreenIfSupported());
    // Cancel any pending orientation restore from a prior player page
    // (e.g. pushReplacement for next episode) to avoid portrait flash.
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = null;
    // Enter immersive landscape mode for video playback.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _log('dispose');
    _periodicSaveTimer?.cancel();
    unawaited(_saveCurrentProgress());
    unawaited(_disposeRuntime());
    unawaited(_restoreWindowsFullscreenIfNeeded());
    // Defer orientation restore so a pushReplacement new PlayerPage can
    // cancel this in its initState, preventing a brief portrait flash.
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = Timer(const Duration(milliseconds: 300), () {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
      _orientationRestoreTimer = null;
    });
    super.dispose();
  }

  Future<void> _installRuntime() async {
    await _disposeRuntime();
    final engine = MediaKitPlaybackEngine(
      forceSoftwareVideoOutput: _forceSoftwareVideoOutput,
      onVideoOutputFallbackRequested: _handleVideoOutputFallback,
    );
    final orchestrator = PlayerSessionOrchestrator(playbackEngine: engine);

    _sessionSub = orchestrator.states.listen((next) {
      _log(
        'session status=${next.status} index=${next.currentCandidateIndex}/${next.totalCandidates} info=${next.infoMessage} error=${next.errorMessage}',
      );
      if (mounted) {
        setState(() => _state = next);
      } else {
        _state = next;
      }
    });

    _positionSub = orchestrator.positionStream.listen((pos) {
      if (_isScrubbing || _resumePosition != null) {
        _log('position stream pos=$pos duration=$_currentDuration');
      }
      final resume = _resumePosition;
      if (resume != null && pos >= resume - const Duration(seconds: 5)) {
        _resumePosition = null;
      }
      if (!mounted) {
        _currentPosition = pos;
        _maybeAutoNextFromEndingResidual(pos);
        return;
      }
      setState(() => _currentPosition = pos);
      _maybeAutoNextFromEndingResidual(pos);
    });
    _durationSub = orchestrator.durationStream.listen((dur) {
      if (dur <= Duration.zero) {
        return;
      }
      _log('duration stream dur=$dur');
      if (!mounted) {
        _currentDuration = dur;
        _maybeLoadAniSkipSegments();
        return;
      }
      setState(() => _currentDuration = dur);
      _maybeLoadAniSkipSegments();
    });

    _playingSub = engine.playingStream.listen(_onPlayingChanged);
    _tracksSub = orchestrator.embeddedTracksStream.listen((tracks) {
      if (!mounted) {
        _embeddedTracks = tracks;
        return;
      }
      setState(() => _embeddedTracks = tracks);
    });
    _completionSub = orchestrator.naturalCompletionStream.listen((_) {
      _onNaturalCompletion();
    });
    _engine = engine;
    _orchestrator = orchestrator;
  }

  Future<void> _initializeRuntimeAndStartPlayback() async {
    // Start loading resume position in parallel with runtime install
    // so the DB read overlaps with engine/orchestrator setup.
    final resumeFuture = _loadResumePosition();
    await _installRuntime();
    _resumePosition = await resumeFuture;
    await _startPlaybackFromPosition(_resumePosition);
  }

  Future<void> _disposeRuntime() async {
    await _sessionSub?.cancel();
    await _playingSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _tracksSub?.cancel();
    await _completionSub?.cancel();
    _sessionSub = null;
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _tracksSub = null;
    _completionSub = null;
    _embeddedTracks = EmbeddedTracks.empty;
    final orchestrator = _orchestrator;
    _orchestrator = null;
    _engine = null;
    if (orchestrator != null) {
      await orchestrator.dispose();
    }
  }

  void _onPlayingChanged(bool playing) {
    _log('playing stream playing=$playing position=$_currentPosition');
    if (!playing) {
      unawaited(_saveCurrentProgress());
      unawaited(_updateWatchHistory());
    }
    if (playing) {
      if (!_historyWrittenForSession) {
        _historyWrittenForSession = true;
        unawaited(_updateWatchHistory());
      }
      _periodicSaveTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_saveCurrentProgress()),
      );
    } else {
      _periodicSaveTimer?.cancel();
      _periodicSaveTimer = null;
    }
  }

  void _onNaturalCompletion() {
    if (!mounted || _isExiting) return;
    _log('naturalCompletion → auto-exit');
    unawaited(_handleExitRequested(naturalCompletion: true));
  }

  Future<void> _saveCurrentProgress() async {
    if (_currentPosition < const Duration(seconds: 5)) return;
    await _saveProgress(
      anilistId: widget.anilistId,
      episodeNumber: _episodeNumberDouble,
      position: _currentPosition,
      totalDuration: _currentDuration > Duration.zero ? _currentDuration : null,
      lastSourcePluginId: widget.sourcePluginId,
      lastServerName: widget.serverName,
      lastResolverPluginId: widget.resolved.resolverId,
    );
  }

  Future<void> _updateWatchHistory() async {
    if (_currentPosition < const Duration(seconds: 5)) return;
    final store = ref.read(animeProgressStoreProvider);
    await store.upsertWatchHistory(
      anilistId: widget.anilistId,
      episodeNumber: _episodeNumberDouble,
      positionSeconds: _currentPosition.inSeconds,
      totalDurationSeconds: _currentDuration > Duration.zero
          ? _currentDuration.inSeconds
          : null,
      lastSourcePluginId: widget.sourcePluginId,
    );
  }

  Future<void> _flushProgressAndRefresh() {
    final pending = _pendingProgressFlush;
    if (pending != null) {
      return pending;
    }

    final future = _saveCurrentProgress().whenComplete(() {
      _pendingProgressFlush = null;
    });
    _pendingProgressFlush = future;
    return future;
  }

  Future<void> _handleExitRequested({bool naturalCompletion = false}) async {
    if (_isExiting) {
      return;
    }
    _isExiting = true;
    try {
      await _flushProgressAndRefresh();
      await _updateWatchHistory();
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(latestEpisodeProgressProvider(widget.anilistId));
      ref.invalidate(animeEpisodeProgressListProvider(widget.anilistId));
    } finally {
      if (mounted) {
        Navigator.of(context).pop(naturalCompletion);
      }
      _isExiting = false;
    }
  }

  void _handleExit(BuildContext context) {
    unawaited(_handleExitRequested());
  }

  Widget _wrapWithExitGuard(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleExitRequested();
        }
      },
      child: child,
    );
  }

  Future<void> _startPlaybackFromPosition(Duration? initialPosition) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    _log(
      'startPlayback resumePosition=$initialPosition streams=${widget.resolved.streams.length} softwareOutput=$_forceSoftwareVideoOutput',
    );
    _autoNextTriggeredByEndingResidual = false;
    final result = await orchestrator.start(
      streamCandidates: widget.resolved.streams,
      externalSubtitles: widget.resolved.externalSubtitles,
      initialPosition: initialPosition,
    );
    if (!mounted || _orchestrator != orchestrator) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {
        unawaited(_persistSuccessfulSelection());
      },
    );
  }

  Future<void> _retryPlayback() async {
    _log('retryPlayback');
    setState(() => _startError = null);
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    final result = await orchestrator.retry();
    if (!mounted) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {
        unawaited(_persistSuccessfulSelection());
      },
    );
  }

  Future<void> _persistSuccessfulSelection() async {
    if (!widget.persistSelection) {
      await _clearPlaybackPreference(widget.anilistId);
      return;
    }
    await _savePlaybackPreference(
      anilistId: widget.anilistId,
      sourcePluginId: widget.sourcePluginId,
      serverName: widget.serverName,
      resolverPluginId: widget.resolved.resolverId,
      preferredAudioPreference: widget.preferredAudioPreference,
    );
  }

  Future<Duration?> _loadResumePosition() async {
    final store = ref.read(animeProgressStoreProvider);
    final result = await store.getProgress(
      widget.anilistId,
      _episodeNumberDouble,
    );
    return result.fold(
      onFailure: (_) => null,
      onSuccess: (progress) {
        if (progress == null ||
            progress.watchState == WatchState.completed ||
            progress.position <= const Duration(seconds: 5)) {
          return null;
        }
        return progress.position;
      },
    );
  }

  Future<void> _seekTo(Duration position) async {
    _log(
      'ui seek target=$position current=$_currentPosition duration=$_currentDuration',
    );
    await _orchestrator?.seekTo(position);
  }

  Future<void> _handleVideoOutputFallback(String reason) async {
    if (_forceSoftwareVideoOutput) {
      return;
    }
    _log('video output fallback requested reason=$reason');
    _forceSoftwareVideoOutput = true;
    await _installRuntime();
    final resumePosition = _currentPosition > Duration.zero
        ? _currentPosition
        : _resumePosition;
    await _startPlaybackFromPosition(resumePosition);
  }

  Future<void> _maybeLoadAniSkipSegments() {
    final pending = _pendingAniSkipLoad;
    if (pending != null) {
      return pending;
    }
    if (_aniSkipSegments.isNotEmpty || _currentDuration <= Duration.zero) {
      return Future<void>.value();
    }

    final episodeNumber = int.tryParse(widget.episodeNumber);
    if (episodeNumber == null || episodeNumber <= 0) {
      return Future<void>.value();
    }
    final episodeLengthSeconds = _currentDuration.inSeconds;
    if (episodeLengthSeconds <= 0) {
      return Future<void>.value();
    }

    _log(
      'aniskip load start anilistId=${widget.anilistId} ep=$episodeNumber duration=${_currentDuration.inSeconds}s',
    );
    final future = ref
        .read(
          aniskipSegmentsProvider((
            anilistId: widget.anilistId,
            episodeNumber: episodeNumber,
            episodeLengthSeconds: episodeLengthSeconds,
          )).future,
        )
        .then((segments) {
          _log('aniskip loaded ${segments.length} segments');
          if (!mounted) {
            _aniSkipSegments = segments;
            return;
          }
          setState(() => _aniSkipSegments = segments);
        })
        .catchError((Object error) {
          _log('aniskip load failed: $error');
        })
        .whenComplete(() {
          _pendingAniSkipLoad = null;
        });

    _pendingAniSkipLoad = future;
    return future;
  }

  AniSkipSegment? get _activeAniSkipSegment {
    if (_aniSkipSegments.isEmpty || _currentDuration <= Duration.zero) {
      return null;
    }
    for (final segment in _aniSkipSegments) {
      final guardStart = segment.start - const Duration(seconds: 1);
      final effectiveStart = guardStart > Duration.zero
          ? guardStart
          : Duration.zero;
      if (_currentPosition >= effectiveStart &&
          _currentPosition < segment.end) {
        return segment;
      }
    }
    return null;
  }

  String? get _activeAniSkipLabel {
    final segment = _activeAniSkipSegment;
    if (segment == null) {
      return null;
    }
    if (segment.kind == AniSkipSegmentKind.ending &&
        _shouldAutoAdvanceAfterEnding(segment)) {
      return context.l10n.playerNextEpisode;
    }
    return switch (segment.kind) {
      AniSkipSegmentKind.opening => context.l10n.playerSkipIntro,
      AniSkipSegmentKind.ending => context.l10n.playerSkipCredits,
    };
  }

  Future<void> _skipActiveSegment() async {
    final segment = _activeAniSkipSegment;
    if (segment == null) {
      return;
    }
    if (segment.kind == AniSkipSegmentKind.ending &&
        _shouldAutoAdvanceAfterEnding(segment)) {
      _autoNextTriggeredByEndingResidual = true;
      _log('ending skip pressed → next episode');
      await _openEpisodeSelectorFromPlayer();
      return;
    }
    final target = segment.end + const Duration(milliseconds: 300);
    final maxSeekTarget = _currentDuration > const Duration(seconds: 1)
        ? _currentDuration - const Duration(seconds: 1)
        : _currentDuration;
    final clamped = target > maxSeekTarget ? maxSeekTarget : target;
    _log('segment skip pressed kind=${segment.kind} target=$clamped');
    await _seekTo(clamped);
  }

  bool _shouldAutoAdvanceAfterEnding(AniSkipSegment ending) {
    final remainingAfterEnding = _currentDuration - ending.end;
    return remainingAfterEnding < const Duration(seconds: 10);
  }

  void _maybeAutoNextFromEndingResidual(Duration position) {
    if (_autoNextTriggeredByEndingResidual ||
        _currentDuration <= Duration.zero) {
      return;
    }

    AniSkipSegment? ending;
    for (final segment in _aniSkipSegments.reversed) {
      if (segment.kind == AniSkipSegmentKind.ending) {
        ending = segment;
        break;
      }
    }
    if (ending == null) {
      return;
    }

    if (!_shouldAutoAdvanceAfterEnding(ending)) {
      return;
    }

    if (position < ending.end) {
      return;
    }

    _autoNextTriggeredByEndingResidual = true;
    _log(
      'auto-next residual trigger ending=[${ending.start}..${ending.end}] remainingAfterEnding=${_currentDuration - ending.end} position=$position',
    );
    unawaited(_openEpisodeSelectorFromPlayer());
  }

  Future<void> _enterWindowsFullscreenIfSupported() async {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }
    try {
      _windowsFullscreenBeforePlayback = await windowManager.isFullScreen();
      if (_windowsFullscreenBeforePlayback != true) {
        await windowManager.setFullScreen(true);
      }
      final fullScreen = await windowManager.isFullScreen();
      if (!mounted) {
        _isWindowsFullscreen = fullScreen;
        return;
      }
      setState(() => _isWindowsFullscreen = fullScreen);
    } catch (_) {}
  }

  Future<void> _restoreWindowsFullscreenIfNeeded() async {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }
    final before = _windowsFullscreenBeforePlayback;
    if (before == null) {
      return;
    }
    try {
      await windowManager.setFullScreen(before);
    } catch (_) {}
  }

  Future<void> _toggleWindowsFullscreen() async {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }
    try {
      final current = await windowManager.isFullScreen();
      final target = !current;
      await windowManager.setFullScreen(target);
      if (!mounted) {
        _isWindowsFullscreen = target;
        return;
      }
      setState(() => _isWindowsFullscreen = target);
    } catch (_) {}
  }

  Future<void> _openEpisodeSelectorFromPlayer() async {
    if (_state.status == PlayerSessionStatus.playing) {
      await _orchestrator?.togglePlayPause();
    }
    final openedNextDownload = await _openNextDownloadedEpisodeIfAvailable();
    if (openedNextDownload || !mounted) {
      return;
    }
    final nextEpisode = _episodeNumberDouble > 0
        ? _episodeNumberDouble + 1
        : 1.0;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeListPage(
          anilistId: widget.anilistId,
          animeTitle: widget.animeTitle,
          focusedEpisodeNumber: nextEpisode,
        ),
      ),
    );
  }

  Future<bool> _openNextDownloadedEpisodeIfAvailable() async {
    final currentEpisode = int.tryParse(widget.episodeNumber);
    if (currentEpisode == null || currentEpisode <= 0) {
      return false;
    }
    final nextEpisodeNumber = currentEpisode + 1;
    final downloadTask = await ref
        .read(downloadManagerProvider)
        .findTaskByEpisode(widget.anilistId, nextEpisodeNumber.toDouble());
    if (downloadTask == null ||
        downloadTask.status != DownloadStatus.completed ||
        downloadTask.filePath == null ||
        downloadTask.filePath!.trim().isEmpty) {
      return false;
    }

    final file = File(downloadTask.filePath!);
    if (!await file.exists()) {
      return false;
    }

    if (!mounted) {
      return true;
    }

    _log(
      'open next downloaded episode ep=$nextEpisodeNumber file=${file.path}',
    );
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: widget.anilistId,
          animeTitle: widget.animeTitle,
          episodeNumber: nextEpisodeNumber.toString(),
          sourcePluginId: downloadTask.sourcePluginId ?? 'offline',
          serverName: downloadTask.serverName ?? 'Downloaded',
          resolved: ResolvedServerLinkResult(
            resolverId: 'offline',
            resolverName: 'Downloaded',
            streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
          ),
        ),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    if (_startError != null) {
      return _wrapWithExitGuard(
        ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: KumoriyaColors.textPrimary,
                    ),
                    onPressed: () => _handleExit(context),
                  ),
                ),
                Expanded(
                  child: ErrorStateView(
                    message: _startError!,
                    onRetry: _retryPlayback,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isLoading =
        _state.status == PlayerSessionStatus.opening ||
        _state.status == PlayerSessionStatus.buffering;

    final subtitleConfig = ref.watch(subtitleSettingsProvider).value;

    return _wrapWithExitGuard(
      Scaffold(
        backgroundColor: Colors.black,
        body: StateTransitionSwitcher(
          stateKey: _state.status.name,
          child: _ImmersivePlayerView(
            engine: engine,
            isLoading: isLoading,
            isPlaying: _state.status == PlayerSessionStatus.playing,
            isError: _state.status == PlayerSessionStatus.error,
            animeTitle: widget.animeTitle,
            episodeNumber: widget.episodeNumber,
            currentPosition: _effectiveSliderPosition,
            totalDuration: _currentDuration,
            sliderValue: _sliderValueMs,
            sliderMax: _sliderMaxMs,
            hasMultipleAudio: _embeddedTracks.hasMultipleAudio,
            hasSubtitles:
                _embeddedTracks.hasSubtitles ||
                widget.resolved.externalSubtitles.isNotEmpty,
            onTogglePlayPause: () => _orchestrator?.togglePlayPause(),
            onSeekChanged: _currentDuration > Duration.zero
                ? (value) {
                    setState(() {
                      _isScrubbing = true;
                      _scrubPositionMs = value;
                    });
                  }
                : null,
            onSeekEnd: _currentDuration > Duration.zero
                ? (value) {
                    final target = Duration(milliseconds: value.round());
                    setState(() {
                      _currentPosition = target;
                      _isScrubbing = false;
                      _scrubPositionMs = null;
                    });
                    unawaited(_seekTo(target));
                  }
                : null,
            onSeekStart: () {
              setState(() => _isScrubbing = true);
            },
            onBack: () => _handleExit(context),
            onRetry: _retryPlayback,
            onOpenEpisodes: () => unawaited(_openEpisodeSelectorFromPlayer()),
            onQuality: () => unawaited(_showQualityPicker(context)),
            onAudio: _embeddedTracks.hasMultipleAudio
                ? () => unawaited(_showAudioTrackPicker(context))
                : null,
            onSubtitle:
                _embeddedTracks.hasSubtitles ||
                    widget.resolved.externalSubtitles.isNotEmpty
                ? () => unawaited(_showSubtitleTrackPicker(context))
                : null,
            onSkipBackward: () {
              final target = _currentPosition - const Duration(seconds: 10);
              unawaited(
                _seekTo(target < Duration.zero ? Duration.zero : target),
              );
            },
            onSkipForward: () {
              final maxPos = _currentDuration - const Duration(seconds: 1);
              final target = _currentPosition + const Duration(seconds: 10);
              unawaited(
                _seekTo(
                  target > maxPos && maxPos > Duration.zero ? maxPos : target,
                ),
              );
            },
            activeSkipLabel: _activeAniSkipLabel,
            onSkipSegment: () => unawaited(_skipActiveSegment()),
            isWindowsFullscreen: _isWindowsFullscreen,
            onToggleWindowsFullscreen: () =>
                unawaited(_toggleWindowsFullscreen()),
            errorMessage: _state.status == PlayerSessionStatus.error
                ? context.l10n.playerAllCandidatesFailed
                : null,
            formatDuration: _formatDuration,
            subtitleViewConfiguration: subtitleConfig?.toViewConfiguration(),
            episodeTitle: widget.episodeTitle,
            onVolumeChanged: (vol) => _engine?.player.setVolume(vol * 100),
            onSpeedChanged: (speed) => _engine?.player.setRate(speed),
          ),
        ),
      ),
    );
  }

  Future<void> _showQualityPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) {
      return;
    }
    final items = orchestrator.qualityCandidates;
    if (items.isEmpty) {
      return;
    }

    await _showPlayerSelectorSheet(
      context: context,
      title: context.l10n.playerQuality,
      icon: KumoriyaIcons.playerQuality,
      options: List<_PlayerSelectorOption>.generate(items.length, (index) {
        final stream = items[index];
        final selected =
            _state.selectedStream?.url.toString() == stream.url.toString();
        final label =
            stream.qualityLabel ?? '${context.l10n.playerQuality} ${index + 1}';
        return _PlayerSelectorOption(
          icon: Icons.high_quality_rounded,
          title: label,
          selected: selected,
          onTap: () => unawaited(orchestrator.selectQualityByIndex(index)),
        );
      }),
    );
  }

  Future<void> _showAudioTrackPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) return;
    final tracks = _embeddedTracks.audio;
    if (tracks.isEmpty) return;

    final activeAudioId = _activeAudioTrack?.id;
    await _showPlayerSelectorSheet(
      context: context,
      title: context.l10n.playerAudio,
      icon: KumoriyaIcons.playerAudio,
      options: tracks
          .map(
            (track) => _PlayerSelectorOption(
              icon: Icons.graphic_eq_rounded,
              title: track.displayLabel,
              subtitle: track.language,
              selected: track.id == activeAudioId,
              onTap: () {
                setState(() => _activeAudioTrack = track);
                unawaited(orchestrator.selectEmbeddedAudioTrack(track));
              },
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _showSubtitleTrackPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) return;
    final embeddedTracks = _embeddedTracks.subtitle;
    final externalTracks = orchestrator.externalSubtitleTracks;

    final activeEmbeddedSubId = _activeEmbeddedSubtitleTrack?.id;
    final activeExternalSubId = _activeExternalSubtitleTrack?.id;
    await _showPlayerSelectorSheet(
      context: context,
      title: context.l10n.playerSubtitles,
      icon: KumoriyaIcons.playerSubtitle,
      options: <_PlayerSelectorOption>[
        _PlayerSelectorOption(
          icon: Icons.subtitles_off_rounded,
          title: context.l10n.playerDisableSubtitles,
          selected: activeEmbeddedSubId == null && activeExternalSubId == null,
          onTap: () {
            setState(() {
              _activeEmbeddedSubtitleTrack = null;
              _activeExternalSubtitleTrack = null;
            });
            unawaited(orchestrator.clearExternalSubtitleTrack());
            unawaited(orchestrator.clearEmbeddedSubtitleTrack());
          },
        ),
        ...externalTracks.map(
          (track) => _PlayerSelectorOption(
            icon: Icons.closed_caption_rounded,
            title: track.label,
            subtitle: track.language,
            selected: track.id == activeExternalSubId,
            onTap: () {
              setState(() {
                _activeExternalSubtitleTrack = track;
                _activeEmbeddedSubtitleTrack = null;
              });
              unawaited(orchestrator.selectExternalSubtitleTrack(track));
            },
          ),
        ),
        ...embeddedTracks.map(
          (track) => _PlayerSelectorOption(
            icon: KumoriyaIcons.playerSubtitle,
            title: track.displayLabel,
            subtitle: track.language,
            selected: track.id == activeEmbeddedSubId,
            onTap: () {
              setState(() {
                _activeEmbeddedSubtitleTrack = track;
                _activeExternalSubtitleTrack = null;
              });
              unawaited(orchestrator.selectEmbeddedSubtitleTrack(track));
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showPlayerSelectorSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<_PlayerSelectorOption> options,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _PlayerSelectorSheet(title: title, icon: icon, options: options);
      },
    );
  }

  Duration get _effectiveSliderPosition => Duration(
    milliseconds:
        (_isScrubbing
                ? (_scrubPositionMs ??
                      _currentPosition.inMilliseconds.toDouble())
                : _currentPosition.inMilliseconds.toDouble())
            .round(),
  );

  double get _sliderMaxMs {
    final durationMs = _currentDuration.inMilliseconds.toDouble();
    return durationMs > 0 ? durationMs : 1;
  }

  double get _sliderValueMs {
    final value = _effectiveSliderPosition.inMilliseconds.toDouble();
    if (value < 0) {
      return 0;
    }
    if (value > _sliderMaxMs) {
      return _sliderMaxMs;
    }
    return value;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _log(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[player.page#$_instanceId ${DateTime.now().toIso8601String()}] $message',
    );
  }
}

class _ImmersivePlayerView extends StatefulWidget {
  const _ImmersivePlayerView({
    required this.engine,
    required this.isLoading,
    required this.isPlaying,
    required this.isError,
    required this.animeTitle,
    required this.episodeNumber,
    required this.currentPosition,
    required this.totalDuration,
    required this.sliderValue,
    required this.sliderMax,
    required this.hasMultipleAudio,
    required this.hasSubtitles,
    required this.onTogglePlayPause,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onSeekStart,
    required this.onBack,
    required this.onRetry,
    required this.onOpenEpisodes,
    required this.onQuality,
    required this.onAudio,
    required this.onSubtitle,
    required this.formatDuration,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.activeSkipLabel,
    required this.onSkipSegment,
    required this.isWindowsFullscreen,
    required this.onToggleWindowsFullscreen,
    this.errorMessage,
    this.subtitleViewConfiguration,
    this.episodeTitle,
    this.onVolumeChanged,
    this.onSpeedChanged,
  });

  final MediaKitPlaybackEngine? engine;
  final bool isLoading;
  final bool isPlaying;
  final bool isError;
  final String animeTitle;
  final String episodeNumber;
  final String? episodeTitle;
  final Duration currentPosition;
  final Duration totalDuration;
  final double sliderValue;
  final double sliderMax;
  final bool hasMultipleAudio;
  final bool hasSubtitles;
  final VoidCallback? onTogglePlayPause;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
  final VoidCallback? onSeekStart;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onQuality;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitle;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;
  final String? activeSkipLabel;
  final VoidCallback? onSkipSegment;
  final bool isWindowsFullscreen;
  final VoidCallback? onToggleWindowsFullscreen;
  final String? errorMessage;
  final String Function(Duration) formatDuration;
  final SubtitleViewConfiguration? subtitleViewConfiguration;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<double>? onSpeedChanged;

  @override
  State<_ImmersivePlayerView> createState() => _ImmersivePlayerViewState();
}

class _ImmersivePlayerViewState extends State<_ImmersivePlayerView> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _seekIndicatorVisible = false;
  bool _seekIndicatorForward = true;
  Timer? _seekIndicatorTimer;
  bool _orientationLocked = true;
  double _gestureSeekDeltaSeconds = 0;

  // Volume/brightness gesture overlay state
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  double _brightnessLevel = 0.5;
  double _volumeLevel = 1.0;
  Timer? _overlayHideTimer;
  Offset? _verticalDragStart;
  bool _isVerticalDragBrightness = false;

  // Long-press speed state
  double _speedMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _overlayHideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) _startHideTimer();
    });
  }

  void _showSeekIndicator({required bool isForward}) {
    _seekIndicatorTimer?.cancel();
    setState(() {
      _seekIndicatorVisible = true;
      _seekIndicatorForward = isForward;
    });
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekIndicatorVisible = false);
    });
  }

  void _toggleOrientationLock() {
    setState(() => _orientationLocked = !_orientationLocked);
    if (_orientationLocked) {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _gestureSeekDeltaSeconds += details.delta.dx / 18;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final deltaSeconds = _gestureSeekDeltaSeconds.round();
    _gestureSeekDeltaSeconds = 0;
    if (deltaSeconds.abs() < 3) {
      return;
    }
    if (deltaSeconds > 0) {
      widget.onSkipForward?.call();
      _showSeekIndicator(isForward: true);
    } else {
      widget.onSkipBackward?.call();
      _showSeekIndicator(isForward: false);
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (Platform.isWindows) return;
    final width = MediaQuery.of(context).size.width;
    _verticalDragStart = details.localPosition;
    _isVerticalDragBrightness = details.localPosition.dx < width / 2;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_verticalDragStart == null) return;
    final delta = -details.delta.dy / 200;
    setState(() {
      if (_isVerticalDragBrightness) {
        _brightnessLevel = (_brightnessLevel + delta).clamp(0.0, 1.0);
        _showBrightnessOverlay = true;
      } else {
        _volumeLevel = (_volumeLevel + delta).clamp(0.0, 1.0);
        _showVolumeOverlay = true;
      }
    });
    if (!_isVerticalDragBrightness) {
      widget.onVolumeChanged?.call(_volumeLevel);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _verticalDragStart = null;
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showBrightnessOverlay = false;
          _showVolumeOverlay = false;
        });
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.keyK:
        widget.onTogglePlayPause?.call();
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        widget.onSkipBackward?.call();
        _showSeekIndicator(isForward: false);
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.onSkipForward?.call();
        _showSeekIndicator(isForward: true);
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final newVolUp = (_volumeLevel + 0.1).clamp(0.0, 1.0);
        setState(() {
          _volumeLevel = newVolUp;
          _showVolumeOverlay = true;
        });
        widget.onVolumeChanged?.call(newVolUp);
        _overlayHideTimer?.cancel();
        _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        final newVolDown = (_volumeLevel - 0.1).clamp(0.0, 1.0);
        setState(() {
          _volumeLevel = newVolDown;
          _showVolumeOverlay = true;
        });
        widget.onVolumeChanged?.call(newVolDown);
        _overlayHideTimer?.cancel();
        _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        final newVolMute = _volumeLevel > 0 ? 0.0 : 1.0;
        setState(() {
          _volumeLevel = newVolMute;
          _showVolumeOverlay = true;
        });
        widget.onVolumeChanged?.call(newVolMute);
        _overlayHideTimer?.cancel();
        _overlayHideTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        widget.onToggleWindowsFullscreen?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onBack.call();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    const scale = 1.5;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onLongPressStart: (_) {
          setState(() => _speedMultiplier = 2.0);
          widget.onSpeedChanged?.call(2.0);
        },
        onLongPressEnd: (_) {
          setState(() => _speedMultiplier = 1.0);
          widget.onSpeedChanged?.call(1.0);
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Video layer
            if (widget.engine != null)
              IgnorePointer(
                // media_kit can render through a native surface on some platforms.
                // Keep pointer handling in the Flutter overlay so playback controls
                // remain tappable/clickable for every stream type.
                child: Video(
                  controller: widget.engine!.videoController,
                  controls: NoVideoControls,
                  subtitleViewConfiguration:
                      widget.subtitleViewConfiguration ??
                      const SubtitleViewConfiguration(),
                ),
              )
            else
              const ColoredBox(color: Colors.black),

            // Double-tap seek zones (3 equal thirds)
            Row(
              children: <Widget>[
                // Left 1/3 — double tap skip backward
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                    onDoubleTap: () {
                      widget.onSkipBackward?.call();
                      _showSeekIndicator(isForward: false);
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                // Center 1/3 — single tap only (toggle controls)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                    child: const SizedBox.expand(),
                  ),
                ),
                // Right 1/3 — double tap skip forward
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                    onDoubleTap: () {
                      widget.onSkipForward?.call();
                      _showSeekIndicator(isForward: true);
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

            // Seek indicator
            if (_seekIndicatorVisible)
              Align(
                alignment: _seekIndicatorForward
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: KumoriyaColors.playerControlBg,
                      borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _seekIndicatorForward
                              ? Icons.forward_10_rounded
                              : Icons.replay_10_rounded,
                          color: KumoriyaColors.textPrimary,
                          size: 28 * scale,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _seekIndicatorForward ? '+10s' : '-10s',
                          style: Theme.of(context).textTheme.headlineSmall!
                              .copyWith(color: KumoriyaColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Volume overlay
            if (_showVolumeOverlay)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: _VerticalSliderOverlay(
                    icon: _volumeLevel > 0.5
                        ? Icons.volume_up_rounded
                        : _volumeLevel > 0
                        ? Icons.volume_down_rounded
                        : Icons.volume_off_rounded,
                    value: _volumeLevel,
                    label: '${(_volumeLevel * 100).round()}%',
                  ),
                ),
              ),

            // Brightness overlay
            if (_showBrightnessOverlay)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: _VerticalSliderOverlay(
                    icon: Icons.brightness_6_rounded,
                    value: _brightnessLevel,
                    label: '${(_brightnessLevel * 100).round()}%',
                  ),
                ),
              ),

            // 2× Speed badge
            if (_speedMultiplier > 1.0)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(top: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: KumoriyaColors.playerControlBg,
                      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.fast_forward_rounded,
                          color: KumoriyaColors.textPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_speedMultiplier.toStringAsFixed(0)}×',
                          style: Theme.of(context).textTheme.labelLarge!
                              .copyWith(color: KumoriyaColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Loading overlay
            if (widget.isLoading)
              Container(
                color: KumoriyaColors.scrimLight,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  color: KumoriyaColors.textPrimary,
                ),
              ),

            // Error banner
            if (widget.isError && widget.errorMessage != null)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: KumoriyaColors.statusDanger,
                      borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(color: KumoriyaColors.textPrimary),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: widget.onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: KumoriyaColors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(context.l10n.playerRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Controls overlay (animated)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        KumoriyaColors.scrimHeavy,
                        Colors.transparent,
                        Colors.transparent,
                        KumoriyaColors.scrimHeavy,
                      ],
                      stops: const <double>[0.0, 0.20, 0.70, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: <Widget>[
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            KumoriyaSpacing.md,
                            KumoriyaSpacing.sm,
                            KumoriyaSpacing.md,
                            0,
                          ),
                          child: Row(
                            children: <Widget>[
                              IconButton(
                                onPressed: widget.onBack,
                                tooltip: context.l10n.playerBack,
                                icon: Icon(
                                  KumoriyaIcons.playerBack,
                                  color: KumoriyaColors.textPrimary,
                                  size: 20 * scale,
                                ),
                                iconSize: 20 * scale,
                                padding: const EdgeInsets.all(12),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      widget.animeTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: KumoriyaColors.textSecondary,
                                            shadows: const <Shadow>[
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                    ),
                                    Text(
                                      widget.episodeTitle != null
                                          ? 'EP ${widget.episodeNumber} - ${widget.episodeTitle}'
                                          : 'EP ${widget.episodeNumber}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: KumoriyaColors.textPrimary,
                                            shadows: const <Shadow>[
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: widget.onOpenEpisodes,
                                icon: Icon(
                                  KumoriyaIcons.playerNextEpisode,
                                  color: KumoriyaColors.textPrimary,
                                  size: 20 * scale,
                                ),
                                iconSize: 20 * scale,
                                padding: const EdgeInsets.all(12),
                                tooltip: context.l10n.playerNextEpisode,
                              ),
                              if (Platform.isWindows)
                                IconButton(
                                  onPressed: widget.onToggleWindowsFullscreen,
                                  icon: Icon(
                                    widget.isWindowsFullscreen
                                        ? KumoriyaIcons.playerFullscreenExit
                                        : KumoriyaIcons.playerFullscreen,
                                    color: KumoriyaColors.textPrimary,
                                    size: 20 * scale,
                                  ),
                                  iconSize: 20 * scale,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: widget.isWindowsFullscreen
                                      ? 'Exit fullscreen'
                                      : 'Fullscreen',
                                )
                              else
                                IconButton(
                                  onPressed: _toggleOrientationLock,
                                  icon: Icon(
                                    _orientationLocked
                                        ? Icons.screen_lock_rotation_rounded
                                        : Icons.screen_rotation_rounded,
                                    color: KumoriyaColors.textPrimary,
                                    size: 20 * scale,
                                  ),
                                  iconSize: 20 * scale,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: _orientationLocked
                                      ? context.l10n.playerUnlockRotation
                                      : context.l10n.playerLockRotation,
                                ),
                            ],
                          ),
                        ),

                        // Center play/pause
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _PlayerIconButton(
                              icon: KumoriyaIcons.playerSeekBack10,
                              size: 36 * scale,
                              onTap: widget.onSkipBackward,
                              tooltip: context.l10n.playerSkipBackward,
                            ),
                            const SizedBox(width: KumoriyaSpacing.xxl),
                            _PlayerIconButton(
                              icon: widget.isPlaying
                                  ? KumoriyaIcons.playerPause
                                  : KumoriyaIcons.playerPlay,
                              size: 56 * scale,
                              onTap: widget.onTogglePlayPause,
                              tooltip: widget.isPlaying
                                  ? context.l10n.playerPause
                                  : context.l10n.playerPlay,
                              emphasized: true,
                            ),
                            const SizedBox(width: KumoriyaSpacing.xxl),
                            _PlayerIconButton(
                              icon: KumoriyaIcons.playerSeekForward10,
                              size: 36 * scale,
                              onTap: widget.onSkipForward,
                              tooltip: context.l10n.playerSkipForward,
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Bottom seek bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            KumoriyaSpacing.xl,
                            0,
                            KumoriyaSpacing.xl,
                            KumoriyaSpacing.md,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: KumoriyaColors.surface.withValues(
                                alpha: 0.78,
                              ),
                              borderRadius: BorderRadius.circular(
                                KumoriyaRadius.xl,
                              ),
                              border: Border.all(
                                color: KumoriyaColors.borderMedium,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                KumoriyaSpacing.lg,
                                KumoriyaSpacing.sm,
                                KumoriyaSpacing.lg,
                                KumoriyaSpacing.md,
                              ),
                              child: Column(
                                children: <Widget>[
                                  Wrap(
                                    spacing: KumoriyaSpacing.sm,
                                    runSpacing: KumoriyaSpacing.sm,
                                    alignment: WrapAlignment.center,
                                    children: <Widget>[
                                      _PlayerQuickActionChip(
                                        label: context.l10n.playerQuality,
                                        icon: KumoriyaIcons.playerQuality,
                                        onTap: widget.onQuality,
                                      ),
                                      if (widget.hasSubtitles)
                                        _PlayerQuickActionChip(
                                          label: context.l10n.playerSubtitles,
                                          icon: KumoriyaIcons.playerSubtitle,
                                          onTap: widget.onSubtitle,
                                        ),
                                      if (widget.hasMultipleAudio)
                                        _PlayerQuickActionChip(
                                          label: context.l10n.playerAudio,
                                          icon: KumoriyaIcons.playerAudio,
                                          onTap: widget.onAudio,
                                        ),
                                    ],
                                  ),
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 7,
                                      ),
                                      activeTrackColor: KumoriyaColors.primary,
                                      inactiveTrackColor: KumoriyaColors
                                          .textPrimary
                                          .withValues(alpha: 0.30),
                                      thumbColor: KumoriyaColors.primaryLight,
                                      overlayColor: KumoriyaColors.primary
                                          .withValues(alpha: 0.15),
                                    ),
                                    child: Slider(
                                      value: widget.sliderValue,
                                      max: widget.sliderMax,
                                      onChangeStart: (_) {
                                        _hideTimer?.cancel();
                                        widget.onSeekStart?.call();
                                      },
                                      onChanged: widget.onSeekChanged,
                                      onChangeEnd: (value) {
                                        widget.onSeekEnd?.call(value);
                                        _startHideTimer();
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: KumoriyaSpacing.xs,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Text(
                                          widget.formatDuration(
                                            widget.currentPosition,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium!
                                              .copyWith(
                                                color:
                                                    KumoriyaColors.textPrimary,
                                              ),
                                        ),
                                        Text(
                                          widget.formatDuration(
                                            widget.totalDuration,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium!
                                              .copyWith(
                                                color:
                                                    KumoriyaColors.textPrimary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (widget.activeSkipLabel != null && widget.onSkipSegment != null)
              Align(
                alignment: Alignment.bottomRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, bottom: 92),
                    child: FilledButton.icon(
                      onPressed: widget.onSkipSegment,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text(widget.activeSkipLabel!),
                      style: FilledButton.styleFrom(
                        backgroundColor: KumoriyaColors.primaryDark,
                        foregroundColor: KumoriyaColors.textPrimary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.emphasized = false,
    this.tooltip,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool emphasized;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget child = Material(
      color: emphasized
          ? KumoriyaColors.primary.withValues(alpha: 0.92)
          : KumoriyaColors.playerControlBg,
      shape: const CircleBorder(),
      elevation: emphasized ? 8 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: emphasized
            ? KumoriyaColors.primaryLight.withValues(alpha: 0.35)
            : KumoriyaColors.primary.withValues(alpha: 0.20),
        onTap: onTap,
        child: SizedBox(
          width: size + 16,
          height: size + 16,
          child: Center(
            child: Icon(icon, color: KumoriyaColors.textPrimary, size: size),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class _VerticalSliderOverlay extends StatelessWidget {
  const _VerticalSliderOverlay({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: KumoriyaColors.playerControlBg,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: KumoriyaColors.textPrimary, size: 20),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: -1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: KumoriyaColors.textPrimary.withValues(
                    alpha: 0.30,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    KumoriyaColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: KumoriyaColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _PlayerQuickActionChip extends StatelessWidget {
  const _PlayerQuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KumoriyaColors.primarySurface10,
      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KumoriyaSpacing.md,
            vertical: KumoriyaSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: KumoriyaColors.textPrimary),
              const SizedBox(width: KumoriyaSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: KumoriyaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSelectorSheet extends StatelessWidget {
  const _PlayerSelectorSheet({
    required this.title,
    required this.icon,
    required this.options,
  });

  final String title;
  final IconData icon;
  final List<_PlayerSelectorOption> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KumoriyaSpacing.md,
          KumoriyaSpacing.md,
          KumoriyaSpacing.md,
          KumoriyaSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KumoriyaColors.surface,
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(color: KumoriyaColors.borderMedium),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: KumoriyaSpacing.sm),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KumoriyaColors.textDisabled,
                    borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KumoriyaSpacing.lg,
                    KumoriyaSpacing.md,
                    KumoriyaSpacing.lg,
                    KumoriyaSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: KumoriyaColors.primarySurface20,
                          borderRadius: BorderRadius.circular(
                            KumoriyaRadius.md,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: KumoriyaColors.textPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: KumoriyaSpacing.sm),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: KumoriyaSpacing.sm,
                      vertical: KumoriyaSpacing.sm,
                    ),
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: KumoriyaSpacing.xs),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return Material(
                        color: option.selected
                            ? KumoriyaColors.primarySurface20
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              KumoriyaRadius.lg,
                            ),
                            side: BorderSide(
                              color: option.selected
                                  ? KumoriyaColors.primaryBorder30
                                  : Colors.transparent,
                            ),
                          ),
                          leading: Icon(option.icon),
                          title: Text(option.title),
                          subtitle: option.subtitle != null
                              ? Text(option.subtitle!)
                              : null,
                          trailing: option.selected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            option.onTap();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSelectorOption {
  const _PlayerSelectorOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
}
