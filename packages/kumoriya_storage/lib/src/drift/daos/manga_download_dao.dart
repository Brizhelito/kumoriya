import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/manga_download_table.dart';

part 'manga_download_dao.g.dart';

@DriftAccessor(tables: [MangaDownloadTable])
class MangaDownloadDao extends DatabaseAccessor<AppDatabase>
    with _$MangaDownloadDaoMixin {
  MangaDownloadDao(super.db);

  Future<void> insertTask(MangaDownloadTableCompanion task) {
    return into(mangaDownloadTable).insertOnConflictUpdate(task);
  }

  Future<void> updateTask(MangaDownloadTableCompanion task) {
    return into(mangaDownloadTable).insertOnConflictUpdate(task);
  }

  Future<MangaDownloadTableData?> getTask(String id) {
    return (select(
      mangaDownloadTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<MangaDownloadTableData?> getTaskByChapter({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  }) {
    return (select(mangaDownloadTable)
          ..where(
            (t) =>
                t.mangaAnilistId.equals(mangaAnilistId) &
                t.sourceId.equals(sourceId) &
                t.sourceChapterId.equals(sourceChapterId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<MangaDownloadTableData>> getTasksByManga(
    int mangaAnilistId, {
    int? limit,
  }) {
    final query = select(mangaDownloadTable)
      ..where((t) => t.mangaAnilistId.equals(mangaAnilistId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<MangaDownloadTableData>> getTasksByStatus(
    String status, {
    int? limit,
    bool ascending = true,
  }) {
    final query = select(mangaDownloadTable)
      ..where((t) => t.status.equals(status))
      ..orderBy([
        (t) => ascending
            ? OrderingTerm.asc(t.createdAt)
            : OrderingTerm.desc(t.createdAt),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<MangaDownloadTableData>> getTasksByStatuses(
    List<String> statuses, {
    int? limit,
    bool ascending = true,
  }) {
    final query = select(mangaDownloadTable)
      ..where((t) => t.status.isIn(statuses))
      ..orderBy([
        (t) => ascending
            ? OrderingTerm.asc(t.createdAt)
            : OrderingTerm.desc(t.createdAt),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<MangaDownloadTableData>> getAllTasks({int? limit}) {
    final query = select(mangaDownloadTable)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<int> deleteTask(String id) {
    return (delete(mangaDownloadTable)..where((t) => t.id.equals(id))).go();
  }
}
