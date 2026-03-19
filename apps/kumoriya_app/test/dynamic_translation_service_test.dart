import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_app/src/shared/dynamic_translation.dart';

void main() {
  group('DynamicTranslationService (Google Translate)', () {
    late DynamicTranslationService service;

    /// Builds a mock client that returns a Google Translate-style JSON body.
    MockClient buildMockClient(String translatedText, {int statusCode = 200}) {
      // Google Translate response shape: [[[translated, original]]]
      final body = jsonEncode([
        [
          [translatedText, 'original'],
        ],
        null,
        'en',
      ]);
      return MockClient((_) async => http.Response(body, statusCode));
    }

    test('returns original text when target language is en', () async {
      service = DynamicTranslationService(
        client: buildMockClient('should not be called'),
      );
      final result = await service.translate(
        text: 'Hello world',
        targetLanguage: 'en',
      );
      expect(result, 'Hello world');
    });

    test('returns original text when text is empty', () async {
      service = DynamicTranslationService(
        client: buildMockClient('should not be called'),
      );
      final result = await service.translate(
        text: '  ',
        targetLanguage: 'es',
      );
      expect(result, '  ');
    });

    test('translates text to Spanish via Google endpoint', () async {
      service = DynamicTranslationService(
        client: buildMockClient('Hola mundo'),
      );
      final result = await service.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );
      expect(result, 'Hola mundo');
    });

    test('caches repeated translation requests', () async {
      var callCount = 0;
      final body = jsonEncode([
        [
          ['Hola mundo', 'Hello world'],
        ],
        null,
        'en',
      ]);
      final client = MockClient((_) async {
        callCount++;
        return http.Response(body, 200);
      });
      service = DynamicTranslationService(client: client);

      final first = await service.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );
      final second = await service.translate(
        text: 'Hello world',
        targetLanguage: 'es',
      );

      expect(first, 'Hola mundo');
      expect(second, 'Hola mundo');
      expect(callCount, 1, reason: 'Second call should use cache');
    });

    test('returns original text on HTTP error', () async {
      service = DynamicTranslationService(
        client: buildMockClient('ignored', statusCode: 503),
      );
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'es',
      );
      expect(result, 'Hello');
    });

    test('returns original text on malformed JSON', () async {
      final client = MockClient(
        (_) async => http.Response('not json', 200),
      );
      service = DynamicTranslationService(client: client);
      final result = await service.translate(
        text: 'Hello',
        targetLanguage: 'es',
      );
      expect(result, 'Hello');
    });

    test('handles multi-segment response', () async {
      final body = jsonEncode([
        [
          ['Primera parte. ', 'First part. '],
          ['Segunda parte.', 'Second part.'],
        ],
        null,
        'en',
      ]);
      final client = MockClient((_) async => http.Response(body, 200));
      service = DynamicTranslationService(client: client);

      final result = await service.translate(
        text: 'First part. Second part.',
        targetLanguage: 'es',
      );
      expect(result, 'Primera parte. Segunda parte.');
    });

    test('deduplicates concurrent identical requests', () async {
      var callCount = 0;
      final body = jsonEncode([
        [
          ['Hola', 'Hello'],
        ],
      ]);
      final client = MockClient((_) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(body, 200);
      });
      service = DynamicTranslationService(client: client);

      // Fire two identical requests concurrently.
      final results = await Future.wait([
        service.translate(text: 'Hello', targetLanguage: 'es'),
        service.translate(text: 'Hello', targetLanguage: 'es'),
      ]);

      expect(results, ['Hola', 'Hola']);
      expect(callCount, 1, reason: 'Should deduplicate concurrent requests');
    });

    test('sends correct URL parameters', () async {
      Uri? capturedUri;
      final body = jsonEncode([
        [
          ['Hola', 'Hello'],
        ],
      ]);
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(body, 200);
      });
      service = DynamicTranslationService(client: client);

      await service.translate(text: 'Hello', targetLanguage: 'es');

      expect(capturedUri, isNotNull);
      expect(capturedUri!.host, 'translate.googleapis.com');
      expect(capturedUri!.path, '/translate_a/single');
      expect(capturedUri!.queryParameters['client'], 'gtx');
      expect(capturedUri!.queryParameters['sl'], 'auto');
      expect(capturedUri!.queryParameters['tl'], 'es');
      expect(capturedUri!.queryParameters['dt'], 't');
      expect(capturedUri!.queryParameters['q'], 'Hello');
    });
  });

  group('DynamicTranslationService._splitIntoChunks (static)', () {
    // We test chunking indirectly through translate with a long text.
    test('chunks long text at sentence boundary', () async {
      // Build a text > 4500 chars with sentence breaks.
      final sentence = 'This is a test sentence. ';
      final longText = sentence * 200; // ~5000 chars

      final chunks = <String>[];
      final body = jsonEncode([
        [
          ['TRANSLATED', 'original'],
        ],
      ]);
      final client = MockClient((request) async {
        chunks.add(request.url.queryParameters['q']!);
        return http.Response(body, 200);
      });

      final service = DynamicTranslationService(client: client);
      await service.translate(text: longText, targetLanguage: 'es');

      expect(chunks.length, greaterThan(1), reason: 'Should split long text');
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(4500));
      }
    });
  });
}
