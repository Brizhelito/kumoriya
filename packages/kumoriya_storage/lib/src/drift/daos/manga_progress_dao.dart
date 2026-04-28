import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/manga_history_table.dart';
import '../tables/manga_progress_table.dart';

part 'manga_progress_dao.g.dart';

@DriftAccessor(tables: [MangaProgressTable, MangaHistoryTable])
class MangaProgressDao extends DatabaseAccessor<AppDatabase>
    with _$MangaProgressDaoMixin {
  MangaProgressDao(super.db);

  Future<void> upsertProgress(MangaProgressTableCompanion entry) {
    return into(mangaProgressTable).insertOnConflictUpdate(entry);
  }

  Future<void> upsertHistory(MangaHistoryTableCompanion entry) {
    return into(mangaHistoryTable).insertOnConflictUpdate(entry);
  }

  Future<MangaProgressTableData?> getProgress({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  }) {
    return (select(mangaProgressTable)
          ..where(
            (t) =>
                t.mangaAnilistId.equals(mangaAnilistId) &
                t.sourceId.equals(sourceId) &
                t.sourceChapterId.equals(sourceChapterId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<MangaProgressTableData?> getLatestProgress(int mangaAnilistId) {
    return (select(mangaProgressTable)
          ..where((t) => t.mangaAnilistId.equals(mangaAnilistId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<MangaProgressTableData>> getAllProgress(int mangaAnilistId) {
    return (select(mangaProgressTable)
          ..where((t) => t.mangaAnilistId.equals(mangaAnilistId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<List<MangaHistoryTableData>> getRecentHistory({required int limit}) {
    return (select(mangaHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastAccessedAt)])
          ..limit(limit))
        .get();
  }

  Future<int> deleteHistoryEntry(int mangaAnilistId) {
    return (delete(
      mangaHistoryTable,
    )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).go();
  }

  Future<int> clearAllHistory() {
    return delete(mangaHistoryTable).go();
  }

  Future<int> clearAllProgress() {
    return delete(mangaProgressTable).go();
  }
}
