import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_filemoon/kumoriya_resolver_filemoon.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:kumoriya_resolver_voe/kumoriya_resolver_voe.dart';

void main() {
  test('registry selects voe resolver for voe host url', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerResolverPlugin(),
        FilemoonResolverPlugin(),
        VoeResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(Uri.parse('https://voe.sx/e/abc123'));

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.voe');
  });

  test('registry selects filemoon resolver for filemoon host url', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerJkResolverPlugin(),
        VoeResolverPlugin(),
        FilemoonResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://filemoon.sx/e/xyz123'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.filemoon');
  });

  test('registry remains deterministic with different host resolvers', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        VoeResolverPlugin(),
        FilemoonResolverPlugin(),
        JkPlayerResolverPlugin(),
      ],
    );

    final voeSelection = registry.selectFor(Uri.parse('https://voe.sx/e/a1'));
    final jkSelection = registry.selectFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
    );

    expect(voeSelection, isA<ResolverSelected>());
    expect(jkSelection, isA<ResolverSelected>());
    expect(
      (voeSelection as ResolverSelected).resolver.manifest.id,
      'kumoriya.resolver.voe',
    );
    expect(
      (jkSelection as ResolverSelected).resolver.manifest.id,
      'kumoriya.resolver.jkplayer.um',
    );
  });
}
