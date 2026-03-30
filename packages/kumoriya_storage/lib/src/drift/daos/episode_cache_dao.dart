import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/episode_catalog_cache_table.dart';

part 'episode_cache_dao.g.dart';

@DriftAccessor(tables: [EpisodeCatalogCacheTable])
class EpisodeCacheDao extends DatabaseAccessor<AppDatabase>
    with _$EpisodeCacheDaoMixin {
  EpisodeCacheDao(super.db);

  Future<void> upsertAll(List<EpisodeCatalogCacheTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(episodeCatalogCacheTable, rows);
    });
  }

  Future<List<EpisodeCatalogCacheTableData>> getAllForAnime(int anilistId) {
    return (select(episodeCatalogCacheTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..orderBy([(t) => OrderingTerm.asc(t.episodeNumber)]))
        .get();
  }

  Future<void> deleteAllForAnime(int anilistId) {
    return (delete(
      episodeCatalogCacheTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }
}
