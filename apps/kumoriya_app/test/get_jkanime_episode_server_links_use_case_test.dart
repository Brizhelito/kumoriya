import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/get_jkanime_episode_server_links_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  test('returns server links from source plugin', () async {
    final useCase = GetJkanimeEpisodeServerLinksUseCase(
      sourcePlugin: _FakeSourcePluginSuccess(),
    );

    final episode = SourceEpisode(
      sourceEpisodeId: '1',
      number: 1,
      title: 'Episode 1',
      episodeUrl: Uri.parse('https://jkanime.net/anime/1/'),
    );

    final result = await useCase.call(episode);
    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (links) {
        expect(links, hasLength(1));
        expect(links.first.serverName, 'Desu');
      },
    );
  });

  test('returns typed failure from source plugin', () async {
    final useCase = GetJkanimeEpisodeServerLinksUseCase(
      sourcePlugin: _FakeSourcePluginFailure(),
    );

    final episode = SourceEpisode(
      sourceEpisodeId: '2',
      number: 2,
      title: 'Episode 2',
      episodeUrl: Uri.parse('https://jkanime.net/anime/2/'),
    );

    final result = await useCase.call(episode);
    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error.kind, KumoriyaErrorKind.transport),
      onSuccess: (_) => fail('expected failure'),
    );
  });
}

final class _FakeSourcePluginSuccess implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.success',
    displayName: 'Fake Success',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.episodeList},
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
        serverId: 'desu-0',
        serverName: 'Desu',
        initialUrl: Uri.parse('https://jkanime.net/jkplayer/um?e=x'),
        language: 'sub',
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

final class _FakeSourcePluginFailure implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.failure',
    displayName: 'Fake Failure',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.episodeList},
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
    return const Failure(
      SimpleError(
        code: 'source.transport',
        message: 'network down',
        kind: KumoriyaErrorKind.transport,
      ),
    );
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    throw UnimplementedError();
  }
}
