import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/episode_progress_table.dart';
import '../tables/playback_preference_table.dart';
import '../tables/watch_history_table.dart';

part 'progress_dao.g.dart';

@DriftAccessor(
  tables: [EpisodeProgressTable, WatchHistoryTable, PlaybackPreferenceTable],
)
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Future<void> upsertProgress(EpisodeProgressTableCompanion entry) {
    return into(episodeProgressTable).insertOnConflictUpdate(entry);
  }

  Future<EpisodeProgressTableData?> getProgress(
    int anilistId,
    double episodeNumber,
  ) {
    return (select(episodeProgressTable)..where(
          (t) =>
              t.anilistId.equals(anilistId) &
              t.episodeNumber.equals(episodeNumber),
        ))
        .getSingleOrNull();
  }

  Future<EpisodeProgressTableData?> getLatestProgress(int anilistId) {
    return (select(episodeProgressTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<EpisodeProgressTableData>> getAllProgress(int anilistId) {
    return (select(episodeProgressTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..orderBy([(t) => OrderingTerm.asc(t.episodeNumber)]))
        .get();
  }

  Future<void> upsertHistory(WatchHistoryTableCompanion entry) {
    return into(watchHistoryTable).insertOnConflictUpdate(entry);
  }

  Future<List<WatchHistoryTableData>> getRecentHistory(int limit) {
    return (select(watchHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastAccessedAt)])
          ..limit(limit))
        .get();
  }

  Future<void> upsertPlaybackPreference(
    PlaybackPreferenceTableCompanion entry,
  ) {
    return into(playbackPreferenceTable).insertOnConflictUpdate(entry);
  }

  Future<PlaybackPreferenceTableData?> getPlaybackPreference(int anilistId) {
    return (select(playbackPreferenceTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..limit(1))
        .getSingleOrNull();
  }
}
