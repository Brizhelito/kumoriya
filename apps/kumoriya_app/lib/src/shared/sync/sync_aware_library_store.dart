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
  })  : _inner = inner,
        _syncQueue = syncQueue,
        _isAuthenticated = isAuthenticated;

  final LibraryStore _inner;
  final SyncQueueStore _syncQueue;
  final bool Function() _isAuthenticated;

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
  }) async {
    final result = await _inner.setFavorite(anilistId, isFavorite: isFavorite);
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
    final result =
        await _inner.setAutoDownload(anilistId, autoDownload: autoDownload);
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
    // Read current state to build full payload.
    final favResult = await _inner.getFavoriteAnimeIds();
    final subResult = await _inner.getSubscribedAnimeIds();
    final autoResult = await _inner.getAutoDownloadAnimeIds();
    final audioPref = await _inner.getAutoDownloadAudioPreference(anilistId);

    final isFav =
        favResult.fold(onSuccess: (s) => s.contains(anilistId), onFailure: (_) => false);
    final isSub =
        subResult.fold(onSuccess: (s) => s.contains(anilistId), onFailure: (_) => false);
    final isAuto =
        autoResult.fold(onSuccess: (s) => s.contains(anilistId), onFailure: (_) => false);

    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncQueue.enqueue(SyncQueueEntry(
      id: 0,
      entityType: SyncEntityType.libraryEntry,
      entityKey: jsonEncode({'anilistId': anilistId}),
      payload: jsonEncode({
        'anilist_id': anilistId,
        'is_favorite': isFav,
        'added_at': now,
        'notify_new_episodes': isSub,
        'auto_download_new_episodes': isAuto,
        'auto_download_audio_preference': audioPref ?? 'none',
      }),
      createdAt: DateTime.now(),
      status: SyncQueueEntryStatus.pending,
    ));
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
      getTrackedAnimeWithLastEpisode() =>
          _inner.getTrackedAnimeWithLastEpisode();

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
}
