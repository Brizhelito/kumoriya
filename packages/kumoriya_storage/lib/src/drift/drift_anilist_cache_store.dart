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
          coverImageUrl: Value(entry.coverImageUrl),
          bannerImageUrl: Value(entry.bannerImageUrl),
          status: Value(entry.status),
          averageScore: Value(entry.averageScore),
          genres: Value(entry.genres != null ? jsonEncode(entry.genres) : null),
          synopsis: Value(entry.synopsis),
          format: Value(entry.format),
          releaseYear: Value(entry.releaseYear),
          totalEpisodes: Value(entry.totalEpisodes),
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

    return AnilistCacheEntry(
      anilistId: row.anilistId,
      titleRomaji: row.titleRomaji,
      titleEnglish: row.titleEnglish,
      titleNative: row.titleNative,
      coverImageUrl: row.coverImageUrl,
      bannerImageUrl: row.bannerImageUrl,
      status: row.status,
      averageScore: row.averageScore,
      genres: genres,
      synopsis: row.synopsis,
      format: row.format,
      releaseYear: row.releaseYear,
      totalEpisodes: row.totalEpisodes,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
