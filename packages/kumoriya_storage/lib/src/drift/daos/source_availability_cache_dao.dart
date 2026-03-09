import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/source_availability_cache_table.dart';

part 'source_availability_cache_dao.g.dart';

@DriftAccessor(tables: [SourceAvailabilityCacheTable])
class SourceAvailabilityCacheDao extends DatabaseAccessor<AppDatabase>
    with _$SourceAvailabilityCacheDaoMixin {
  SourceAvailabilityCacheDao(super.db);

  Future<List<SourceAvailabilityCacheTableData>> getAvailability(
    int anilistId,
  ) {
    return (select(sourceAvailabilityCacheTable)
          ..where((t) => t.anilistId.equals(anilistId))
          ..orderBy([(t) => OrderingTerm.asc(t.sourcePluginId)]))
        .get();
  }

  Future<void> replaceAvailability(
    int anilistId,
    List<SourceAvailabilityCacheTableCompanion> entries,
  ) {
    return transaction(() async {
      await (delete(
        sourceAvailabilityCacheTable,
      )..where((t) => t.anilistId.equals(anilistId))).go();

      if (entries.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(sourceAvailabilityCacheTable, entries);
        });
      }
    });
  }

  Future<void> clearAvailability(int anilistId) {
    return (delete(
      sourceAvailabilityCacheTable,
    )..where((t) => t.anilistId.equals(anilistId))).go();
  }
}
