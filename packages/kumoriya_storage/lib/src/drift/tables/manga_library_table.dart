import 'package:drift/drift.dart';

/// User-saved manga. Mirrors `LibraryEntryTable` (anime) and follows the
/// same "soft-delete via `addedAt = 0` when notify/auto-download are
/// still on" pattern.
class MangaLibraryTable extends Table {
  @override
  String get tableName => 'manga_library';

  IntColumn get mangaAnilistId => integer()();
  IntColumn get addedAt => integer()();

  BoolColumn get notifyNewChapters =>
      boolean().withDefault(const Constant(false))();

  /// Last chapter number for which a notification was sent (null = never).
  RealColumn get lastNotifiedChapter => real().nullable()();

  BoolColumn get autoDownloadNewChapters =>
      boolean().withDefault(const Constant(false))();

  /// BCP-47 preferred language for chapter listings of this manga.
  TextColumn get preferredLanguage => text().nullable()();

  /// Preferred scanlator name/id for chapter listings of this manga.
  TextColumn get preferredScanlator => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mangaAnilistId};
}
