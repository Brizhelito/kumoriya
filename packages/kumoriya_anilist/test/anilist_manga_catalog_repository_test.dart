import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart'
    show SeasonalCatalogRequest;
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AnilistMangaCatalogRepository.fetchHomeCatalog', () {
    test('maps gateway media list into Manga entities', () async {
      final gateway = _FakeGateway(
        homeCatalog: const Success(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': <String, dynamic>{'romaji': 'A'},
            'format': 'MANGA',
          },
          <String, dynamic>{
            'id': 2,
            'title': <String, dynamic>{'romaji': 'B'},
            'format': 'MANHWA',
          },
        ]),
      );
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      final result = await repo.fetchHomeCatalog();

      result.fold(
        onSuccess: (manga) {
          expect(manga, hasLength(2));
          expect(manga[0].format, MangaFormat.manga);
          expect(manga[1].format, MangaFormat.manhwa);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test('propagates gateway failure', () async {
      const error = AnilistTransportError(message: 'offline');
      final gateway = _FakeGateway(homeCatalog: const Failure(error));
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      final result = await repo.fetchHomeCatalog();

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, error),
      );
    });

    test('returns mapping error on malformed payload', () async {
      // missing id forces FormatException inside the mapper.
      final gateway = _FakeGateway(
        homeCatalog: const Success(<Map<String, dynamic>>[
          <String, dynamic>{
            'title': <String, dynamic>{'romaji': 'X'},
          },
        ]),
      );
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      final result = await repo.fetchHomeCatalog();

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<AnilistMappingError>()),
      );
    });
  });

  group('AnilistMangaCatalogRepository.fetchMangaDetail', () {
    test('returns NotFound when gateway has no media', () async {
      final gateway = _FakeGateway();
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      final result = await repo.fetchMangaDetail(42);

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<AnilistNotFoundError>()),
      );
    });

    test('maps gateway payload into MangaDetail', () async {
      final gateway = _FakeGateway(
        detail: const Success(<String, dynamic>{
          'id': 9,
          'title': <String, dynamic>{'romaji': 'Series'},
          'format': 'MANGA',
          'chapters': 120,
          'volumes': 12,
          'countryOfOrigin': 'JP',
        }),
      );
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      final result = await repo.fetchMangaDetail(9);

      result.fold(
        onSuccess: (detail) {
          expect(detail.manga.anilistId, 9);
          expect(detail.manga.totalChapters, 120);
          expect(detail.manga.totalVolumes, 12);
          expect(detail.manga.countryOfOrigin, MangaCountryOfOrigin.jp);
          expect(detail.relations, isEmpty);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });
  });

  test(
    'fetchMangaChapters returns empty list (AniList lacks per-chapter data)',
    () async {
      final repo = AnilistMangaCatalogRepository(gateway: _FakeGateway());
      final result = await repo.fetchMangaChapters(1);

      result.fold(
        onSuccess: (chapters) => expect(chapters, isEmpty),
        onFailure: (e) => fail('expected success, got $e'),
      );
    },
  );

  group('AnilistMangaCatalogRepository.browseManga', () {
    test('forwards filters to gateway and uses first country only', () async {
      final gateway = _FakeGateway();
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      await repo.browseManga(
        const MangaBrowseRequest(
          search: 'k',
          genres: ['Action'],
          formats: [MangaFormat.manhwa, MangaFormat.manga],
          statuses: [MangaStatus.releasing],
          countriesOfOrigin: [MangaCountryOfOrigin.kr, MangaCountryOfOrigin.jp],
          sort: MangaSortType.score,
        ),
      );

      expect(gateway.lastBrowse, isNotNull);
      expect(gateway.lastBrowse!['search'], 'k');
      expect(gateway.lastBrowse!['genres'], <String>['Action']);
      expect(gateway.lastBrowse!['formats'], <String>['MANHWA', 'MANGA']);
      expect(gateway.lastBrowse!['statuses'], <String>['RELEASING']);
      expect(gateway.lastBrowse!['countryOfOrigin'], 'KR');
      expect(gateway.lastBrowse!['sort'], <String>['SCORE_DESC']);
    });

    test('omits countryOfOrigin when filter list is empty', () async {
      final gateway = _FakeGateway();
      final repo = AnilistMangaCatalogRepository(gateway: gateway);

      await repo.browseManga(const MangaBrowseRequest(search: 'x'));

      expect(gateway.lastBrowse, isNotNull);
      expect(gateway.lastBrowse!['countryOfOrigin'], isNull);
    });
  });
}

final class _FakeGateway implements AnilistMetadataGateway {
  _FakeGateway({
    this.homeCatalog = const Success(<Map<String, dynamic>>[]),
    this.detail = const Failure(AnilistNotFoundError(message: 'not found')),
  });

  final Result<List<Map<String, dynamic>>, KumoriyaError> homeCatalog;
  final Result<Map<String, dynamic>, KumoriyaError> detail;

  Map<String, dynamic>? lastBrowse;

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchMangaHomeCatalog({int page = 1, int perPage = 20}) async {
    return homeCatalog;
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchManga({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async {
    return homeCatalog;
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) async {
    return detail;
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchMangaByIds(List<int> ids, {int page = 1, int perPage = 50}) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> browseManga({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<String>? formats,
    List<String>? statuses,
    String? countryOfOrigin,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    lastBrowse = <String, dynamic>{
      'search': search,
      'genres': genres,
      'tags': tags,
      'formats': formats,
      'statuses': statuses,
      'countryOfOrigin': countryOfOrigin,
      'sort': sort,
      'page': page,
      'perPage': perPage,
    };
    return const Success(<Map<String, dynamic>>[]);
  }

  // ---- Anime methods stubs (unused in this test file). ----

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchUpcomingSeasonCatalog(SeasonalCatalogRequest request) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchSeasonRecommendations(SeasonalCatalogRequest request) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchAnime({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    return const Failure(AnilistNotFoundError(message: 'not found'));
  }

  @override
  Future<Result<Map<String, List<Map<String, dynamic>>>, KumoriyaError>>
  fetchSeasonDiscovery(SeasonalCatalogRequest request) async {
    return const Success(<String, List<Map<String, dynamic>>>{
      'current': <Map<String, dynamic>>[],
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchAnimeByIds(List<int> ids, {int page = 1, int perPage = 50}) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> browseAnime({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<String>? formats,
    String? season,
    int? seasonYear,
    List<String>? statuses,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    return const Success(<Map<String, dynamic>>[]);
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() async {
    return const Success(<String>[]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchTagCollection() async {
    return const Success(<Map<String, dynamic>>[]);
  }
}
