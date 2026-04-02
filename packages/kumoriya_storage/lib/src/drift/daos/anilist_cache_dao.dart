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

  Future<List<AnilistCacheTableData>> getRecent({
    required int limit,
    required int offset,
  }) {
    return (select(anilistCacheTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<List<AnilistCacheTableData>> getByStatus(
    String status, {
    required int limit,
    required int offset,
  }) {
    return (select(anilistCacheTable)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<List<AnilistCacheTableData>> getByYearAndStatus(
    int year, {
    String? status,
    required int limit,
    required int offset,
  }) {
    return (select(anilistCacheTable)
          ..where((t) {
            final yearFilter = t.releaseYear.equals(year);
            if (status != null) {
              return yearFilter & t.status.equals(status);
            }
            return yearFilter;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.averageScore)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<List<AnilistCacheTableData>> searchByTitle(
    String query, {
    required int limit,
    required int offset,
  }) {
    final pattern = '%$query%';
    return (select(anilistCacheTable)
          ..where(
            (t) =>
                t.titleRomaji.like(pattern) |
                t.titleEnglish.like(pattern) |
                t.titleNative.like(pattern),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.averageScore)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<List<AnilistCacheTableData>> getByIds(List<int> ids) {
    return (select(
      anilistCacheTable,
    )..where((t) => t.anilistId.isIn(ids))).get();
  }
}
