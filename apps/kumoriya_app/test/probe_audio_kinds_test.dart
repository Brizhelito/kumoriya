import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/downloads/application/probe_audio_kinds.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  final sampleEpisode = SourceEpisode(
    sourceEpisodeId: '1',
    number: 1,
    title: 'Episode 1',
    episodeUrl: Uri.parse('https://example.com/1'),
  );

  ResolverRegistry registryWithHosts(List<String> hosts) {
    return ResolverRegistry(
      resolvers: hosts
          .map<ResolverPlugin>((host) => _FakeResolver(host: host))
          .toList(),
    );
  }

  test('detects both SUB and DUB when source advertises both', () async {
    final kinds = await probeAudioKindsForPlugin(
      sourcePlugin: _DualLanguageSourcePlugin(),
      registry: registryWithHosts(<String>['streamtape.com', 'mp4upload.com']),
      sampleEpisode: sampleEpisode,
    );

    expect(
      kinds,
      equals(<SourceAudioKind>{SourceAudioKind.sub, SourceAudioKind.dub}),
    );
  });

  test('detects only SUB when source has a single language', () async {
    final kinds = await probeAudioKindsForPlugin(
      sourcePlugin: _SingleLanguageSourcePlugin(language: 'sub'),
      registry: registryWithHosts(<String>['streamtape.com']),
      sampleEpisode: sampleEpisode,
    );

    expect(kinds, equals(<SourceAudioKind>{SourceAudioKind.sub}));
  });

  test('returns empty set when source links cannot be resolved', () async {
    final kinds = await probeAudioKindsForPlugin(
      sourcePlugin: _DualLanguageSourcePlugin(),
      registry: ResolverRegistry(resolvers: const <ResolverPlugin>[]),
      sampleEpisode: sampleEpisode,
    );

    expect(kinds, isEmpty);
  });
}

final class _DualLanguageSourcePlugin implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.dual',
    displayName: 'Fake Dual-Language Source',
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
        serverId: 'sub-streamtape',
        serverName: 'StreamTape',
        initialUrl: Uri.parse('https://streamtape.com/e/sub/'),
        language: 'sub',
        detectedHost: 'streamtape.com',
      ),
      SourceServerLink(
        serverId: 'dub-mp4upload',
        serverName: 'MP4Upload',
        initialUrl: Uri.parse('https://mp4upload.com/e/dub/'),
        language: 'dub',
        detectedHost: 'mp4upload.com',
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

final class _SingleLanguageSourcePlugin implements SourcePlugin {
  _SingleLanguageSourcePlugin({required this.language});
  final String language;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.single',
    displayName: 'Fake Single-Language Source',
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
        serverId: 'streamtape',
        serverName: 'StreamTape',
        initialUrl: Uri.parse('https://streamtape.com/e/only/'),
        language: language,
        detectedHost: 'streamtape.com',
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
