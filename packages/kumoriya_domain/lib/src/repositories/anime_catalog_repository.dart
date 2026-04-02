import 'package:kumoriya_core/kumoriya_core.dart';

import '../anime/anime.dart';
import '../anime/anime_browse_request.dart';
import '../anime/anime_detail.dart';
import '../anime/anime_episode.dart';
import '../anime/anime_season.dart';
import '../anime/anime_tag.dart';
import '../anime/season_discovery_result.dart';

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

  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  );

  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  );

  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  );

  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  });

  /// Returns every airing entry in the window without deduplication.
  /// The same anime may appear multiple times (once per episode).
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendarSlots({
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

  /// Fetches current-season, upcoming, and recommended anime in a single
  /// consolidated operation. When [SeasonalCatalogRequest.includeCarryovers]
  /// is true, still-airing shows from the previous season are merged into
  /// [SeasonDiscoveryResult.inSeason].
  Future<Result<SeasonDiscoveryResult, KumoriyaError>> fetchSeasonDiscovery(
    SeasonalCatalogRequest request,
  );

  /// Fetches full catalog-level metadata for a batch of AniList IDs.
  Future<Result<List<Anime>, KumoriyaError>> fetchBatchAnimeByIds(
    List<int> ids,
  );

  /// Browses anime with advanced filters (genres, tags, format, season, sort).
  Future<Result<List<Anime>, KumoriyaError>> browseAnime(
    AnimeBrowseRequest request,
  );

  /// Fetches all available genre names from AniList.
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection();

  /// Fetches all available tags from AniList.
  Future<Result<List<AnimeTag>, KumoriyaError>> fetchTagCollection();
}
