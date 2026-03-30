import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:test/test.dart';

void main() {
  test('fetchAiringCalendar filters adult entries from schedules', () async {
    final gateway = GraphqlAnilistMetadataGateway(
      client: _FakeClient(
        response: Success(<String, dynamic>{
          'Page': <String, dynamic>{
            'airingSchedules': <Map<String, dynamic>>[
              <String, dynamic>{
                'episode': 8,
                'airingAt': 1774008000,
                'media': <String, dynamic>{
                  'id': 101,
                  'isAdult': true,
                  'title': <String, dynamic>{'romaji': 'Adult Show'},
                  'format': 'TV',
                  'status': 'RELEASING',
                },
              },
              <String, dynamic>{
                'episode': 12,
                'airingAt': 1774011600,
                'media': <String, dynamic>{
                  'id': 202,
                  'isAdult': false,
                  'title': <String, dynamic>{'romaji': 'Family Show'},
                  'format': 'TV',
                  'status': 'RELEASING',
                },
              },
            ],
          },
        }),
      ),
    );

    final result = await gateway.fetchAiringCalendar();

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (media) {
        expect(media.length, 1);
        expect(media.first['id'], 202);
      },
    );
  });

  test(
    'fetchSeasonCatalog merges previous-season carryovers by trending',
    () async {
      final gateway = GraphqlAnilistMetadataGateway(
        client: _SequenceClient(
          responses: <Result<Map<String, dynamic>, KumoriyaError>>[
            Success(<String, dynamic>{
              'Page': <String, dynamic>{
                'media': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 2,
                    'title': <String, dynamic>{'romaji': 'Current Hit'},
                    'format': 'TV',
                    'status': 'RELEASING',
                    'trending': 900,
                  },
                ],
              },
            }),
            Success(<String, dynamic>{
              'Page': <String, dynamic>{
                'media': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 1,
                    'title': <String, dynamic>{'romaji': 'Carryover Show'},
                    'format': 'TV',
                    'status': 'RELEASING',
                    'trending': 1200,
                  },
                ],
              },
            }),
          ],
        ),
      );

      final result = await gateway.fetchSeasonCatalog(
        const SeasonalCatalogRequest(season: AnimeSeason.spring, year: 2026),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (media) {
          expect(media, hasLength(2));
          expect(media.first['id'], 1);
          expect(media.last['id'], 2);
        },
      );
    },
  );
}

final class _FakeClient implements AnilistGraphqlClient {
  _FakeClient({required this.response});

  final Result<Map<String, dynamic>, KumoriyaError> response;

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> execute({
    required String query,
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    return response;
  }
}

final class _SequenceClient implements AnilistGraphqlClient {
  _SequenceClient({
    required List<Result<Map<String, dynamic>, KumoriyaError>> responses,
  }) : _responses = responses;

  final List<Result<Map<String, dynamic>, KumoriyaError>> _responses;
  int _index = 0;

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> execute({
    required String query,
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    if (_index >= _responses.length) {
      throw StateError('No more fake responses configured.');
    }

    final response = _responses[_index];
    _index += 1;
    return response;
  }
}
