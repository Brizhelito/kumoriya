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

  test('graphql client retries once after 429 using Retry-After', () async {
    var calls = 0;
    final client = HttpAnilistGraphqlClient(
      minRequestGap: Duration.zero,
      defaultRateLimitBackoff: Duration.zero,
      httpClient: MockClient((_) async {
        calls += 1;
        if (calls == 1) {
          return http.Response(
            'rate limited',
            429,
            headers: <String, String>{'retry-after': '0'},
          );
        }

        return http.Response('{"data":{"Page":{"media":[]}}}', 200);
      }),
    );

    final result = await client.execute(query: 'query {}');

    expect(calls, 2);
    expect(result.isSuccess, isTrue);
  });

  test('graphql client serves stale cache when 429 persists', () async {
    var calls = 0;
    final client = HttpAnilistGraphqlClient(
      minRequestGap: Duration.zero,
      responseCacheTtl: const Duration(milliseconds: 1),
      defaultRateLimitBackoff: Duration.zero,
      staleOnRateLimitTtl: const Duration(minutes: 5),
      httpClient: MockClient((_) async {
        calls += 1;
        if (calls == 1) {
          return http.Response('{"data":{"Page":{"media":[1]}}}', 200);
        }

        return http.Response(
          'rate limited',
          429,
          headers: <String, String>{'retry-after': '0'},
        );
      }),
    );

    final first = await client.execute(query: 'query {}');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await client.execute(query: 'query {}');

    expect(first.isSuccess, isTrue);
    expect(second.isSuccess, isTrue);
    expect(calls, 3);

    second.fold(
      onFailure: (_) => fail('expected stale cached success'),
      onSuccess: (data) {
        final page = data['Page']! as Map<String, dynamic>;
        expect(page['media'], <dynamic>[1]);
      },
    );
  });

  test(
    'graphql client returns rate-limit error after persistent 429',
    () async {
      final client = HttpAnilistGraphqlClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        staleOnRateLimitTtl: Duration.zero,
        defaultRateLimitBackoff: Duration.zero,
        httpClient: MockClient((_) async {
          return http.Response(
            'rate limited',
            429,
            headers: <String, String>{'retry-after': '0'},
          );
        }),
      );

      final result = await client.execute(query: 'query {}');

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) => expect(error, isA<AnilistRateLimitError>()),
        onSuccess: (_) => fail('expected rate-limit failure'),
      );
    },
  );
}
