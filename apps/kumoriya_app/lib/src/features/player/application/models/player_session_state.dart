import 'package:kumoriya_plugins/kumoriya_plugins.dart';

enum PlayerSessionStatus { idle, opening, buffering, playing, paused, error }

final class PlayerSessionState {
  const PlayerSessionState({
    required this.status,
    this.selectedStream,
    this.errorMessage,
  });

  const PlayerSessionState.idle() : this(status: PlayerSessionStatus.idle);

  final PlayerSessionStatus status;
  final ResolvedStream? selectedStream;
  final String? errorMessage;

  PlayerSessionState copyWith({
    PlayerSessionStatus? status,
    ResolvedStream? selectedStream,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerSessionState(
      status: status ?? this.status,
      selectedStream: selectedStream ?? this.selectedStream,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
