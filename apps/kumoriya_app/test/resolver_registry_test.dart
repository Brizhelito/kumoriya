import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('findFor selects resolver that supports URL host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        _FakeResolver(host: 'other.example'),
        _FakeResolver(host: 'jkanime.net'),
      ],
    );

    final resolver = registry.findFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
    );
    expect(resolver, isNotNull);
    expect(resolver!.manifest.id, 'fake.jkanime.net');
  });

  test('findFor returns null when no resolver supports URL', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[_FakeResolver(host: 'other.example')],
    );

    final resolver = registry.findFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
    );
    expect(resolver, isNull);
  });
}

final class _FakeResolver implements ResolverPlugin {
  const _FakeResolver({required this.host});

  final String host;

  @override
  PluginManifest get manifest => PluginManifest(
    id: 'fake.$host',
    displayName: 'Fake $host',
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
