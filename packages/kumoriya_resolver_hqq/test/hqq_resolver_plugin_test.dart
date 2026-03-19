import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_hqq/kumoriya_resolver_hqq.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/hqq_payload_sources.html',
  ).readAsStringSync();
  final embedPageFixture = File(
    'test/fixtures/hqq_embed_page.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/hqq_payload_inconsistent.html',
  ).readAsStringSync();
  final md5SuccessFixture = File(
    'test/fixtures/hqq_md5_success.json',
  ).readAsStringSync();
  final md5ChallengeFixture = File(
    'test/fixtures/hqq_md5_challenge.json',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/hqq_payload_empty.html',
  ).readAsStringSync();

  test('supports hqq embed links and direct e links', () {
    final plugin = HqqResolverPlugin();

    expect(
      plugin.supports(
        Uri.parse(
          'https://hqq.tv/player/embed_player.php?vid=265236238205211208278225263244206267194271217261258',
        ),
      ),
      isTrue,
    );
    expect(
      plugin.supports(
        Uri.parse(
          'https://hqq.tv/e/265236238205211208278225263244206267194271217261258',
        ),
      ),
      isTrue,
    );
    expect(plugin.supports(Uri.parse('https://ok.ru/videoembed/123')), isFalse);
  });

  test('resolves hls stream from hqq md5 handshake payload', () async {
    final plugin = HqqResolverPlugin(
      httpClient: MockClient((request) async {
        if (request.url.path == '/player/embed_player.php') {
          return http.Response(embedPageFixture, 200);
        }
        if (request.url.path == '/player/get_md5.php') {
          expect(request.method, 'POST');
          return http.Response(md5SuccessFixture, 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse(
        'https://hqq.tv/player/embed_player.php?vid=265236238205211208278225263244206267194271217261258',
      ),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.isHls, isTrue);
        expect(streams.single.url.host, 'cdn.example.com');
        expect(streams.single.url.path, '/hls/master.mp4.m3u8');
      },
    );
  });

  test('converts direct e link into embed player request', () async {
    final plugin = HqqResolverPlugin(
      httpClient: MockClient((request) async {
        if (request.url.path == '/player/embed_player.php') {
          expect(
            request.url.queryParameters['vid'],
            '265236238205211208278225263244206267194271217261258',
          );
          return http.Response(embedPageFixture, 200);
        }
        if (request.url.path == '/player/get_md5.php') {
          return http.Response(md5SuccessFixture, 200);
        }
        return http.Response('Not found', 404);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse(
        'https://hqq.tv/e/265236238205211208278225263244206267194271217261258',
      ),
    );

    expect(result.isSuccess, isTrue);
  });

  test(
    'falls back to trusted direct player source when already present',
    () async {
      final plugin = HqqResolverPlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/player/embed_player.php');
          return http.Response(sourcesFixture, 200);
        }),
      );

      final result = await plugin.resolve(
        Uri.parse(
          'https://hqq.tv/player/embed_player.php?vid=265236238205211208278225263244206267194271217261258',
        ),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (result) {
          final streams = result.streams;
          expect(streams, hasLength(1));
          expect(streams.single.url.host, '4fw4gd.cfglobalcdn.com');
        },
      );
    },
  );

  test('returns challenge failure when hqq blocks the md5 handshake', () async {
    final plugin = HqqResolverPlugin(
      httpClient: MockClient((request) async {
        if (request.url.path == '/player/embed_player.php') {
          return http.Response(embedPageFixture, 200);
        }
        if (request.url.path == '/player/get_md5.php') {
          return http.Response(md5ChallengeFixture, 407);
        }
        return http.Response('Not found', 404);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse(
        'https://hqq.tv/player/embed_player.php?vid=265236238205211208278225263244206267194271217261258',
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.hqq.challenge_required');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable links',
    () async {
      final plugin = HqqResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse(
          'https://hqq.tv/player/embed_player.php?vid=265236238205211208278225263244206267194271217261258',
        ),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.hqq.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no hints', () async {
    final plugin = HqqResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse(
        'https://hqq.tv/player/embed_player.php?vid=265236238205211208278225263244206267194271217261258',
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.hqq.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
