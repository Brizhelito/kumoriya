import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_pixeldrain/kumoriya_resolver_pixeldrain.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/pixeldrain_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/pixeldrain_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/pixeldrain_payload_empty.html',
  ).readAsStringSync();

  test('supports pixeldrain share links', () {
    final plugin = PixeldrainResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://pixeldrain.com/u/qi2eVVgY?embed')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://pixeldrain.com/api/file/qi2eVVgY')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://www.yourupload.com/embed/abc')),
      isFalse,
    );
  });

  test('extracts direct api file url from share page', () async {
    final plugin = PixeldrainResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/u/qi2eVVgY');
        return http.Response(sourcesFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://pixeldrain.com/u/qi2eVVgY?embed'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(1));
        expect(
          streams.single.url,
          Uri.parse('https://pixeldrain.com/api/file/qi2eVVgY'),
        );
      },
    );
  });

  test('supports direct api file urls without fetch', () async {
    final plugin = PixeldrainResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://pixeldrain.com/api/file/qi2eVVgY'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams.single.url.path, '/api/file/qi2eVVgY');
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without a usable id',
    () async {
      final plugin = PixeldrainResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://pixeldrain.com/u/qi2eVVgY?embed'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.pixeldrain.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no hints', () async {
    final plugin = PixeldrainResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://pixeldrain.com/u/qi2eVVgY?embed'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.pixeldrain.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
