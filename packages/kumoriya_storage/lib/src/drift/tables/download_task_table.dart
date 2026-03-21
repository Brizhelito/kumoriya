import 'package:drift/drift.dart';

class DownloadTaskTable extends Table {
  @override
  String get tableName => 'download_task';

  TextColumn get id => text()();
  IntColumn get anilistId => integer()();
  RealColumn get episodeNumber => real()();
  TextColumn get sourceUrl => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get fileName => text().nullable()();
  TextColumn get filePath => text().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get downloadedBytes => integer().nullable()();
  TextColumn get sourcePluginId => text().nullable()();
  TextColumn get serverName => text().nullable()();
  TextColumn get detectedHost => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer().nullable()();

  /// JSON-encoded Map<String, String> of HTTP headers (referer, origin, etc.)
  TextColumn get headers => text().nullable()();

  /// Whether this download is an HLS stream requiring segment download.
  BoolColumn get isHls =>
      boolean().withDefault(const Constant(false)).nullable()();

  /// Human-readable anime title (used for folder name and UI).
  TextColumn get animeTitle => text().nullable()();

  /// Stream quality label (e.g. "1080p", "720p").
  TextColumn get qualityLabel => text().nullable()();

  /// Human-readable episode title from the source.
  TextColumn get episodeTitle => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
