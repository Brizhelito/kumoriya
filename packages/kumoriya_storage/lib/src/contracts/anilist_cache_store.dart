import 'package:kumoriya_core/kumoriya_core.dart';

final class AnilistCacheEntry {
  const AnilistCacheEntry({
    required this.anilistId,
    required this.titleRomaji,
    required this.updatedAt,
    this.titleEnglish,
    this.titleNative,
    this.synonyms,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.status,
    this.season,
    this.averageScore,
    this.popularity,
    this.genres,
    this.synopsis,
    this.format,
    this.releaseYear,
    this.totalEpisodes,
    this.nextAiringEpisode,
    this.nextAiringAt,
  });

  final int anilistId;
  final String titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final List<String>? synonyms;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? status;
  final String? season;
  final int? averageScore;
  final int? popularity;
  final List<String>? genres;
  final String? synopsis;
  final String? format;
  final int? releaseYear;
  final int? totalEpisodes;
  final int? nextAiringEpisode;
  final DateTime? nextAiringAt;
  final DateTime updatedAt;
}

abstract interface class AnilistCacheStore {
  Future<Result<void, KumoriyaError>> upsert(AnilistCacheEntry entry);

  Future<Result<AnilistCacheEntry?, KumoriyaError>> get(int anilistId);

  Future<Result<void, KumoriyaError>> remove(int anilistId);

  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge);

  /// Most-recently-updated entries, ordered by [updatedAt] descending.
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getRecent({
    int limit = 20,
    int offset = 0,
  });

  /// Entries matching the given AniList [status] string (e.g. `'RELEASING'`).
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getByStatus(
    String status, {
    int limit = 20,
    int offset = 0,
  });

  /// Entries matching [year] and optionally [status], ordered by score desc.
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> getByYearAndStatus(
    int year, {
    String? status,
    int limit = 20,
    int offset = 0,
  });

  /// Full-text-ish search across romaji / english / native titles.
  Future<Result<List<AnilistCacheEntry>, KumoriyaError>> searchByTitle(
    String query, {
    int limit = 20,
    int offset = 0,
  });
}
