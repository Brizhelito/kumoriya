import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

final class SaveProgressUseCase {
  const SaveProgressUseCase({required AnimeProgressStore store})
    : _store = store;

  final AnimeProgressStore _store;

  static const double _completionThreshold = 0.90;
  static const Duration _minPositionToSave = Duration(seconds: 5);

  Future<Result<void, KumoriyaError>> call({
    required int anilistId,
    required double episodeNumber,
    required Duration position,
    Duration? totalDuration,
    String? lastSourcePluginId,
    String? lastServerName,
    String? lastResolverPluginId,
  }) async {
    if (position < _minPositionToSave) {
      return const Success(null);
    }

    final watchState = _resolveWatchState(position, totalDuration);

    return _store.upsert(
      EpisodeProgress(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        position: position,
        totalDuration: totalDuration,
        watchState: watchState,
        updatedAt: DateTime.now(),
        lastSourcePluginId: lastSourcePluginId,
        lastServerName: lastServerName,
        lastResolverPluginId: lastResolverPluginId,
      ),
    );
  }

  WatchState _resolveWatchState(Duration position, Duration? totalDuration) {
    if (totalDuration == null || totalDuration.inSeconds == 0) {
      return WatchState.watching;
    }
    final ratio = position.inSeconds / totalDuration.inSeconds;
    if (ratio >= _completionThreshold) {
      return WatchState.completed;
    }
    return WatchState.watching;
  }
}
