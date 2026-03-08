import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  test(
    'selectFor picks highest-priority resolver when multiple support URL',
    () {
      final registry = ResolverRegistry(
        resolvers: <ResolverPlugin>[
          _FakeResolver(host: 'jkanime.net', id: 'low', priority: 100),
          _FakeResolver(host: 'jkanime.net', id: 'high', priority: 200),
        ],
      );

      final selection = registry.selectFor(
        Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
      );

      expect(selection, isA<ResolverSelected>());
      final selected = selection as ResolverSelected;
      expect(selected.resolver.manifest.id, 'high');
    },
  );

  test('selectFor returns notFound when no resolver supports URL', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        _FakeResolver(host: 'other.example', id: 'other', priority: 100),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
    );
    expect(selection, isA<ResolverNotFound>());
  });

  test('selectFor returns ambiguous when top priority ties', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        _FakeResolver(host: 'jkanime.net', id: 'a', priority: 100),
        _FakeResolver(host: 'jkanime.net', id: 'b', priority: 100),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
    );

    expect(selection, isA<ResolverAmbiguous>());
    final ambiguous = selection as ResolverAmbiguous;
    expect(ambiguous.resolvers, hasLength(2));
  });
}

final class _FakeResolver implements ResolverPlugin {
  const _FakeResolver({
    required this.host,
    required this.id,
    required this.priority,
  });

  final String host;
  final String id;

  @override
  final int priority;

  @override
  PluginManifest get manifest => PluginManifest(
    id: id,
    displayName: 'Fake $id',
    type: PluginType.resolver,
    capabilities: const <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    return Success(<ResolvedStream>[
      ResolvedStream(url: url, qualityLabel: 'auto', isHls: true),
    ]);
  }

  @override
  bool supports(Uri url) => url.host.toLowerCase().endsWith(host);
}
