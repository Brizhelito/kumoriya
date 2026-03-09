import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_vidhide/kumoriya_resolver_vidhide.dart';
import 'package:test/test.dart';

void main() {
  group('VidhideResolverPlugin.supports', () {
    final plugin = VidhideResolverPlugin();

    test('accepts vidhide.com /e/ path', () {
      expect(
        plugin.supports(Uri.parse('https://vidhide.com/e/abc123')),
        isTrue,
      );
    });

    test('accepts vidhide.com /v/ path', () {
      expect(
        plugin.supports(Uri.parse('https://vidhide.com/v/abc123')),
        isTrue,
      );
    });

    test('accepts vidhidevip.com /embed/ path (JKAnime current pattern)', () {
      expect(
        plugin.supports(Uri.parse('https://vidhidevip.com/embed/4bd00sirezr5')),
        isTrue,
      );
    });

    test('accepts vidhidepro.com /embed/ path', () {
      expect(
        plugin.supports(Uri.parse('https://vidhidepro.com/embed/abc123')),
        isTrue,
      );
    });

    test('rejects unknown host', () {
      expect(
        plugin.supports(Uri.parse('https://streamwish.to/e/abc123')),
        isFalse,
      );
    });

    test('rejects vidhide.com with wrong path', () {
      expect(
        plugin.supports(Uri.parse('https://vidhide.com/watch/abc123')),
        isFalse,
      );
    });

    test('rejects missing host', () {
      expect(plugin.supports(Uri.parse('/embed/abc123')), isFalse);
    });
  });

  group('VidhideResolverPlugin.resolve', () {
    const packedHtml = r'''
<html><body>
<script>
eval(function(p,a,c,k,e,d){e=function(c){return c};if(!''.replace(/^/,String)){while(c--){d[c]=k[c]||c}k=[function(e){return d[e]}];e=function(){return'\w+'};c=1};while(c--){if(k[c]){p=p.replace(new RegExp('\b'+e(c)+'\b','g'),k[c])}}return p}('var links={"hls2":"https://cdn.example.com/hls/abc123/master.m3u8"};jwplayer("vplayer").setup({sources:[{file:links.hls2,type:"hls"}]});',62,3,'|||'.split('|'),0,{}))
</script>
</body></html>
''';

    const plainHlsHtml = '''
<html><body>
<script>
var sources = [{file: "https://cdn.example.com/hls/abc123/master.m3u8", type: "hls"}];
</script>
</body></html>
''';

    test('extracts HLS stream from plain sources key', () async {
      final plugin = VidhideResolverPlugin(
        httpClient: MockClient((request) async {
          expect(request.url.host, 'vidhidevip.com');
          return http.Response(plainHlsHtml, 200);
        }),
      );

      final result = await plugin.resolve(
        Uri.parse('https://vidhidevip.com/embed/abc123'),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (streams) {
          expect(streams, isNotEmpty);
          expect(streams.first.isHls, isTrue);
          expect(
            streams.first.url.toString(),
            contains('master.m3u8'),
          );
        },
      );
    });

    test('returns transport error on non-200 response', () async {
      final plugin = VidhideResolverPlugin(
        httpClient: MockClient((_) async => http.Response('Forbidden', 403)),
      );

      final result = await plugin.resolve(
        Uri.parse('https://vidhide.com/e/abc123'),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (err) => expect(err.code, contains('transport')),
        onSuccess: (_) => fail('expected failure'),
      );
    });

    test('returns parse error when no stream candidates in payload', () async {
      final plugin = VidhideResolverPlugin(
        httpClient: MockClient(
          (_) async => http.Response('<html><body>empty</body></html>', 200),
        ),
      );

      final result = await plugin.resolve(
        Uri.parse('https://vidhide.com/e/abc123'),
      );

      expect(result.isFailure, isTrue);
    });
  });
}
