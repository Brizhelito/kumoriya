import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'fcm_service.dart';

/// Decorates a [LibraryStore] so toggling the "notify new episodes"
/// flag also mirrors the change into the FCM topic subscription.
///
/// Topic is `media_{anilistId}` — the same convention the API's
/// airing-worker dispatches to.
///
/// Failures on the FCM side do not roll back the local mutation:
/// the user's local state is the source of truth; a missed topic
/// subscription is reconciled on next login/app-start via
/// [FcmTopicSyncService]. Errors are swallowed (with a debug log
/// inside `FcmService`) so a transient FCM outage never surfaces
/// as a library write failure.
final class FcmAwareLibraryStore implements LibraryStore {
  FcmAwareLibraryStore({
    required LibraryStore inner,
    required FcmTopicSubscriber fcm,
  }) : _inner = inner,
       _fcm = fcm;

  final LibraryStore _inner;
  final FcmTopicSubscriber _fcm;

  @override
  Future<Result<void, KumoriyaError>> setSubscription(
    int anilistId, {
    required bool notify,
  }) async {
    final result = await _inner.setSubscription(anilistId, notify: notify);
    if (!result.isSuccess) return result;
    try {
      if (notify) {
        await _fcm.subscribeToMedia(anilistId);
      } else {
        await _fcm.unsubscribeFromMedia(anilistId);
      }
    } catch (_) {
      // Intentional: see class doc. Local state already committed.
    }
    return result;
  }

  // ── Pass-through ────────────────────────────────────────────────

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  }) => _inner.setFavorite(anilistId, isFavorite: isFavorite, addedAt: addedAt);

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
  Future<Result<void, KumoriyaError>> setAutoDownload(
    int anilistId, {
    required bool autoDownload,
  }) => _inner.setAutoDownload(anilistId, autoDownload: autoDownload);

  @override
  Future<String?> getAutoDownloadAudioPreference(int anilistId) =>
      _inner.getAutoDownloadAudioPreference(anilistId);

  @override
  Future<void> setAutoDownloadAudioPreference(
    int anilistId,
    String preference,
  ) => _inner.setAutoDownloadAudioPreference(anilistId, preference);

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds() =>
      _inner.getAutoDownloadAnimeIds();

  @override
  Future<LibraryEntrySnapshot?> getEntrySnapshot(int anilistId) =>
      _inner.getEntrySnapshot(anilistId);

  @override
  Future<Result<void, KumoriyaError>> clearAll() => _inner.clearAll();
}
