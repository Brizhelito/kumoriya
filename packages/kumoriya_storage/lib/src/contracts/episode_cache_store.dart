import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

abstract interface class EpisodeCacheStore {
  Future<Result<void, KumoriyaError>> upsertAll(
    int anilistId,
    List<AnimeEpisode> episodes,
  );

  Future<Result<List<AnimeEpisode>, KumoriyaError>> getAll(int anilistId);

  Future<Result<void, KumoriyaError>> deleteAll(int anilistId);
}
