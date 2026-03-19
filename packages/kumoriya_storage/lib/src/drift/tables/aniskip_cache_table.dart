import 'package:drift/drift.dart';

class AniSkipCacheTable extends Table {
  @override
  String get tableName => 'aniskip_cache';

  IntColumn get anilistId => integer()();

  IntColumn get episodeNumber => integer()();

  TextColumn get payloadJson => text()();

  IntColumn get updatedAt => integer()();

  IntColumn get requestedEpisodeLengthSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    anilistId,
    episodeNumber,
  };
}
