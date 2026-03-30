import 'package:drift/drift.dart';

class EpisodeCatalogCacheTable extends Table {
  @override
  String get tableName => 'episode_catalog_cache';

  IntColumn get anilistId => integer()();
  RealColumn get episodeNumber => real()();
  TextColumn get title => text()();
  IntColumn get airDate => integer().nullable()();
  BoolColumn get isAired => boolean().withDefault(const Constant(true))();
  BoolColumn get isFiller => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId, episodeNumber};
}
