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
  const GetSeasonalDiscoveryCatalogUseCase({
    required GetSeasonCatalogUseCase seasonCatalog,
    required GetUpcomingSeasonCatalogUseCase upcomingSeasonCatalog,
    required GetSeasonRecommendationsUseCase seasonRecommendations,
  }) : _seasonCatalog = seasonCatalog,
       _upcomingSeasonCatalog = upcomingSeasonCatalog,
       _seasonRecommendations = seasonRecommendations;

  final GetSeasonCatalogUseCase _seasonCatalog;
  final GetUpcomingSeasonCatalogUseCase _upcomingSeasonCatalog;
  final GetSeasonRecommendationsUseCase _seasonRecommendations;

  Future<Result<SeasonalDiscoveryCatalog, KumoriyaError>> call(
    SeasonalCatalogRequest request,
  ) async {
    final results = await Future.wait<Result<List<Anime>, KumoriyaError>>(
      <Future<Result<List<Anime>, KumoriyaError>>>[
        _seasonCatalog.call(request),
        _upcomingSeasonCatalog.call(
          SeasonalCatalogRequest(
            season: request.season,
            year: request.year,
            page: request.page,
            perPage: request.perPage,
            includeCarryovers: false,
          ),
        ),
        _seasonRecommendations.call(
          SeasonalCatalogRequest(
            season: request.season,
            year: request.year,
            page: request.page,
            perPage: request.perPage,
            includeCarryovers: false,
          ),
        ),
      ],
    );

    for (final result in results) {
      if (result.isFailure) {
        return result.fold(
          onSuccess: (_) => throw StateError('unreachable'),
          onFailure: Failure.new,
        );
      }
    }

    final inSeason = results[0].fold(
      onSuccess: (value) => value,
      onFailure: (_) => throw StateError('unreachable'),
    );
    final upcoming = results[1].fold(
      onSuccess: (value) => value,
      onFailure: (_) => throw StateError('unreachable'),
    );
    final recommended = results[2].fold(
      onSuccess: (value) => value,
      onFailure: (_) => throw StateError('unreachable'),
    );

    return Success(
      SeasonalDiscoveryCatalog(
        request: request,
        inSeason: inSeason,
        upcoming: upcoming,
        recommended: recommended,
      ),
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
