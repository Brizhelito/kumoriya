import 'dart:convert';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// Wraps a [LibraryStore] to automatically enqueue changes to the
/// sync queue when the user is authenticated.
final class SyncAwareLibraryStore implements LibraryStore {
  SyncAwareLibraryStore({
    required LibraryStore inner,
    required SyncQueueStore syncQueue,
    required bool Function() isAuthenticated,
  }) : _inner = inner,
       _syncQueue = syncQueue,
       _isAuthenticated = isAuthenticated;

  final LibraryStore _inner;
  final SyncQueueStore _syncQueue;
  final bool Function() _isAuthenticated;

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  }) async {
    final result = await _inner.setFavorite(
      anilistId,
      isFavorite: isFavorite,
      addedAt: addedAt,
    );
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(anilistId);
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> setSubscription(
    int anilistId, {
    required bool notify,
  }) async {
    final result = await _inner.setSubscription(anilistId, notify: notify);
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(anilistId);
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> setAutoDownload(
    int anilistId, {
    required bool autoDownload,
  }) async {
    final result = await _inner.setAutoDownload(
      anilistId,
      autoDownload: autoDownload,
    );
    if (result.isSuccess && _isAuthenticated()) {
      await _enqueueLibraryChange(anilistId);
    }
    return result;
  }

  @override
  Future<void> setAutoDownloadAudioPreference(
    int anilistId,
    String preference,
  ) async {
    await _inner.setAutoDownloadAudioPreference(anilistId, preference);
    if (_isAuthenticated()) {
      await _enqueueLibraryChange(anilistId);
    }
  }

  Future<void> _enqueueLibraryChange(int anilistId) async {
    final snapshot = await _inner.getEntrySnapshot(anilistId);
    final entityKey = jsonEncode({'anilistId': anilistId});
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    if (snapshot == null) {
      // Local row was fully purged (not favorite + not subscribed + no
      // auto-download). Tell the server to delete its row too; the
      // queue-store's collapse logic drops any pending upsert for this id.
      await _syncQueue.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.libraryEntryDeletion,
          entityKey: entityKey,
          payload: jsonEncode({
            'anilist_id': anilistId,
            'updated_at': nowMs,
          }),
          createdAt: now,
          status: SyncQueueEntryStatus.pending,
        ),
      );
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
        entityType: SyncEntityType.libraryEntry,
        entityKey: entityKey,
        payload: jsonEncode({
          'anilist_id': anilistId,
          'added_at': addedAtMs,
          'notify_new_episodes': snapshot.notifyNewEpisodes,
          'auto_download_new_episodes': snapshot.autoDownloadNewEpisodes,
          'auto_download_audio_preference':
              snapshot.autoDownloadAudioPreference ?? 'none',
          'updated_at': nowMs,
        }),
        createdAt: now,
        status: SyncQueueEntryStatus.pending,
      ),
    );
  }

  // Pass-through reads.
  @override
  Future<Result<Set<int>, KumoriyaError>> getFavoriteAnimeIds() =>
      _inner.getFavoriteAnimeIds();

  @override
  Future<Result<Set<int>, KumoriyaError>> getSubscribedAnimeIds() =>
      _inner.getSubscribedAnimeIds();

  @override
  Future<Result<Map<int, int?>, KumoriyaError>>
  getSubscribedWithLastEpisode() => _inner.getSubscribedWithLastEpisode();

  @override
  Future<Result<Map<int, int?>, KumoriyaError>>
  getTrackedAnimeWithLastEpisode() => _inner.getTrackedAnimeWithLastEpisode();

  @override
  Future<Result<void, KumoriyaError>> updateLastNotifiedEpisode(
    int anilistId,
    int episodeNumber,
  ) => _inner.updateLastNotifiedEpisode(anilistId, episodeNumber);

  @override
  Future<String?> getAutoDownloadAudioPreference(int anilistId) =>
      _inner.getAutoDownloadAudioPreference(anilistId);

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds() =>
      _inner.getAutoDownloadAnimeIds();

  @override
  Future<LibraryEntrySnapshot?> getEntrySnapshot(int anilistId) =>
      _inner.getEntrySnapshot(anilistId);

  // Wipe operations bypass the sync queue intentionally: they are invoked
  // during logout to leave the local DB in an anonymous state, and must not
  // leak deletion intents to the server of the account being signed out of.
  @override
  Future<Result<void, KumoriyaError>> clearAll() => _inner.clearAll();
}
