import 'package:drift/drift.dart';

class LibraryEntryTable extends Table {
  @override
  String get tableName => 'library_entry';

  IntColumn get anilistId => integer()();
  IntColumn get addedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
