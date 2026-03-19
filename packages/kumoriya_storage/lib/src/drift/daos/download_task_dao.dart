import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/download_task_table.dart';

part 'download_task_dao.g.dart';

@DriftAccessor(tables: [DownloadTaskTable])
class DownloadTaskDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadTaskDaoMixin {
  DownloadTaskDao(super.db);

  Future<void> insertTask(DownloadTaskTableCompanion entry) {
    return into(downloadTaskTable).insert(entry);
  }

  Future<void> updateTask(DownloadTaskTableCompanion entry) {
    return into(downloadTaskTable).insertOnConflictUpdate(entry);
  }

  Future<DownloadTaskTableData?> getTask(String id) {
    return (select(downloadTaskTable)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<DownloadTaskTableData?> getTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) {
    return (select(downloadTaskTable)
          ..where(
            (t) =>
                t.anilistId.equals(anilistId) &
                t.episodeNumber.equals(episodeNumber),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<DownloadTaskTableData>> getTasksByAnime(int anilistId) {
    return (select(downloadTaskTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<DownloadTaskTableData>> getTasksByStatus(String status) {
    return (select(downloadTaskTable)
          ..where((t) => t.status.equals(status))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<DownloadTaskTableData>> getAllTasks() {
    return (select(
      downloadTaskTable,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<void> deleteTask(String id) {
    return (delete(downloadTaskTable)..where((t) => t.id.equals(id))).go();
  }
}
