import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/plugin_runtime_catalog.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';

void main() {
  test(
    'anime.nexus watch URL picks the native bypass on Android, legacy elsewhere',
    () {
      final registry = ResolverRegistry(
        resolvers: buildDefaultResolverPlugins(),
      );
      // segments[1] must be a UUID for the legacy resolver's
      // supports() to match; the native bypass accepts any non-empty
      // segment so the URL is compatible with both candidates.
      final selection = registry.selectFor(
        Uri.parse(
          'https://anime.nexus/watch/'
          '550e8400-e29b-41d4-a716-446655440000/my-anime/1',
        ),
      );
      expect(selection, isA<ResolverSelected>());
      final id = (selection as ResolverSelected).resolver.manifest.id;
      // On Android the native-bypass resolver (priority 200) must win
      // over the legacy Dart-proxy resolver (priority 120). Everywhere
      // else the native bypass is not registered so the legacy
      // resolver is the only candidate.
      if (Platform.isAndroid) {
        expect(id, 'kumoriya.resolver.anime_nexus.native_bypass');
      } else {
        expect(id, 'kumoriya.resolver.anime_nexus');
      }
    },
  );

  test('default resolver catalog covers common JKAnime stream hosts', () {
    final registry = ResolverRegistry(resolvers: buildDefaultResolverPlugins());

    final expectations = <Uri, String>{
      Uri.parse('https://voe.sx/e/abc123'): 'kumoriya.resolver.voe',
      Uri.parse('https://mixdrop.co/e/abc123'): 'kumoriya.resolver.mixdrop',
      Uri.parse('https://filemoon.sx/e/abc123'): 'kumoriya.resolver.filemoon',
      Uri.parse('https://vidhide.com/e/abc123'): 'kumoriya.resolver.vidhide',
      Uri.parse('https://sfastwish.com/e/abc123'):
          'kumoriya.resolver.streamwish',
      Uri.parse('https://dood.la/e/abc123'): 'kumoriya.resolver.doodstream',
    };

    for (final entry in expectations.entries) {
      final selection = registry.selectFor(entry.key);
      expect(
        selection,
        isA<ResolverSelected>(),
        reason: '${entry.key} should resolve',
      );
      final selected = selection as ResolverSelected;
      expect(selected.resolver.manifest.id, entry.value);
    }
  });
}
