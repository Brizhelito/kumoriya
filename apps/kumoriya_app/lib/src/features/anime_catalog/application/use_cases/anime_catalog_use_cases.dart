import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../models/seasonal_discovery_catalog.dart';

final class GetHomeCatalogUseCase {
  const GetHomeCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call({
    int page = 1,
    int perPage = 20,
  }) {
    return _repository.fetchHomeCatalog(page: page, perPage: perPage);
  }
}

final class GetTrendingCatalogUseCase {
  const GetTrendingCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call({
    int page = 1,
    int perPage = 50,
  }) {
    return _repository.fetchHomeCatalog(page: page, perPage: perPage);
  }
}

final class GetSeasonCatalogUseCase {
  const GetSeasonCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(
    SeasonalCatalogRequest request,
  ) {
    return _repository.fetchSeasonCatalog(request);
  }
}

final class GetUpcomingSeasonCatalogUseCase {
  const GetUpcomingSeasonCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(
    SeasonalCatalogRequest request,
  ) {
    return _repository.fetchUpcomingSeasonCatalog(request);
  }
}

final class GetSeasonRecommendationsUseCase {
  const GetSeasonRecommendationsUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(
    SeasonalCatalogRequest request,
  ) {
    return _repository.fetchSeasonRecommendations(request);
  }
}

final class GetSeasonalDiscoveryCatalogUseCase {
  const GetSeasonalDiscoveryCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<SeasonalDiscoveryCatalog, KumoriyaError>> call(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _repository.fetchSeasonDiscovery(request);

    return result.fold(
      onSuccess: (discovery) {
        return Success(
          SeasonalDiscoveryCatalog(
            request: request,
            inSeason: discovery.inSeason,
            upcoming: discovery.upcoming,
            recommended: discovery.recommended,
          ),
        );
      },
      onFailure: Failure.new,
    );
  }
}

final class GetCalendarCatalogUseCase {
  const GetCalendarCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) {
    return _repository.fetchAiringCalendar(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    );
  }
}

final class GetAiringCalendarSlotsUseCase {
  const GetAiringCalendarSlotsUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) {
    return _repository.fetchAiringCalendarSlots(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    );
  }
}

final class SearchAnimeUseCase {
  const SearchAnimeUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(String query) {
    return _repository.searchAnime(AnimeSearchRequest(query: query));
  }
}

final class GetAnimeDetailUseCase {
  const GetAnimeDetailUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<AnimeDetail, KumoriyaError>> call(int anilistId) {
    return _repository.fetchAnimeDetail(anilistId);
  }
}

final class GetAnimeEpisodesUseCase {
  const GetAnimeEpisodesUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<AnimeEpisode>, KumoriyaError>> call(int anilistId) {
    return _repository.fetchAnimeEpisodes(anilistId);
  }
}

final class GetBatchAnimeByIdsUseCase {
  const GetBatchAnimeByIdsUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(List<int> ids) {
    return _repository.fetchBatchAnimeByIds(ids);
  }
}

final class BrowseAnimeUseCase {
  const BrowseAnimeUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(AnimeBrowseRequest request) {
    return _repository.browseAnime(request);
  }
}

final class GetGenreCollectionUseCase {
  const GetGenreCollectionUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<String>, KumoriyaError>> call() {
    return _repository.fetchGenreCollection();
  }
}

final class GetTagCollectionUseCase {
  const GetTagCollectionUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<AnimeTag>, KumoriyaError>> call() {
    return _repository.fetchTagCollection();
  }
}
