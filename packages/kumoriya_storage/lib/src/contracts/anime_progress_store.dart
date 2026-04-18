import 'package:kumoriya_core/kumoriya_core.dart';

enum WatchState { unwatched, watching, completed }

enum PlaybackAudioPreference { sub, dub }

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
    this.lastPositionSeconds = 0,
    this.lastTotalDurationSeconds,
  });

  final int anilistId;
  final double lastEpisodeNumber;
  final DateTime lastAccessedAt;
  final String? lastSourcePluginId;
  final int lastPositionSeconds;
  final int? lastTotalDurationSeconds;

  double? get progressFraction {
    final total = lastTotalDurationSeconds;
    if (total == null || total <= 0) return null;
    return (lastPositionSeconds / total).clamp(0.0, 1.0);
  }
}

final class PlaybackPreference {
  const PlaybackPreference({
    required this.anilistId,
    required this.updatedAt,
    this.preferredSourcePluginId,
    this.preferredServerName,
    this.preferredResolverPluginId,
    this.preferredAudioPreference,
  });

  final int anilistId;
  final DateTime updatedAt;
  final String? preferredSourcePluginId;
  final String? preferredServerName;
  final String? preferredResolverPluginId;
  final PlaybackAudioPreference? preferredAudioPreference;
}

abstract interface class AnimeProgressStore {
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress);

  Future<Result<void, KumoriyaError>> upsertWatchHistory({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    int? totalDurationSeconds,
    String? lastSourcePluginId,
    DateTime? lastAccessedAt,
  });

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

  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getAllHistory();

  Future<Result<void, KumoriyaError>> deleteHistoryEntry(int anilistId);

  Future<Result<void, KumoriyaError>> clearAllHistory();

  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference preference,
  );

  Future<Result<PlaybackPreference?, KumoriyaError>> getPlaybackPreference(
    int anilistId,
  );

  Future<Result<void, KumoriyaError>> clearPlaybackPreference(int anilistId);

  Future<Result<void, KumoriyaError>> clearAllPlaybackPreferences();

  /// Wipes every stored `EpisodeProgress` row. Meant to be invoked when
  /// the user signs out so another account cannot inherit the previous
  /// user's per-episode watch state.
  Future<Result<void, KumoriyaError>> clearAllProgress();
}
