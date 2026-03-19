import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/aniskip_cache_store.dart';
import 'app_database.dart';
import 'daos/aniskip_cache_dao.dart';

final class DriftAniSkipCacheStore implements AniSkipCacheStore {
  DriftAniSkipCacheStore(AppDatabase db) : _dao = AniSkipCacheDao(db);

  final AniSkipCacheDao _dao;

  @override
  Future<Result<AniSkipCacheRecord?, KumoriyaError>> getEpisode(
    int anilistId,
    int episodeNumber,
  ) async {
    try {
      final row = await _dao.getEpisode(anilistId, episodeNumber);
      return Success(row == null ? null : _mapRow(row));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_read_failed',
          message: 'Failed to read AniSkip cache entry: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AniSkipCacheRecord>, KumoriyaError>> getEpisodesForAnime(
    int anilistId,
  ) async {
    try {
      final rows = await _dao.getEpisodesForAnime(anilistId);
      return Success(rows.map(_mapRow).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_list_failed',
          message: 'Failed to read AniSkip cache for anime: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> upsert(AniSkipCacheRecord record) async {
    try {
      await _dao.upsertEpisode(
        AniSkipCacheTableCompanion(
          anilistId: Value(record.anilistId),
          episodeNumber: Value(record.episodeNumber),
          payloadJson: Value(record.payloadJson),
          updatedAt: Value(record.updatedAt.millisecondsSinceEpoch),
          requestedEpisodeLengthSeconds: Value(
            record.requestedEpisodeLengthSeconds,
          ),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_write_failed',
          message: 'Failed to store AniSkip cache entry: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAnime(int anilistId) async {
    try {
      await _dao.clearAnime(anilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_clear_failed',
          message: 'Failed to clear AniSkip cache entries: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    try {
      final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
      final deleted = await _dao.deleteOlderThan(cutoff);
      return Success(deleted);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.aniskip_cleanup_failed',
          message: 'Failed to clean AniSkip cache entries: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  AniSkipCacheRecord _mapRow(AniSkipCacheTableData row) {
    return AniSkipCacheRecord(
      anilistId: row.anilistId,
      episodeNumber: row.episodeNumber,
      payloadJson: row.payloadJson,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      requestedEpisodeLengthSeconds: row.requestedEpisodeLengthSeconds,
    );
  }
}
