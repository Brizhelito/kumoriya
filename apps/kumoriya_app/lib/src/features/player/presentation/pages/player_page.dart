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
    required this.sourcePluginId,
    required this.serverName,
    this.persistSelection = true,
    this.preferredAudioPreference,
    required this.resolved,
  });

  final int anilistId;
  final String animeTitle;
  final String episodeNumber;
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
  late final String _instanceId = identityHashCode(this).toRadixString(16);

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
    // Restore normal orientation and system UI.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
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
      return 'Next episode';
    }
    return switch (segment.kind) {
      AniSkipSegmentKind.opening => 'Skip intro',
      AniSkipSegmentKind.ending => 'Skip credits',
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
        Scaffold(
          appBar: AppBar(title: Text(context.l10n.playerTitle)),
          body: ErrorStateView(message: _startError!, onRetry: _retryPlayback),
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
        body: _ImmersivePlayerView(
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
            unawaited(_seekTo(target < Duration.zero ? Duration.zero : target));
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

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final stream = items[index];
              final selected =
                  _state.selectedStream?.url.toString() ==
                  stream.url.toString();
              final label =
                  stream.qualityLabel ??
                  '${context.l10n.playerQuality} ${index + 1}';
              return ListTile(
                title: Text(label),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(orchestrator.selectQualityByIndex(index));
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAudioTrackPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) return;
    final tracks = _embeddedTracks.audio;
    if (tracks.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.playerAudio,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...tracks.map(
                (track) => ListTile(
                  leading: const Icon(Icons.audiotrack),
                  title: Text(track.displayLabel),
                  subtitle: track.language != null
                      ? Text(track.language!)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(orchestrator.selectEmbeddedAudioTrack(track));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSubtitleTrackPicker(BuildContext context) async {
    final orchestrator = _orchestrator;
    if (orchestrator == null) return;
    final embeddedTracks = _embeddedTracks.subtitle;
    final externalTracks = orchestrator.externalSubtitleTracks;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.playerSubtitles,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_off),
                title: Text(context.l10n.playerDisableSubtitles),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(orchestrator.clearExternalSubtitleTrack());
                  unawaited(orchestrator.clearEmbeddedSubtitleTrack());
                },
              ),
              ...externalTracks.map(
                (track) => ListTile(
                  leading: const Icon(Icons.closed_caption_rounded),
                  title: Text(track.label),
                  subtitle: track.language != null
                      ? Text(track.language!)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(orchestrator.selectExternalSubtitleTrack(track));
                  },
                ),
              ),
              ...embeddedTracks.map(
                (track) => ListTile(
                  leading: const Icon(Icons.subtitles),
                  title: Text(track.displayLabel),
                  subtitle: track.language != null
                      ? Text(track.language!)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(orchestrator.selectEmbeddedSubtitleTrack(track));
                  },
                ),
              ),
            ],
          ),
        );
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
  });

  final MediaKitPlaybackEngine? engine;
  final bool isLoading;
  final bool isPlaying;
  final bool isError;
  final String animeTitle;
  final String episodeNumber;
  final Duration currentPosition;
  final Duration totalDuration;
  final double sliderValue;
  final double sliderMax;
  final bool hasMultipleAudio;
  final bool hasSubtitles;
  final VoidCallback? onTogglePlayPause;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
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

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    const scale = 1.5;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
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

          // Double-tap seek zones
          Row(
            children: <Widget>[
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
                    color: Colors.black.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _seekIndicatorForward
                            ? Icons.forward_10_rounded
                            : Icons.replay_10_rounded,
                        color: Colors.white,
                        size: 28 * scale,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _seekIndicatorForward ? '+10s' : '-10s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
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
              child: const CircularProgressIndicator(color: Colors.white),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.onRetry,
                        child: Text(
                          context.l10n.playerRetry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Controls overlay (animated)
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xAA000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                    stops: <double>[0.0, 0.25, 0.65, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: <Widget>[
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: widget.onBack,
                              tooltip: context.l10n.playerBack,
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20 * scale,
                              ),
                              iconSize: 20 * scale,
                              padding: const EdgeInsets.all(12),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.animeTitle} - EP ${widget.episodeNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onOpenEpisodes,
                              icon: Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                                size: 20 * scale,
                              ),
                              iconSize: 20 * scale,
                              padding: const EdgeInsets.all(12),
                              tooltip: context.l10n.playerNextEpisode,
                            ),
                            if (widget.hasMultipleAudio)
                              IconButton(
                                onPressed: widget.onAudio,
                                icon: Icon(
                                  Icons.audiotrack_rounded,
                                  color: Colors.white,
                                  size: 20 * scale,
                                ),
                                iconSize: 20 * scale,
                                padding: const EdgeInsets.all(12),
                                tooltip: context.l10n.playerAudio,
                              ),
                            if (widget.hasSubtitles)
                              IconButton(
                                onPressed: widget.onSubtitle,
                                icon: Icon(
                                  Icons.subtitles_rounded,
                                  color: Colors.white,
                                  size: 20 * scale,
                                ),
                                iconSize: 20 * scale,
                                padding: const EdgeInsets.all(12),
                                tooltip: context.l10n.playerSubtitles,
                              ),
                            IconButton(
                              onPressed: widget.onQuality,
                              icon: Icon(
                                Icons.hd_rounded,
                                color: Colors.white,
                                size: 20 * scale,
                              ),
                              iconSize: 20 * scale,
                              padding: const EdgeInsets.all(12),
                              tooltip: context.l10n.playerQuality,
                            ),
                            if (Platform.isWindows)
                              IconButton(
                                onPressed: widget.onToggleWindowsFullscreen,
                                icon: Icon(
                                  widget.isWindowsFullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                  color: Colors.white,
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
                                  color: Colors.white,
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
                            icon: Icons.replay_10_rounded,
                            size: 36 * scale,
                            onTap: widget.onSkipBackward,
                            tooltip: context.l10n.playerSkipBackward,
                          ),
                          const SizedBox(width: 40),
                          _PlayerIconButton(
                            icon: widget.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 56 * scale,
                            onTap: widget.onTogglePlayPause,
                            tooltip: widget.isPlaying
                                ? context.l10n.playerPause
                                : context.l10n.playerPlay,
                          ),
                          const SizedBox(width: 40),
                          _PlayerIconButton(
                            icon: Icons.forward_10_rounded,
                            size: 36 * scale,
                            onTap: widget.onSkipForward,
                            tooltip: context.l10n.playerSkipForward,
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Bottom seek bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          children: <Widget>[
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 9,
                                ),
                                activeTrackColor: KumoriyaColors.primary,
                                inactiveTrackColor: Colors.white.withValues(
                                  alpha: 0.20,
                                ),
                                thumbColor: KumoriyaColors.primary,
                                overlayColor: KumoriyaColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: Slider(
                                value: widget.sliderValue,
                                max: widget.sliderMax,
                                onChanged: widget.onSeekChanged,
                                onChangeEnd: widget.onSeekEnd,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    widget.formatDuration(
                                      widget.currentPosition,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    widget.formatDuration(widget.totalDuration),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
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
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.40),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
