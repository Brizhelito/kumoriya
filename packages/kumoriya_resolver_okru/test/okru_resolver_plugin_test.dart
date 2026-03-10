import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_okru/kumoriya_resolver_okru.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/okru_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/okru_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/okru_payload_empty.html',
  ).readAsStringSync();

  test('supports okru videoembed links', () {
    final plugin = OkruResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://ok.ru/videoembed/123456')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://www.ok.ru/videoembed/123456')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://my.mail.ru/video/123456')),
      isFalse,
    );
  });

  test(
    'extracts hls and mp4 stream candidates from metadata payload',
    () async {
      final plugin = OkruResolverPlugin(
        httpClient: MockClient((request) async {
          expect(request.url.host, 'ok.ru');
          return http.Response(sourcesFixture, 200);
        }),
      );

      final result = await plugin.resolve(
        Uri.parse('https://ok.ru/videoembed/4787623037612'),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (streams) {
          expect(streams, hasLength(3));
          expect(streams.first.isHls, isTrue);
          expect(streams.first.url.path, '/video.m3u8');
          expect(streams[1].qualityLabel, 'mobile');
          expect(streams[2].qualityLabel, 'sd');
        },
      );
    },
  );

  test(
    'returns inconsistent payload when metadata exists without playable links',
    () async {
      final plugin = OkruResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://ok.ru/videoembed/4787623037612'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.okru.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no player hints', () async {
    final plugin = OkruResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://ok.ru/videoembed/4787623037612'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.okru.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
