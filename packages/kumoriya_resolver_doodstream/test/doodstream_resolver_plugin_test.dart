import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_resolver_doodstream/kumoriya_resolver_doodstream.dart';
import 'package:test/test.dart';

void main() {
  group('DoodstreamResolverPlugin.supports', () {
    final plugin = DoodstreamResolverPlugin();

    test('accepts canonical doodstream.com /e/ path', () {
      expect(
        plugin.supports(Uri.parse('https://doodstream.com/e/abc123')),
        isTrue,
      );
    });

    test('accepts d-s.io /e/ path (JKAnime current alias)', () {
      expect(
        plugin.supports(Uri.parse('https://d-s.io/e/k6al7x50u88e')),
        isTrue,
      );
    });

    test('accepts dood.la /e/ path', () {
      expect(plugin.supports(Uri.parse('https://dood.la/e/abc123')), isTrue);
    });

    test('accepts dsvplay.com /e/ path (JKAnime 2026-03 alias)', () {
      expect(
        plugin.supports(Uri.parse('https://dsvplay.com/e/q9ribs5zcel5')),
        isTrue,
      );
    });

    test('accepts myvidplay.com /e/ path (dsvplay redirect target)', () {
      expect(
        plugin.supports(Uri.parse('https://myvidplay.com/e/q9ribs5zcel5')),
        isTrue,
      );
    });

    test('accepts /d/ path variant', () {
      expect(
        plugin.supports(Uri.parse('https://doodstream.com/d/abc123')),
        isTrue,
      );
    });

    test('rejects unknown host', () {
      expect(plugin.supports(Uri.parse('https://voe.sx/e/abc123')), isFalse);
    });

    test('rejects doodstream.com with wrong path', () {
      expect(
        plugin.supports(Uri.parse('https://doodstream.com/watch/abc123')),
        isFalse,
      );
    });

    test('rejects missing host', () {
      expect(plugin.supports(Uri.parse('/e/abc123')), isFalse);
    });
  });

  group('DoodstreamResolverPlugin.resolve', () {
    const embedHtml = '''
<html><body>
<script>
var dsplayer = {};
dsplayer.video = '/pass_md5/abc123def456/tokenpath';
</script>
</body></html>
''';

    const partialUrl = 'https://cdn.doodstream.com/v2/abc123def/';

    test('extracts pass_md5 path and builds stream URL', () async {
      var callCount = 0;
      final plugin = DoodstreamResolverPlugin(
        httpClient: MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            expect(request.url.host, 'doodstream.com');
            return http.Response(embedHtml, 200);
          } else {
            expect(request.url.path, '/pass_md5/abc123def456/tokenpath');
            return http.Response(partialUrl, 200);
          }
        }),
      );

      final result = await plugin.resolve(
        Uri.parse('https://doodstream.com/e/abc123'),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (result) {
          final streams = result.streams;
          expect(streams, hasLength(1));
          expect(streams.single.url.toString(), contains(partialUrl));
          expect(streams.single.mimeType, 'video/mp4');
          expect(streams.single.isHls, isFalse);
        },
      );
    });

    test('returns parse error when no pass_md5 path in payload', () async {
      final plugin = DoodstreamResolverPlugin(
        httpClient: MockClient(
          (_) async =>
              http.Response('<html><body>no token here</body></html>', 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://doodstream.com/e/abc123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (err) => expect(err.code, 'resolver.doodstream.parse'),
        onSuccess: (_) => fail('expected failure'),
      );
    });

    test('returns transport error on non-200 response', () async {
      final plugin = DoodstreamResolverPlugin(
        httpClient: MockClient((_) async => http.Response('Not Found', 404)),
      );

      final result = await plugin.resolve(
        Uri.parse('https://doodstream.com/e/abc123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (err) => expect(err.code, contains('transport')),
        onSuccess: (_) => fail('expected failure'),
      );
    });
  });
}
