import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/chapter_page_cache_store.dart';
import 'app_database.dart';
import 'daos/chapter_page_cache_dao.dart';

final class DriftChapterPageCacheStore implements ChapterPageCacheStore {
  DriftChapterPageCacheStore(AppDatabase db) : _dao = ChapterPageCacheDao(db);

  final ChapterPageCacheDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsert(
    ChapterPageCacheEntry entry,
  ) async {
    try {
      await _dao.upsert(_entryToCompanion(entry));
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_upsert_failed',
          message: 'Failed to upsert chapter page cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> upsertAll(
    List<ChapterPageCacheEntry> entries,
  ) async {
    if (entries.isEmpty) return const Success(null);
    try {
      await _dao.upsertAll(entries.map(_entryToCompanion).toList());
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_upsert_failed',
          message: 'Failed to upsert chapter page cache batch: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<ChapterPageCacheEntry>, KumoriyaError>> listForChapter(
    String sourceId,
    String sourceChapterId,
  ) async {
    try {
      final rows = await _dao.listForChapter(sourceId, sourceChapterId);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_query_failed',
          message: 'Failed to list chapter page cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<ChapterPageCacheEntry?, KumoriyaError>> get(
    String sourceId,
    String sourceChapterId,
    int pageIndex,
  ) async {
    try {
      final row = await _dao.get(sourceId, sourceChapterId, pageIndex);
      return Success(row != null ? _rowToEntry(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_read_failed',
          message: 'Failed to read chapter page cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> evictExpired(DateTime now) async {
    try {
      final count = await _dao.evictExpired(now.millisecondsSinceEpoch);
      return Success(count);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_evict_failed',
          message: 'Failed to evict expired chapter page cache rows: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> totalBytes() async {
    try {
      return Success(await _dao.totalBytes());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_total_bytes_failed',
          message: 'Failed to compute total chapter page cache bytes: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteForChapter(
    String sourceId,
    String sourceChapterId,
  ) async {
    try {
      await _dao.deleteForChapter(sourceId, sourceChapterId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.chapter_page_cache_delete_failed',
          message: 'Failed to delete chapter page cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  ChapterPageCacheTableCompanion _entryToCompanion(ChapterPageCacheEntry e) {
    return ChapterPageCacheTableCompanion(
      sourceId: Value(e.sourceId),
      sourceChapterId: Value(e.sourceChapterId),
      pageIndex: Value(e.pageIndex),
      imageUrl: Value(e.imageUrl),
      headers: Value(e.headers.isNotEmpty ? jsonEncode(e.headers) : null),
      localPath: Value(e.localPath),
      bytes: Value(e.bytes),
      width: Value(e.width),
      height: Value(e.height),
      expiresAt: Value(e.expiresAt?.millisecondsSinceEpoch),
      updatedAt: Value(e.updatedAt.millisecondsSinceEpoch),
    );
  }

  ChapterPageCacheEntry _rowToEntry(ChapterPageCacheTableData row) {
    Map<String, String> headers = const <String, String>{};
    if (row.headers != null) {
      try {
        final decoded = jsonDecode(row.headers!) as Map<String, dynamic>;
        headers = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        // Ignore malformed headers JSON.
      }
    }
    return ChapterPageCacheEntry(
      sourceId: row.sourceId,
      sourceChapterId: row.sourceChapterId,
      pageIndex: row.pageIndex,
      imageUrl: row.imageUrl,
      headers: headers,
      localPath: row.localPath,
      bytes: row.bytes,
      width: row.width,
      height: row.height,
      expiresAt: row.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.expiresAt!)
          : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
