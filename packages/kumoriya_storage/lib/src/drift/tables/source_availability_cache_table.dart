import 'package:drift/drift.dart';

class SourceAvailabilityCacheTable extends Table {
  IntColumn get anilistId => integer()();
  TextColumn get sourcePluginId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    anilistId,
    sourcePluginId,
  };
}
