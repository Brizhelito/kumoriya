import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_upnshare/kumoriya_resolver_upnshare.dart';
import 'package:test/test.dart';

void main() {
  final successFixture = File(
    'test/fixtures/upnshare_video_xhutzl.hex',
  ).readAsStringSync();
  final inconsistentFixture = File(
    'test/fixtures/upnshare_video_inconsistent.hex',
  ).readAsStringSync();

  test('supports animeav1 uns bio fragment links', () {
    final plugin = UpnshareResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://animeav1.uns.bio/#xhutzl')),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://animeav1.uns.bio/#xhutzl&dl=1')),
      isTrue,
    );
    expect(plugin.supports(Uri.parse('https://animeav1.uns.bio/')), isFalse);
    expect(
      plugin.supports(Uri.parse('https://other.uns.bio/#xhutzl')),
      isFalse,
    );
  });

  test('resolves cloudflare hls stream from encrypted payload', () async {
    final plugin = UpnshareResolverPlugin(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'animeav1.uns.bio');
        expect(request.url.path, '/api/v1/video');
        expect(request.url.queryParameters['id'], 'xhutzl');
        return http.Response(successFixture, 200);
      }),
    );

    final result = await plugin.resolve(
      Uri.parse('https://animeav1.uns.bio/#xhutzl'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(2));
        expect(streams.first.isHls, isTrue);
        expect(streams.first.url.host, endsWith('assetanalytics.cfd'));
        expect(streams.first.url.path, contains('/xhutzl/cf-master.'));
        expect(streams[1].url.path, contains('/xhutzl/master.m3u8'));
      },
    );
  });

  test(
    'returns inconsistent payload when decrypted json has no playable url',
    () async {
      final plugin = UpnshareResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response(inconsistentFixture, 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://animeav1.uns.bio/#xhutzl'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'resolver.upnshare.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test('returns parse failure when payload is not encrypted hex', () async {
    final plugin = UpnshareResolverPlugin(
      httpClient: MockClient((_) async => http.Response('not-hex', 200)),
    );

    final result = await plugin.resolve(
      Uri.parse('https://animeav1.uns.bio/#xhutzl'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.mapping);
        expect(error.code, 'resolver.upnshare.parse');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
