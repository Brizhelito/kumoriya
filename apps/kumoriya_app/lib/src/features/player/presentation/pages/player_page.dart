import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/player_session_state.dart';
import '../../application/services/player_session_orchestrator.dart';
import '../../infrastructure/media_kit_playback_engine.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.animeTitle,
    required this.episodeNumber,
    required this.resolved,
  });

  final String animeTitle;
  final String episodeNumber;
  final ResolvedServerLinkResult resolved;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final MediaKitPlaybackEngine _engine;
  late final PlayerSessionOrchestrator _orchestrator;
  StreamSubscription<PlayerSessionState>? _subscription;

  PlayerSessionState _state = const PlayerSessionState.idle();
  String? _startError;

  @override
  void initState() {
    super.initState();
    _engine = MediaKitPlaybackEngine();
    _orchestrator = PlayerSessionOrchestrator(playbackEngine: _engine);
    _subscription = _orchestrator.states.listen((next) {
      if (mounted) {
        setState(() => _state = next);
      }
    });
    _startPlayback();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _orchestrator.dispose();
    super.dispose();
  }

  Future<void> _startPlayback() async {
    final result = await _orchestrator.start(
      streamCandidates: widget.resolved.streams,
    );

    if (!mounted) {
      return;
    }

    result.fold(
      onFailure: (error) {
        setState(() => _startError = mapErrorMessage(context, error));
      },
      onSuccess: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_startError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.playerTitle)),
        body: ErrorStateView(message: _startError!),
      );
    }

    final selected = _state.selectedStream;
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
                    child: Text(
                      context.l10n.playerLoading,
                      style: const TextStyle(color: Colors.white),
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
                        context.l10n.playerPlaybackError(
                          _state.errorMessage ??
                              context.l10n.errorUnexpectedSource,
                        ),
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
                Text(context.l10n.resolverUsed(widget.resolved.resolverName)),
                if (selected != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.playerCurrentStream(selected.url.toString()),
                  ),
                ],
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
