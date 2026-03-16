import 'package:kumoriya_core/kumoriya_core.dart';

abstract interface class LibraryStore {
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
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

  Future<Result<void, KumoriyaError>> updateLastNotifiedEpisode(
    int anilistId,
    int episodeNumber,
  );
}
