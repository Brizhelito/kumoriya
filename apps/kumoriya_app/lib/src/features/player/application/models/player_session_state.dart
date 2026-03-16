import 'package:kumoriya_plugins/kumoriya_plugins.dart';

enum PlayerSessionStatus {
  idle,
  opening,
  buffering,
  fallbacking,
  playing,
  paused,
  error,
}

final class PlayerSessionState {
  const PlayerSessionState({
    required this.status,
    this.selectedStream,
    this.errorMessage,
    this.infoMessage,
    this.currentCandidateIndex = 0,
    this.totalCandidates = 0,
    this.errorGeneration = -1,
  });

  const PlayerSessionState.idle() : this(status: PlayerSessionStatus.idle);

  final PlayerSessionStatus status;
  final ResolvedStream? selectedStream;
  final String? errorMessage;
  final String? infoMessage;
  final int currentCandidateIndex;
  final int totalCandidates;

  /// The open generation that produced the current [errorMessage].
  ///
  /// Defaults to `-1` (no error generation).  Set by [_fail] calls inside
  /// `_openCurrentCandidate` to the generation counter at the time of failure.
  /// Used by the success emit to decide whether to clear a stale error:
  /// if [errorGeneration] < current open generation, the error is stale and
  /// should be cleared.
  final int errorGeneration;

  PlayerSessionState copyWith({
    PlayerSessionStatus? status,
    ResolvedStream? selectedStream,
    String? errorMessage,
    String? infoMessage,
    int? currentCandidateIndex,
    int? totalCandidates,
    int? errorGeneration,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return PlayerSessionState(
      status: status ?? this.status,
      selectedStream: selectedStream ?? this.selectedStream,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfo ? null : infoMessage ?? this.infoMessage,
      currentCandidateIndex:
          currentCandidateIndex ?? this.currentCandidateIndex,
      totalCandidates: totalCandidates ?? this.totalCandidates,
      errorGeneration: clearError
          ? -1
          : errorGeneration ?? this.errorGeneration,
    );
  }
}
