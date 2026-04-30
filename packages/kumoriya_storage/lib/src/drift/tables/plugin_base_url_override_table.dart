import 'package:drift/drift.dart';

/// Per-plugin user override of the active base URL.
///
/// Manifest-declared mirrors stay the source of truth; this table only
/// records that the user has promoted one URL ahead of the manifest list
/// (e.g. to bypass a regional block or to point at a self-hosted mirror).
///
/// One row per plugin. Absent row means "use manifest default order".
class PluginBaseUrlOverrideTable extends Table {
  @override
  String get tableName => 'plugin_base_url_override';

  TextColumn get pluginId => text()();
  TextColumn get baseUrl => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {pluginId};
}
