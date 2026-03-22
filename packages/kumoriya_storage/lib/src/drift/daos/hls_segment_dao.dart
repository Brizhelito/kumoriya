import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/hls_segment_table.dart';

part 'hls_segment_dao.g.dart';

@DriftAccessor(tables: [HlsSegmentTable])
class HlsSegmentDao extends DatabaseAccessor<AppDatabase>
    with _$HlsSegmentDaoMixin {
  HlsSegmentDao(super.db);

  /// Batch-insert all segments for a task using a single transaction.
  Future<void> insertAll(List<HlsSegmentTableCompanion> entries) {
    return batch((b) => b.insertAll(hlsSegmentTable, entries));
  }

  /// All segments for a task, ordered by index for correct concatenation.
  Future<List<HlsSegmentTableData>> getByTask(String downloadTaskId) {
    return (select(hlsSegmentTable)
          ..where((t) => t.downloadTaskId.equals(downloadTaskId))
          ..orderBy([(t) => OrderingTerm.asc(t.segmentIndex)]))
        .get();
  }

  /// Update a single segment via upsert (insertOnConflictUpdate).
  Future<void> updateSegment(HlsSegmentTableCompanion entry) {
    return into(hlsSegmentTable).insertOnConflictUpdate(entry);
  }

  /// Batch-update multiple segments in a single transaction.
  Future<void> updateAll(List<HlsSegmentTableCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(hlsSegmentTable, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  /// Delete all segments for a task (cleanup after completion or cancel).
  Future<void> deleteByTask(String downloadTaskId) {
    return (delete(
      hlsSegmentTable,
    )..where((t) => t.downloadTaskId.equals(downloadTaskId))).go();
  }

  /// Count segments matching a given status for a task.
  Future<int> countByStatus(String downloadTaskId, String status) async {
    final count = hlsSegmentTable.id.count();
    final query = selectOnly(hlsSegmentTable)
      ..addColumns([count])
      ..where(
        hlsSegmentTable.downloadTaskId.equals(downloadTaskId) &
            hlsSegmentTable.status.equals(status),
      );
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
