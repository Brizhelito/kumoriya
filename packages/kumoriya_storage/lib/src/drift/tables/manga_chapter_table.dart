import 'package:drift/drift.dart';

/// Source-side chapter cache. One row per `(sourceId, sourceChapterId)`
/// tuple — the same chapter from a different scanlator/language is a
/// different `sourceChapterId` and gets its own row.
///
/// `number` is `REAL` to preserve fractional chapters (`12.5`,
/// side-stories) which break integer-only assumptions across all
/// current manga aggregators.
class MangaChapterTable extends Table {
  @override
  String get tableName => 'manga_chapter';

  TextColumn get sourceId => text()();
  TextColumn get sourceChapterId => text()();
  IntColumn get mangaAnilistId => integer()();

  /// Source-side opaque manga id (matches the value used by the source
  /// plugin's `getMangaDetail`/`getChapters`). Stored separately from
  /// `mangaAnilistId` so chapter rows survive matching corrections.
  TextColumn get sourceMangaId => text()();

  RealColumn get number => real()();
  TextColumn get title => text().nullable()();
  IntColumn get volume => integer().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get scanlator => text().nullable()();
  IntColumn get publishedAt => integer().nullable()();
  IntColumn get pageCount => integer().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, sourceChapterId};
}
