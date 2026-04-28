import 'package:drift/drift.dart';

/// Last-read state per `(manga, source, chapter)` triple.
///
/// `pageIndex` resumes paginated mode; `scrollOffset` resumes vertical
/// webtoon mode (null when not in vertical layout). `chapterNumber` is
/// duplicated from the chapter row so the recents view doesn't have to
/// join.
class MangaProgressTable extends Table {
  @override
  String get tableName => 'manga_progress';

  IntColumn get mangaAnilistId => integer()();
  TextColumn get sourceId => text()();
  TextColumn get sourceChapterId => text()();
  RealColumn get chapterNumber => real()();
  IntColumn get pageIndex => integer().withDefault(const Constant(0))();
  RealColumn get scrollOffset => real().nullable()();

  /// `unread` / `reading` / `completed`.
  TextColumn get readState => text().withDefault(const Constant('unread'))();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    mangaAnilistId,
    sourceId,
    sourceChapterId,
  };
}
