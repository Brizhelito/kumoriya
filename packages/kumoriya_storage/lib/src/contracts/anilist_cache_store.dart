import 'package:kumoriya_core/kumoriya_core.dart';

final class AnilistCacheEntry {
  const AnilistCacheEntry({
    required this.anilistId,
    required this.titleRomaji,
    required this.updatedAt,
    this.titleEnglish,
    this.titleNative,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.status,
    this.averageScore,
    this.genres,
    this.synopsis,
    this.format,
    this.releaseYear,
    this.totalEpisodes,
  });

  final int anilistId;
  final String titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? status;
  final int? averageScore;
  final List<String>? genres;
  final String? synopsis;
  final String? format;
  final int? releaseYear;
  final int? totalEpisodes;
  final DateTime updatedAt;
}

abstract interface class AnilistCacheStore {
  Future<Result<void, KumoriyaError>> upsert(AnilistCacheEntry entry);

  Future<Result<AnilistCacheEntry?, KumoriyaError>> get(int anilistId);

  Future<Result<void, KumoriyaError>> remove(int anilistId);

  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge);
}
