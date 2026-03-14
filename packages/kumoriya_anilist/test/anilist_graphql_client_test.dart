import 'dart:convert';

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

  test('graphql client decodes utf8 payloads without mojibake', () async {
    final payload = utf8.encode(
      '{"data":{"Page":{"media":[{"title":{"native":"葬送のフリーレン","english":"Frieren: Beyond Journey’s End"}}]}}}',
    );
    final client = HttpAnilistGraphqlClient(
      httpClient: MockClient((_) async {
        return http.Response.bytes(
          payload,
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.execute(query: 'query {}');

    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (data) {
        final page = data['Page']! as Map<String, dynamic>;
        final media = page['media']! as List<dynamic>;
        final title = media.first['title']! as Map<String, dynamic>;
        expect(title['native'], '葬送のフリーレン');
        expect(title['english'], 'Frieren: Beyond Journey’s End');
      },
    );
  });
}
