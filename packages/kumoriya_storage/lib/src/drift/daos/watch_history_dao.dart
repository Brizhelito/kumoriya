import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/watch_history_table.dart';

part 'watch_history_dao.g.dart';

@DriftAccessor(tables: [WatchHistoryTable])
class WatchHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$WatchHistoryDaoMixin {
  WatchHistoryDao(super.db);

  Future<void> upsertHistory(WatchHistoryTableCompanion entry) {
    return into(watchHistoryTable).insertOnConflictUpdate(entry);
  }

  Future<List<WatchHistoryTableData>> getRecentHistory(int limit) {
    return (select(watchHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.lastAccessedAt)])
          ..limit(limit))
        .get();
  }

  Future<List<WatchHistoryTableData>> getAllHistory() {
    return (select(
      watchHistoryTable,
    )..orderBy([(t) => OrderingTerm.desc(t.lastAccessedAt)])).get();
  }

  Future<int> deleteHistoryEntry(int anilistId) {
    return (delete(
      watchHistoryTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }

  Future<int> clearAllHistory() {
    return delete(watchHistoryTable).go();
  }
}
