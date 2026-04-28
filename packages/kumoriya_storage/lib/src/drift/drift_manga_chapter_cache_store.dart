import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/manga_chapter_cache_store.dart';
import 'app_database.dart';
import 'daos/manga_chapter_dao.dart';

final class DriftMangaChapterCacheStore implements MangaChapterCacheStore {
  DriftMangaChapterCacheStore(AppDatabase db) : _dao = MangaChapterDao(db);

  final MangaChapterDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsertAll(
    List<MangaChapterCacheEntry> entries,
  ) async {
    if (entries.isEmpty) return const Success(null);
    try {
      await _dao.upsertAll(entries.map(_entryToCompanion).toList());
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_chapter_upsert_failed',
          message: 'Failed to upsert manga chapters: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<MangaChapterCacheEntry?, KumoriyaError>> get(
    String sourceId,
    String sourceChapterId,
  ) async {
    try {
      final row = await _dao.get(sourceId, sourceChapterId);
      return Success(row != null ? _rowToEntry(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_chapter_read_failed',
          message: 'Failed to read manga chapter: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaChapterCacheEntry>, KumoriyaError>> listForManga(
    int mangaAnilistId, {
    String? language,
  }) async {
    try {
      final rows = await _dao.listForManga(mangaAnilistId, language: language);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_chapter_query_failed',
          message: 'Failed to list manga chapters: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> replaceForManga({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceMangaId,
    required List<MangaChapterCacheEntry> entries,
  }) async {
    try {
      await _dao.replaceForManga(
        mangaAnilistId: mangaAnilistId,
        sourceId: sourceId,
        sourceMangaId: sourceMangaId,
        entries: entries.map(_entryToCompanion).toList(),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_chapter_replace_failed',
          message: 'Failed to replace manga chapters: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteForManga(int mangaAnilistId) async {
    try {
      await _dao.deleteForManga(mangaAnilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_chapter_delete_failed',
          message: 'Failed to delete manga chapters: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  MangaChapterTableCompanion _entryToCompanion(MangaChapterCacheEntry e) {
    return MangaChapterTableCompanion(
      sourceId: Value(e.sourceId),
      sourceChapterId: Value(e.sourceChapterId),
      mangaAnilistId: Value(e.mangaAnilistId),
      sourceMangaId: Value(e.sourceMangaId),
      number: Value(e.number),
      title: Value(e.title),
      volume: Value(e.volume),
      language: Value(e.language),
      scanlator: Value(e.scanlator),
      publishedAt: Value(e.publishedAt?.millisecondsSinceEpoch),
      pageCount: Value(e.pageCount),
      updatedAt: Value(e.updatedAt.millisecondsSinceEpoch),
    );
  }

  MangaChapterCacheEntry _rowToEntry(MangaChapterTableData row) {
    return MangaChapterCacheEntry(
      sourceId: row.sourceId,
      sourceChapterId: row.sourceChapterId,
      mangaAnilistId: row.mangaAnilistId,
      sourceMangaId: row.sourceMangaId,
      number: row.number,
      title: row.title,
      volume: row.volume,
      language: row.language,
      scanlator: row.scanlator,
      publishedAt: row.publishedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.publishedAt!)
          : null,
      pageCount: row.pageCount,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
