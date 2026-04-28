import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/manga_library_store.dart';
import 'app_database.dart';
import 'daos/manga_library_dao.dart';

final class DriftMangaLibraryStore implements MangaLibraryStore {
  DriftMangaLibraryStore(AppDatabase db) : _dao = MangaLibraryDao(db);

  final MangaLibraryDao _dao;

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int mangaAnilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  }) async {
    try {
      if (isFavorite) {
        final ts = (addedAt ?? DateTime.now()).millisecondsSinceEpoch;
        await _dao.addFavorite(mangaAnilistId, ts);
      } else {
        await _dao.removeFavorite(mangaAnilistId);
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_set_favorite_failed',
          message: 'Failed to update manga favorite: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getFavoriteMangaIds() async {
    try {
      final ids = await _dao.getFavoriteMangaIds();
      return Success(ids.toSet());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_read_failed',
          message: 'Failed to read manga favorites: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> setSubscription(
    int mangaAnilistId, {
    required bool notify,
  }) async {
    try {
      await _dao.updateSubscription(mangaAnilistId, notify: notify);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_set_subscription_failed',
          message: 'Failed to update manga subscription: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getSubscribedMangaIds() async {
    try {
      final ids = await _dao.getSubscribedMangaIds();
      return Success(ids.toSet());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_read_subscribed_failed',
          message: 'Failed to read subscribed manga: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Map<int, double?>, KumoriyaError>>
  getTrackedMangaWithLastChapter() async {
    try {
      final rows = await _dao.getTrackedEntries();
      return Success({
        for (final r in rows) r.mangaAnilistId: r.lastNotifiedChapter,
      });
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_read_tracked_failed',
          message: 'Failed to read tracked manga: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateLastNotifiedChapter(
    int mangaAnilistId,
    double chapterNumber,
  ) async {
    try {
      await _dao.updateLastNotifiedChapter(mangaAnilistId, chapterNumber);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_update_last_notified_failed',
          message: 'Failed to update last notified chapter: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> setAutoDownload(
    int mangaAnilistId, {
    required bool autoDownload,
  }) async {
    try {
      await _dao.updateAutoDownload(mangaAnilistId, autoDownload: autoDownload);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_set_auto_download_failed',
          message: 'Failed to update manga auto-download: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadMangaIds() async {
    try {
      final ids = await _dao.getAutoDownloadMangaIds();
      return Success(ids.toSet());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_read_auto_download_failed',
          message: 'Failed to read auto-download manga: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> setPreferredLanguage(
    int mangaAnilistId,
    String? language,
  ) async {
    try {
      await _dao.setPreferredLanguage(mangaAnilistId, language);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_set_preferred_language_failed',
          message: 'Failed to set preferred language: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> setPreferredScanlator(
    int mangaAnilistId,
    String? scanlator,
  ) async {
    try {
      await _dao.setPreferredScanlator(mangaAnilistId, scanlator);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_set_preferred_scanlator_failed',
          message: 'Failed to set preferred scanlator: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<MangaLibraryEntrySnapshot?> getEntrySnapshot(
    int mangaAnilistId,
  ) async {
    final row = await _dao.getEntry(mangaAnilistId);
    if (row == null) return null;
    return MangaLibraryEntrySnapshot(
      mangaAnilistId: row.mangaAnilistId,
      isFavorite: row.addedAt > 0,
      addedAt: row.addedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(row.addedAt)
          : null,
      notifyNewChapters: row.notifyNewChapters,
      autoDownloadNewChapters: row.autoDownloadNewChapters,
      preferredLanguage: row.preferredLanguage,
      preferredScanlator: row.preferredScanlator,
      lastNotifiedChapter: row.lastNotifiedChapter,
    );
  }

  @override
  Future<Result<void, KumoriyaError>> clearAll() async {
    try {
      await _dao.clearAll();
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_library_clear_all_failed',
          message: 'Failed to clear manga library: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }
}
