import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'package:kumoriya_app/src/features/player/infrastructure/native_anime_nexus_bypass_resolver.dart';

void main() {
  group('NativeAnimeNexusBypassResolver', () {
    const resolver = NativeAnimeNexusBypassResolver();

    test('supports anime.nexus watch URLs, rejects everything else', () {
      expect(
        resolver.supports(
          Uri.parse(
            'https://anime.nexus/watch/998f535b-705e-4df1-ab6c-dbb830c741f8/'
            'kyoto-sister-school-exchange-event-group-battle-3-85',
          ),
        ),
        isTrue,
      );
      expect(
        resolver.supports(Uri.parse('https://anime.nexus/')),
        isFalse,
        reason: 'Non-watch paths must not hijack the resolver registry',
      );
      expect(
        resolver.supports(Uri.parse('https://example.com/watch/abc')),
        isFalse,
      );
      expect(
        resolver.supports(Uri.parse('ftp://anime.nexus/watch/abc')),
        isFalse,
      );
    });

    test('priority beats the Dart AnimeNexusResolverPlugin', () {
      // AnimeNexusResolverPlugin.priority == 120. Keep this regression test
      // so a future bump in either resolver is caught immediately.
      expect(resolver.priority, greaterThan(120));
    });

    test('resolve produces the native carrier URL', () async {
      final result = await resolver.resolve(
        Uri.parse('https://anime.nexus/watch/uuid-1/slug-42'),
      );

      expect(result, isA<Success<ResolveResult, KumoriyaError>>());
      final streams =
          (result as Success<ResolveResult, KumoriyaError>).value.streams;
      expect(streams, hasLength(1));
      final carrier = streams.single.url;
      expect(carrier.scheme, 'kumoriya-native');
      expect(carrier.host, 'anime-nexus');
      expect(
        Uri.decodeComponent(carrier.queryParameters['watch']!),
        'https://anime.nexus/watch/uuid-1/slug-42',
      );
      expect(streams.single.isHls, isTrue);
      expect(streams.single.mimeType, 'application/x-mpegURL');
    });

    test('resolve rejects non-anime.nexus URLs', () async {
      final result = await resolver.resolve(
        Uri.parse('https://example.com/watch/abc'),
      );
      expect(result, isA<Failure<ResolveResult, KumoriyaError>>());
    });
  });
}
