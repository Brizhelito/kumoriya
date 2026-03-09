import 'package:drift/drift.dart';

class WatchHistoryTable extends Table {
  @override
  String get tableName => 'watch_history';

  IntColumn get anilistId => integer()();
  RealColumn get lastEpisodeNumber => real()();
  TextColumn get lastSourcePluginId => text().nullable()();
  IntColumn get lastAccessedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
