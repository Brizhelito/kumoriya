import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
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
