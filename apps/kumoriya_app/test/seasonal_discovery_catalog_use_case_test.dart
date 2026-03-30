import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/anime_catalog_use_cases.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

void main() {
  test('aggregates in-season, upcoming, and recommended catalogs', () async {
    final repository = _FakeAnimeCatalogRepository(
      seasonCatalog: Success(<Anime>[_anime(1, 'Solo Leveling')]),
      upcomingCatalog: Success(<Anime>[_anime(2, 'Witch Watch')]),
      recommendations: Success(<Anime>[_anime(3, 'Frieren')]),
    );
    final useCase = GetSeasonalDiscoveryCatalogUseCase(
      seasonCatalog: GetSeasonCatalogUseCase(repository),
      upcomingSeasonCatalog: GetUpcomingSeasonCatalogUseCase(repository),
      seasonRecommendations: GetSeasonRecommendationsUseCase(repository),
    );

    final result = await useCase.call(
      const SeasonalCatalogRequest(season: AnimeSeason.spring, year: 2026),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (catalog) {
        expect(catalog.inSeason.single.title.romaji, 'Solo Leveling');
        expect(catalog.upcoming.single.title.romaji, 'Witch Watch');
        expect(catalog.recommended.single.title.romaji, 'Frieren');
      },
    );
  });
}

Anime _anime(int id, String title) {
  return Anime(
    anilistId: id,
    title: AnimeTitle(romaji: title),
    format: AnimeFormat.tv,
    status: AnimeStatus.releasing,
  );
}

final class _FakeAnimeCatalogRepository implements AnimeCatalogRepository {
  _FakeAnimeCatalogRepository({
    required this.seasonCatalog,
    required this.upcomingCatalog,
    required this.recommendations,
  });

  final Result<List<Anime>, KumoriyaError> seasonCatalog;
  final Result<List<Anime>, KumoriyaError> upcomingCatalog;
  final Result<List<Anime>, KumoriyaError> recommendations;

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return seasonCatalog;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return upcomingCatalog;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  ) async {
    return recommendations;
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(int anilistId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  ) {
    throw UnimplementedError();
  }
}
