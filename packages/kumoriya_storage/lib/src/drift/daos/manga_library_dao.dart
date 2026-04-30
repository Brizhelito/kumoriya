import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/manga_library_table.dart';

part 'manga_library_dao.g.dart';

@DriftAccessor(tables: [MangaLibraryTable])
class MangaLibraryDao extends DatabaseAccessor<AppDatabase>
    with _$MangaLibraryDaoMixin {
  MangaLibraryDao(super.db);

  Future<MangaLibraryTableData?> getEntry(int mangaAnilistId) {
    return (select(
      mangaLibraryTable,
    )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).getSingleOrNull();
  }

  Future<void> addFavorite(int mangaAnilistId, int addedAt) {
    return into(mangaLibraryTable).insertOnConflictUpdate(
      MangaLibraryTableCompanion(
        mangaAnilistId: Value(mangaAnilistId),
        addedAt: Value(addedAt),
      ),
    );
  }

  Future<void> removeFavorite(int mangaAnilistId) {
    return transaction(() async {
      final existing = await getEntry(mangaAnilistId);
      if (existing == null) return;
      final keep =
          existing.notifyNewChapters ||
          existing.autoDownloadNewChapters ||
          existing.preferredLanguage != null ||
          existing.preferredScanlator != null;
      if (keep) {
        await (update(mangaLibraryTable)
              ..where((t) => t.mangaAnilistId.equals(mangaAnilistId)))
            .write(const MangaLibraryTableCompanion(addedAt: Value(0)));
        return;
      }
      await (delete(
        mangaLibraryTable,
      )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).go();
    });
  }

  Future<List<int>> getFavoriteMangaIds() {
    final query = selectOnly(mangaLibraryTable)
      ..addColumns([mangaLibraryTable.mangaAnilistId])
      ..where(mangaLibraryTable.addedAt.isBiggerThanValue(0));
    return query
        .map((row) => row.read(mangaLibraryTable.mangaAnilistId)!)
        .get();
  }

  Future<void> updateSubscription(int mangaAnilistId, {required bool notify}) {
    return transaction(() async {
      final existing = await getEntry(mangaAnilistId);
      if (existing == null) {
        if (!notify) return;
        await into(mangaLibraryTable).insert(
          MangaLibraryTableCompanion(
            mangaAnilistId: Value(mangaAnilistId),
            addedAt: const Value(0),
            notifyNewChapters: Value(notify),
          ),
        );
        return;
      }
      await (update(mangaLibraryTable)
            ..where((t) => t.mangaAnilistId.equals(mangaAnilistId)))
          .write(MangaLibraryTableCompanion(notifyNewChapters: Value(notify)));
      if (!notify &&
          existing.addedAt <= 0 &&
          !existing.autoDownloadNewChapters &&
          existing.preferredLanguage == null &&
          existing.preferredScanlator == null) {
        await (delete(
          mangaLibraryTable,
        )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).go();
      }
    });
  }

  Future<List<int>> getSubscribedMangaIds() {
    final query = selectOnly(mangaLibraryTable)
      ..addColumns([mangaLibraryTable.mangaAnilistId])
      ..where(mangaLibraryTable.notifyNewChapters.equals(true));
    return query
        .map((row) => row.read(mangaLibraryTable.mangaAnilistId)!)
        .get();
  }

  Future<List<MangaLibraryTableData>> getTrackedEntries() {
    return (select(mangaLibraryTable)
          ..where(
            (t) =>
                t.notifyNewChapters.equals(true) |
                t.autoDownloadNewChapters.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
        .get();
  }

  Future<void> updateLastNotifiedChapter(
    int mangaAnilistId,
    double chapterNumber,
  ) {
    return (update(
      mangaLibraryTable,
    )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).write(
      MangaLibraryTableCompanion(lastNotifiedChapter: Value(chapterNumber)),
    );
  }

  Future<void> updateAutoDownload(
    int mangaAnilistId, {
    required bool autoDownload,
  }) {
    return transaction(() async {
      final existing = await getEntry(mangaAnilistId);
      if (existing == null) {
        if (!autoDownload) return;
        await into(mangaLibraryTable).insert(
          MangaLibraryTableCompanion(
            mangaAnilistId: Value(mangaAnilistId),
            addedAt: const Value(0),
            autoDownloadNewChapters: Value(autoDownload),
          ),
        );
        return;
      }
      await (update(
        mangaLibraryTable,
      )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).write(
        MangaLibraryTableCompanion(
          autoDownloadNewChapters: Value(autoDownload),
        ),
      );
      if (!autoDownload &&
          existing.addedAt <= 0 &&
          !existing.notifyNewChapters &&
          existing.preferredLanguage == null &&
          existing.preferredScanlator == null) {
        await (delete(
          mangaLibraryTable,
        )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).go();
      }
    });
  }

  Future<List<int>> getAutoDownloadMangaIds() {
    final query = selectOnly(mangaLibraryTable)
      ..addColumns([mangaLibraryTable.mangaAnilistId])
      ..where(mangaLibraryTable.autoDownloadNewChapters.equals(true));
    return query
        .map((row) => row.read(mangaLibraryTable.mangaAnilistId)!)
        .get();
  }

  Future<void> setPreferredLanguage(int mangaAnilistId, String? language) {
    return transaction(() async {
      final existing = await getEntry(mangaAnilistId);
      if (existing == null) {
        if (language == null) return;
        await into(mangaLibraryTable).insert(
          MangaLibraryTableCompanion(
            mangaAnilistId: Value(mangaAnilistId),
            addedAt: const Value(0),
            preferredLanguage: Value(language),
          ),
        );
        return;
      }
      await (update(
        mangaLibraryTable,
      )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).write(
        MangaLibraryTableCompanion(preferredLanguage: Value(language)),
      );
    });
  }

  Future<void> setPreferredScanlator(int mangaAnilistId, String? scanlator) {
    return transaction(() async {
      final existing = await getEntry(mangaAnilistId);
      if (existing == null) {
        if (scanlator == null) return;
        await into(mangaLibraryTable).insert(
          MangaLibraryTableCompanion(
            mangaAnilistId: Value(mangaAnilistId),
            addedAt: const Value(0),
            preferredScanlator: Value(scanlator),
          ),
        );
        return;
      }
      await (update(
        mangaLibraryTable,
      )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).write(
        MangaLibraryTableCompanion(preferredScanlator: Value(scanlator)),
      );
    });
  }

  Future<void> setPreferredSourceId(int mangaAnilistId, String? sourceId) {
    return transaction(() async {
      final existing = await getEntry(mangaAnilistId);
      if (existing == null) {
        if (sourceId == null) return;
        await into(mangaLibraryTable).insert(
          MangaLibraryTableCompanion(
            mangaAnilistId: Value(mangaAnilistId),
            addedAt: const Value(0),
            preferredSourceId: Value(sourceId),
          ),
        );
        return;
      }
      await (update(
        mangaLibraryTable,
      )..where((t) => t.mangaAnilistId.equals(mangaAnilistId))).write(
        MangaLibraryTableCompanion(preferredSourceId: Value(sourceId)),
      );
    });
  }

  Future<int> clearAll() {
    return delete(mangaLibraryTable).go();
  }
}
