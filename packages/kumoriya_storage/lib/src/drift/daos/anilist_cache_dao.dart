import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/anilist_cache_table.dart';

part 'anilist_cache_dao.g.dart';

@DriftAccessor(tables: [AnilistCacheTable])
class AnilistCacheDao extends DatabaseAccessor<AppDatabase>
    with _$AnilistCacheDaoMixin {
  AnilistCacheDao(super.db);

  Future<void> upsert(AnilistCacheTableCompanion entry) {
    return into(anilistCacheTable).insertOnConflictUpdate(entry);
  }

  Future<AnilistCacheTableData?> get(int anilistId) {
    return (select(anilistCacheTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> remove(int anilistId) {
    return (delete(
      anilistCacheTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }

  Future<int> deleteOlderThan(int epochMs) {
    return (delete(
      anilistCacheTable,
    )..where((t) => t.updatedAt.isSmallerThanValue(epochMs))).go();
  }
}
