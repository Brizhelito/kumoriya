import 'package:drift/drift.dart';

class LibraryEntryTable extends Table {
  @override
  String get tableName => 'library_entry';

  IntColumn get anilistId => integer()();
  IntColumn get addedAt => integer()();
  BoolColumn get notifyNewEpisodes =>
      boolean().withDefault(const Constant(false))();
  // Last episode number for which a notification was sent (null = never notified)
  IntColumn get lastNotifiedEpisode => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
