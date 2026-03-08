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

  test('supports only jkanime jkplayer links', () {
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
      plugin.supports(Uri.parse('https://example.com/video?id=1')),
      isFalse,
    );
  });

  test('resolve extracts HLS stream with metadata and headers', () async {
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
      onSuccess: (streams) {
        expect(streams, hasLength(1));
        expect(streams.single.isHls, isTrue);
        expect(streams.single.mimeType, 'application/vnd.apple.mpegurl');
        expect(streams.single.qualityLabel, '720p');
        expect(streams.single.headers['Referer'], isNotEmpty);
      },
    );
  });

  test('resolve extracts escaped mp4 stream', () async {
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
      onSuccess: (streams) {
        expect(streams.single.isHls, isFalse);
        expect(streams.single.mimeType, 'video/mp4');
        expect(streams.single.qualityLabel, '1080p');
      },
    );
  });

  test('resolve returns notFound for unsupported host', () async {
    final plugin = JkPlayerResolverPlugin();

    final result = await plugin.resolve(Uri.parse('https://example.com/video'));
    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.notFound);
        expect(error.code, 'resolver.jkplayer.unsupported_host');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test(
    'resolve returns malformed link when required token is missing',
    () async {
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
    },
  );

  test('resolve returns parse failure when no stream URL is present', () async {
    final plugin = JkPlayerResolverPlugin(
      httpClient: MockClient((_) async => http.Response(noStreamsFixture, 200)),
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
  });

  test('resolve returns transport failure for non-200 response', () async {
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
