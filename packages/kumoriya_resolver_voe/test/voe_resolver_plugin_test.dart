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
  final placeholderOnlyFixture = File(
    'test/fixtures/voe_payload_placeholder_only.html',
  ).readAsStringSync();
  final tokenGatedFixture = File(
    'test/fixtures/voe_payload_token_gated.html',
  ).readAsStringSync();
  final sessionGatedFixture = File(
    'test/fixtures/voe_payload_session_gated.html',
  ).readAsStringSync();
  final base64EmbeddedFixture = File(
    'test/fixtures/voe_payload_base64_embedded.html',
  ).readAsStringSync();
  final sourceTagFixture = File(
    'test/fixtures/voe_payload_source_tag.html',
  ).readAsStringSync();
  final packedJsFixture = File(
    'test/fixtures/voe_payload_packed_js.html',
  ).readAsStringSync();

  test('supports voe hosts with /e/ path', () {
    final plugin = VoeResolverPlugin();

    expect(plugin.supports(Uri.parse('https://voe.sx/e/abcd1234')), isTrue);
    expect(plugin.supports(Uri.parse('https://voe.uno/v/abcd1234')), isTrue);
    expect(plugin.supports(Uri.parse('https://voe.cx/e/abcd1234')), isTrue);
    expect(
      plugin.supports(Uri.parse('https://voe.network/e/abcd1234')),
      isTrue,
    );
    expect(plugin.supports(Uri.parse('https://voe.sh/e/abcd1234')), isTrue);
    expect(plugin.supports(Uri.parse('https://voe.su/e/abcd1234')), isTrue);
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

  test('extracts stream from api/video style payload', () async {
    const apiVideoFixture = '''
<html>
  <body>
    <script>var config = { url: "https://voe.sx/api/video/abc12345" };</script>
  </body>
</html>
''';
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((_) async => http.Response(apiVideoFixture, 200)),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(1));
        expect(streams.single.url.toString(), contains('/api/video/abc12345'));
      },
    );
  });

  test('extracts stream from source tag payload', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((_) async => http.Response(sourceTagFixture, 200)),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(1));
        expect(
          streams.single.url.toString(),
          contains('/video/source-123.mp4'),
        );
        expect(streams.single.isHls, isFalse);
      },
    );
  });

  test('extracts stream from base64 embedded payload', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient(
        (_) async => http.Response(base64EmbeddedFixture, 200),
      ),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(1));
        expect(streams.single.isHls, isTrue);
        expect(streams.single.url.toString(), contains('/hls/abc/master.m3u8'));
      },
    );
  });

  test('extracts stream from packed javascript payload', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((_) async => http.Response(packedJsFixture, 200)),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, isNotEmpty);
        expect(
          streams.any(
            (stream) =>
                stream.url.toString().contains('/hls/packed/master.m3u8'),
          ),
          isTrue,
        );
        expect(streams.where((stream) => stream.isHls), isNotEmpty);
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

  test(
    'rejects placeholder demo streams and returns inconsistent error',
    () async {
      final plugin = VoeResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(placeholderOnlyFixture, 200),
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

  test('returns inconsistent for token-gated payload flow', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient(
        (_) async => http.Response(tokenGatedFixture, 200),
      ),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/abcd1234'));

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.voe.inconsistent');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test(
    'returns session-gated failure for runtime token/cookie flow payload',
    () async {
      final plugin = VoeResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(sessionGatedFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://voe.sx/e/abcd1234'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.voe.session_gated');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

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

  test('returns redirect limit error on recursive redirect loop', () async {
    final plugin = VoeResolverPlugin(
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/loop-a')) {
          return http.Response(
            '<script>window.location.href="https://voe.sx/e/loop-b"</script>',
            200,
          );
        }
        return http.Response(
          '<script>window.location.href="https://voe.sx/e/loop-a"</script>',
          200,
        );
      }),
    );

    final result = await plugin.resolve(Uri.parse('https://voe.sx/e/loop-a'));

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.voe.redirect_limit');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
