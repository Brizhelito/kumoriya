import 'package:kumoriya_core/kumoriya_core.dart';

final class EpisodeProgress {
  const EpisodeProgress({
    required this.anilistId,
    required this.episodeNumber,
    required this.position,
    required this.updatedAt,
  });

  final int anilistId;
  final double episodeNumber;
  final Duration position;
  final DateTime updatedAt;
}

abstract interface class AnimeProgressStore {
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress);

  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  );
}
