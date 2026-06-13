import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_miruro_anidb/kumoriya_resolver_miruro_anidb.dart';
import 'package:test/test.dart';

void main() {
  test('supports only confirmed anidb direct streams', () {
    const plugin = MiruroAnidbResolverPlugin();

    expect(
      plugin.supports(Uri.parse('https://hls.anidb.app/stream/4ezavJr2Oxf')),
      isTrue,
    );
    expect(
      plugin.supports(
        Uri.parse(
          'https://anidb.app/embed/VDq1nMbiJ9dPYO-C5pl_BeHaaS2PH1RtnNacGwrWckI',
        ),
      ),
      isFalse,
    );
  });

  test('returns passthrough hls stream with anidb headers', () async {
    const plugin = MiruroAnidbResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://hls.anidb.app/stream/4ezavJr2Oxf'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (resolveResult) {
        final stream = resolveResult.streams.single;
        expect(stream.isHls, isTrue);
        expect(stream.headers['Referer'], 'https://anidb.app/');
      },
    );
  });

  test('returns unsupported-host error for anidb embeds', () async {
    const plugin = MiruroAnidbResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse(
        'https://anidb.app/embed/VDq1nMbiJ9dPYO-C5pl_BeHaaS2PH1RtnNacGwrWckI',
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.notFound);
        expect(error.code, 'resolver.miruro_anidb.unsupported_host');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
