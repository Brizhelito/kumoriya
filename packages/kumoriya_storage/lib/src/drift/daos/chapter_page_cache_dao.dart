import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/chapter_page_cache_table.dart';

part 'chapter_page_cache_dao.g.dart';

@DriftAccessor(tables: [ChapterPageCacheTable])
class ChapterPageCacheDao extends DatabaseAccessor<AppDatabase>
    with _$ChapterPageCacheDaoMixin {
  ChapterPageCacheDao(super.db);

  Future<void> upsert(ChapterPageCacheTableCompanion entry) {
    return into(chapterPageCacheTable).insertOnConflictUpdate(entry);
  }

  Future<void> upsertAll(List<ChapterPageCacheTableCompanion> entries) {
    return batch((b) {
      b.insertAllOnConflictUpdate(chapterPageCacheTable, entries);
    });
  }

  Future<List<ChapterPageCacheTableData>> listForChapter(
    String sourceId,
    String sourceChapterId,
  ) {
    return (select(chapterPageCacheTable)
          ..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                t.sourceChapterId.equals(sourceChapterId),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.pageIndex)]))
        .get();
  }

  Future<ChapterPageCacheTableData?> get(
    String sourceId,
    String sourceChapterId,
    int pageIndex,
  ) {
    return (select(chapterPageCacheTable)
          ..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                t.sourceChapterId.equals(sourceChapterId) &
                t.pageIndex.equals(pageIndex),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> evictExpired(int nowMs) {
    return (delete(chapterPageCacheTable)..where(
          (t) =>
              t.expiresAt.isNotNull() & t.expiresAt.isSmallerThanValue(nowMs),
        ))
        .go();
  }

  Future<int> totalBytes() async {
    final sumExp = chapterPageCacheTable.bytes.sum();
    final query = selectOnly(chapterPageCacheTable)..addColumns([sumExp]);
    final row = await query.getSingleOrNull();
    return row?.read(sumExp) ?? 0;
  }

  Future<int> deleteForChapter(String sourceId, String sourceChapterId) {
    return (delete(chapterPageCacheTable)..where(
          (t) =>
              t.sourceId.equals(sourceId) &
              t.sourceChapterId.equals(sourceChapterId),
        ))
        .go();
  }
}
