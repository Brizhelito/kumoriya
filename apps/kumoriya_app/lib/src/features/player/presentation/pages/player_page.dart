import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
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
import '../../application/models/player_diagnostics.dart';
import '../../../anime_catalog/application/services/mal_metadata_bridge_service.dart';
import '../../application/models/player_session_state.dart';
import '../../application/services/player_session_orchestrator.dart';
import '../../application/use_cases/clear_playback_preference_use_case.dart';
import '../../application/use_cases/save_playback_preference_use_case.dart';
import '../../application/use_cases/save_progress_use_case.dart';
import '../../infrastructure/media_kit_playback_engine.dart';
import '../widgets/player_debug_overlay.dart';

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
  bool _autoSkipEnabled = false; // TODO: persist via settings store
  List<AniSkipSegment> _aniSkipSegments = const <AniSkipSegment>[];
  Future<void>? _pendingAniSkipLoad;
  final Set<String> _autoSkippedSegments = <String>{};

  PlayerSessionState _state = const PlayerSessionState.idle();
  String? _startError;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration? _resumePosition;
  DateTime _lastPositionSetState = DateTime(0);
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
  static bool _suppressOrientationRestore = false;

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
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = null;
    if (!_suppressOrientationRestore) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    }
    _suppressOrientationRestore = false;
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
      final now = DateTime.now();
      if (now.difference(_lastPositionSetState).inMilliseconds >= 500) {
        _lastPositionSetState = now;
        setState(() => _currentPosition = pos);
      } else {
        _currentPosition = pos;
      }
      if (_autoSkipEnabled) {
        _maybeAutoSkipSegment();
      }
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

  // Cache the last found segment to avoid re-scanning on consecutive calls
  // at the same position. Cleared when segments list changes.
  AniSkipSegment? _cachedActiveSegment;
  int _cachedSegmentPositionSec = -1;

  AniSkipSegment? get _activeAniSkipSegment {
    if (_aniSkipSegments.isEmpty || _currentDuration <= Duration.zero) {
      return null;
    }
    // Fast path: if position (rounded to seconds) hasn't changed, reuse cache.
    final posSec = _currentPosition.inSeconds;
    if (posSec == _cachedSegmentPositionSec && _cachedActiveSegment != null) {
      // Verify cached segment is still valid (could have exited its range).
      final seg = _cachedActiveSegment!;
      final guardStart = seg.start - const Duration(seconds: 1);
      final effectiveStart = guardStart > Duration.zero
          ? guardStart
          : Duration.zero;
      if (_currentPosition >= effectiveStart && _currentPosition < seg.end) {
        return seg;
      }
    }
    _cachedSegmentPositionSec = posSec;
    for (final segment in _aniSkipSegments) {
      final guardStart = segment.start - const Duration(seconds: 1);
      final effectiveStart = guardStart > Duration.zero
          ? guardStart
          : Duration.zero;
      if (_currentPosition >= effectiveStart &&
          _currentPosition < segment.end) {
        _cachedActiveSegment = segment;
        return segment;
      }
    }
    _cachedActiveSegment = null;
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

  void _maybeAutoSkipSegment() {
    final segment = _activeAniSkipSegment;
    if (segment == null) return;

    // Only auto-skip once per segment window.
    final segmentKey = '${segment.kind}_${segment.start.inMilliseconds}';
    if (_autoSkippedSegments.contains(segmentKey)) return;
    _autoSkippedSegments.add(segmentKey);

    final target = segment.end + const Duration(milliseconds: 300);
    final maxTarget = _currentDuration > const Duration(seconds: 1)
        ? _currentDuration - const Duration(seconds: 1)
        : _currentDuration;
    final clamped = target > maxTarget ? maxTarget : target;

    _log('auto-skip segment kind=${segment.kind} target=$clamped');
    unawaited(_seekTo(clamped));

    if (mounted) {
      final label = segment.kind == AniSkipSegmentKind.opening
          ? 'Skipped Intro'
          : 'Skipped Credits';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 200,
        ),
      );
    }
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
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
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
      if (before != true) {
        await windowManager.setFullScreen(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
    } catch (_) {}
  }

  Future<void> _toggleWindowsFullscreen() async {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }
    try {
      final current = await windowManager.isFullScreen();
      final target = !current;
      if (target) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      await windowManager.setFullScreen(target);
      if (!target) {
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
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
    // Prevent position listeners from triggering further auto-next while
    // the pushReplacement is in-flight.
    _isExiting = true;
    _autoNextTriggeredByEndingResidual = true;
    await _positionSub?.cancel();
    await _completionSub?.cancel();
    _positionSub = null;
    _completionSub = null;
    // Keep the player locked while replacing this page with the next player
    // instance, avoiding an intermediate orientation/UI transition.
    _orientationRestoreTimer?.cancel();
    _orientationRestoreTimer = null;
    _suppressOrientationRestore = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: widget.anilistId,
          animeTitle: widget.animeTitle,
          episodeNumber: nextEpisodeNumber.toString(),
          episodeTitle: downloadTask.episodeTitle,
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

  Future<void> _openPreviousEpisode() async {
    final currentEpisode = int.tryParse(widget.episodeNumber);
    if (currentEpisode == null || currentEpisode <= 1) {
      return;
    }
    if (_state.status == PlayerSessionStatus.playing) {
      await _orchestrator?.togglePlayPause();
    }
    final prevEpisodeNumber = currentEpisode - 1;
    // Check for downloaded previous episode first
    final downloadTask = await ref
        .read(downloadManagerProvider)
        .findTaskByEpisode(widget.anilistId, prevEpisodeNumber.toDouble());
    if (downloadTask != null &&
        downloadTask.status == DownloadStatus.completed &&
        downloadTask.filePath != null &&
        downloadTask.filePath!.trim().isNotEmpty) {
      final file = File(downloadTask.filePath!);
      if (await file.exists() && mounted) {
        _isExiting = true;
        await _positionSub?.cancel();
        await _completionSub?.cancel();
        _positionSub = null;
        _completionSub = null;
        _orientationRestoreTimer?.cancel();
        _orientationRestoreTimer = null;
        _suppressOrientationRestore = true;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PlayerPage(
              anilistId: widget.anilistId,
              animeTitle: widget.animeTitle,
              episodeNumber: prevEpisodeNumber.toString(),
              episodeTitle: downloadTask.episodeTitle,
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
        return;
      }
    }
    // Fall back to episode list focused on previous episode
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeListPage(
          anilistId: widget.anilistId,
          animeTitle: widget.animeTitle,
          focusedEpisodeNumber: prevEpisodeNumber.toDouble(),
        ),
      ),
    );
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

    final subtitleConfig = ref.watch(
      subtitleSettingsProvider.select((s) => s.value),
    );

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
            onPreviousEpisode: (int.tryParse(widget.episodeNumber) ?? 0) > 1
                ? () => unawaited(_openPreviousEpisode())
                : null,
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
            onSeekByDelta: (target) => unawaited(_seekTo(target)),
            activeSkipLabel: _autoSkipEnabled ? null : _activeAniSkipLabel,
            onSkipSegment: () => unawaited(_skipActiveSegment()),
            autoSkipEnabled: _autoSkipEnabled,
            showFallbackSkip:
                _aniSkipSegments.isEmpty ||
                !_aniSkipSegments.any(
                  (s) => s.kind == AniSkipSegmentKind.opening,
                ),
            onFallbackSkip: () {
              final fallback = _currentPosition + const Duration(seconds: 90);
              final maxPos = _currentDuration > const Duration(seconds: 1)
                  ? _currentDuration - const Duration(seconds: 1)
                  : _currentDuration;
              final target = fallback > maxPos ? maxPos : fallback;
              unawaited(_seekTo(target));
            },
            onAutoSkipToggled: () {
              setState(() => _autoSkipEnabled = !_autoSkipEnabled);
            },
            isWindowsFullscreen: _isWindowsFullscreen,
            onToggleWindowsFullscreen: () =>
                unawaited(_toggleWindowsFullscreen()),
            errorMessage: _state.status == PlayerSessionStatus.error
                ? context.l10n.playerAllCandidatesFailed
                : null,
            formatDuration: _formatDuration,
            subtitleViewConfiguration: subtitleConfig?.toViewConfiguration(),
            episodeTitle: widget.episodeTitle,
            onVolumeChanged: (vol) {
              _engine?.player.setVolume(vol * 100);
              VolumeController.instance.setVolume(vol.clamp(0.0, 1.0));
              // Activate smart audio boost (dynamic normalization) when
              // volume exceeds 100 % so the boost raises dialogue clarity
              // instead of hard-clipping all frequencies.
              _engine?.setSmartAudioBoost(enabled: vol > 1.0);
            },
            onBrightnessChanged: (brightness) {
              unawaited(
                ScreenBrightness().setApplicationScreenBrightness(brightness),
              );
            },
            onSpeedChanged: (speed) => _engine?.player.setRate(speed),
            diagnosticsStream: engine?.diagnosticsStream,
            seekLatencyMs: _orchestrator?.lastSeekLatencyMs,
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
        _PlayerSelectorOption(
          icon: Icons.tune_rounded,
          title: context.l10n.playerSubtitleStyle,
          subtitle: context.l10n.playerSubtitleStyleDescription,
          selected: false,
          onTap: () => unawaited(_showSubtitleStyleSheet(context)),
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

  Future<void> _showSubtitleStyleSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final settings =
                ref.watch(subtitleSettingsProvider).value ??
                const SubtitleSettings();
            final notifier = ref.read(subtitleSettingsProvider.notifier);

            Widget buildColorDot({
              required Color color,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? KumoriyaColors.primary
                          : KumoriyaColors.borderSubtle,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: color.computeLuminance() > 0.7
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: KumoriyaSpacing.md,
                  right: KumoriyaSpacing.md,
                  top: KumoriyaSpacing.md,
                  bottom:
                      MediaQuery.of(sheetContext).viewInsets.bottom +
                      KumoriyaSpacing.lg,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KumoriyaColors.surface,
                    borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
                    border: Border.all(color: KumoriyaColors.borderMedium),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 720),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        KumoriyaSpacing.lg,
                        KumoriyaSpacing.lg,
                        KumoriyaSpacing.lg,
                        KumoriyaSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
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
                                child: const Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: KumoriyaColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      context.l10n.playerSubtitleStyle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context
                                          .l10n
                                          .playerSubtitleStyleDescription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: KumoriyaColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            context.l10n.settingsSubtitleFontSize,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          SegmentedButton<SubtitleFontSize>(
                            segments: <ButtonSegment<SubtitleFontSize>>[
                              ButtonSegment(
                                value: SubtitleFontSize.small,
                                label: Text(context.l10n.settingsSubtitleSmall),
                              ),
                              ButtonSegment(
                                value: SubtitleFontSize.medium,
                                label: Text(
                                  context.l10n.settingsSubtitleMedium,
                                ),
                              ),
                              ButtonSegment(
                                value: SubtitleFontSize.large,
                                label: Text(context.l10n.settingsSubtitleLarge),
                              ),
                              ButtonSegment(
                                value: SubtitleFontSize.extraLarge,
                                label: Text(
                                  context.l10n.settingsSubtitleExtraLarge,
                                ),
                              ),
                            ],
                            selected: <SubtitleFontSize>{settings.fontSize},
                            onSelectionChanged: (selection) {
                              notifier.save(
                                (current) =>
                                    current.copyWith(fontSize: selection.first),
                              );
                            },
                          ),
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            context.l10n.settingsSubtitleFontColor,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          Wrap(
                            spacing: KumoriyaSpacing.sm,
                            runSpacing: KumoriyaSpacing.sm,
                            children: SubtitleFontColor.values
                                .map(
                                  (color) => buildColorDot(
                                    color: color.color,
                                    selected: settings.fontColor == color,
                                    onTap: () => notifier.save(
                                      (current) =>
                                          current.copyWith(fontColor: color),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            '${context.l10n.settingsSubtitleFontOpacity} ${(settings.fontOpacity * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Slider(
                            value: settings.fontOpacity,
                            min: 0.25,
                            max: 1.0,
                            divisions: 3,
                            onChanged: (value) {
                              notifier.save(
                                (current) =>
                                    current.copyWith(fontOpacity: value),
                              );
                            },
                          ),
                          Text(
                            context.l10n.settingsSubtitleBgColor,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          SegmentedButton<SubtitleBackgroundColor>(
                            segments: <ButtonSegment<SubtitleBackgroundColor>>[
                              ButtonSegment(
                                value: SubtitleBackgroundColor.black,
                                label: Text(
                                  context.l10n.settingsSubtitleBgBlack,
                                ),
                              ),
                              ButtonSegment(
                                value: SubtitleBackgroundColor.darkGray,
                                label: Text(
                                  context.l10n.settingsSubtitleBgDarkGray,
                                ),
                              ),
                              ButtonSegment(
                                value: SubtitleBackgroundColor.transparent,
                                label: Text(
                                  context.l10n.settingsSubtitleBgNone,
                                ),
                              ),
                            ],
                            selected: <SubtitleBackgroundColor>{
                              settings.backgroundColor,
                            },
                            onSelectionChanged: (selection) {
                              notifier.save(
                                (current) => current.copyWith(
                                  backgroundColor: selection.first,
                                ),
                              );
                            },
                          ),
                          if (settings.backgroundColor !=
                              SubtitleBackgroundColor.transparent) ...<Widget>[
                            const SizedBox(height: KumoriyaSpacing.lg),
                            Text(
                              '${context.l10n.settingsSubtitleBgOpacity} ${(settings.backgroundOpacity * 100).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Slider(
                              value: settings.backgroundOpacity,
                              min: 0.0,
                              max: 1.0,
                              divisions: 4,
                              onChanged: (value) {
                                notifier.save(
                                  (current) => current.copyWith(
                                    backgroundOpacity: value,
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: KumoriyaSpacing.lg),
                          Text(
                            context.l10n.settingsSubtitleEdgeStyle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: KumoriyaSpacing.sm),
                          Wrap(
                            spacing: KumoriyaSpacing.sm,
                            runSpacing: KumoriyaSpacing.sm,
                            children: SubtitleEdgeStyle.values
                                .map((style) {
                                  final label = switch (style) {
                                    SubtitleEdgeStyle.none =>
                                      context.l10n.settingsSubtitleEdgeNone,
                                    SubtitleEdgeStyle.outline =>
                                      context.l10n.settingsSubtitleEdgeOutline,
                                    SubtitleEdgeStyle.dropShadow =>
                                      context
                                          .l10n
                                          .settingsSubtitleEdgeDropShadow,
                                    SubtitleEdgeStyle.raised =>
                                      context.l10n.settingsSubtitleEdgeRaised,
                                    SubtitleEdgeStyle.depressed =>
                                      context
                                          .l10n
                                          .settingsSubtitleEdgeDepressed,
                                  };
                                  return ChoiceChip(
                                    label: Text(label),
                                    selected: settings.edgeStyle == style,
                                    onSelected: (_) {
                                      notifier.save(
                                        (current) =>
                                            current.copyWith(edgeStyle: style),
                                      );
                                    },
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
    this.onPreviousEpisode,
    required this.onQuality,
    required this.onAudio,
    required this.onSubtitle,
    required this.formatDuration,
    required this.onSkipBackward,
    required this.onSkipForward,
    this.onSeekByDelta,
    required this.activeSkipLabel,
    required this.onSkipSegment,
    required this.autoSkipEnabled,
    this.onAutoSkipToggled,
    this.showFallbackSkip = false,
    this.onFallbackSkip,
    required this.isWindowsFullscreen,
    required this.onToggleWindowsFullscreen,
    this.errorMessage,
    this.subtitleViewConfiguration,
    this.episodeTitle,
    this.onVolumeChanged,
    this.onBrightnessChanged,
    this.onSpeedChanged,
    this.diagnosticsStream,
    this.seekLatencyMs,
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
  final VoidCallback? onPreviousEpisode;
  final VoidCallback onQuality;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitle;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;
  final ValueChanged<Duration>? onSeekByDelta;
  final String? activeSkipLabel;
  final VoidCallback? onSkipSegment;
  final bool autoSkipEnabled;
  final VoidCallback? onAutoSkipToggled;
  final bool showFallbackSkip;
  final VoidCallback? onFallbackSkip;
  final bool isWindowsFullscreen;
  final VoidCallback? onToggleWindowsFullscreen;
  final String? errorMessage;
  final String Function(Duration) formatDuration;
  final SubtitleViewConfiguration? subtitleViewConfiguration;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onSpeedChanged;
  final Stream<PlayerDiagnostics>? diagnosticsStream;
  final int? seekLatencyMs;

  @override
  State<_ImmersivePlayerView> createState() => _ImmersivePlayerViewState();
}

class _ImmersivePlayerViewState extends State<_ImmersivePlayerView>
    with SingleTickerProviderStateMixin {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _seekIndicatorVisible = false;
  bool _seekIndicatorForward = true;
  Timer? _seekIndicatorTimer;

  // Accumulated seek state: taps add ±10s, commit after idle.
  int _pendingSeekSeconds = 0;
  Timer? _seekCommitTimer;
  static const Duration _seekCommitDelay = Duration(milliseconds: 800);
  bool _orientationLocked = true;
  bool _isDragSeeking = false;
  double _dragSeekAccumulatedDx = 0;
  Duration _dragSeekTargetPosition = Duration.zero;
  DateTime _lastDragSetState = DateTime(2000);
  Timer? _mouseIdleTimer;
  bool _skipButtonVisible = true;
  Timer? _skipButtonHideTimer;
  late final AnimationController _skipProgressController;
  String? _lastSkipLabel;

  // Double-tap seek state
  Timer? _doubleTapTimer;
  int _lastTapZone = -1;

  // Rapid-seek state: after a double-tap seek, subsequent taps in the same
  // zone within _rapidSeekWindow keep seeking without the 200 ms wait.
  bool _inRapidSeekMode = false;
  Timer? _rapidSeekTimer;
  static const Duration _rapidSeekWindow = Duration(seconds: 1);

  // Brightness restore
  double? _initialBrightness;

  // Controls lock
  bool _controlsLocked = false;

  // Volume/brightness gesture overlay state
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  double _brightnessLevel = 0.5;
  double _volumeLevel = 1.0;
  Timer? _overlayHideTimer;
  Offset? _verticalDragStart;
  bool _isVerticalDragBrightness = false;

  // Long-press speed state
  double _baseSpeed = 1.0;
  double _speedMultiplier = 1.0;

  // Player HUD status indicators
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _skipProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
      value: 1.0,
    );
    unawaited(_initBrightness());
    unawaited(_initVolume());
    _startClockTicker();
    _startHideTimer();
  }

  void _startClockTicker() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ImmersivePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Track skip label changes for auto-hide behavior.
    if (widget.activeSkipLabel != null &&
        widget.activeSkipLabel != _lastSkipLabel) {
      _lastSkipLabel = widget.activeSkipLabel;
      setState(() {
        _skipButtonVisible = true;
      });
      _skipButtonHideTimer?.cancel();
      _skipProgressController.value = 1.0;
      _skipProgressController.reverse();

      _skipButtonHideTimer = Timer(const Duration(seconds: 5), () {
        _skipProgressController.stop();
        if (mounted) setState(() => _skipButtonVisible = false);
      });
    } else if (widget.activeSkipLabel == null) {
      _lastSkipLabel = null;
      _skipButtonHideTimer?.cancel();
      _skipProgressController.stop();
      _skipProgressController.value = 1.0;
      _skipButtonVisible = true;
    }
  }

  Future<void> _initBrightness() async {
    try {
      final current = await ScreenBrightness().application;
      _initialBrightness = current;
      if (mounted) {
        setState(() => _brightnessLevel = current);
      }
    } catch (_) {}
  }

  Future<void> _initVolume() async {
    try {
      VolumeController.instance.showSystemUI = false;
      final current = await VolumeController.instance.getVolume();
      if (mounted) {
        setState(() => _volumeLevel = current);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _seekCommitTimer?.cancel();
    _overlayHideTimer?.cancel();
    _mouseIdleTimer?.cancel();
    _skipButtonHideTimer?.cancel();
    _clockTimer?.cancel();
    _skipProgressController.dispose();
    _doubleTapTimer?.cancel();
    _rapidSeekTimer?.cancel();
    if (_initialBrightness != null) {
      unawaited(
        ScreenBrightness().setApplicationScreenBrightness(_initialBrightness!),
      );
    }
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isDragSeeking) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.isPlaying && !_isDragSeeking) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsLocked) return;
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) _startHideTimer();
    });
  }

  int _zoneFromPosition(Offset localPosition) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 0) return 1;
    final third = width / 3;
    if (localPosition.dx < third) return 0;
    if (localPosition.dx < third * 2) return 1;
    return 2;
  }

  void _onTapUp(TapUpDetails details) {
    if (_controlsLocked) return;
    final zone = _zoneFromPosition(details.localPosition);
    _handleTapInZone(zone);
  }

  void _handleTapInZone(int zone) {
    if (_controlsLocked) return;

    // During rapid-seek mode every side tap acts like a seek button press.
    // This keeps repeated taps responsive and avoids falling back to toggle.
    if (_inRapidSeekMode && (zone == 0 || zone == 2)) {
      _rapidSeekTimer?.cancel();
      setState(() {
        _lastTapZone = zone;
      });
      _performSeekForZone(zone);
      _rapidSeekTimer = Timer(_rapidSeekWindow, _exitRapidSeekMode);
      return;
    }

    // ── Double-tap detection ──
    if (_doubleTapTimer?.isActive == true && _lastTapZone == zone) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
      if (zone == 0 || zone == 2) {
        _performSeekForZone(zone);
        _enterRapidSeekMode(zone);
      } else if (zone == 1 && !kIsWeb && Platform.isWindows) {
        widget.onToggleWindowsFullscreen?.call();
      }
    } else {
      _doubleTapTimer?.cancel();
      _exitRapidSeekMode();
      setState(() {
        _lastTapZone = zone;
      });
      _doubleTapTimer = Timer(const Duration(milliseconds: 200), () {
        _doubleTapTimer = null;
        _toggleControls();
      });
    }
  }

  void _performSeekForZone(int zone) {
    if (zone == 0) {
      _accumulateSeek(-10);
      return;
    }
    if (zone == 2) {
      _accumulateSeek(10);
    }
  }

  void _accumulateSeek(int deltaSeconds) {
    _seekCommitTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    setState(() {
      _pendingSeekSeconds += deltaSeconds;
      _seekIndicatorForward = _pendingSeekSeconds >= 0;
      _seekIndicatorVisible = true;
    });
    _seekCommitTimer = Timer(_seekCommitDelay, _commitPendingSeek);
  }

  void _commitPendingSeek() {
    if (!mounted || _pendingSeekSeconds == 0) {
      _hidePendingSeekIndicator();
      return;
    }
    final delta = _pendingSeekSeconds;
    _pendingSeekSeconds = 0;
    if (delta > 0) {
      // Forward seek
      final maxPos = widget.totalDuration - const Duration(seconds: 1);
      final target = widget.currentPosition + Duration(seconds: delta);
      widget.onSeekByDelta?.call(
        target > maxPos && maxPos > Duration.zero ? maxPos : target,
      );
    } else {
      // Backward seek
      final target = widget.currentPosition + Duration(seconds: delta);
      widget.onSeekByDelta?.call(
        target < Duration.zero ? Duration.zero : target,
      );
    }
    // Hide indicator after a short delay so user sees the final value.
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 400), () {
      _hidePendingSeekIndicator();
    });
  }

  void _hidePendingSeekIndicator() {
    if (!mounted) return;
    setState(() {
      _seekIndicatorVisible = false;
      _pendingSeekSeconds = 0;
    });
  }

  void _enterRapidSeekMode(int zone) {
    setState(() {
      _inRapidSeekMode = true;
      _lastTapZone = zone;
    });
    _rapidSeekTimer?.cancel();
    _rapidSeekTimer = Timer(_rapidSeekWindow, _exitRapidSeekMode);
  }

  void _exitRapidSeekMode() {
    if (mounted && _inRapidSeekMode) {
      setState(() {
        _inRapidSeekMode = false;
      });
    } else {
      _inRapidSeekMode = false;
    }
    _rapidSeekTimer?.cancel();
    _rapidSeekTimer = null;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_controlsLocked) return;
    if (Platform.isWindows) return;
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
    _exitRapidSeekMode();
    _hideTimer?.cancel();
    setState(() {
      _isDragSeeking = true;
      _controlsVisible = true;
      _dragSeekAccumulatedDx = 0;
      _dragSeekTargetPosition = widget.currentPosition;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_controlsLocked) return;
    if (!_isDragSeeking) return;

    _dragSeekAccumulatedDx += details.delta.dx;
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 0) return;
    final ratio = _dragSeekAccumulatedDx / (screenWidth * 2.5);
    final seekDeltaMs = (ratio * widget.totalDuration.inMilliseconds).round();
    final target = Duration(
      milliseconds: (widget.currentPosition.inMilliseconds + seekDeltaMs).clamp(
        0,
        widget.totalDuration.inMilliseconds,
      ),
    );

    // Throttle setState during drag to ~15 Hz (every ~66ms) to cut rebuilds.
    _dragSeekTargetPosition = target;
    final now = DateTime.now();
    if (now.difference(_lastDragSetState).inMilliseconds >= 66) {
      _lastDragSetState = now;
      setState(() {});
    }
  }

  void _onMouseActivity() {
    if (!_controlsVisible && !_controlsLocked) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _startHideTimer();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_controlsLocked) return;
    if (!_isDragSeeking) return;

    final deltaMs =
        (_dragSeekTargetPosition - widget.currentPosition).inMilliseconds;
    setState(() {
      _isDragSeeking = false;
      _dragSeekAccumulatedDx = 0;
      _controlsVisible = false;
    });
    _hideTimer?.cancel();

    // Only seek if delta is significant (>1 second)
    if (deltaMs.abs() > 1000) {
      widget.onSeekChanged?.call(
        _dragSeekTargetPosition.inMilliseconds.toDouble(),
      );
      widget.onSeekEnd?.call(_dragSeekTargetPosition.inMilliseconds.toDouble());
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_controlsLocked) return;
    if (Platform.isWindows) return;
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
    _exitRapidSeekMode();
    final width = MediaQuery.of(context).size.width;
    _verticalDragStart = details.localPosition;
    _isVerticalDragBrightness = details.localPosition.dx < width / 2;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_controlsLocked) return;
    if (_verticalDragStart == null) return;
    final delta = -details.delta.dy / 200;
    setState(() {
      if (_isVerticalDragBrightness) {
        _brightnessLevel = (_brightnessLevel + delta).clamp(0.0, 1.0);
        _showBrightnessOverlay = true;
        widget.onBrightnessChanged?.call(_brightnessLevel);
      } else {
        _volumeLevel = (_volumeLevel + delta).clamp(0.0, 2.0);
        _showVolumeOverlay = true;
      }
    });
    if (!_isVerticalDragBrightness) {
      widget.onVolumeChanged?.call(_volumeLevel);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_controlsLocked) return;
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

  void _toggleOrientationLock() {
    setState(() {
      _orientationLocked = !_orientationLocked;
    });
    if (_orientationLocked) {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    }
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
        _accumulateSeek(-10);
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _accumulateSeek(10);
        _startHideTimer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final newVolUp = (_volumeLevel + 0.1).clamp(0.0, 2.0);
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
        final newVolDown = (_volumeLevel - 0.1).clamp(0.0, 2.0);
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

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSeekDelta(Duration delta) {
    final totalSeconds = delta.inSeconds;
    final sign = totalSeconds >= 0 ? '+' : '-';
    final abs = totalSeconds.abs();
    final m = abs ~/ 60;
    final s = abs % 60;
    if (m > 0) {
      return '$sign${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$sign${s}s';
  }

  String _formatCurrentTime(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(locale).format(_currentTime);
  }

  void _showSpeedSelector(BuildContext context) {
    const speeds = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<double>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Playback Speed',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: speeds
                    .map(
                      (speed) => ListTile(
                        title: Text(
                          speed == 1.0 ? '1.0x (Normal)' : '${speed}x',
                          style: TextStyle(
                            color: speed == _baseSpeed
                                ? KumoriyaColors.primary
                                : KumoriyaColors.textPrimary,
                            fontWeight: speed == _baseSpeed
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: speed == _baseSpeed
                            ? const Icon(
                                Icons.check_rounded,
                                color: KumoriyaColors.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(ctx).pop(speed),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ).then((selected) {
      if (!mounted || selected == null || selected == _baseSpeed) {
        return;
      }
      setState(() {
        _baseSpeed = selected;
        _speedMultiplier = selected;
      });
      widget.onSpeedChanged?.call(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onHover: (_) {
          if (Platform.isWindows) _onMouseActivity();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: _onTapUp,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onLongPressStart: (_) {
            if (_controlsLocked) return;
            _doubleTapTimer?.cancel();
            _doubleTapTimer = null;
            _exitRapidSeekMode();
            setState(() => _speedMultiplier = 2.0);
            widget.onSpeedChanged?.call(2.0);
          },
          onLongPressEnd: (_) {
            if (_controlsLocked) return;
            setState(() => _speedMultiplier = _baseSpeed);
            widget.onSpeedChanged?.call(_baseSpeed);
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
                    fit: BoxFit.contain,
                    subtitleViewConfiguration:
                        widget.subtitleViewConfiguration ??
                        const SubtitleViewConfiguration(),
                  ),
                )
              else
                const ColoredBox(color: Colors.black),

              // Seek indicator (double-tap accumulation)
              if (_seekIndicatorVisible && !_isDragSeeking)
                Align(
                  alignment: _seekIndicatorForward
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _seekIndicatorForward
                              ? Icons.fast_forward_rounded
                              : Icons.fast_rewind_rounded,
                          color: KumoriyaColors.textPrimary,
                          size: 36,
                          shadows: const <Shadow>[
                            Shadow(color: Color(0xCC000000), blurRadius: 8),
                            Shadow(color: Color(0x66000000), blurRadius: 24),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_pendingSeekSeconds >= 0 ? '+' : ''}${_pendingSeekSeconds}s',
                          style: Theme.of(context).textTheme.headlineSmall!
                              .copyWith(
                                color: KumoriyaColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 8,
                                  ),
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                        ),
                      ],
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
                      icon: _volumeLevel > 1.0
                          ? Icons.volume_up_rounded
                          : _volumeLevel > 0.5
                          ? Icons.volume_up_rounded
                          : _volumeLevel > 0
                          ? Icons.volume_down_rounded
                          : Icons.volume_off_rounded,
                      value: (_volumeLevel / 2.0).clamp(0.0, 1.0),
                      label: '${(_volumeLevel * 100).round()}%',
                      isBoost: _volumeLevel > 1.0,
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
                      isBoost: false,
                    ),
                  ),
                ),

              // 2× Speed badge
              if (_speedMultiplier > 1.0)
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 56),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          KumoriyaRadius.full,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x731E1629),
                              borderRadius: BorderRadius.circular(
                                KumoriyaRadius.full,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
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
                                      .copyWith(
                                        color: KumoriyaColors.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

              // Debug diagnostics overlay (debug builds only)
              if (kDebugMode && widget.diagnosticsStream != null)
                PlayerDebugOverlay(
                  diagnosticsStream: widget.diagnosticsStream!,
                  seekLatencyMs: widget.seekLatencyMs,
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
              RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // Radial vignettes (replaces linear gradient)
                        CustomPaint(
                          size: Size.infinite,
                          painter: const _RadialVignettePainter(),
                        ),

                        // Top-left: Back + title
                        Positioned(
                          left: KumoriyaSpacing.lg,
                          top:
                              KumoriyaSpacing.md +
                              MediaQuery.of(context).padding.top,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                onPressed: widget.onBack,
                                tooltip: context.l10n.playerBack,
                                icon: Icon(
                                  KumoriyaIcons.playerBack,
                                  color: KumoriyaColors.textPrimary,
                                  size: 24,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                iconSize: 24,
                                padding: const EdgeInsets.all(12),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              Column(
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
                                          color: KumoriyaColors.textMuted,
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
                                        ? 'EP ${widget.episodeNumber} \u2014 ${widget.episodeTitle}'
                                        : 'EP ${widget.episodeNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall!
                                        .copyWith(
                                          color: KumoriyaColors.textPrimary,
                                          shadows: const <Shadow>[
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Top-right: Settings + navigation cluster
                        Positioned(
                          right: KumoriyaSpacing.lg,
                          top:
                              KumoriyaSpacing.md +
                              MediaQuery.of(context).padding.top,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: KumoriyaColors.playerControlBg,
                                  borderRadius: BorderRadius.circular(
                                    KumoriyaRadius.full,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: KumoriyaColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatCurrentTime(context),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: KumoriyaColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              // Speed pill
                              GestureDetector(
                                onTap: () => _showSpeedSelector(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KumoriyaColors.playerControlBg,
                                    borderRadius: BorderRadius.circular(
                                      KumoriyaRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    '${_baseSpeed}x',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .copyWith(
                                          color: _baseSpeed != 1.0
                                              ? KumoriyaColors.accentAmber
                                              : KumoriyaColors.textPrimary,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              // Auto-skip toggle
                              GestureDetector(
                                onTap: widget.onAutoSkipToggled,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: KumoriyaColors.playerControlBg,
                                    borderRadius: BorderRadius.circular(
                                      KumoriyaRadius.full,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.fast_forward_rounded,
                                        size: 16,
                                        color: widget.autoSkipEnabled
                                            ? KumoriyaColors.accentAmber
                                            : KumoriyaColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Auto',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall!
                                            .copyWith(
                                              color: widget.autoSkipEnabled
                                                  ? KumoriyaColors.accentAmber
                                                  : KumoriyaColors
                                                        .textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: KumoriyaSpacing.md),
                              // Previous episode
                              if (widget.onPreviousEpisode != null)
                                IconButton(
                                  onPressed: widget.onPreviousEpisode,
                                  icon: Icon(
                                    KumoriyaIcons.playerPreviousEpisode,
                                    color: KumoriyaColors.textPrimary,
                                    size: 24,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 24,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: context.l10n.playerPreviousEpisode,
                                ),
                              // Next episode
                              IconButton(
                                onPressed: widget.onOpenEpisodes,
                                icon: Icon(
                                  KumoriyaIcons.playerNextEpisode,
                                  color: KumoriyaColors.textPrimary,
                                  size: 28,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                iconSize: 28,
                                padding: const EdgeInsets.all(10),
                                tooltip: context.l10n.playerNextEpisode,
                              ),
                              const SizedBox(width: KumoriyaSpacing.md),
                              // Fullscreen / Orientation lock
                              if (Platform.isWindows)
                                IconButton(
                                  onPressed: widget.onToggleWindowsFullscreen,
                                  icon: Icon(
                                    widget.isWindowsFullscreen
                                        ? KumoriyaIcons.playerFullscreenExit
                                        : KumoriyaIcons.playerFullscreen,
                                    color: KumoriyaColors.textPrimary,
                                    size: 24,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 24,
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
                                    size: 24,
                                    shadows: const <Shadow>[
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  iconSize: 24,
                                  padding: const EdgeInsets.all(12),
                                  tooltip: _orientationLocked
                                      ? context.l10n.playerUnlockRotation
                                      : context.l10n.playerLockRotation,
                                ),
                              const SizedBox(width: KumoriyaSpacing.sm),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _controlsLocked = true;
                                    _controlsVisible = false;
                                  });
                                  _hideTimer?.cancel();
                                },
                                icon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: KumoriyaColors.textPrimary,
                                  size: 24,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                iconSize: 24,
                                padding: const EdgeInsets.all(12),
                                tooltip: context.l10n.playerLockControls,
                              ),
                            ],
                          ),
                        ),

                        // Center: Frosted glass play/pause + bare skip buttons
                        if (!_isDragSeeking)
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // Skip back
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: IconButton(
                                    onPressed: widget.onSkipBackward,
                                    tooltip: context.l10n.playerSkipBackward,
                                    icon: Icon(
                                      KumoriyaIcons.playerSeekBack10,
                                      color: KumoriyaColors.textPrimary,
                                      size: 28,
                                      shadows: const <Shadow>[
                                        Shadow(
                                          color: Color(0xCC000000),
                                          blurRadius: 8,
                                        ),
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: KumoriyaSpacing.xxxl),
                                // Frosted glass play/pause
                                ClipOval(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 12,
                                      sigmaY: 12,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: widget.onTogglePlayPause,
                                        splashColor: KumoriyaColors.primaryLight
                                            .withValues(alpha: 0.20),
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(
                                              0x731E1629,
                                            ), // surface @ 45%
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.10,
                                              ),
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              widget.isPlaying
                                                  ? KumoriyaIcons.playerPause
                                                  : KumoriyaIcons.playerPlay,
                                              color: KumoriyaColors.textPrimary,
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: KumoriyaSpacing.xxxl),
                                // Skip forward
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: IconButton(
                                    onPressed: widget.onSkipForward,
                                    tooltip: context.l10n.playerSkipForward,
                                    icon: Icon(
                                      KumoriyaIcons.playerSeekForward10,
                                      color: KumoriyaColors.textPrimary,
                                      size: 28,
                                      shadows: const <Shadow>[
                                        Shadow(
                                          color: Color(0xCC000000),
                                          blurRadius: 8,
                                        ),
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                // Fallback +90s skip (discrete, only when missing opening OR ending)
                                if (widget.showFallbackSkip && _controlsVisible)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: SizedBox(
                                      height: 32,
                                      child: TextButton(
                                        onPressed: widget.onFallbackSkip,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          backgroundColor: Colors.black38,
                                          foregroundColor:
                                              KumoriyaColors.textSecondary,
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        child: const Text('+90s'),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Bottom: Bare text action selectors
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 56,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _BottomTextAction(
                                icon: KumoriyaIcons.playerQuality,
                                label: context.l10n.playerQuality,
                                onTap: widget.onQuality,
                              ),
                              if (widget.hasSubtitles) ...<Widget>[
                                const SizedBox(width: KumoriyaSpacing.xl),
                                _BottomTextAction(
                                  icon: KumoriyaIcons.playerSubtitle,
                                  label: context.l10n.playerSubtitles,
                                  onTap: widget.onSubtitle,
                                ),
                              ],
                              if (widget.hasMultipleAudio) ...<Widget>[
                                const SizedBox(width: KumoriyaSpacing.xl),
                                _BottomTextAction(
                                  icon: KumoriyaIcons.playerAudio,
                                  label: context.l10n.playerAudio,
                                  onTap: widget.onAudio,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Bottom: Time labels
                        Positioned(
                          left: KumoriyaSpacing.lg,
                          bottom: 36,
                          child: RepaintBoundary(
                            child: Text(
                              widget.formatDuration(widget.currentPosition),
                              style: Theme.of(context).textTheme.labelSmall!
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
                          ),
                        ),
                        Positioned(
                          right: KumoriyaSpacing.lg,
                          bottom: 36,
                          child: RepaintBoundary(
                            child: Text(
                              widget.formatDuration(widget.totalDuration),
                              style: Theme.of(context).textTheme.labelSmall!
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
                          ),
                        ),

                        // Bottom: Full-bleed progress bar
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: RepaintBoundary(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                activeTrackColor: KumoriyaColors.primary,
                                inactiveTrackColor: KumoriyaColors.textPrimary
                                    .withValues(alpha: 0.20),
                                thumbColor: KumoriyaColors.primaryLight,
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24,
                                ),
                                overlayColor: KumoriyaColors.primary.withValues(
                                  alpha: 0.15,
                                ),
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Proportional drag seek overlay (above controls)
              if (_isDragSeeking)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: KumoriyaColors.playerControlBg,
                      borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatDuration(_dragSeekTargetPosition),
                          style: Theme.of(context).textTheme.headlineMedium!
                              .copyWith(
                                color: KumoriyaColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatSeekDelta(
                            _dragSeekTargetPosition - widget.currentPosition,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color:
                                    (_dragSeekTargetPosition >=
                                        widget.currentPosition)
                                    ? KumoriyaColors.accentMint
                                    : KumoriyaColors.accentRose,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Unlock overlay for locked controls
              if (_controlsLocked)
                Positioned(
                  bottom: KumoriyaSpacing.xl,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _controlsLocked = false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KumoriyaColors.playerControlBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: KumoriyaColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

              if (widget.activeSkipLabel != null &&
                  widget.onSkipSegment != null &&
                  _skipButtonVisible)
                RepaintBoundary(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24, bottom: 92),
                        child: AnimatedSlide(
                          offset: _skipButtonVisible
                              ? Offset.zero
                              : const Offset(0.3, 0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _skipButtonVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                KumoriyaRadius.full,
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.onSkipSegment,
                                    borderRadius: BorderRadius.circular(
                                      KumoriyaRadius.full,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xB31E1629),
                                        borderRadius: BorderRadius.circular(
                                          KumoriyaRadius.full,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: <Widget>[
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: AnimatedBuilder(
                                                    animation:
                                                        _skipProgressController,
                                                    builder: (_, _) =>
                                                        CircularProgressIndicator(
                                                          value:
                                                              _skipProgressController
                                                                  .value,
                                                          strokeWidth: 2,
                                                          color: KumoriyaColors
                                                              .textPrimary
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                          backgroundColor:
                                                              KumoriyaColors
                                                                  .textPrimary
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                        ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.skip_next_rounded,
                                                  color: KumoriyaColors
                                                      .textPrimary,
                                                  size: 14,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            widget.activeSkipLabel!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge!
                                                .copyWith(
                                                  color: KumoriyaColors
                                                      .textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalSliderOverlay extends StatelessWidget {
  const _VerticalSliderOverlay({
    required this.icon,
    required this.value,
    required this.label,
    required this.isBoost,
  });
  final IconData icon;
  final double value;
  final String label;
  final bool isBoost;

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
                    isBoost
                        ? KumoriyaColors.statusWarning
                        : KumoriyaColors.primary,
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

class _RadialVignettePainter extends CustomPainter {
  const _RadialVignettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Top-left vignette (for back + title)
    final topLeftPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.90),
        radius: 0.6,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.55),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topLeftPaint);

    // Center vignette (for play/pause)
    final centerPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.35,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.40),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, centerPaint);

    // Bottom vignette (for progress bar + time)
    final bottomPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.2),
        radius: 0.5,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.60),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomTextAction extends StatelessWidget {
  const _BottomTextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KumoriyaRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KumoriyaSpacing.sm,
              vertical: KumoriyaSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: KumoriyaColors.textSecondary),
                const SizedBox(width: KumoriyaSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: KumoriyaColors.textSecondary,
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
