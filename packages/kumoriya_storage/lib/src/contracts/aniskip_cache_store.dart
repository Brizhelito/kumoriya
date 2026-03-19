import 'package:kumoriya_core/kumoriya_core.dart';

final class AniSkipCacheRecord {
  const AniSkipCacheRecord({
    required this.anilistId,
    required this.episodeNumber,
    required this.payloadJson,
    required this.updatedAt,
    this.requestedEpisodeLengthSeconds,
  });

  final int anilistId;
  final int episodeNumber;
  final String payloadJson;
  final DateTime updatedAt;
  final int? requestedEpisodeLengthSeconds;
}

abstract interface class AniSkipCacheStore {
  Future<Result<AniSkipCacheRecord?, KumoriyaError>> getEpisode(
    int anilistId,
    int episodeNumber,
  );

  Future<Result<List<AniSkipCacheRecord>, KumoriyaError>> getEpisodesForAnime(
    int anilistId,
  );

  Future<Result<void, KumoriyaError>> upsert(AniSkipCacheRecord record);

  Future<Result<void, KumoriyaError>> clearAnime(int anilistId);

  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge);
}
