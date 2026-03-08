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
  }) : _playbackEngine = playbackEngine,
       _selectionPolicy = selectionPolicy ?? const StreamSelectionPolicy() {
    _subscriptions = <StreamSubscription<dynamic>>[
      _playbackEngine.playingStream.listen(_onPlayingChanged),
      _playbackEngine.bufferingStream.listen(_onBufferingChanged),
      _playbackEngine.errorStream.listen(_onPlaybackError),
    ];
  }

  final PlaybackEngine _playbackEngine;
  final StreamSelectionPolicy _selectionPolicy;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  final _stateController = StreamController<PlayerSessionState>.broadcast();
  PlayerSessionState _state = const PlayerSessionState.idle();
  bool _isPlaying = false;
  bool _isBuffering = false;

  Stream<PlayerSessionState> get states => _stateController.stream;
  PlayerSessionState get state => _state;

  Future<Result<ResolvedStream, KumoriyaError>> start({
    required List<ResolvedStream> streamCandidates,
  }) async {
    final selected = _selectionPolicy.selectBest(streamCandidates);
    if (selected == null) {
      return const Failure(
        SimpleError(
          code: 'player.no_playable_stream',
          message: 'No playable stream candidates were provided to player.',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }

    if (!_isSupportedUrl(selected.url)) {
      return Failure(
        SimpleError(
          code: 'player.unsupported_stream',
          message: 'Unsupported stream URL for player: ${selected.url}',
          kind: KumoriyaErrorKind.mapping,
        ),
      );
    }

    _emit(
      _state.copyWith(
        status: PlayerSessionStatus.opening,
        selectedStream: selected,
        clearError: true,
      ),
    );

    try {
      await _playbackEngine.open(selected);
      return Success(selected);
    } catch (error) {
      _emit(
        _state.copyWith(
          status: PlayerSessionStatus.error,
          errorMessage: error.toString(),
        ),
      );
      return Failure(
        SimpleError(
          code: 'player.open_failed',
          message: 'Player failed to open stream: $error',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _playbackEngine.pause();
      return;
    }

    await _playbackEngine.play();
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _playbackEngine.dispose();
    await _stateController.close();
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
      return;
    }

    _emit(
      _state.copyWith(
        status: _isPlaying
            ? PlayerSessionStatus.playing
            : PlayerSessionStatus.paused,
      ),
    );
  }

  void _onPlaybackError(String error) {
    _emit(
      _state.copyWith(status: PlayerSessionStatus.error, errorMessage: error),
    );
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
}
