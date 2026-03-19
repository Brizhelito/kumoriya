import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_yourupload/kumoriya_resolver_yourupload.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/yourupload_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/yourupload_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/yourupload_payload_empty.html',
  ).readAsStringSync();

  test('supports yourupload embed links', () {
    final plugin = YouruploadResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://www.yourupload.com/embed/abc123')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://yourupload.com/watch/abc123')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://pixeldrain.com/u/abc123')),
      isFalse,
    );
  });

  test('extracts mp4 stream candidate', () async {
    final plugin = YouruploadResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'www.yourupload.com');
        return http.Response(sourcesFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://www.yourupload.com/embed/abc123'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.mimeType, 'video/mp4');
        expect(streams.single.url.host, 'vidcache.net');
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable links',
    () async {
      final plugin = YouruploadResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://www.yourupload.com/embed/abc123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.yourupload.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no hints', () async {
    final plugin = YouruploadResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://www.yourupload.com/embed/abc123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.yourupload.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
