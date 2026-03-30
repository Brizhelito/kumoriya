import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';
import 'package:test/test.dart';

void main() {
  group('DeanEdwardsUnpacker', () {
    test('unpacks a simple base-10 packed payload', () {
      // eval(function(p,a,c,k,e,d){...}('var x=0;var y=1;',10,2,'x|y'.split('|')
      const packed = r"""
        eval(function(p,a,c,k,e,d){return p}('var 0=0;var 1=1;',10,2,'hello|world'.split('|')
      """;
      final results = unpackDeanEdwards(packed);
      expect(results, hasLength(1));
      expect(results.first, contains('hello'));
      expect(results.first, contains('world'));
    });

    test('returns empty list when no packed payloads present', () {
      expect(unpackDeanEdwards('just some normal html'), isEmpty);
    });

    test('hasDeanEdwardsPacking detects packed JS', () {
      const packed = r"""eval(function(p,a,c,k,e,d){return p}('x',10,1,'y'.split('|')""";
      expect(hasDeanEdwardsPacking(packed), isTrue);
      expect(hasDeanEdwardsPacking('no packing here'), isFalse);
    });

    test('buildExtractionPayload combines source with unpacked', () {
      const source = 'original html';
      final payload = buildExtractionPayload(source);
      expect(payload, startsWith('original html'));
    });
  });

  group('decodeJsEscapes', () {
    test('decodes \\x hex escapes', () {
      expect(decodeJsEscapes(r'\x2F'), equals('/'));
      expect(decodeJsEscapes(r'\x3A'), equals(':'));
    });

    test('decodes \\u unicode escapes', () {
      expect(decodeJsEscapes(r'\u0026'), equals('&'));
      expect(decodeJsEscapes(r'\u002F'), equals('/'));
    });

    test('decodes \\/ escape', () {
      expect(decodeJsEscapes(r'\/'), equals('/'));
    });

    test('decodes \\n, \\r, \\t', () {
      expect(decodeJsEscapes(r'\n'), equals('\n'));
      expect(decodeJsEscapes(r'\r'), equals('\r'));
      expect(decodeJsEscapes(r'\t'), equals('\t'));
    });

    test('passes through non-escape characters', () {
      expect(decodeJsEscapes('hello world'), equals('hello world'));
    });
  });

  group('PayloadNormalizer', () {
    test('normalizePayload handles common escapes', () {
      expect(normalizePayload(r'https:\/\/example.com'), 'https://example.com');
      expect(normalizePayload(r'a&amp;b'), 'a&b');
      expect(normalizePayload(r'a\u0026b'), 'a&b');
      expect(normalizePayload(r'a\x2Fb'), 'a/b');
    });

    test('htmlUnescape handles entities', () {
      expect(htmlUnescape('&quot;test&quot;'), '"test"');
      expect(htmlUnescape('&#34;test&#34;'), '"test"');
      expect(htmlUnescape('a&amp;b'), 'a&b');
      expect(htmlUnescape('&#39;quote&#39;'), "'quote'");
    });
  });

  group('UrlHelpers', () {
    test('toAbsoluteUri resolves absolute URLs', () {
      final base = Uri.parse('https://example.com/page');
      final result = toAbsoluteUri('https://cdn.com/video.mp4', base);
      expect(result, isNotNull);
      expect(result!.host, 'cdn.com');
    });

    test('toAbsoluteUri resolves protocol-relative URLs', () {
      final base = Uri.parse('https://example.com/page');
      final result = toAbsoluteUri('//cdn.com/video.mp4', base);
      expect(result, isNotNull);
      expect(result!.scheme, 'https');
      expect(result.host, 'cdn.com');
    });

    test('toAbsoluteUri resolves root-relative URLs', () {
      final base = Uri.parse('https://example.com/page');
      final result = toAbsoluteUri('/video/stream.m3u8', base);
      expect(result, isNotNull);
      expect(result!.host, 'example.com');
      expect(result.path, '/video/stream.m3u8');
    });

    test('toAbsoluteUri returns null for junk', () {
      final base = Uri.parse('https://example.com');
      expect(toAbsoluteUri('not-a-url-at-all', base), isNull);
    });

    test('isPlayableUri detects .mp4 and .m3u8', () {
      expect(isPlayableUri(Uri.parse('https://cdn.com/video.mp4')), isTrue);
      expect(isPlayableUri(Uri.parse('https://cdn.com/master.m3u8')), isTrue);
      expect(isPlayableUri(Uri.parse('https://cdn.com/hls/index')), isTrue);
      expect(isPlayableUri(Uri.parse('https://cdn.com/page.html')), isFalse);
    });

    test('inferQualityFromUrl extracts resolution labels', () {
      expect(
          inferQualityFromUrl(Uri.parse('https://cdn.com/1080p/stream.mp4')),
          '1080p');
      expect(
          inferQualityFromUrl(Uri.parse('https://cdn.com/stream.m3u8')),
          'auto');
      expect(
          inferQualityFromUrl(Uri.parse('https://cdn.com/video.mp4')),
          'unknown');
    });

    test('isHostSupported matches exact and subdomain', () {
      final hosts = {'example.com', 'cdn.test.io'};
      expect(isHostSupported('example.com', hosts), isTrue);
      expect(isHostSupported('sub.example.com', hosts), isTrue);
      expect(isHostSupported('other.com', hosts), isFalse);
    });

    test('buildEmbedHeaders includes Referer and Origin', () {
      final headers =
          buildEmbedHeaders(Uri.parse('https://embed.host.com/e/abc'));
      expect(headers['Referer'], 'https://embed.host.com/');
      expect(headers['Origin'], 'https://embed.host.com');
    });
  });
}
