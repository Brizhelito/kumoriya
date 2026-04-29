import 'dart:convert';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// Wraps a [MangaProgressStore] so chapter-progress and read-history
/// writes are mirrored into the sync queue when the user is
/// authenticated. Mirrors `SyncAwareProgressStore` for the anime side.
///
/// Until the backend ships manga endpoints (Slice 10C-2), entries
/// stay in `pending` and `HttpSyncService` filters them out.
final class SyncAwareMangaProgressStore implements MangaProgressStore {
  SyncAwareMangaProgressStore({
    required MangaProgressStore inner,
    required SyncQueueStore syncQueue,
    required bool Function() isAuthenticated,
    void Function()? onEnqueued,
  }) : _inner = inner,
       _syncQueue = syncQueue,
       _isAuthenticated = isAuthenticated,
       _onEnqueued = onEnqueued;

  final MangaProgressStore _inner;
  final SyncQueueStore _syncQueue;
  final bool Function() _isAuthenticated;
  final void Function()? _onEnqueued;

  // ---------------------------------------------------------------------------
  // Writes — every successful write is enqueued for the authenticated user.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, KumoriyaError>> upsert(
    MangaChapterProgress progress,
  ) async {
    final result = await _inner.upsert(progress);
    if (result.isSuccess && _isAuthenticated()) {
      await _syncQueue.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaChapterProgress,
          entityKey: jsonEncode({
            'mangaAnilistId': progress.mangaAnilistId,
            'sourceId': progress.sourceId,
            'sourceChapterId': progress.sourceChapterId,
          }),
          payload: jsonEncode({
            'manga_anilist_id': progress.mangaAnilistId,
            'source_id': progress.sourceId,
            'source_chapter_id': progress.sourceChapterId,
            'chapter_number': progress.chapterNumber,
            'page_index': progress.pageIndex,
            'scroll_offset': progress.scrollOffset,
            'read_state': progress.readState.name,
            'updated_at': progress.updatedAt.millisecondsSinceEpoch,
          }),
          createdAt: DateTime.now(),
          status: SyncQueueEntryStatus.pending,
        ),
      );
      _onEnqueued?.call();
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> upsertReadHistory({
    required int mangaAnilistId,
    required double chapterNumber,
    String? lastSourceId,
    String? lastSourceChapterId,
    int? lastPageIndex,
    DateTime? lastAccessedAt,
  }) async {
    final effectiveAccessedAt = lastAccessedAt ?? DateTime.now();
    final result = await _inner.upsertReadHistory(
      mangaAnilistId: mangaAnilistId,
      chapterNumber: chapterNumber,
      lastSourceId: lastSourceId,
      lastSourceChapterId: lastSourceChapterId,
      lastPageIndex: lastPageIndex,
      lastAccessedAt: effectiveAccessedAt,
    );
    if (result.isSuccess && _isAuthenticated()) {
      await _syncQueue.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaReadHistory,
          entityKey: jsonEncode({'mangaAnilistId': mangaAnilistId}),
          payload: jsonEncode({
            'manga_anilist_id': mangaAnilistId,
            'last_chapter_number': chapterNumber,
            'last_source_id': lastSourceId,
            'last_source_chapter_id': lastSourceChapterId,
            'last_page_index': lastPageIndex,
            'last_accessed_at': effectiveAccessedAt.millisecondsSinceEpoch,
          }),
          createdAt: effectiveAccessedAt,
          status: SyncQueueEntryStatus.pending,
        ),
      );
      _onEnqueued?.call();
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> deleteHistoryEntry(
    int mangaAnilistId,
  ) async {
    final result = await _inner.deleteHistoryEntry(mangaAnilistId);
    if (result.isSuccess && _isAuthenticated()) {
      final now = DateTime.now();
      await _syncQueue.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaReadHistoryDeletion,
          entityKey: jsonEncode({'mangaAnilistId': mangaAnilistId}),
          payload: jsonEncode({
            'manga_anilist_id': mangaAnilistId,
            'updated_at': now.millisecondsSinceEpoch,
          }),
          createdAt: now,
          status: SyncQueueEntryStatus.pending,
        ),
      );
      _onEnqueued?.call();
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Pass-through reads / non-syncable writes.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<MangaChapterProgress?, KumoriyaError>> getProgress({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  }) => _inner.getProgress(
    mangaAnilistId: mangaAnilistId,
    sourceId: sourceId,
    sourceChapterId: sourceChapterId,
  );

  @override
  Future<Result<MangaChapterProgress?, KumoriyaError>> getLatestProgress(
    int mangaAnilistId,
  ) => _inner.getLatestProgress(mangaAnilistId);

  @override
  Future<Result<List<MangaChapterProgress>, KumoriyaError>> getAllProgress(
    int mangaAnilistId,
  ) => _inner.getAllProgress(mangaAnilistId);

  @override
  Future<Result<List<MangaReadHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) => _inner.getRecentHistory(limit: limit);

  // Bulk wipes are local-only (logout flow); they must not leak to
  // the server that owns the account being signed out of.
  @override
  Future<Result<void, KumoriyaError>> clearAllHistory() =>
      _inner.clearAllHistory();

  @override
  Future<Result<void, KumoriyaError>> clearAllProgress() =>
      _inner.clearAllProgress();
}
