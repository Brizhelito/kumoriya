import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/aniskip_cache_table.dart';

part 'aniskip_cache_dao.g.dart';

@DriftAccessor(tables: [AniSkipCacheTable])
class AniSkipCacheDao extends DatabaseAccessor<AppDatabase>
    with _$AniSkipCacheDaoMixin {
  AniSkipCacheDao(super.db);

  Future<AniSkipCacheTableData?> getEpisode(int anilistId, int episodeNumber) {
    return (select(aniSkipCacheTable)..where(
          (t) =>
              t.anilistId.equals(anilistId) &
              t.episodeNumber.equals(episodeNumber),
        ))
        .getSingleOrNull();
  }

  Future<List<AniSkipCacheTableData>> getEpisodesForAnime(int anilistId) {
    return (select(aniSkipCacheTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..orderBy([(t) => OrderingTerm.asc(t.episodeNumber)]))
        .get();
  }

  Future<void> upsertEpisode(AniSkipCacheTableCompanion companion) {
    return into(aniSkipCacheTable).insertOnConflictUpdate(companion);
  }

  Future<void> clearAnime(int anilistId) {
    return (delete(
      aniSkipCacheTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }

  Future<int> deleteOlderThan(int epochMs) {
    return (delete(
      aniSkipCacheTable,
    )..where((t) => t.updatedAt.isSmallerThanValue(epochMs))).go();
  }
}
