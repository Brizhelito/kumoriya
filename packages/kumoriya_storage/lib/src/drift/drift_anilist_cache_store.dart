import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/anilist_cache_store.dart';
import 'app_database.dart';
import 'daos/anilist_cache_dao.dart';

final class DriftAnilistCacheStore implements AnilistCacheStore {
  DriftAnilistCacheStore(AppDatabase db) : _dao = AnilistCacheDao(db);

  final AnilistCacheDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsert(AnilistCacheEntry entry) async {
    try {
      await _dao.upsert(
        AnilistCacheTableCompanion(
          anilistId: Value(entry.anilistId),
          titleRomaji: Value(entry.titleRomaji),
          titleEnglish: Value(entry.titleEnglish),
          titleNative: Value(entry.titleNative),
          synonyms: Value(
            entry.synonyms != null ? jsonEncode(entry.synonyms) : null,
          ),
          coverImageUrl: Value(entry.coverImageUrl),
          bannerImageUrl: Value(entry.bannerImageUrl),
          status: Value(entry.status),
          season: Value(entry.season),
          averageScore: Value(entry.averageScore),
          popularity: Value(entry.popularity),
          genres: Value(entry.genres != null ? jsonEncode(entry.genres) : null),
          synopsis: Value(entry.synopsis),
          format: Value(entry.format),
          releaseYear: Value(entry.releaseYear),
          totalEpisodes: Value(entry.totalEpisodes),
          nextAiringEpisode: Value(entry.nextAiringEpisode),
          nextAiringAt: Value(entry.nextAiringAt?.millisecondsSinceEpoch),
          // List-level persistence does not know about relations (the
          // AniList list queries don't request them). Passing `Value(null)`
          // here would overwrite any previously-cached relations JSON with
          // NULL on every list refresh. Use `Value.absent()` so callers that
          // don't provide relations leave the column untouched; detail-level
          // persistence always supplies a non-null JSON (`[]` when empty).
          relations: entry.relationsJson == null
              ? const Value.absent()
              : Value(entry.relationsJson),
          updatedAt: Value(entry.updatedAt.millisecondsSinceEpoch),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_upsert_failed',
          message: 'Failed to cache AniList metadata: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<AnilistCacheEntry?, KumoriyaError>> get(int anilistId) async {
    try {
      final row = await _dao.get(anilistId);
      return Success(row != null ? _rowToEntry(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_read_failed',
          message: 'Failed to read AniList cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> remove(int anilistId) async {
    try {
      await _dao.remove(anilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_remove_failed',
          message: 'Failed to remove AniList cache entry: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    try {
      final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
      final count = await _dao.deleteOlderThan(cutoff);
      return Success(count);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_cleanup_failed',
          message: 'Failed to clean up AniList cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getRecent({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _dao.getRecent(limit: limit, offset: offset);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_query_failed',
          message: 'Failed to query recent AniList cache entries: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getByStatus(
    String status, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _dao.getByStatus(status, limit: limit, offset: offset);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_query_failed',
          message: 'Failed to query AniList cache by status: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getByYearAndStatus(
    int year, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _dao.getByYearAndStatus(
        year,
        status: status,
        limit: limit,
        offset: offset,
      );
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_query_failed',
          message: 'Failed to query AniList cache by year/status: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> searchByTitle(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _dao.searchByTitle(
        query,
        limit: limit,
        offset: offset,
      );
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_query_failed',
          message: 'Failed to search AniList cache by title: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getByIds(
    List<int> ids,
  ) async {
    if (ids.isEmpty) {
      return const Success(<AnilistCacheEntry>[]);
    }
    try {
      final rows = await _dao.getByIds(ids);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.anilist_cache_query_failed',
          message: 'Failed to query AniList cache by IDs: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  AnilistCacheEntry _rowToEntry(AnilistCacheTableData row) {
    List<String>? genres;
    if (row.genres != null) {
      try {
        final decoded = jsonDecode(row.genres!) as List<dynamic>;
        genres = decoded.whereType<String>().toList(growable: false);
      } catch (_) {
        genres = null;
      }
    }

    List<String>? synonyms;
    if (row.synonyms != null) {
      try {
        final decoded = jsonDecode(row.synonyms!) as List<dynamic>;
        synonyms = decoded.whereType<String>().toList(growable: false);
      } catch (_) {
        synonyms = null;
      }
    }

    return AnilistCacheEntry(
      anilistId: row.anilistId,
      titleRomaji: row.titleRomaji,
      titleEnglish: row.titleEnglish,
      titleNative: row.titleNative,
      synonyms: synonyms,
      coverImageUrl: row.coverImageUrl,
      bannerImageUrl: row.bannerImageUrl,
      status: row.status,
      season: row.season,
      averageScore: row.averageScore,
      popularity: row.popularity,
      genres: genres,
      synopsis: row.synopsis,
      format: row.format,
      releaseYear: row.releaseYear,
      totalEpisodes: row.totalEpisodes,
      nextAiringEpisode: row.nextAiringEpisode,
      nextAiringAt: row.nextAiringAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.nextAiringAt!)
          : null,
      relationsJson: row.relations,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
