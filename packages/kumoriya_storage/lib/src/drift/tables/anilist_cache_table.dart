import 'package:drift/drift.dart';

class AnilistCacheTable extends Table {
  @override
  String get tableName => 'anilist_cache';

  IntColumn get anilistId => integer()();
  TextColumn get titleRomaji => text()();
  TextColumn get titleEnglish => text().nullable()();
  TextColumn get titleNative => text().nullable()();
  TextColumn get coverImageUrl => text().nullable()();
  TextColumn get bannerImageUrl => text().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get averageScore => integer().nullable()();
  TextColumn get genres => text().nullable()();
  TextColumn get synopsis => text().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get releaseYear => integer().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
