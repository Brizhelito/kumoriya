import 'package:drift/drift.dart';

/// Tracks per-segment download state for HLS streams.
///
/// Each row corresponds to one .ts segment parsed from the m3u8 playlist.
/// This enables pause/resume at segment granularity — on resume, only
/// pending or failed segments are re-downloaded, completed ones are skipped.
class HlsSegmentTable extends Table {
  @override
  String get tableName => 'hls_segment';

  /// Deterministic ID: `{downloadTaskId}:seg:{segmentIndex}`.
  TextColumn get id => text()();

  /// FK reference to the parent download_task.id.
  TextColumn get downloadTaskId => text()();

  /// Zero-based position in the playlist — determines concatenation order.
  IntColumn get segmentIndex => integer()();

  /// Absolute URL of the .ts segment.
  TextColumn get url => text()();

  /// Current status: pending | downloading | completed | failed.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Local file path where the segment is stored.
  TextColumn get localPath => text().nullable()();

  /// Byte count of the downloaded segment.
  IntColumn get byteSize => integer().nullable()();

  /// Number of failed retry attempts.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
