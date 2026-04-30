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

  /// Preferred source plugin id for chapter listings of this manga
  /// (e.g. `mangadex`, `olympus`). When null, the composite repository
  /// fans out to every registered plugin and dedupes across them. When
  /// non-null, the composite restricts the fan-out to the picked
  /// plugin only.
  TextColumn get preferredSourceId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mangaAnilistId};
}
