import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_mp4upload/kumoriya_resolver_mp4upload.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/mp4upload_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/mp4upload_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/mp4upload_payload_empty.html',
  ).readAsStringSync();

  test('supports mp4upload embed links', () {
    final plugin = Mp4uploadResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://www.mp4upload.com/embed-abc123.html')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://mp4upload.com/embed-abc123.html')),
      isTrue,
    );
    expect(plugin.supports(Uri.parse('https://mixdrop.co/e/abc123')), isFalse);
  });

  test('extracts mp4 stream candidate', () async {
    final plugin = Mp4uploadResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'www.mp4upload.com');
        return http.Response(sourcesFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://www.mp4upload.com/embed-abc123.html'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.mimeType, 'video/mp4');
        expect(streams.single.url.host, 'cdn.mp4upload.com');
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable links',
    () async {
      final plugin = Mp4uploadResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://www.mp4upload.com/embed-abc123.html'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.mp4upload.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no hints', () async {
    final plugin = Mp4uploadResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://www.mp4upload.com/embed-abc123.html'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.mp4upload.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('returns transport failure for non-200 response', () async {
    final plugin = Mp4uploadResolverPlugin(
      httpClient: MockClient((_) async => http.Response('fail', 500)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://www.mp4upload.com/embed-abc123.html'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.transport);
        expect(error.code, 'resolver.mp4upload.transport');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
