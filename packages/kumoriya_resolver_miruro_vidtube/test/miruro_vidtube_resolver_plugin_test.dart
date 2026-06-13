import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_resolver_miruro_vidtube/kumoriya_resolver_miruro_vidtube.dart';
import 'package:test/test.dart';

void main() {
  test('supports nekostream direct urls and rejects subtitle assets', () {
    const plugin = MiruroVidtubeResolverPlugin();

    expect(
      plugin.supports(
        Uri.parse(
          'https://mt.nekostream.site/1b252d77b90e951c15c32d17e81e5882',
        ),
      ),
      isTrue,
    );
    expect(
      plugin.supports(
        Uri.parse('https://mt.nekostream.site/1b252/subtitles/English.vtt'),
      ),
      isFalse,
    );
  });

  test('returns passthrough hls stream with vidtube headers', () async {
    const plugin = MiruroVidtubeResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://mt.nekostream.site/1b252d77b90e951c15c32d17e81e5882'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (resolveResult) {
        final stream = resolveResult.streams.single;
        expect(stream.isHls, isTrue);
        expect(stream.headers['Referer'], 'https://vidtube.site/');
      },
    );
  });

  test('returns unsupported-host error for subtitle files', () async {
    const plugin = MiruroVidtubeResolverPlugin();

    final result = await plugin.resolve(
      Uri.parse('https://mt.nekostream.site/1b252/subtitles/English.vtt'),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.kind, KumoriyaErrorKind.notFound);
        expect(error.code, 'resolver.miruro_vidtube.unsupported_host');
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}
