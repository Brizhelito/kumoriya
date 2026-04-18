import 'package:kumoriya_core/kumoriya_core.dart';

abstract interface class LibraryStore {
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  });

  Future<Result<Set<int>, KumoriyaError>> getFavoriteAnimeIds();

  Future<Result<void, KumoriyaError>> setSubscription(
    int anilistId, {
    required bool notify,
  });

  Future<Result<Set<int>, KumoriyaError>> getSubscribedAnimeIds();

  /// Returns a map of anilistId → lastNotifiedEpisode (null if never notified)
  /// for all subscribed entries.
  Future<Result<Map<int, int?>, KumoriyaError>> getSubscribedWithLastEpisode();

  /// Returns a map of anilistId → lastNotifiedEpisode (null if never tracked)
  /// for entries that have notifications and/or auto-download enabled.
  Future<Result<Map<int, int?>, KumoriyaError>>
  getTrackedAnimeWithLastEpisode();

  Future<Result<void, KumoriyaError>> updateLastNotifiedEpisode(
    int anilistId,
    int episodeNumber,
  );

  Future<Result<void, KumoriyaError>> setAutoDownload(
    int anilistId, {
    required bool autoDownload,
  });

  Future<String?> getAutoDownloadAudioPreference(int anilistId);

  Future<void> setAutoDownloadAudioPreference(int anilistId, String preference);

  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds();

  /// Wipes every user-scoped row in the library (favorites, subscriptions,
  /// auto-download preferences). Meant to be invoked when the user signs out
  /// so another account cannot inherit the previous user's library.
  Future<Result<void, KumoriyaError>> clearAll();
}
