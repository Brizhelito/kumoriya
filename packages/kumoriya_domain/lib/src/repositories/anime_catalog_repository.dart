import 'package:kumoriya_core/kumoriya_core.dart';

import '../anime/anime.dart';
import '../anime/anime_detail.dart';
import '../anime/anime_episode.dart';

final class AnimeSearchRequest {
  const AnimeSearchRequest({
    required this.query,
    this.page = 1,
    this.perPage = 20,
  });

  final String query;
  final int page;
  final int perPage;
}

abstract interface class AnimeCatalogRepository {
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  });

  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  });

  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  );

  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(int anilistId);

  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  );
}
