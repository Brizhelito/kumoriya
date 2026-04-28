import 'package:drift/drift.dart';

/// Most-recently-accessed manga, one row per `mangaAnilistId`.
///
/// Mirrors `WatchHistoryTable` (anime). Updated on chapter open; the
/// recent-reads UI reads from this table ordered by `lastAccessedAt`.
class MangaHistoryTable extends Table {
  @override
  String get tableName => 'manga_history';

  IntColumn get mangaAnilistId => integer()();
  RealColumn get lastChapterNumber => real()();
  TextColumn get lastSourceId => text().nullable()();
  TextColumn get lastSourceChapterId => text().nullable()();
  IntColumn get lastPageIndex => integer().nullable()();
  IntColumn get lastAccessedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {mangaAnilistId};
}
