import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_voe/kumoriya_resolver_voe.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/voe_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/voe_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/voe_payload_empty.html',
  ).readAsStringSync();
  final redirectFixture = File(
    'test/fixtures/voe_payload_redirect.html',
  ).readAsStringSync();
  final redirectTargetFixture = File(
    'test/fixtures/voe_payload_redirect_target.html',
  ).readAsStringSync();

  test('supports voe hosts with /e/ path', () {
    final plugin = VoeResolverPlugin();

    expect(plugin.supports(Uri.parse('https://voe.sx/e/abcd1234')), isTrue);
    expect(plugin.supports(Uri.parse('https://voe.uno/v/abcd1234')), isTrue);
    expect(
      plugin.supports(Uri.parse('https://lancewhosedifficult.com/e/abcd1234')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://filemoon.sx/e/abcd1234')),
      isFalse,
    );
  });

  test(
    'follows javascript redirect and extracts streams from target payload',
    () async {
      var hits = 0;
      final plugin = VoeResolverPlugin(
        httpClient: MockClient((request) async {
          hits++;
          if (request.url.host == 'voe.sx') {
            return http.Response(redirectFixture, 200);
          }
          if (request.url.host == 'lancewhosedifficult.com') {
            expect(request.headers['referer'], contains('voe.sx/e/abcd1234'));
            return http.Response(redirectTargetFixture, 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final result = await plugin.resolve(
        Uri.parse('https://voe.sx/e/abcd1234'),
      );

      expect(hits, 2);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (streams) {
          expect(streams, hasLength(2));
          expect(streams.where((stream) => stream.isHls), isNotEmpty);
          expect(
            streams.where((stream) => stream.mimeType == 'video/mp4'),
            isNotEmpty,
          );
        },
      );
    },
  );

  test('extracts hls and mp4 streams with metadata', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'voe.sx');
        expect(request.headers['referer'], isNotEmpty);
        return http.Response(sourcesFixture, 200);
      }),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(2));
        expect(streams.first.isHls, isTrue);
        expect(streams.first.mimeType, 'application/vnd.apple.mpegurl');
        expect(streams.last.mimeType, 'video/mp4');
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable urls',
    () async {
      final plugin = VoeResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://voe.sx/e/abcd1234'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.voe.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse error when payload has no stream hints', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.voe.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('returns transport failure for non-200 response', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((_) async => http.Response('fail', 503)),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.transport);
        expect(error.code, 'resolver.voe.transport');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
