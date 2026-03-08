import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';

void main() {
  test('registry selects jk resolver for /jkplayer/jk links', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerResolverPlugin(),
        JkPlayerJkResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://jkanime.net/jkplayer/jk?u=stream/jkmedia/a/b/1/2/'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.jkplayer.jk');
  });

  test('registry selects um resolver for /jkplayer/um links', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerJkResolverPlugin(),
        JkPlayerResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc&t=def'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.jkplayer.um');
  });
}
