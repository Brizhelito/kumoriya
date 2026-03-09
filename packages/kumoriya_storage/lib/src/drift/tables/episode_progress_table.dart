import 'package:drift/drift.dart';

class EpisodeProgressTable extends Table {
  @override
  String get tableName => 'episode_progress';

  IntColumn get anilistId => integer()();
  RealColumn get episodeNumber => real()();
  IntColumn get positionSeconds => integer()();
  IntColumn get totalDurationSeconds => integer().nullable()();
  TextColumn get watchState =>
      text().withDefault(const Constant('unwatched'))();
  TextColumn get lastSourcePluginId => text().nullable()();
  TextColumn get lastServerName => text().nullable()();
  TextColumn get lastResolverPluginId => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId, episodeNumber};
}
