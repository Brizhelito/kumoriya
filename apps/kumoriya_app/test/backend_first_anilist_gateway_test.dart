import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_app/src/shared/anilist_backend/anilist_home_backend_client.dart';
import 'package:kumoriya_app/src/shared/anilist_backend/backend_first_anilist_gateway.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

// ---------------------------------------------------------------------------
// Fake inner gateway — records which methods get called so we can assert
// that the decorator fell back vs. served from the backend.
// ---------------------------------------------------------------------------

class _FakeInnerGateway implements AnilistMetadataGateway {
  int homeCalls = 0;
  int seasonDiscoveryCalls = 0;
  int airingCalls = 0;
  int airingSlotsCalls = 0;

  List<Map<String, dynamic>> homeResponse = const [
    {'id': 999, 'source': 'inner'},
  ];
  Map<String, List<Map<String, dynamic>>> seasonDiscoveryResponse = const {
    'current': [
      {'id': 111, 'source': 'inner'},
    ],
  };

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    homeCalls += 1;
    return Success(homeResponse);
  }

  @override
  Future<Result<Map<String, List<Map<String, dynamic>>>, KumoriyaError>>
  fetchSeasonDiscovery(SeasonalCatalogRequest request) async {
    seasonDiscoveryCalls += 1;
    return Success(seasonDiscoveryResponse);
  }

  // -- The decorator must pass everything else through unchanged. The tests
  // below only assert the two backend-first methods, so these stubs are
  // intentionally minimal.

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async => const Success([]);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchUpcomingSeasonCatalog(SeasonalCatalogRequest request) async =>
      const Success([]);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchSeasonRecommendations(SeasonalCatalogRequest request) async =>
      const Success([]);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    airingCalls += 1;
    return const Success([]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    airingSlotsCalls += 1;
    return const Success([]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchAnime({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async => const Success([]);

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async => const Success({});

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchAnimeByIds(List<int> ids, {int page = 1, int perPage = 50}) async =>
      const Success([]);

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
  }) async => const Success([]);

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() async =>
      const Success([]);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchTagCollection() async => const Success([]);

  // Manga stubs — this fake covers anime decorator paths only.

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchMangaHomeCatalog({int page = 1, int perPage = 20}) async =>
      const Success([]);

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchManga({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async => const Success([]);

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) async => const Failure(AnilistNotFoundError(message: 'not found'));

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchMangaByIds(List<int> ids, {int page = 1, int perPage = 50}) async =>
      const Success([]);

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
  }) async => const Success([]);
}

BackendFirstAnilistMetadataGateway _buildGateway({
  required http.Client httpClient,
  required _FakeInnerGateway inner,
}) {
  return BackendFirstAnilistMetadataGateway(
    inner: inner,
    backend: AnilistHomeBackendClient(
      baseUrl: 'https://test.local',
      httpClient: httpClient,
    ),
  );
}

