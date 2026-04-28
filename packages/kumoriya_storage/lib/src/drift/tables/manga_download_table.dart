import 'package:drift/drift.dart';

/// Durable manga downloads. One row per chapter; on completion the
/// pages are bundled into a CBZ at `cbzPath`.
///
/// Mirrors `DownloadTaskTable` so the existing downloads UI scaffolding
/// (queue, retry, status filters) can be reused with minimal changes.
class MangaDownloadTable extends Table {
  @override
  String get tableName => 'manga_download';

  TextColumn get id => text()();
  IntColumn get mangaAnilistId => integer()();
  TextColumn get sourceId => text()();
  TextColumn get sourceMangaId => text()();
  TextColumn get sourceChapterId => text()();
  RealColumn get chapterNumber => real()();
  IntColumn get volume => integer().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get scanlator => text().nullable()();

  /// Human-readable manga title (used for folder name and UI).
  TextColumn get mangaTitle => text().nullable()();

  /// Human-readable chapter title from the source.
  TextColumn get chapterTitle => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get pageCount => integer().nullable()();
  IntColumn get pagesDownloaded => integer().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get downloadedBytes => integer().nullable()();

  /// Final CBZ path on disk once the chapter is fully downloaded.
  TextColumn get cbzPath => text().nullable()();

  TextColumn get errorMessage => text().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
