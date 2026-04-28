import 'package:drift/drift.dart';

/// Index of the per-page disk cache for chapters.
///
/// Bytes live on disk under the app cache directory; this table holds
/// only the metadata (URL, headers, local path, size, optional
/// dimensions, TTL). The reader resolves the right source (cache vs
/// network) by querying this table by `(sourceId, sourceChapterId)`.
class ChapterPageCacheTable extends Table {
  @override
  String get tableName => 'chapter_page_cache';

  TextColumn get sourceId => text()();
  TextColumn get sourceChapterId => text()();
  IntColumn get pageIndex => integer()();
  TextColumn get imageUrl => text()();

  /// JSON-encoded `Map<String, String>` of HTTP headers required to
  /// fetch the image (Referer, Origin, Cookie pinning, etc.).
  TextColumn get headers => text().nullable()();

  /// Path to the cached file relative to the app cache dir, when
  /// downloaded. Null while only the URL is known.
  TextColumn get localPath => text().nullable()();

  IntColumn get bytes => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();

  /// Epoch ms after which the cache row should be evicted; null means
  /// no TTL.
  IntColumn get expiresAt => integer().nullable()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, sourceChapterId, pageIndex};
}
