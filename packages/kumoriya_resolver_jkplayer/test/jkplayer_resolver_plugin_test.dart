import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:test/test.dart';

void main() {
  final hlsFixture = File(
    'test/fixtures/jkplayer_payload_hls.html',
  ).readAsStringSync();
  final escapedMp4Fixture = File(
    'test/fixtures/jkplayer_payload_escaped_mp4.html',
  ).readAsStringSync();
  final noStreamsFixture = File(
    'test/fixtures/jkplayer_payload_no_streams.html',
  ).readAsStringSync();
  final jkFixture = File(
    'test/fixtures/jkplayer_payload_jk_url.html',
  ).readAsStringSync();

  test('um resolver supports only um and umv paths', () {
    final plugin = JkPlayerResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://jkanime.net/jkplayer/um?e=abc')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://jkanime.net/jkplayer/umv?e=abc')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://jkanime.net/jkplayer/jk?u=stream/x')),
      isFalse,
    );
  });

  test('jk resolver supports only jk path', () {
    final plugin = JkPlayerJkResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://jkanime.net/jkplayer/jk?u=stream/x')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://jkanime.net/jkplayer/um?e=abc')),
      isFalse,
    );
  });

  test('um resolver extracts HLS stream with metadata and headers', () async {
    final plugin = JkPlayerResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/jkplayer/um');
        expect(request.headers['referer'], isNotEmpty);
        return http.Response(hlsFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc&t=def'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.isHls, isTrue);
        expect(streams.single.mimeType, 'application/vnd.apple.mpegurl');
        expect(streams.single.qualityLabel, '720p');
        expect(streams.single.headers['Referer'], isNotEmpty);
      },
    );
  });

  test('um resolver extracts escaped mp4 stream', () async {
    final plugin = JkPlayerResolverPlugin(
      httpClient: MockClient(
        (_) async => http.Response(escapedMp4Fixture, 200),
      ),
    );

    final result = await plugin.resolve(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc&t=def'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams.single.isHls, isFalse);
        expect(streams.single.mimeType, 'video/mp4');
        expect(streams.single.qualityLabel, '1080p');
      },
    );
  });

  test('jk resolver extracts stream URL without media extension', () async {
    final plugin = JkPlayerJkResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/jkplayer/jk');
        return http.Response(jkFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://jkanime.net/jkplayer/jk?u=stream/jkmedia/abc/1/2/3/'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.url.host, 'jkplayers.com');
        expect(streams.single.mimeType, isNull);
      },
    );
  });

  test('um resolver returns malformed link when token e is missing', () async {
    final plugin = JkPlayerResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://jkanime.net/jkplayer/um'),
    );
    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.jkplayer.malformed_link');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('jk resolver returns malformed link when token u is missing', () async {
    final plugin = JkPlayerJkResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://jkanime.net/jkplayer/jk'),
    );
    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.jkplayer.malformed_link');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test(
    'um resolver returns parse failure when no stream URL is present',
    () async {
      final plugin = JkPlayerResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(noStreamsFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://jkanime.net/jkplayer/um?e=abc&t=def'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.jkplayer.parse');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('resolver returns transport failure for non-200 response', () async {
    final plugin = JkPlayerResolverPlugin(
      httpClient: MockClient((_) async => http.Response('fail', 503)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc&t=def'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.transport);
        expect(error.code, 'resolver.jkplayer.transport');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
