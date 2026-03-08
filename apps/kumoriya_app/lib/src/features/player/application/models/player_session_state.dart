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
  });

  const PlayerSessionState.idle() : this(status: PlayerSessionStatus.idle);

  final PlayerSessionStatus status;
  final ResolvedStream? selectedStream;
  final String? errorMessage;
  final String? infoMessage;
  final int currentCandidateIndex;
  final int totalCandidates;

  PlayerSessionState copyWith({
    PlayerSessionStatus? status,
    ResolvedStream? selectedStream,
    String? errorMessage,
    String? infoMessage,
    int? currentCandidateIndex,
    int? totalCandidates,
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
    );
  }
}
