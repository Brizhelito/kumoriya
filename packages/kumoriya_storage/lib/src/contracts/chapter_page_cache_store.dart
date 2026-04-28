import 'package:kumoriya_core/kumoriya_core.dart';

final class ChapterPageCacheEntry {
  const ChapterPageCacheEntry({
    required this.sourceId,
    required this.sourceChapterId,
    required this.pageIndex,
    required this.imageUrl,
    required this.updatedAt,
    this.headers = const <String, String>{},
    this.localPath,
    this.bytes,
    this.width,
    this.height,
    this.expiresAt,
  });

  final String sourceId;
  final String sourceChapterId;
  final int pageIndex;
  final String imageUrl;
  final Map<String, String> headers;
  final String? localPath;
  final int? bytes;
  final int? width;
  final int? height;
  final DateTime? expiresAt;
  final DateTime updatedAt;
}

abstract interface class ChapterPageCacheStore {
  Future<Result<void, KumoriyaError>> upsert(ChapterPageCacheEntry entry);

  Future<Result<void, KumoriyaError>> upsertAll(
    List<ChapterPageCacheEntry> entries,
  );

  Future<Result<List<ChapterPageCacheEntry>, KumoriyaError>> listForChapter(
    String sourceId,
    String sourceChapterId,
  );

  Future<Result<ChapterPageCacheEntry?, KumoriyaError>> get(
    String sourceId,
    String sourceChapterId,
    int pageIndex,
  );

  /// Deletes rows whose `expiresAt < now`. Returns number of rows
  /// removed; the caller is responsible for deleting the underlying
  /// files on disk.
  Future<Result<int, KumoriyaError>> evictExpired(DateTime now);

  /// Total bytes accounted for by the cache index. Returns 0 when
  /// the index has no `bytes` populated.
  Future<Result<int, KumoriyaError>> totalBytes();

  Future<Result<void, KumoriyaError>> deleteForChapter(
    String sourceId,
    String sourceChapterId,
  );
}
