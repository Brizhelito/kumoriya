import 'package:kumoriya_core/kumoriya_core.dart';

enum WatchState { unwatched, watching, completed }

final class EpisodeProgress {
  const EpisodeProgress({
    required this.anilistId,
    required this.episodeNumber,
    required this.position,
    required this.updatedAt,
    this.totalDuration,
    this.watchState = WatchState.unwatched,
    this.lastSourcePluginId,
    this.lastServerName,
    this.lastResolverPluginId,
  });

  final int anilistId;
  final double episodeNumber;
  final Duration position;
  final DateTime updatedAt;
  final Duration? totalDuration;
  final WatchState watchState;
  final String? lastSourcePluginId;
  final String? lastServerName;
  final String? lastResolverPluginId;
}

final class AnimeWatchHistory {
  const AnimeWatchHistory({
    required this.anilistId,
    required this.lastEpisodeNumber,
    required this.lastAccessedAt,
    this.lastSourcePluginId,
  });

  final int anilistId;
  final double lastEpisodeNumber;
  final DateTime lastAccessedAt;
  final String? lastSourcePluginId;
}

abstract interface class AnimeProgressStore {
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress);

  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  );

  Future<Result<EpisodeProgress?, KumoriyaError>> getLatestProgress(
    int anilistId,
  );

  Future<Result<List<EpisodeProgress>, KumoriyaError>> getAllProgress(
    int anilistId,
  );

  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  });
}
