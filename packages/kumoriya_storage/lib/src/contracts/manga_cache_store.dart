import 'package:kumoriya_core/kumoriya_core.dart';

/// Local cache row for a manga as represented by AniList.
final class MangaCacheEntry {
  const MangaCacheEntry({
    required this.anilistId,
    required this.titleRomaji,
    required this.updatedAt,
    this.titleEnglish,
    this.titleNative,
    this.synonyms,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.status,
    this.format,
    this.countryOfOrigin,
    this.originalLanguage,
    this.releaseYear,
    this.totalChapters,
    this.totalVolumes,
    this.averageScore,
    this.popularity,
    this.genres,
    this.tagsJson,
    this.synopsis,
    this.relationsJson,
  });

  final int anilistId;
  final String titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final List<String>? synonyms;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? status;
  final String? format;
  final String? countryOfOrigin;
  final String? originalLanguage;
  final int? releaseYear;
  final int? totalChapters;
  final int? totalVolumes;
  final int? averageScore;
  final int? popularity;
  final List<String>? genres;

  /// JSON-encoded list of `{"name": ..., "rank": ...}` objects.
  final String? tagsJson;

  final String? synopsis;

  /// JSON-encoded list of `{"id": int, "type": string, "mediaKind": string}`.
  final String? relationsJson;

  final DateTime updatedAt;
}

abstract interface class MangaCacheStore {
  Future<Result<void, KumoriyaError>> upsert(MangaCacheEntry entry);

  Future<Result<MangaCacheEntry?, KumoriyaError>> get(int anilistId);

  Future<Result<void, KumoriyaError>> remove(int anilistId);

  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge);

  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getRecent({
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getByStatus(
    String status, {
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<MangaCacheEntry>, KumoriyaError>> searchByTitle(
    String query, {
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<MangaCacheEntry>, KumoriyaError>> getByIds(List<int> ids);
}
