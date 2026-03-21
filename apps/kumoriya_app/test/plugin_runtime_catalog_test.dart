import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/plugin_runtime_catalog.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';

void main() {
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
