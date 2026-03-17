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
  }) async {
    try {
      if (isFavorite) {
        await _dao.addFavorite(
          anilistId,
          DateTime.now().millisecondsSinceEpoch,
        );
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
      final rows = await _dao.getAllFavorites();
      return Success(rows.map((r) => r.anilistId).toSet());
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
      final rows = await _dao.getSubscribedEntries();
      return Success(rows.map((r) => r.anilistId).toSet());
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
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds() async {
    try {
      final rows = await _dao.getAutoDownloadEntries();
      return Success(rows.map((r) => r.anilistId).toSet());
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
}
