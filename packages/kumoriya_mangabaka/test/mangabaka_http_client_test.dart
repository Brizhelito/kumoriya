import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_mangabaka/kumoriya_mangabaka.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMangaBakaClient.getJson', () {
    test('returns parsed JSON on 200', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'api.mangabaka.dev');
          expect(request.url.path, '/v1/series/1');
          expect(request.headers['User-Agent'], contains('Kumoriya'));
          return http.Response(
            '{"status":200,"data":{"id":1,"title":"X"}}',
            200,
          );
        }),
      );

      final result = await client.getJson(path: 'series/1');

      expect(result.isSuccess, isTrue);
      result.fold(
        onSuccess: (json) => expect(json['data'], isA<Map<String, dynamic>>()),
        onFailure: (_) => fail('expected success'),
      );
    });

    test('serializes query parameters', () async {
      Uri? capturedUri;
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response('{"status":200,"data":[]}', 200);
        }),
      );

      await client.getJson(
        path: 'series/search',
        queryParameters: <String, dynamic>{'q': 'solo leveling', 'limit': 3},
      );

      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['q'], 'solo leveling');
      expect(capturedUri!.queryParameters['limit'], '3');
    });

    test('returns NotFound on HTTP 404', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient(
          (_) async =>
              http.Response('{"status":404,"message":"NOT_FOUND"}', 404),
        ),
      );

      final result = await client.getJson(path: 'series/999');

      expect(result.isFailure, isTrue);
      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaBakaNotFoundError>()),
      );
    });

    test('returns NotFound when 200 envelope carries logical 404', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient(
          (_) async =>
              http.Response('{"status":404,"message":"NOT_FOUND"}', 200),
        ),
      );

      final result = await client.getJson(path: 'series/999');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaBakaNotFoundError>()),
      );
    });

    test('returns ServiceUnavailable on 5xx', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient(
          (_) async => http.Response('{"message":"upstream"}', 503),
        ),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) {
          expect(err, isA<MangaBakaServiceUnavailableError>());
          expect((err as MangaBakaServiceUnavailableError).statusCode, 503);
        },
      );
    });

    test('returns TransportError on other non-success status codes', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('forbidden', 403)),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) {
          expect(err, isA<MangaBakaTransportError>());
          expect((err as MangaBakaTransportError).statusCode, 403);
        },
      );
    });

    test(
      'retries once after 429 honoring Retry-After=0 then succeeds',
      () async {
        var calls = 0;
        final client = HttpMangaBakaClient(
          minRequestGap: Duration.zero,
          defaultRateLimitBackoff: Duration.zero,
          responseCacheTtl: Duration.zero,
          httpClient: MockClient((_) async {
            calls += 1;
            if (calls == 1) {
              return http.Response(
                'rate limited',
                429,
                headers: <String, String>{'retry-after': '0'},
              );
            }
            return http.Response('{"status":200,"data":[]}', 200);
          }),
        );

        final result = await client.getJson(path: 'series/search');

        expect(calls, 2);
        expect(result.isSuccess, isTrue);
      },
    );

    test(
      'returns RateLimitError when 429 persists past retry budget',
      () async {
        final client = HttpMangaBakaClient(
          minRequestGap: Duration.zero,
          defaultRateLimitBackoff: Duration.zero,
          responseCacheTtl: Duration.zero,
          httpClient: MockClient(
            (_) async => http.Response(
              'rate limited',
              429,
              headers: <String, String>{'retry-after': '0'},
            ),
          ),
        );

        final result = await client.getJson(path: 'series/search');

        result.fold(
          onSuccess: (_) => fail('expected failure'),
          onFailure: (err) => expect(err, isA<MangaBakaRateLimitError>()),
        );
      },
    );

    test('returns MappingError on malformed JSON', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('not-json', 200)),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaBakaMappingError>()),
      );
    });

    test('returns MappingError when payload is not a JSON object', () async {
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaBakaMappingError>()),
      );
    });

    test('decodes utf-8 payloads without mojibake', () async {
      final payload = utf8.encode(
        '{"status":200,"data":{"id":1,"title":"葬送のフリーレン"}}',
      );
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            payload,
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (json) {
          final data = json['data']! as Map<String, dynamic>;
          expect(data['title'], '葬送のフリーレン');
        },
        onFailure: (_) => fail('expected success'),
      );
    });

    test('serves the same URI from cache within TTL', () async {
      var calls = 0;
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: const Duration(minutes: 1),
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('{"status":200,"data":{"id":$calls}}', 200);
        }),
      );

      final first = await client.getJson(path: 'series/1');
      final second = await client.getJson(path: 'series/1');

      expect(calls, 1);
      // Both responses should resolve to the same payload.
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
    });

    test('different query parameters bypass the cache', () async {
      var calls = 0;
      final client = HttpMangaBakaClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: const Duration(minutes: 1),
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('{"status":200,"data":[]}', 200);
        }),
      );

      await client.getJson(
        path: 'series/search',
        queryParameters: <String, dynamic>{'q': 'a'},
      );
      await client.getJson(
        path: 'series/search',
        queryParameters: <String, dynamic>{'q': 'b'},
      );

      expect(calls, 2);
    });
  });
}
