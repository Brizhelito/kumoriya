import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_filemoon/kumoriya_resolver_filemoon.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/filemoon_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/filemoon_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/filemoon_payload_empty.html',
  ).readAsStringSync();

  test('supports filemoon hosts', () {
    final plugin = FilemoonResolverPlugin();

    expect(plugin.supports(Uri.parse('https://filemoon.sx/e/xyz123')), isTrue);
    expect(plugin.supports(Uri.parse('https://filemoon.to/e/xyz123')), isTrue);
    expect(plugin.supports(Uri.parse('https://bysekoze.com/e/xyz123')), isTrue);
    expect(plugin.supports(Uri.parse('https://voe.sx/e/xyz123')), isFalse);
  });

  test('extracts streams with labels and metadata', () async {
    final plugin = FilemoonResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'filemoon.sx');
        expect(request.headers['origin'], 'https://filemoon.sx');
        return http.Response(sourcesFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://filemoon.sx/e/xyz123'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(2));
        expect(streams.where((stream) => stream.isHls), isNotEmpty);
        expect(
          streams.where((stream) => stream.qualityLabel != 'unknown'),
          isNotEmpty,
        );
        expect(
          streams.where((stream) => stream.mimeType == 'video/mp4'),
          isNotEmpty,
        );
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable urls',
    () async {
      final plugin = FilemoonResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://filemoon.sx/e/xyz123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.filemoon.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no hints', () async {
    final plugin = FilemoonResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://filemoon.sx/e/xyz123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.filemoon.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('returns transport failure for non-200 response', () async {
    final plugin = FilemoonResolverPlugin(
      httpClient: MockClient((_) async => http.Response('fail', 500)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://filemoon.sx/e/xyz123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.transport);
        expect(error.code, 'resolver.filemoon.transport');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
