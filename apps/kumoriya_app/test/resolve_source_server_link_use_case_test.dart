import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves stream when resolver exists and returns streams', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(host: 'jkanime.net'),
        ],
      ),
    );

    final result = await useCase.call(
      SourceServerLink(
        serverId: 'desu-0',
        serverName: 'Desu',
        initialUrl: Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
      ),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (streams) {
        expect(streams, hasLength(1));
        expect(streams.single.isHls, isTrue);
      },
    );
  });

  test('returns no_resolver when no resolver supports link host', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(host: 'other.example'),
        ],
      ),
    );

    final result = await useCase.call(
      SourceServerLink(
        serverId: 'desu-0',
        serverName: 'Desu',
        initialUrl: Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.code, 'resolver.no_resolver');
        expect(error.kind, KumoriyaErrorKind.notFound);
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('returns malformed_link for malformed source URL', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(host: 'jkanime.net'),
        ],
      ),
    );

    final result = await useCase.call(
      SourceServerLink(
        serverId: 'desu-0',
        serverName: 'Desu',
        initialUrl: Uri(),
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.code, 'resolver.malformed_link');
        expect(error.kind, KumoriyaErrorKind.mapping);
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('propagates resolver failures', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _FailureResolver(host: 'jkanime.net'),
        ],
      ),
    );

    final result = await useCase.call(
      SourceServerLink(
        serverId: 'desu-0',
        serverName: 'Desu',
        initialUrl: Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) {
        expect(error.code, 'resolver.transport');
        expect(error.kind, KumoriyaErrorKind.transport);
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });
}

final class _SuccessResolver implements ResolverPlugin {
  const _SuccessResolver({required this.host});

  final String host;

  @override
  PluginManifest get manifest => PluginManifest(
    id: 'success.$host',
    displayName: 'Success $host',
    type: PluginType.resolver,
    capabilities: const <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    return Success(<ResolvedStream>[
      ResolvedStream(
        url: Uri.parse('https://stream.example/master.m3u8'),
        qualityLabel: 'auto',
        isHls: true,
      ),
    ]);
  }

  @override
  bool supports(Uri url) => url.host.toLowerCase().endsWith(host);
}

final class _FailureResolver implements ResolverPlugin {
  const _FailureResolver({required this.host});

  final String host;

  @override
  PluginManifest get manifest => PluginManifest(
    id: 'failure.$host',
    displayName: 'Failure $host',
    type: PluginType.resolver,
    capabilities: const <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    return const Failure(
      SimpleError(
        code: 'resolver.transport',
        message: 'network',
        kind: KumoriyaErrorKind.transport,
      ),
    );
  }

  @override
  bool supports(Uri url) => url.host.toLowerCase().endsWith(host);
}
