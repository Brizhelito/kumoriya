import 'dart:convert';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// Wraps a [MangaLibraryStore] so every write is mirrored into the
/// sync queue when the user is authenticated. Mirrors
/// `SyncAwareLibraryStore` for the anime side.
///
/// The Kumoriya Go backend does not yet accept manga library payloads
/// (Slice 10C-2). Until then, entries enqueued here stay `pending` —
/// `HttpSyncService` filters them out before pushing — so the user's
/// writes survive logout/login round-trips and the eventual server
/// rollout drains an already-populated queue.
final class SyncAwareMangaLibraryStore implements MangaLibraryStore {
  SyncAwareMangaLibraryStore({
    required MangaLibraryStore inner,
    required SyncQueueStore syncQueue,
    required bool Function() isAuthenticated,
    void Function()? onEnqueued,
  }) : _inner = inner,
       _syncQueue = syncQueue,
       _isAuthenticated = isAuthenticated,
       _onEnqueued = onEnqueued;

  final MangaLibraryStore _inner;
  final SyncQueueStore _syncQueue;
  final bool Function() _isAuthenticated;
  final void Function()? _onEnqueued;

  // ---------------------------------------------------------------------------
  // Writes — every successful write is enqueued for the authenticated user.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int mangaAnilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  }) async {
    final result = await _inner.setFavorite(
      mangaAnilistId,
      isFavorite: isFavorite,
      addedAt: addedAt,
    );
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(mangaAnilistId);
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> setSubscription(
    int mangaAnilistId, {
    required bool notify,
  }) async {
    final result = await _inner.setSubscription(mangaAnilistId, notify: notify);
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(mangaAnilistId);
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> setAutoDownload(
    int mangaAnilistId, {
    required bool autoDownload,
  }) async {
    final result = await _inner.setAutoDownload(
      mangaAnilistId,
      autoDownload: autoDownload,
    );
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(mangaAnilistId);
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> setPreferredLanguage(
    int mangaAnilistId,
    String? language,
  ) async {
    final result = await _inner.setPreferredLanguage(mangaAnilistId, language);
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(mangaAnilistId);
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> setPreferredScanlator(
    int mangaAnilistId,
    String? scanlator,
  ) async {
    final result = await _inner.setPreferredScanlator(
      mangaAnilistId,
      scanlator,
    );
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(mangaAnilistId);
    }
    return result;
  }

  Future<void> _enqueueLibraryChange(int mangaAnilistId) async {
    final snapshot = await _inner.getEntrySnapshot(mangaAnilistId);
    final entityKey = jsonEncode({'mangaAnilistId': mangaAnilistId});
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    if (snapshot == null) {
      // Local row was fully purged. Queue a deletion intent so the
      // server eventually mirrors the wipe; queue collapse logic will
      // drop any pending upsert for the same id.
      await _syncQueue.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaLibraryEntryDeletion,
          entityKey: entityKey,
          payload: jsonEncode({
            'manga_anilist_id': mangaAnilistId,
            'updated_at': nowMs,
          }),
          createdAt: now,
          status: SyncQueueEntryStatus.pending,
        ),
      );
      _onEnqueued?.call();
      return;
    }

    // `added_at = 0` is the wire signal for "not favorite". The server uses
    // LWW on `updated_at`, so the full snapshot is safe to transmit.
    final addedAtMs = snapshot.isFavorite
        ? (snapshot.addedAt ?? now).millisecondsSinceEpoch
        : 0;

    await _syncQueue.enqueue(
      SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.mangaLibraryEntry,
        entityKey: entityKey,
        payload: jsonEncode({
          'manga_anilist_id': mangaAnilistId,
          'added_at': addedAtMs,
          'notify_new_chapters': snapshot.notifyNewChapters,
          'auto_download_new_chapters': snapshot.autoDownloadNewChapters,
          'preferred_language': snapshot.preferredLanguage,
          'preferred_scanlator': snapshot.preferredScanlator,
          'last_notified_chapter': snapshot.lastNotifiedChapter,
          'updated_at': nowMs,
        }),
        createdAt: now,
        status: SyncQueueEntryStatus.pending,
      ),
    );
    _onEnqueued?.call();
  }

  // ---------------------------------------------------------------------------
  // Pass-through reads / non-syncable writes.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Set<int>, KumoriyaError>> getFavoriteMangaIds() =>
      _inner.getFavoriteMangaIds();

  @override
  Future<Result<Set<int>, KumoriyaError>> getSubscribedMangaIds() =>
      _inner.getSubscribedMangaIds();

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadMangaIds() =>
      _inner.getAutoDownloadMangaIds();

  @override
  Future<Result<Map<int, double?>, KumoriyaError>>
  getTrackedMangaWithLastChapter() => _inner.getTrackedMangaWithLastChapter();

  @override
  Future<Result<void, KumoriyaError>> updateLastNotifiedChapter(
    int mangaAnilistId,
    double chapterNumber,
  ) => _inner.updateLastNotifiedChapter(mangaAnilistId, chapterNumber);

  @override
  Future<MangaLibraryEntrySnapshot?> getEntrySnapshot(int mangaAnilistId) =>
      _inner.getEntrySnapshot(mangaAnilistId);

  // Wipe operations bypass the sync queue intentionally: they are
  // invoked during logout to leave the local DB in an anonymous state,
  // and must not leak deletion intents to the account being signed
  // out of.
  @override
  Future<Result<void, KumoriyaError>> clearAll() => _inner.clearAll();
}
