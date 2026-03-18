import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
import '../../application/models/embedded_tracks.dart';
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
  Timer? _periodicSaveTimer;
  Future<void>? _pendingProgressFlush;
  bool _isExiting = false;
  bool _historyWrittenForSession = false;
  bool _forceSoftwareVideoOutput =
      defaultTargetPlatform == TargetPlatform.windows;

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
        return;
      }
      setState(() => _currentPosition = pos);
    });
    _durationSub = orchestrator.durationStream.listen((dur) {
      if (dur <= Duration.zero) {
        return;
      }
      _log('duration stream dur=$dur');
      if (!mounted) {
        _currentDuration = dur;
        return;
      }
      setState(() => _currentDuration = dur);
    });

    _playingSub = engine.playingStream.listen(_onPlayingChanged);
    _tracksSub = orchestrator.embeddedTracksStream.listen((tracks) {
      if (!mounted) {
        _embeddedTracks = tracks;
        return;
      }
      setState(() => _embeddedTracks = tracks);
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
    _sessionSub = null;
    _playingSub = null;
    _positionSub = null;
    _durationSub = null;
    _tracksSub = null;
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

  Future<void> _handleExitRequested() async {
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
        Navigator.of(context).pop();
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
          hasSubtitles: _embeddedTracks.hasSubtitles,
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
          onQuality: () => unawaited(_showQualityPicker(context)),
          onAudio: _embeddedTracks.hasMultipleAudio
              ? () => unawaited(_showAudioTrackPicker(context))
              : null,
          onSubtitle: _embeddedTracks.hasSubtitles
              ? () => unawaited(_showSubtitleTrackPicker(context))
              : null,
          onSkipBackward: () {
            final target = _currentPosition - const Duration(seconds: 10);
            unawaited(_seekTo(target < Duration.zero ? Duration.zero : target));
          },
          onSkipForward: () {
            final maxPos = _currentDuration - const Duration(seconds: 1);
            final target = _currentPosition + const Duration(seconds: 10);
            unawaited(_seekTo(target > maxPos && maxPos > Duration.zero ? maxPos : target));
          },
          errorMessage: _state.status == PlayerSessionStatus.error
              ? context.l10n.playerAllCandidatesFailed
              : null,
          formatDuration: _formatDuration,
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
              final label = stream.qualityLabel ?? stream.url.toString();
              return ListTile(
                title: Text(label),
                subtitle: Text(stream.url.toString(), maxLines: 1),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    final tracks = _embeddedTracks.subtitle;

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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_off),
                title: Text(context.l10n.playerDisableSubtitles),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(orchestrator.clearEmbeddedSubtitleTrack());
                },
              ),
              ...tracks.map(
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
    required this.onQuality,
    required this.onAudio,
    required this.onSubtitle,
    required this.formatDuration,
    required this.onSkipBackward,
    required this.onSkipForward,
    this.errorMessage,
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
  final VoidCallback onQuality;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitle;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;
  final String? errorMessage;
  final String Function(Duration) formatDuration;

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Video layer
        if (widget.engine != null)
          Video(
            controller: widget.engine!.videoController,
            controls: NoVideoControls,
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
            alignment: _seekIndicatorForward ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _seekIndicatorForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _seekIndicatorForward ? '+10s' : '-10s',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
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
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: widget.onBack,
                              tooltip: context.l10n.playerBack,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.animeTitle} - EP ${widget.episodeNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.hasMultipleAudio)
                              IconButton(
                                onPressed: widget.onAudio,
                                icon: const Icon(
                                  Icons.audiotrack_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: context.l10n.playerAudio,
                              ),
                            if (widget.hasSubtitles)
                              IconButton(
                                onPressed: widget.onSubtitle,
                                icon: const Icon(
                                  Icons.subtitles_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: context.l10n.playerSubtitles,
                              ),
                            IconButton(
                              onPressed: widget.onQuality,
                              icon: const Icon(
                                Icons.hd_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: context.l10n.playerQuality,
                            ),
                            IconButton(
                              onPressed: _toggleOrientationLock,
                              icon: Icon(
                                _orientationLocked ? Icons.screen_lock_rotation_rounded : Icons.screen_rotation_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: _orientationLocked ? context.l10n.playerUnlockRotation : context.l10n.playerLockRotation,
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
                            size: 36,
                            onTap: widget.onSkipBackward,
                            tooltip: context.l10n.playerSkipBackward,
                          ),
                          const SizedBox(width: 32),
                          _PlayerIconButton(
                            icon: widget.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 56,
                            onTap: widget.onTogglePlayPause,
                            tooltip: widget.isPlaying ? context.l10n.playerPause : context.l10n.playerPlay,
                          ),
                          const SizedBox(width: 32),
                          _PlayerIconButton(
                            icon: Icons.forward_10_rounded,
                            size: 36,
                            onTap: widget.onSkipForward,
                            tooltip: context.l10n.playerSkipForward,
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Bottom seek bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          children: <Widget>[
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
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
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (widget.totalDuration > Duration.zero)
                                    Text(
                                      '-${widget.formatDuration(widget.totalDuration - widget.currentPosition)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                  Text(
                                    widget.formatDuration(widget.totalDuration),
                                    style: const TextStyle(
                                      fontSize: 12,
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
        ],
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
