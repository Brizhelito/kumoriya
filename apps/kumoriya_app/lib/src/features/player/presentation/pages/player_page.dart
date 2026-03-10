import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
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
  late final MediaKitPlaybackEngine _engine;
  late final PlayerSessionOrchestrator _orchestrator;
  late final SaveProgressUseCase _saveProgress;
  late final SavePlaybackPreferenceUseCase _savePlaybackPreference;
  late final ClearPlaybackPreferenceUseCase _clearPlaybackPreference;

  StreamSubscription<PlayerSessionState>? _sessionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Timer? _periodicSaveTimer;

  PlayerSessionState _state = const PlayerSessionState.idle();
  String? _startError;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration? _resumePosition;
  bool _isScrubbing = false;
  double? _scrubPositionMs;

  double get _episodeNumberDouble =>
      double.tryParse(widget.episodeNumber) ?? 0.0;

  @override
  void initState() {
    super.initState();
    _engine = MediaKitPlaybackEngine();
    _orchestrator = PlayerSessionOrchestrator(playbackEngine: _engine);
    _saveProgress = SaveProgressUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _savePlaybackPreference = SavePlaybackPreferenceUseCase(
      store: ref.read(animeProgressStoreProvider),
    );
    _clearPlaybackPreference = ClearPlaybackPreferenceUseCase(
      store: ref.read(animeProgressStoreProvider),
    );

    _sessionSub = _orchestrator.states.listen((next) {
      if (mounted) setState(() => _state = next);
    });

    _positionSub = _engine.positionStream.listen((pos) {
      if (!mounted) {
        _currentPosition = pos;
        return;
      }
      setState(() => _currentPosition = pos);
    });
    _durationSub = _engine.durationStream.listen((dur) {
      if (dur <= Duration.zero) {
        return;
      }
      if (!mounted) {
        _currentDuration = dur;
        return;
      }
      setState(() => _currentDuration = dur);
    });

    _playingSub = _engine.playingStream.listen(_onPlayingChanged);

    _startPlayback();
  }

  @override
  void dispose() {
    _periodicSaveTimer?.cancel();
    _sessionSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _saveCurrentProgress();
    _orchestrator.dispose();
    super.dispose();
  }

  void _onPlayingChanged(bool playing) {
    if (!playing) {
      _saveCurrentProgress();
    }
    if (playing) {
      _periodicSaveTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => _saveCurrentProgress(),
      );
    } else {
      _periodicSaveTimer?.cancel();
      _periodicSaveTimer = null;
    }
  }

  void _saveCurrentProgress() {
    if (_currentPosition < const Duration(seconds: 5)) return;
    final selected = _state.selectedStream;
    final persistServerMetadata = widget.persistSelection && selected != null;
    unawaited(
      _saveProgress(
        anilistId: widget.anilistId,
        episodeNumber: _episodeNumberDouble,
        position: _currentPosition,
        totalDuration: _currentDuration > Duration.zero
            ? _currentDuration
            : null,
        lastSourcePluginId: persistServerMetadata
            ? widget.sourcePluginId
            : null,
        lastServerName: persistServerMetadata ? widget.serverName : null,
        lastResolverPluginId: persistServerMetadata
            ? widget.resolved.resolverId
            : null,
      ),
    );
  }

  Future<void> _startPlayback() async {
    _resumePosition = await _loadResumePosition();
    final result = await _orchestrator.start(
      streamCandidates: widget.resolved.streams,
      initialPosition: _resumePosition,
    );
    if (!mounted) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {
        unawaited(_persistSuccessfulSelection());
      },
    );
  }

  Future<void> _retryPlayback() async {
    setState(() => _startError = null);
    final result = await _orchestrator.retry();
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
    await _orchestrator.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    if (_startError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.playerTitle)),
        body: ErrorStateView(message: _startError!, onRetry: _retryPlayback),
      );
    }

    final isLoading =
        _state.status == PlayerSessionStatus.opening ||
        _state.status == PlayerSessionStatus.buffering;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.playerEpisodeTitle(
            widget.animeTitle,
            widget.episodeNumber,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Video(
                  controller: _engine.videoController,
                  controls: NoVideoControls,
                ),
                if (isLoading)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.playerLoading,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (_state.status == PlayerSessionStatus.error)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.l10n.playerPlaybackErrorGeneric,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.playerSourceSummary(
                    widget.serverName,
                    widget.resolved.resolverName,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.playerCandidatePosition(
                    (_state.currentCandidateIndex + 1).toString(),
                    _state.totalCandidates.toString(),
                  ),
                ),
                if (_state.infoMessage != null &&
                    _state.infoMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(_mapInfoMessage(context, _state.infoMessage!)),
                ],
                if (widget.preferredAudioPreference != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.playerAudioPreference(
                      widget.preferredAudioPreference!.name.toUpperCase(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => _orchestrator.togglePlayPause(),
                      icon: Icon(
                        _state.status == PlayerSessionStatus.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        _state.status == PlayerSessionStatus.playing
                            ? context.l10n.playerPause
                            : context.l10n.playerPlay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _retryPlayback,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.retry),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _sliderValueMs,
                  max: _sliderMaxMs,
                  onChanged: _currentDuration > Duration.zero
                      ? (value) {
                          setState(() {
                            _isScrubbing = true;
                            _scrubPositionMs = value;
                          });
                        }
                      : null,
                  onChangeEnd: _currentDuration > Duration.zero
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
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_formatDuration(_effectiveSliderPosition)),
                    Text(_formatDuration(_currentDuration)),
                  ],
                ),
                if (_state.status == PlayerSessionStatus.error) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.playerAllCandidatesFailed,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mapInfoMessage(BuildContext context, String code) {
    switch (code) {
      case 'player.fallback_in_progress':
        return context.l10n.playerCandidateFailedTryingFallback;
      case 'player.tried_all_candidates':
        return context.l10n.playerAllCandidatesFailed;
      default:
        return code;
    }
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
}
