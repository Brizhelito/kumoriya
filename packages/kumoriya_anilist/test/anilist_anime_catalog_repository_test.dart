import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:test/test.dart';

void main() {
  test('repository maps home catalog on success', () async {
    final repository = AnilistAnimeCatalogRepository(
      gateway: _FakeGateway(
        homeCatalog: const Success(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': <String, dynamic>{'romaji': 'Solo Leveling'},
            'format': 'TV',
            'status': 'RELEASING',
            'nextAiringEpisode': <String, dynamic>{
              'episode': 11,
              'airingAt': 1773662400,
            },
          },
        ]),
      ),
    );

    final result = await repository.fetchHomeCatalog();

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (animeList) {
        expect(animeList.first.anilistId, 1);
        expect(animeList.first.nextAiringEpisodeNumber, 11);
        expect(
          animeList.first.nextAiringAt,
          DateTime.fromMillisecondsSinceEpoch(1773662400 * 1000, isUtc: true),
        );
      },
    );
  });

  test('repository maps airing calendar on success', () async {
    final repository = AnilistAnimeCatalogRepository(
      gateway: _FakeGateway(
        airingCalendar: const Success(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 9,
            'title': <String, dynamic>{'romaji': 'Apothecary Diaries'},
            'format': 'TV',
            'status': 'RELEASING',
            'nextAiringEpisode': <String, dynamic>{
              'episode': 22,
              'airingAt': 1774008000,
            },
          },
        ]),
      ),
    );

    final result = await repository.fetchAiringCalendar(
      from: DateTime.utc(2026, 3, 15),
      to: DateTime.utc(2026, 3, 22),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (animeList) {
        expect(animeList.first.anilistId, 9);
        expect(animeList.first.nextAiringEpisodeNumber, 22);
        expect(
          animeList.first.nextAiringAt,
          DateTime.fromMillisecondsSinceEpoch(1774008000 * 1000, isUtc: true),
        );
      },
    );
  });

  test('repository returns mapping error when payload is invalid', () async {
    final repository = AnilistAnimeCatalogRepository(
      gateway: _FakeGateway(
        homeCatalog: const Success(<Map<String, dynamic>>[
          <String, dynamic>{
            'title': <String, dynamic>{'romaji': 'Invalid'},
          },
        ]),
      ),
    );

    final result = await repository.fetchHomeCatalog();

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error, isA<AnilistMappingError>()),
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('repository keeps not-found errors from gateway', () async {
    final repository = AnilistAnimeCatalogRepository(
      gateway: _FakeGateway(
        detail: const Failure(
          AnilistNotFoundError(message: 'No anime found for AniList id 999.'),
        ),
      ),
    );

    final result = await repository.fetchAnimeDetail(999);

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error, isA<AnilistNotFoundError>()),
      onSuccess: (_) => fail('expected failure'),
    );
  });
}

final class _FakeGateway implements AnilistMetadataGateway {
  _FakeGateway({
    this.homeCatalog = const Success(<Map<String, dynamic>>[]),
    this.airingCalendar = const Success(<Map<String, dynamic>>[]),
    this.detail = const Failure(AnilistNotFoundError(message: 'not found')),
  });

  final Result<List<Map<String, dynamic>>, KumoriyaError> homeCatalog;
  final Result<List<Map<String, dynamic>>, KumoriyaError> airingCalendar;
  final Result<Map<String, dynamic>, KumoriyaError> detail;

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    return airingCalendar;
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    return detail;
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    return homeCatalog;
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchAnime({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async {
    return homeCatalog;
  }
}
