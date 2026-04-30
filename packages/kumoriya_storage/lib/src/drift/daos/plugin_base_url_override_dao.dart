import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/plugin_base_url_override_table.dart';

part 'plugin_base_url_override_dao.g.dart';

@DriftAccessor(tables: [PluginBaseUrlOverrideTable])
class PluginBaseUrlOverrideDao extends DatabaseAccessor<AppDatabase>
    with _$PluginBaseUrlOverrideDaoMixin {
  PluginBaseUrlOverrideDao(super.db);

  Future<List<PluginBaseUrlOverrideTableData>> getAllOverrides() {
    return select(pluginBaseUrlOverrideTable).get();
  }

  Future<PluginBaseUrlOverrideTableData?> getOverride(String pluginId) {
    return (select(pluginBaseUrlOverrideTable)
          ..where((t) => t.pluginId.equals(pluginId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> setOverride({
    required String pluginId,
    required String baseUrl,
    required DateTime updatedAt,
  }) {
    return into(pluginBaseUrlOverrideTable).insertOnConflictUpdate(
      PluginBaseUrlOverrideTableCompanion(
        pluginId: Value(pluginId),
        baseUrl: Value(baseUrl),
        updatedAt: Value(updatedAt.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> clearOverride(String pluginId) {
    return (delete(
      pluginBaseUrlOverrideTable,
    )..where((t) => t.pluginId.equals(pluginId))).go();
  }
}
