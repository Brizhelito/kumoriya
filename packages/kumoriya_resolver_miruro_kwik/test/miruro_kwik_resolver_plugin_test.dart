import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_miruro_kwik/kumoriya_resolver_miruro_kwik.dart';
import 'package:test/test.dart';

void main() {
  test('supports confirmed kwik direct hosts and rejects embeds', () {
    const plugin = MiruroKwikResolverPlugin();

    expect(
      plugin.supports(
        Uri.parse('https://vault-05.uwucdn.top/stream/05/abc/uwu.m3u8'),
      ),
      isTrue,
    );
    expect(
      plugin.supports(
        Uri.parse('https://na-01.cdn.kwik.si/hls/hash/1080p.m3u8'),
      ),
      isTrue,
    );
    expect(
      plugin.supports(Uri.parse('https://kwik.cx/e/InzZMv1U52OE')),
      isFalse,
    );
  });

  test('returns passthrough hls stream with kwik headers', () async {
    const plugin = MiruroKwikResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://vault-05.uwucdn.top/stream/05/abc/uwu.m3u8'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (resolveResult) {
        final stream = resolveResult.streams.single;
        expect(stream.isHls, isTrue);
        expect(stream.headers['Referer'], 'https://kwik.cx/');
        expect(stream.headers['Origin'], 'https://kwik.cx');
      },
    );
  });

  test('returns unsupported-host error for kwik embed links', () async {
    const plugin = MiruroKwikResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://kwik.cx/e/InzZMv1U52OE'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.notFound);
        expect(error.code, 'resolver.miruro_kwik.unsupported_host');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
