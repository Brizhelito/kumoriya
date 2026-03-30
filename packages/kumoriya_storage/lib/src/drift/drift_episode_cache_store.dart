import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../contracts/episode_cache_store.dart';
import 'app_database.dart';
import 'daos/episode_cache_dao.dart';

final class DriftEpisodeCacheStore implements EpisodeCacheStore {
  DriftEpisodeCacheStore(AppDatabase db) : _dao = EpisodeCacheDao(db);

  final EpisodeCacheDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsertAll(
    int anilistId,
    List<AnimeEpisode> episodes,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = episodes.map((e) {
        return EpisodeCatalogCacheTableCompanion(
          anilistId: Value(anilistId),
          episodeNumber: Value(e.number),
          title: Value(e.title),
          airDate: Value(e.airDate?.millisecondsSinceEpoch),
          isAired: Value(e.isAired),
          isFiller: Value(e.isFiller),
          updatedAt: Value(now),
        );
      }).toList();
      await _dao.upsertAll(rows);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.episode_cache_upsert_failed',
          message: 'Failed to cache episode list: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> getAll(
    int anilistId,
  ) async {
    try {
      final rows = await _dao.getAllForAnime(anilistId);
      final episodes = rows.map(_rowToEpisode).toList();
      return Success(episodes);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.episode_cache_read_failed',
          message: 'Failed to read episode cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteAll(int anilistId) async {
    try {
      await _dao.deleteAllForAnime(anilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.episode_cache_delete_failed',
          message: 'Failed to delete episode cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  AnimeEpisode _rowToEpisode(EpisodeCatalogCacheTableData row) {
    return AnimeEpisode(
      number: row.episodeNumber,
      title: row.title,
      airDate: row.airDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.airDate!)
          : null,
      isAired: row.isAired,
      isFiller: row.isFiller,
    );
  }
}
