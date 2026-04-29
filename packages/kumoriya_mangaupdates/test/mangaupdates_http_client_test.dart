import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_mangaupdates/kumoriya_mangaupdates.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMangaUpdatesClient.getJson', () {
    test('returns parsed JSON on 200', () async {
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'api.mangaupdates.com');
          expect(request.url.path, '/v1/series/1');
          expect(request.headers['User-Agent'], contains('Kumoriya'));
          return http.Response('{"series_id":1,"title":"X"}', 200);
        }),
      );

      final result = await client.getJson(path: 'series/1');

      expect(result.isSuccess, isTrue);
      result.fold(
        onSuccess: (json) => expect(json['series_id'], 1),
        onFailure: (_) => fail('expected success'),
      );
    });

    test('returns NotFound on 404 with empty body', () async {
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('', 404)),
      );

      final result = await client.getJson(path: 'series/999');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaUpdatesNotFoundError>()),
      );
    });

    test('returns ServiceUnavailable on 5xx', () async {
      final client = HttpMangaUpdatesClient(
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
          expect(err, isA<MangaUpdatesServiceUnavailableError>());
          expect((err as MangaUpdatesServiceUnavailableError).statusCode, 503);
        },
      );
    });

    test('returns TransportError on other non-success status codes', () async {
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('forbidden', 403)),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) {
          expect(err, isA<MangaUpdatesTransportError>());
          expect((err as MangaUpdatesTransportError).statusCode, 403);
        },
      );
    });

    test(
      'retries once after 429 honoring Retry-After=0 then succeeds',
      () async {
        var calls = 0;
        final client = HttpMangaUpdatesClient(
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
            return http.Response('{"ok":true}', 200);
          }),
        );

        final result = await client.getJson(path: 'series/1');

        expect(calls, 2);
        expect(result.isSuccess, isTrue);
      },
    );

    test(
      'returns RateLimitError when 429 persists past retry budget',
      () async {
        final client = HttpMangaUpdatesClient(
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

        final result = await client.getJson(path: 'series/1');

        result.fold(
          onSuccess: (_) => fail('expected failure'),
          onFailure: (err) => expect(err, isA<MangaUpdatesRateLimitError>()),
        );
      },
    );

    test('returns MappingError on malformed JSON', () async {
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('not-json', 200)),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaUpdatesMappingError>()),
      );
    });

    test('returns MappingError when 200 body is empty', () async {
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final result = await client.getJson(path: 'series/1');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (err) => expect(err, isA<MangaUpdatesMappingError>()),
      );
    });

    test(
      'returns MappingError when payload is a JSON array (not object)',
      () async {
        final client = HttpMangaUpdatesClient(
          minRequestGap: Duration.zero,
          responseCacheTtl: Duration.zero,
          httpClient: MockClient((_) async => http.Response('[]', 200)),
        );

        final result = await client.getJson(path: 'series/1');

        result.fold(
          onSuccess: (_) => fail('expected failure'),
          onFailure: (err) => expect(err, isA<MangaUpdatesMappingError>()),
        );
      },
    );

    test('caches GETs by URI within TTL', () async {
      var calls = 0;
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: const Duration(minutes: 1),
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('{"id":$calls}', 200);
        }),
      );

      await client.getJson(path: 'series/1');
      await client.getJson(path: 'series/1');

      expect(calls, 1);
    });
  });

  group('HttpMangaUpdatesClient.postJson', () {
    test('serializes the body as JSON and POSTs', () async {
      String? capturedBody;
      String? capturedContentType;
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: Duration.zero,
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          capturedBody = request.body;
          capturedContentType = request.headers['Content-Type'];
          return http.Response('{"results":[]}', 200);
        }),
      );

      await client.postJson(
        path: 'series/search',
        body: <String, dynamic>{'search': 'x', 'page': 1},
      );

      expect(capturedContentType, contains('application/json'));
      expect(jsonDecode(capturedBody!), <String, dynamic>{
        'search': 'x',
        'page': 1,
      });
    });

    test('caches POSTs by URI + body within TTL', () async {
      var calls = 0;
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: const Duration(minutes: 1),
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('{"results":[]}', 200);
        }),
      );

      await client.postJson(
        path: 'series/search',
        body: <String, dynamic>{'search': 'x'},
      );
      await client.postJson(
        path: 'series/search',
        body: <String, dynamic>{'search': 'x'},
      );

      expect(calls, 1);
    });

    test('different POST bodies bypass the cache', () async {
      var calls = 0;
      final client = HttpMangaUpdatesClient(
        minRequestGap: Duration.zero,
        responseCacheTtl: const Duration(minutes: 1),
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('{"results":[]}', 200);
        }),
      );

      await client.postJson(
        path: 'series/search',
        body: <String, dynamic>{'search': 'a'},
      );
      await client.postJson(
        path: 'series/search',
        body: <String, dynamic>{'search': 'b'},
      );

      expect(calls, 2);
    });
  });
}
