import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/anime_catalog_use_cases.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/controllers/paginated_anime_feed_notifier.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('loads first page and marks end when fewer than perPage', () async {
    final repository = _FakeAnimeCatalogRepository(
      pages: <int, Result<List<Anime>, KumoriyaError>>{
        1: Success(<Anime>[_anime(1), _anime(2)]),
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final request = const AnimeBrowseRequest(perPage: 24);
    final sub = container.listen(
      paginatedAnimeFeedProvider(request),
      (_, _) {},
    );
    addTearDown(sub.close);
    await _pump();

    final state = container.read(paginatedAnimeFeedProvider(request));
    expect(state.items.map((anime) => anime.anilistId), <int>[1, 2]);
    expect(state.isLoadingFirstPage, isFalse);
    expect(state.hasReachedEnd, isTrue);
  });

  test('appends next page and dedupes repeated AniList ids', () async {
    final repository = _FakeAnimeCatalogRepository(
      pages: <int, Result<List<Anime>, KumoriyaError>>{
        1: Success(List<Anime>.generate(24, (index) => _anime(index + 1))),
        2: Success(<Anime>[_anime(24), _anime(25)]),
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final request = const AnimeBrowseRequest(perPage: 24);
    final sub = container.listen(
      paginatedAnimeFeedProvider(request),
      (_, _) {},
    );
    addTearDown(sub.close);
    await _pump();
    await container
        .read(paginatedAnimeFeedProvider(request).notifier)
        .loadNextPage();

    final state = container.read(paginatedAnimeFeedProvider(request));
    expect(state.items.length, 25);
    expect(state.items.last.anilistId, 25);
    expect(state.request.page, 2);
    expect(state.hasReachedEnd, isTrue);
  });

  test('keeps current items when load more fails', () async {
    final repository = _FakeAnimeCatalogRepository(
      pages: <int, Result<List<Anime>, KumoriyaError>>{
        1: Success(List<Anime>.generate(24, (index) => _anime(index + 1))),
        2: const Failure<List<Anime>, KumoriyaError>(
          SimpleError(code: 'boom', message: 'boom'),
        ),
      },
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    final request = const AnimeBrowseRequest(perPage: 24);
    final sub = container.listen(
      paginatedAnimeFeedProvider(request),
      (_, _) {},
    );
    addTearDown(sub.close);
    await _pump();
    await container
        .read(paginatedAnimeFeedProvider(request).notifier)
        .loadNextPage();

    final state = container.read(paginatedAnimeFeedProvider(request));
    expect(state.items.length, 24);
    expect(state.request.page, 1);
    expect(state.error, isNotNull);
  });
}

ProviderContainer _container(_FakeAnimeCatalogRepository repository) {
  return ProviderContainer(
    overrides: [
      browseAnimeUseCaseProvider.overrideWithValue(
        BrowseAnimeUseCase(repository),
      ),
    ],
  );
}

Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 1));

Anime _anime(int id) {
  return Anime(
    anilistId: id,
    title: AnimeTitle(romaji: 'Anime $id'),
    format: AnimeFormat.tv,
  );
}

final class _FakeAnimeCatalogRepository implements AnimeCatalogRepository {
  _FakeAnimeCatalogRepository({required this.pages});

  final Map<int, Result<List<Anime>, KumoriyaError>> pages;

  @override
  Future<Result<List<Anime>, KumoriyaError>> browseAnime(
    AnimeBrowseRequest request,
  ) async {
    return pages[request.page] ?? const Success(<Anime>[]);
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
  Future<Result<List<Anime>, KumoriyaError>> fetchBatchAnimeByIds(
    List<int> ids,
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

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() async {
    return const Success(<String>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<SeasonDiscoveryResult, KumoriyaError>> fetchSeasonDiscovery(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(
      SeasonDiscoveryResult(
        inSeason: <Anime>[],
        upcoming: <Anime>[],
        recommended: <Anime>[],
      ),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<AnimeTag>, KumoriyaError>> fetchTagCollection() async {
    return const Success(<AnimeTag>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    return const Success(<Anime>[]);
  }
}
