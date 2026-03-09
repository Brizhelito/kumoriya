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
    this.preferredAudioPreference,
    required this.resolved,
  });

  final int anilistId;
  final String animeTitle;
  final String episodeNumber;
  final String sourcePluginId;
  final String serverName;
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

  StreamSubscription<PlayerSessionState>? _sessionSub;
  StreamSubscription<bool>? _playingSub;
  Timer? _periodicSaveTimer;

  PlayerSessionState _state = const PlayerSessionState.idle();
  String? _startError;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _resumeAttempted = false;

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

    _sessionSub = _orchestrator.states.listen((next) {
      if (mounted) setState(() => _state = next);
    });

    _engine.positionStream.listen((pos) => _currentPosition = pos);
    _engine.durationStream.listen((dur) {
      if (dur > Duration.zero) _currentDuration = dur;
    });

    _playingSub = _engine.playingStream.listen(_onPlayingChanged);

    _startPlayback();
  }

  @override
  void dispose() {
    _periodicSaveTimer?.cancel();
    _sessionSub?.cancel();
    _playingSub?.cancel();
    _saveCurrentProgress();
    _orchestrator.dispose();
    super.dispose();
  }

  void _onPlayingChanged(bool playing) {
    if (!playing) {
      _saveCurrentProgress();
    } else if (!_resumeAttempted) {
      _attemptResume();
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

  Future<void> _attemptResume() async {
    _resumeAttempted = true;
    final store = ref.read(animeProgressStoreProvider);
    final result = await store.getProgress(
      widget.anilistId,
      _episodeNumberDouble,
    );
    result.fold(
      onFailure: (_) {},
      onSuccess: (progress) {
        if (progress != null &&
            progress.watchState != WatchState.completed &&
            progress.position > const Duration(seconds: 5)) {
          _engine.seekTo(progress.position);
        }
      },
    );
  }

  void _saveCurrentProgress() {
    if (_currentPosition < const Duration(seconds: 5)) return;
    final selected = _state.selectedStream;
    unawaited(
      _saveProgress(
        anilistId: widget.anilistId,
        episodeNumber: _episodeNumberDouble,
        position: _currentPosition,
        totalDuration: _currentDuration > Duration.zero
            ? _currentDuration
            : null,
        lastSourcePluginId: widget.sourcePluginId,
        lastServerName: selected != null ? widget.serverName : null,
        lastResolverPluginId: selected != null
            ? widget.resolved.resolverId
            : null,
      ),
    );
  }

  Future<void> _startPlayback() async {
    final result = await _orchestrator.start(
      streamCandidates: widget.resolved.streams,
    );
    if (!mounted) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {
        unawaited(
          _savePlaybackPreference(
            anilistId: widget.anilistId,
            sourcePluginId: widget.sourcePluginId,
            serverName: widget.serverName,
            resolverPluginId: widget.resolved.resolverId,
            preferredAudioPreference: widget.preferredAudioPreference,
          ),
        );
      },
    );
  }

  Future<void> _retryPlayback() async {
    setState(() => _startError = null);
    _resumeAttempted = false;
    final result = await _orchestrator.retry();
    if (!mounted) return;
    result.fold(
      onFailure: (error) =>
          setState(() => _startError = mapErrorMessage(context, error)),
      onSuccess: (_) {},
    );
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
                Video(controller: _engine.videoController),
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
}
