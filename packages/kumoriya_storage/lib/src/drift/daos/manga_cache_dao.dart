import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/manga_cache_table.dart';

part 'manga_cache_dao.g.dart';

@DriftAccessor(tables: [MangaCacheTable])
class MangaCacheDao extends DatabaseAccessor<AppDatabase>
    with _$MangaCacheDaoMixin {
  MangaCacheDao(super.db);

  Future<void> upsert(MangaCacheTableCompanion entry) {
    return into(mangaCacheTable).insertOnConflictUpdate(entry);
  }

  Future<MangaCacheTableData?> get(int anilistId) {
    return (select(mangaCacheTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> remove(int anilistId) {
    return (delete(
      mangaCacheTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }

  Future<int> deleteOlderThan(int epochMs) {
    return (delete(
      mangaCacheTable,
    )..where((t) => t.updatedAt.isSmallerThanValue(epochMs))).go();
  }

  Future<List<MangaCacheTableData>> getRecent({
    required int limit,
    required int offset,
  }) {
    return (select(mangaCacheTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<List<MangaCacheTableData>> getByStatus(
    String status, {
    required int limit,
    required int offset,
  }) {
    return (select(mangaCacheTable)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<List<MangaCacheTableData>> searchByTitle(
    String query, {
    required int limit,
    required int offset,
  }) {
    final pattern = '%$query%';
    return (select(mangaCacheTable)
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

  Future<List<MangaCacheTableData>> getByIds(List<int> ids) {
    return (select(mangaCacheTable)..where((t) => t.anilistId.isIn(ids))).get();
  }
}
