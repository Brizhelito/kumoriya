import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_streamwish/kumoriya_resolver_streamwish.dart';
import 'package:test/test.dart';

void main() {
  final sourcesFixture = File(
    'test/fixtures/streamwish_payload_sources.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/streamwish_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/streamwish_payload_empty.html',
  ).readAsStringSync();
  final packedEvalFixture = File(
    'test/fixtures/streamwish_payload_packed_eval.html',
  ).readAsStringSync();

  test('supports known StreamWish hosts', () {
    final plugin = StreamwishResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://streamwish.to/e/abc123')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://sfastwish.com/e/abc123')),
      isTrue,
    );
    expect(plugin.supports(Uri.parse('https://voe.sx/e/abc123')), isFalse);
  });

  test('extracts hls/mp4 stream candidates with metadata', () async {
    final plugin = StreamwishResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'streamwish.to');
        return http.Response(sourcesFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://streamwish.to/e/abc123'),
    );

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
  });

  test('extracts stream from eval-packed payload shape', () async {
    final plugin = StreamwishResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'sfastwish.com');
        return http.Response(packedEvalFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://sfastwish.com/e/abc123'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, isNotEmpty);
        expect(streams.single.url.toString(), contains('master.m3u8'));
        expect(streams.single.isHls, isTrue);
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable links',
    () async {
      final plugin = StreamwishResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://streamwish.to/e/abc123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.streamwish.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse error when no stream hints are present', () async {
    final plugin = StreamwishResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://streamwish.to/e/abc123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.streamwish.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('returns transport error for non-200 response', () async {
    final plugin = StreamwishResolverPlugin(
      httpClient: MockClient((_) async => http.Response('nope', 503)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://streamwish.to/e/abc123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.transport);
        expect(error.code, 'resolver.streamwish.transport');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
