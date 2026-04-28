import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/manga_cache_store.dart';
import 'app_database.dart';
import 'daos/manga_cache_dao.dart';

final class DriftMangaCacheStore implements MangaCacheStore {
  DriftMangaCacheStore(AppDatabase db) : _dao = MangaCacheDao(db);

  final MangaCacheDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsert(MangaCacheEntry entry) async {
    try {
      await _dao.upsert(
        MangaCacheTableCompanion(
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
          format: Value(entry.format),
          countryOfOrigin: Value(entry.countryOfOrigin),
          originalLanguage: Value(entry.originalLanguage),
          releaseYear: Value(entry.releaseYear),
          totalChapters: Value(entry.totalChapters),
          totalVolumes: Value(entry.totalVolumes),
          averageScore: Value(entry.averageScore),
          popularity: Value(entry.popularity),
          genres: Value(entry.genres != null ? jsonEncode(entry.genres) : null),
          tags: Value(entry.tagsJson),
          synopsis: Value(entry.synopsis),
          // Mirror anilist_cache.upsert's behavior: leave relations
          // untouched when the caller doesn't provide them, so a
          // list-level refresh doesn't NULL-out cached relations from
          // an earlier detail-level fetch.
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
          code: 'storage.manga_cache_upsert_failed',
          message: 'Failed to cache manga metadata: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<MangaCacheEntry?, KumoriyaError>> get(int anilistId) async {
    try {
      final row = await _dao.get(anilistId);
      return Success(row != null ? _rowToEntry(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_cache_read_failed',
          message: 'Failed to read manga cache: $e',
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
          code: 'storage.manga_cache_remove_failed',
          message: 'Failed to remove manga cache entry: $e',
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
          code: 'storage.manga_cache_cleanup_failed',
          message: 'Failed to clean up manga cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getRecent({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _dao.getRecent(limit: limit, offset: offset);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_cache_query_failed',
          message: 'Failed to query recent manga: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getByStatus(
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
          code: 'storage.manga_cache_query_failed',
          message: 'Failed to query manga by status: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> searchByTitle(
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
          code: 'storage.manga_cache_query_failed',
          message: 'Failed to search manga by title: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getByIds(
    List<int> ids,
  ) async {
    if (ids.isEmpty) {
      return const Success(<MangaCacheEntry>[]);
    }
    try {
      final rows = await _dao.getByIds(ids);
      return Success(rows.map(_rowToEntry).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_cache_query_failed',
          message: 'Failed to query manga cache by IDs: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  MangaCacheEntry _rowToEntry(MangaCacheTableData row) {
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

    return MangaCacheEntry(
      anilistId: row.anilistId,
      titleRomaji: row.titleRomaji,
      titleEnglish: row.titleEnglish,
      titleNative: row.titleNative,
      synonyms: synonyms,
      coverImageUrl: row.coverImageUrl,
      bannerImageUrl: row.bannerImageUrl,
      status: row.status,
      format: row.format,
      countryOfOrigin: row.countryOfOrigin,
      originalLanguage: row.originalLanguage,
      releaseYear: row.releaseYear,
      totalChapters: row.totalChapters,
      totalVolumes: row.totalVolumes,
      averageScore: row.averageScore,
      popularity: row.popularity,
      genres: genres,
      tagsJson: row.tags,
      synopsis: row.synopsis,
      relationsJson: row.relations,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
