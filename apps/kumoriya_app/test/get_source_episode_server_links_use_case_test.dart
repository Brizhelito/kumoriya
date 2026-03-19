import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/get_source_episode_server_links_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  test('filters unsupported and download-only links', () async {
    final useCase = GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: _FakeSourcePlugin(),
      registry: ResolverRegistry(
        resolvers: <ResolverPlugin>[_FakeResolver(host: 'streamtape.com')],
      ),
    );

    final result = await useCase.call(
      SourceEpisode(
        sourceEpisodeId: '1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    );

    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (links) {
        expect(links, hasLength(1));
        expect(links.first.detectedHost, 'streamtape.com');
      },
    );
  });

  test(
    'returns no-supported-links when source links cannot be resolved',
    () async {
      final useCase = GetSourceEpisodeServerLinksUseCase(
        sourcePlugin: _FakeSourcePlugin(),
        registry: const ResolverRegistry(resolvers: <ResolverPlugin>[]),
      );

      final result = await useCase.call(
        SourceEpisode(
          sourceEpisodeId: '1',
          number: 1,
          title: 'Episode 1',
          episodeUrl: Uri.parse('https://example.com/1'),
        ),
      );

      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) => expect(error.code, 'source.no_supported_links'),
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );
}

final class _FakeSourcePlugin implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.source',
    displayName: 'Fake Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.linkExtraction},
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'stream',
        serverName: 'StreamTape',
        initialUrl: Uri.parse('https://streamtape.com/e/abc/'),
        detectedHost: 'streamtape.com',
      ),
      SourceServerLink(
        serverId: 'download',
        serverName: 'Mega',
        initialUrl: Uri.parse('https://mega.nz/file/abc'),
        linkType: SourceServerLinkType.download,
        detectedHost: 'mega.nz',
      ),
      SourceServerLink(
        serverId: 'unsupported',
        serverName: 'Unknown',
        initialUrl: Uri.parse('https://unsupported.example/e/abc'),
        detectedHost: 'unsupported.example',
      ),
    ]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    throw UnimplementedError();
  }
}

final class _FakeResolver implements ResolverPlugin {
  const _FakeResolver({required this.host});

  final String host;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.resolver',
    displayName: 'Fake Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.linkExtraction},
  );

  @override
  int get priority => 100;

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    throw UnimplementedError();
  }

  @override
  bool supports(Uri url) => url.host == host;
}
