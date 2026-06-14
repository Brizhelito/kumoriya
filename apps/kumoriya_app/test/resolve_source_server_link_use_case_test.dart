import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  test('resolves stream when resolver exists and returns streams', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(
            host: 'jkanime.net',
            id: 'resolver.primary',
            priority: 100,
          ),
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
      onSuccess: (resolved) {
        expect(resolved.streams, hasLength(1));
        expect(resolved.streams.single.isHls, isTrue);
        expect(resolved.resolverId, 'resolver.primary');
      },
    );
  });

  test('returns no_resolver when no resolver supports link host', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(
            host: 'other.example',
            id: 'resolver.other',
            priority: 100,
          ),
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

  test('returns ambiguous when top resolver candidates tie', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(
            host: 'jkanime.net',
            id: 'resolver.a',
            priority: 100,
          ),
          _SuccessResolver(
            host: 'jkanime.net',
            id: 'resolver.b',
            priority: 100,
          ),
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
        expect(error.code, 'resolver.ambiguous');
        expect(error.kind, KumoriyaErrorKind.unexpected);
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test('uses preferred resolver when it supports the URL', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(
            host: 'jkanime.net',
            id: 'resolver.a',
            priority: 100,
          ),
          _SuccessResolver(
            host: 'jkanime.net',
            id: 'resolver.b',
            priority: 100,
          ),
        ],
      ),
    );

    final result = await useCase.call(
      SourceServerLink(
        serverId: 'desu-0',
        serverName: 'Desu',
        initialUrl: Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
      ),
      preferredResolverId: 'resolver.b',
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (resolved) {
        expect(resolved.resolverId, 'resolver.b');
      },
    );
  });

  test('returns malformed_link for malformed source URL', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _SuccessResolver(
            host: 'jkanime.net',
            id: 'resolver.primary',
            priority: 100,
          ),
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
          _FailureResolver(
            host: 'jkanime.net',
            id: 'resolver.fail',
            priority: 200,
          ),
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

  test('returns timeout when resolver never finishes', () async {
    final useCase = ResolveSourceServerLinkUseCase(
      registry: ResolverRegistry(
        resolvers: const <ResolverPlugin>[
          _NeverCompletesResolver(
            host: 'jkanime.net',
            id: 'resolver.hang',
            priority: 300,
          ),
        ],
      ),
      resolveTimeout: const Duration(milliseconds: 10),
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
        expect(error.code, 'resolver.timeout');
        expect(error.kind, KumoriyaErrorKind.transport);
      },
      onSuccess: (_) => fail('expected failure'),
    );
  });

  test(
    'keeps mediafire links unresolved when no playback resolver exists',
    () async {
      final useCase = ResolveSourceServerLinkUseCase(
        registry: ResolverRegistry(
          resolvers: const <ResolverPlugin>[
            _SuccessResolver(
              host: 'jkanime.net',
              id: 'resolver.primary',
              priority: 100,
            ),
          ],
        ),
      );

      final result = await useCase.call(
        SourceServerLink(
          serverId: 'download-mediafire',
          serverName: 'Mediafire',
          initialUrl: Uri.parse('https://mediafire.com/file/abc123/'),
          linkType: SourceServerLinkType.download,
          detectedHost: 'mediafire.com',
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
    },
  );

  test(
    'resolves direct stream when isDirectStream is true and no resolver exists',
    () async {
      final useCase = ResolveSourceServerLinkUseCase(
        registry: ResolverRegistry(resolvers: const <ResolverPlugin>[]),
      );

      final result = await useCase.call(
        SourceServerLink(
          serverId: 'direct-0',
          serverName: 'Direct',
          initialUrl: Uri.parse('https://example.com/video.m3u8'),
          isDirectStream: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (resolved) {
          expect(resolved.resolverId, 'direct');
          expect(resolved.streams, hasLength(1));
          expect(resolved.streams.single.isHls, isTrue);
          expect(
            resolved.streams.single.url.toString(),
            'https://example.com/video.m3u8',
          );
        },
      );
    },
  );
}

final class _SuccessResolver implements ResolverPlugin {
  const _SuccessResolver({
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
    displayName: 'Success $id',
    type: PluginType.resolver,
    capabilities: const <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse('https://stream.example/master.m3u8'),
            qualityLabel: 'auto',
            isHls: true,
          ),
        ],
      ),
    );
  }

  @override
  bool supports(Uri url) => url.host.toLowerCase().endsWith(host);
}

final class _FailureResolver implements ResolverPlugin {
  const _FailureResolver({
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
    displayName: 'Failure $id',
    type: PluginType.resolver,
    capabilities: const <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
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

final class _NeverCompletesResolver implements ResolverPlugin {
  const _NeverCompletesResolver({
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
    displayName: 'Never $id',
    type: PluginType.resolver,
    capabilities: const <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) {
    return Completer<Result<ResolveResult, KumoriyaError>>().future;
  }

  @override
  bool supports(Uri url) => url.host.toLowerCase().endsWith(host);
}
