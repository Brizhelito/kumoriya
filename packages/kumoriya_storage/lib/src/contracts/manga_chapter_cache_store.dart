import 'package:kumoriya_core/kumoriya_core.dart';

/// Source-side chapter row, identified by `(sourceId, sourceChapterId)`.
///
/// `mangaAnilistId` and `sourceMangaId` are duplicated so chapter rows
/// can survive matching corrections without losing their source-side
/// anchor.
final class MangaChapterCacheEntry {
  const MangaChapterCacheEntry({
    required this.sourceId,
    required this.sourceChapterId,
    required this.mangaAnilistId,
    required this.sourceMangaId,
    required this.number,
    required this.updatedAt,
    this.title,
    this.volume,
    this.language = 'en',
    this.scanlator,
    this.publishedAt,
    this.pageCount,
  });

  final String sourceId;
  final String sourceChapterId;
  final int mangaAnilistId;
  final String sourceMangaId;
  final double number;
  final String? title;
  final int? volume;
  final String language;
  final String? scanlator;
  final DateTime? publishedAt;
  final int? pageCount;
  final DateTime updatedAt;
}

abstract interface class MangaChapterCacheStore {
  /// Bulk insert/update; rows are matched by `(sourceId, sourceChapterId)`.
  Future<Result<void, KumoriyaError>> upsertAll(
    List<MangaChapterCacheEntry> entries,
  );

  Future<Result<MangaChapterCacheEntry?, KumoriyaError>> get(
    String sourceId,
    String sourceChapterId,
  );

  /// Returns chapters for [mangaAnilistId] sorted by `number` ascending.
  /// Optionally filtered by [language] (BCP-47).
  Future<Result<List<MangaChapterCacheEntry>, KumoriyaError>> listForManga(
    int mangaAnilistId, {
    String? language,
  });

  /// Replaces the cached chapter set for `(mangaAnilistId, sourceId,
  /// sourceMangaId)` with [entries]. Existing rows with the same key
  /// triple that are not in [entries] are deleted.
  Future<Result<void, KumoriyaError>> replaceForManga({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceMangaId,
    required List<MangaChapterCacheEntry> entries,
  });

  Future<Result<void, KumoriyaError>> deleteForManga(int mangaAnilistId);
}
