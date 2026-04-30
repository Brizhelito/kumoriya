import 'package:kumoriya_core/kumoriya_core.dart';

final class MangaLibraryEntrySnapshot {
  const MangaLibraryEntrySnapshot({
    required this.mangaAnilistId,
    required this.isFavorite,
    required this.addedAt,
    required this.notifyNewChapters,
    required this.autoDownloadNewChapters,
    required this.preferredLanguage,
    required this.preferredScanlator,
    required this.preferredSourceId,
    required this.lastNotifiedChapter,
  });

  final int mangaAnilistId;
  final bool isFavorite;
  final DateTime? addedAt;
  final bool notifyNewChapters;
  final bool autoDownloadNewChapters;
  final String? preferredLanguage;
  final String? preferredScanlator;

  /// Per-manga preferred source plugin id (`mangadex`, `olympus`, …).
  /// `null` means "auto / fan out to every registered plugin".
  /// See [MangaLibraryStore.setPreferredSourceId].
  final String? preferredSourceId;

  final double? lastNotifiedChapter;
}

abstract interface class MangaLibraryStore {
  Future<Result<void, KumoriyaError>> setFavorite(
    int mangaAnilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  });

  Future<Result<Set<int>, KumoriyaError>> getFavoriteMangaIds();

  Future<Result<void, KumoriyaError>> setSubscription(
    int mangaAnilistId, {
    required bool notify,
  });

  Future<Result<Set<int>, KumoriyaError>> getSubscribedMangaIds();

  /// Returns a map of `mangaAnilistId → lastNotifiedChapter` (null when
  /// never tracked) for entries that have notifications and/or
  /// auto-download enabled.
  Future<Result<Map<int, double?>, KumoriyaError>>
  getTrackedMangaWithLastChapter();

  Future<Result<void, KumoriyaError>> updateLastNotifiedChapter(
    int mangaAnilistId,
    double chapterNumber,
  );

  Future<Result<void, KumoriyaError>> setAutoDownload(
    int mangaAnilistId, {
    required bool autoDownload,
  });

  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadMangaIds();

  Future<Result<void, KumoriyaError>> setPreferredLanguage(
    int mangaAnilistId,
    String? language,
  );

  Future<Result<void, KumoriyaError>> setPreferredScanlator(
    int mangaAnilistId,
    String? scanlator,
  );

  /// Persists the per-manga preferred source plugin id
  /// (e.g. `mangadex`, `olympus`). Pass `null` to clear the preference
  /// — the composite repository will then fan out to every registered
  /// plugin again.
  Future<Result<void, KumoriyaError>> setPreferredSourceId(
    int mangaAnilistId,
    String? sourceId,
  );

  Future<MangaLibraryEntrySnapshot?> getEntrySnapshot(int mangaAnilistId);

  /// Wipes every user-scoped manga library row.
  Future<Result<void, KumoriyaError>> clearAll();
}
