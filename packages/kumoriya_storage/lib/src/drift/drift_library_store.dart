import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/library_store.dart';
import 'app_database.dart';
import 'daos/library_entry_dao.dart';

final class DriftLibraryStore implements LibraryStore {
  DriftLibraryStore(AppDatabase db) : _dao = LibraryEntryDao(db);

  final LibraryEntryDao _dao;

  @override
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
    DateTime? addedAt,
  }) async {
    try {
      if (isFavorite) {
        final ts = (addedAt ?? DateTime.now()).millisecondsSinceEpoch;
        await _dao.addFavorite(anilistId, ts);
      } else {
        await _dao.removeFavorite(anilistId);
      }
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_set_favorite_failed',
          message: 'Failed to update favorite: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getFavoriteAnimeIds() async {
    try {
      final ids = await _dao.getFavoriteAnimeIds();
      return Success(ids.toSet());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_read_failed',
          message: 'Failed to read favorites: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> setSubscription(
    int anilistId, {
    required bool notify,
  }) async {
    try {
      await _dao.updateSubscription(anilistId, notify: notify);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_set_subscription_failed',
          message: 'Failed to update subscription: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getSubscribedAnimeIds() async {
    try {
      final ids = await _dao.getSubscribedAnimeIds();
      return Success(ids.toSet());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_read_subscribed_failed',
          message: 'Failed to read subscribed: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Map<int, int?>, KumoriyaError>>
  getSubscribedWithLastEpisode() async {
    try {
      final rows = await _dao.getSubscribedEntries();
      return Success({
        for (final r in rows) r.anilistId: r.lastNotifiedEpisode,
      });
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_read_subscribed_failed',
          message: 'Failed to read subscribed with episode: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<Map<int, int?>, KumoriyaError>>
  getTrackedAnimeWithLastEpisode() async {
    try {
      final rows = await _dao.getTrackedEntries();
      return Success({
        for (final r in rows) r.anilistId: r.lastNotifiedEpisode,
      });
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_read_tracked_failed',
          message: 'Failed to read tracked anime with episode: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateLastNotifiedEpisode(
    int anilistId,
    int episodeNumber,
  ) async {
    try {
      await _dao.updateLastNotifiedEpisode(anilistId, episodeNumber);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_update_last_notified_failed',
          message: 'Failed to update last notified episode: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> setAutoDownload(
    int anilistId, {
    required bool autoDownload,
  }) async {
    try {
      await _dao.updateAutoDownload(anilistId, autoDownload: autoDownload);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_set_auto_download_failed',
          message: 'Failed to update auto download: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<String?> getAutoDownloadAudioPreference(int anilistId) {
    return _dao.getAutoDownloadAudioPreference(anilistId);
  }

  @override
  Future<void> setAutoDownloadAudioPreference(
    int anilistId,
    String preference,
  ) {
    return _dao.setAutoDownloadAudioPreference(anilistId, preference);
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds() async {
    try {
      final ids = await _dao.getAutoDownloadAnimeIds();
      return Success(ids.toSet());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.library_read_auto_download_failed',
          message: 'Failed to read auto download entries: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<LibraryEntrySnapshot?> getEntrySnapshot(int anilistId) async {
    final row = await _dao.getEntry(anilistId);
    if (row == null) {
      return null;
    }

    return LibraryEntrySnapshot(
      anilistId: row.anilistId,
      isFavorite: row.addedAt > 0,
      addedAt: row.addedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(row.addedAt)
          : null,
      notifyNewEpisodes: row.notifyNewEpisodes,
      autoDownloadNewEpisodes: row.autoDownloadNewEpisodes,
      autoDownloadAudioPreference: row.autoDownloadAudioPreference,
      lastNotifiedEpisode: row.lastNotifiedEpisode,
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
          code: 'storage.library_clear_all_failed',
          message: 'Failed to clear library: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }
}
