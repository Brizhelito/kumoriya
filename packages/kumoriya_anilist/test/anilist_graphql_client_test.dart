import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:test/test.dart';

void main() {
  test('graphql client returns data map on success', () async {
    final client = HttpAnilistGraphqlClient(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response('{"data":{"Page":{"media":[]}}}', 200);
      }),
    );

    final result = await client.execute(query: 'query {}');
    expect(result.isSuccess, isTrue);
  });

  test('graphql client returns transport error on non-200', () async {
    final client = HttpAnilistGraphqlClient(
      httpClient: MockClient((_) async => http.Response('server error', 500)),
    );

    final result = await client.execute(query: 'query {}');

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error, isA<AnilistTransportError>()),
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('graphql client returns mapping error on invalid json', () async {
    final client = HttpAnilistGraphqlClient(
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );

    final result = await client.execute(query: 'query {}');

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error, isA<AnilistMappingError>()),
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
