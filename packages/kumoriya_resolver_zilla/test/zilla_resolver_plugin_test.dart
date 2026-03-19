import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_zilla/kumoriya_resolver_zilla.dart';
import 'package:test/test.dart';

void main() {
  final playlistFixture = File(
    'test/fixtures/zilla_master.m3u8',
  ).readAsStringSync();
  final invalidFixture = File(
    'test/fixtures/zilla_invalid_payload.txt',
  ).readAsStringSync();

  test('supports zilla player links', () {
    final plugin = ZillaResolverPlugin();

    expect(
      plugin.supports(
        Uri.parse(
          'https://player.zilla-networks.com/play/6918779582b6c03ddb61dfd86129d3cd',
        ),
      ),
      isTrue,
    );
    expect(
      plugin.supports(
        Uri.parse(
          'https://player.zilla-networks.com/m3u8/6918779582b6c03ddb61dfd86129d3cd',
        ),
      ),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://pixeldrain.com/u/qi2eVVgY')),
      isFalse,
    );
  });

  test('resolves play url into hls playlist', () async {
    final plugin = ZillaResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/m3u8/6918779582b6c03ddb61dfd86129d3cd');
        return http.Response(playlistFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse(
        'https://player.zilla-networks.com/play/6918779582b6c03ddb61dfd86129d3cd',
      ),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (result) {
        final streams = result.streams;
        expect(streams, hasLength(1));
        expect(streams.single.isHls, isTrue);
        expect(
          streams.single.url.path,
          '/m3u8/6918779582b6c03ddb61dfd86129d3cd',
        );
      },
    );
  });

  test('returns parse failure for non-manifest payload', () async {
    final plugin = ZillaResolverPlugin(
      httpClient: MockClient((_) async => http.Response(invalidFixture, 200)),
    );

    final result = await plugin.resolve(
      Uri.parse(
        'https://player.zilla-networks.com/play/6918779582b6c03ddb61dfd86129d3cd',
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.zilla.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
