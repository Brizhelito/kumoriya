import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/manga_chapter_table.dart';

part 'manga_chapter_dao.g.dart';

@DriftAccessor(tables: [MangaChapterTable])
class MangaChapterDao extends DatabaseAccessor<AppDatabase>
    with _$MangaChapterDaoMixin {
  MangaChapterDao(super.db);

  Future<void> upsertAll(List<MangaChapterTableCompanion> entries) {
    return batch((b) {
      b.insertAllOnConflictUpdate(mangaChapterTable, entries);
    });
  }

  Future<MangaChapterTableData?> get(String sourceId, String sourceChapterId) {
    return (select(mangaChapterTable)
          ..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                t.sourceChapterId.equals(sourceChapterId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<MangaChapterTableData>> listForManga(
    int mangaAnilistId, {
    String? language,
  }) {
    final query = select(mangaChapterTable)
      ..where((t) => t.mangaAnilistId.equals(mangaAnilistId))
      ..orderBy([(t) => OrderingTerm.asc(t.number)]);
    if (language != null) {
      query.where((t) => t.language.equals(language));
    }
    return query.get();
  }

  /// Replaces the cached chapter set for a `(mangaAnilistId, sourceId,
  /// sourceMangaId)` triple with [entries] in a single transaction.
  Future<void> replaceForManga({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceMangaId,
    required List<MangaChapterTableCompanion> entries,
  }) {
    return transaction(() async {
      await (delete(mangaChapterTable)..where(
            (t) =>
                t.mangaAnilistId.equals(mangaAnilistId) &
                t.sourceId.equals(sourceId) &
                t.sourceMangaId.equals(sourceMangaId),
          ))
          .go();
      if (entries.isEmpty) return;
      await batch((b) {
        b.insertAll(mangaChapterTable, entries);
      });
    });
  }

  Future<int> deleteForManga(int mangaAnilistId) {
    return (delete(
      mangaChapterTable,
    )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).go();
  }
}
