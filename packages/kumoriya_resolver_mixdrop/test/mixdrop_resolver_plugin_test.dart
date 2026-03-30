import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_mixdrop/kumoriya_resolver_mixdrop.dart';
import 'package:test/test.dart';

void main() {
  final wurlFixture = File(
    'test/fixtures/mixdrop_payload_wurl.html',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/mixdrop_payload_inconsistent.html',
  ).readAsStringSync();
  final emptyFixture = File(
    'test/fixtures/mixdrop_payload_empty.html',
  ).readAsStringSync();
  final packedEvalFixture = File(
    'test/fixtures/mixdrop_payload_packed_eval.html',
  ).readAsStringSync();

  test('supports known MixDrop hosts', () {
    final plugin = MixdropResolverPlugin();

    expect(plugin.supports(Uri.parse('https://mixdrop.co/e/abc123')), isTrue);
    expect(plugin.supports(Uri.parse('https://mixdrop.top/e/abc123')), isTrue);
    expect(plugin.supports(Uri.parse('https://mxdrop.to/e/abc123')), isTrue);
    expect(plugin.supports(Uri.parse('https://mixdrop.is/e/abc123')), isTrue);
    expect(plugin.supports(Uri.parse('https://mdbekjwqa.pw/e/abc123')), isTrue);
    expect(
      plugin.supports(Uri.parse('https://evil-mxdrop-gateway.com/e/abc123')),
      isFalse,
    );
    expect(
      plugin.supports(Uri.parse('https://streamwish.to/e/abc123')),
      isFalse,
    );
  });

  test('extracts stream from MDCore.wurl payload', () async {
    final plugin = MixdropResolverPlugin(
      httpClient: _StaticStreamedClient(
        body: wurlFixture,
        statusCode: 200,
        responseUrl: Uri.parse('https://m1xdrop.bz/e/abc123'),
        onRequest: (request) => expect(request.url.host, 'mixdrop.co'),
      ),
    );

    final result = await plugin.resolve(
      Uri.parse('https://mixdrop.co/e/abc123'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.url.host, 'cdn.mixdrop.co');
        expect(streams.single.mimeType, 'video/mp4');
        expect(streams.single.headers['Referer'], 'https://m1xdrop.bz/');
        expect(streams.single.headers['Origin'], 'https://m1xdrop.bz');
        expect(streams.single.headers.containsKey('User-Agent'), isTrue);
      },
    );
  });

  test('extracts stream from mxcontent path without file extension', () async {
    const mxContentFixture = '''
<html>
  <body>
    <script>MDCore = {}; MDCore.wurl = "//a-4.mxcontent.net/17/abcde12345";</script>
  </body>
</html>
''';
    final plugin = MixdropResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'mdbekjwqa.pw');
        return http.Response(mxContentFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://mdbekjwqa.pw/e/abc123'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.url.host, 'a-4.mxcontent.net');
      },
    );
  });

  test('extracts stream from packed eval payload', () async {
    final plugin = MixdropResolverPlugin(
      httpClient: MockClient(
        (_) async => http.Response(packedEvalFixture, 200),
      ),
    );

    final result = await plugin.resolve(
      Uri.parse('https://mxdrop.to/e/abc123'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.url.host, 'cdn.mixdrop');
        expect(streams.single.url.path, '/video/abc.file_720p.mp4');
        expect(streams.single.headers['Referer'], 'https://mxdrop.to/');
        expect(streams.single.headers['Origin'], 'https://mxdrop.to');
        expect(streams.single.headers.containsKey('User-Agent'), isTrue);
      },
    );
  });

  test(
    'returns inconsistent payload when hints exist without playable links',
    () async {
      final plugin = MixdropResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://mixdrop.co/e/abc123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.mixdrop.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload has no hints', () async {
    final plugin = MixdropResolverPlugin(
      httpClient: MockClient((_) async => http.Response(emptyFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://mixdrop.co/e/abc123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.mixdrop.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('returns transport failure for non-200 response', () async {
    final plugin = MixdropResolverPlugin(
      httpClient: MockClient((_) async => http.Response('nope', 500)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://mixdrop.co/e/abc123'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.transport);
        expect(error.code, 'resolver.mixdrop.transport');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}

final class _StreamedResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _StreamedResponseWithUrl(
    super.stream,
    super.statusCode, {
    required this.url,
    super.request,
  });

  @override
  final Uri url;
}

final class _StaticStreamedClient extends http.BaseClient {
  _StaticStreamedClient({
    required this.body,
    required this.statusCode,
    required this.responseUrl,
    this.onRequest,
  });

  final String body;
  final int statusCode;
  final Uri responseUrl;
  final void Function(http.BaseRequest request)? onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onRequest?.call(request);
    return _StreamedResponseWithUrl(
      http.ByteStream.fromBytes(utf8.encode(body)),
      statusCode,
      url: responseUrl,
      request: request,
    );
  }
}
