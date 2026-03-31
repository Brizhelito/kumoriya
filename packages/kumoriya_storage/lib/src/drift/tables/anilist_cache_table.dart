import 'package:drift/drift.dart';

class AnilistCacheTable extends Table {
  @override
  String get tableName => 'anilist_cache';

  IntColumn get anilistId => integer()();
  TextColumn get titleRomaji => text()();
  TextColumn get titleEnglish => text().nullable()();
  TextColumn get titleNative => text().nullable()();
  TextColumn get synonyms => text().nullable()();
  TextColumn get coverImageUrl => text().nullable()();
  TextColumn get bannerImageUrl => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get season => text().nullable()();
  IntColumn get averageScore => integer().nullable()();
  IntColumn get popularity => integer().nullable()();
  TextColumn get genres => text().nullable()();
  TextColumn get synopsis => text().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get releaseYear => integer().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get nextAiringEpisode => integer().nullable()();
  IntColumn get nextAiringAt => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