void main() {
  group('BackendFirstAnilistMetadataGateway — fetchHomeCatalog', () {
    test(
      'returns backend media list when backend 200s with Page.media',
      () async {
        final mock = http_testing.MockClient((req) async {
          expect(req.url.path, '/v1/anilist/home/trending');
          expect(req.url.queryParameters['perPage'], '15');
          return http.Response(
            jsonEncode({
              'Page': {
                'media': [
                  {'id': 1, 'source': 'backend'},
                  {'id': 2, 'source': 'backend'},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final inner = _FakeInnerGateway();
        final gateway = _buildGateway(httpClient: mock, inner: inner);

        final result = await gateway.fetchHomeCatalog(perPage: 15);

        expect(result.isSuccess, isTrue);
        expect(
          result.fold(onSuccess: (v) => v, onFailure: (_) => null),
          equals([
            {'id': 1, 'source': 'backend'},
            {'id': 2, 'source': 'backend'},
          ]),
        );
        expect(
          inner.homeCalls,
          0,
          reason: 'inner must not be called on success',
        );
      },
    );

    test('falls back to inner when backend returns 502', () async {
      final mock = http_testing.MockClient(
        (_) async => http.Response('nope', 502),
      );
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      final result = await gateway.fetchHomeCatalog();

      expect(inner.homeCalls, 1);
      final list = result.fold(onSuccess: (v) => v, onFailure: (_) => null);
      expect(list, isNotNull);
      expect(list!.first['source'], 'inner');
    });

    test(
      'falls back to inner when backend returns malformed payload',
      () async {
        final mock = http_testing.MockClient(
          (_) async => http.Response(jsonEncode({'unexpected': true}), 200),
        );
        final inner = _FakeInnerGateway();
        final gateway = _buildGateway(httpClient: mock, inner: inner);

        await gateway.fetchHomeCatalog();

        expect(inner.homeCalls, 1);
      },
    );

    test('falls back to inner when backend throws network error', () async {
      final mock = http_testing.MockClient((_) async {
        throw const _FakeSocketException();
      });
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      await gateway.fetchHomeCatalog();

      expect(inner.homeCalls, 1);
    });
  });

  group('BackendFirstAnilistMetadataGateway — fetchSeasonDiscovery', () {
    test('returns backend sections when payload contains current', () async {
      final mock = http_testing.MockClient((req) async {
        expect(req.url.path, '/v1/anilist/home/season-discovery');
        expect(req.url.queryParameters['includeCarryover'], 'true');
        return http.Response(
          jsonEncode({
            'current': {
              'media': [
                {'id': 10},
              ],
            },
            'upcoming': {
              'media': [
                {'id': 20},
              ],
            },
            'recommended': {'media': []},
          }),
          200,
        );
      });
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      final result = await gateway.fetchSeasonDiscovery(
        const SeasonalCatalogRequest(
          season: AnimeSeason.spring,
          year: 2026,
          includeCarryovers: true,
        ),
      );

      expect(inner.seasonDiscoveryCalls, 0);
      final sections = result.fold(onSuccess: (v) => v, onFailure: (_) => null);
      expect(sections, isNotNull);
      expect(sections!['current']!.first['id'], 10);
      expect(sections['upcoming']!.first['id'], 20);
    });

    test('falls back when current section is missing', () async {
      final mock = http_testing.MockClient(
        (_) async => http.Response(
          jsonEncode({
            'upcoming': {'media': []},
          }),
          200,
        ),
      );
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      await gateway.fetchSeasonDiscovery(
        const SeasonalCatalogRequest(
          season: AnimeSeason.spring,
          year: 2026,
          includeCarryovers: false,
        ),
      );

      expect(inner.seasonDiscoveryCalls, 1);
    });

    test('falls back on HTTP failure', () async {
      final mock = http_testing.MockClient((_) async => http.Response('', 500));
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      await gateway.fetchSeasonDiscovery(
        const SeasonalCatalogRequest(
          season: AnimeSeason.winter,
          year: 2026,
          includeCarryovers: false,
        ),
      );

      expect(inner.seasonDiscoveryCalls, 1);
    });
  });

  group('BackendFirstAnilistMetadataGateway — fetchAiringCalendar', () {
    test(
      'paginates backend, dedupes by anime id, and sorts by airingAt',
      () async {
        var calls = 0;
        final mock = http_testing.MockClient((req) async {
          calls += 1;
          expect(req.url.path, '/v1/anilist/home/airing-calendar');
          expect(req.url.queryParameters['airingAtGreater'], isNotEmpty);
          expect(req.url.queryParameters['airingAtLesser'], isNotEmpty);

          if (calls == 1) {
            return http.Response(
              jsonEncode({
                'Page': {
                  'pageInfo': {'hasNextPage': true},
                  'airingSchedules': [
                    {
                      'episode': 5,
                      'airingAt': 1_000_000_300,
                      'media': {
                        'id': 100,
                        'title': {'romaji': 'A'},
                      },
                    },
                    // Earlier slot for same anime -> dedupe should keep this one
                    {
                      'episode': 4,
                      'airingAt': 1_000_000_100,
                      'media': {
                        'id': 100,
                        'title': {'romaji': 'A'},
                      },
                    },
                  ],
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'Page': {
                'pageInfo': {'hasNextPage': false},
                'airingSchedules': [
                  {
                    'episode': 7,
                    'airingAt': 1_000_000_200,
                    'media': {
                      'id': 200,
                      'title': {'romaji': 'B'},
                    },
                  },
                ],
              },
            }),
            200,
          );
        });
        final inner = _FakeInnerGateway();
        final gateway = _buildGateway(httpClient: mock, inner: inner);

        final result = await gateway.fetchAiringCalendar(
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2026, 1, 8),
        );

        expect(calls, 2);
        final list = result.fold(onSuccess: (v) => v, onFailure: (_) => null)!;
        expect(list.length, 2);
        expect(
          list[0]['id'],
          100,
          reason: 'earliest airingAt (100) must come first after sort',
        );
        expect(
          list[0]['nextAiringEpisode']['episode'],
          4,
          reason: 'dedupe must keep the earlier slot for anime 100',
        );
        expect(list[1]['id'], 200);
      },
    );

    test('filters out isAdult media', () async {
      final mock = http_testing.MockClient((_) async {
        return http.Response(
          jsonEncode({
            'Page': {
              'pageInfo': {'hasNextPage': false},
              'airingSchedules': [
                {
                  'episode': 1,
                  'airingAt': 1_000_000_000,
                  'media': {'id': 1, 'isAdult': true},
                },
                {
                  'episode': 1,
                  'airingAt': 1_000_000_100,
                  'media': {'id': 2},
                },
              ],
            },
          }),
          200,
        );
      });
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      final result = await gateway.fetchAiringCalendar();
      final list = result.fold(onSuccess: (v) => v, onFailure: (_) => null)!;
      expect(list.length, 1);
      expect(list.single['id'], 2);
    });

    test('falls back to inner on mid-pagination backend failure', () async {
      var calls = 0;
      final mock = http_testing.MockClient((_) async {
        calls += 1;
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'Page': {
                'pageInfo': {'hasNextPage': true},
                'airingSchedules': [
                  {
                    'episode': 1,
                    'airingAt': 1_000_000_000,
                    'media': {'id': 1},
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('nope', 502);
      });
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      final result = await gateway.fetchAiringCalendar();
      expect(inner.airingCalls, 1, reason: 'inner must cover the whole call');
      expect(result.isSuccess, isTrue);
    });

    test('falls back to inner on invalid window (to <= from)', () async {
      final mock = http_testing.MockClient((_) async {
        fail('backend must not be called when window is invalid');
      });
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      final now = DateTime.utc(2026, 1, 1);
      await gateway.fetchAiringCalendar(from: now, to: now);
      expect(inner.airingCalls, 1);
    });
  });

  group('BackendFirstAnilistMetadataGateway — fetchAiringCalendarSlots', () {
    test('returns every schedule entry without deduplication', () async {
      final mock = http_testing.MockClient((_) async {
        return http.Response(
          jsonEncode({
            'Page': {
              'pageInfo': {'hasNextPage': false},
              'airingSchedules': [
                {
                  'episode': 1,
                  'airingAt': 1_000_000_000,
                  'media': {'id': 1},
                },
                {
                  'episode': 2,
                  'airingAt': 1_000_000_100,
                  'media': {'id': 1},
                },
                {
                  'episode': 5,
                  'airingAt': 1_000_000_200,
                  'media': {'id': 2},
                },
              ],
            },
          }),
          200,
        );
      });
      final inner = _FakeInnerGateway();
      final gateway = _buildGateway(httpClient: mock, inner: inner);

      final result = await gateway.fetchAiringCalendarSlots();
      final list = result.fold(onSuccess: (v) => v, onFailure: (_) => null)!;
      expect(list.length, 3, reason: 'slots variant preserves duplicates');
    });
  });
}

// http mock callbacks can't throw `SocketException` without dart:io,
// so we use a sentinel. `_get` in the client catches everything.
class _FakeSocketException implements Exception {
  const _FakeSocketException();
  @override
  String toString() => 'FakeSocketException';
}
