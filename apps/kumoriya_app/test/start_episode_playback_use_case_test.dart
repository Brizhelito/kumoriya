import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_selection_policy.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/get_source_availability_summary_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/start_episode_playback_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';

void main() {
  late AppDatabase db;
  late DriftAnimeProgressStore store;
  late ResolverRegistry registry;
  late ResolveSourceServerLinkUseCase resolver;

  setUp(() {
    db = openInMemoryDatabase();
    store = DriftAnimeProgressStore(db);
    registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[_FakeResolverPlugin()],
    );
    resolver = ResolveSourceServerLinkUseCase(registry: registry);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'uses persisted source and server preference when still valid',
    () async {
      const source = _SingleServerSourcePlugin();
      final summary = await GetSourceAvailabilitySummaryUseCase(
        sourcePlugins: const <SourcePlugin>[source],
        matcher: const AnilistSourceMatcher(),
        selectionPolicy: const SourceSelectionPolicy(),
        registry: registry,
      ).call(_detail);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: source.manifest.id,
          preferredServerName: 'Streamwish',
          preferredResolverPluginId: 'kumoriya.resolver.fake',
          preferredAudioPreference: PlaybackAudioPreference.sub,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await StartEpisodePlaybackUseCase(
            sourcePlugins: <String, SourcePlugin>{source.manifest.id: source},
            registry: registry,
            resolver: resolver,
            progressStore: store,
            sourceSelectionPolicy: const SourceSelectionPolicy(),
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      expect(decision.type.name, 'direct');
      expect(decision.launch, isNotNull);
      expect(decision.launch!.option.serverLink.serverName, 'Streamwish');
      expect(decision.launch!.option.isPreferred, isTrue);
    },
  );

  test(
    'returns selection when the best source has multiple usable servers',
    () async {
      const source = _MultiServerSourcePlugin();
      final summary = await GetSourceAvailabilitySummaryUseCase(
        sourcePlugins: const <SourcePlugin>[source],
        matcher: const AnilistSourceMatcher(),
        selectionPolicy: const SourceSelectionPolicy(),
        registry: registry,
      ).call(_detail);

      final decision =
          await StartEpisodePlaybackUseCase(
            sourcePlugins: <String, SourcePlugin>{source.manifest.id: source},
            registry: registry,
            resolver: resolver,
            progressStore: store,
            sourceSelectionPolicy: const SourceSelectionPolicy(),
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      expect(decision.type.name, 'selection');
      expect(decision.options.length, 2);
      expect(decision.options.first.isRecommended, isTrue);
    },
  );

  test(
    'falls back to selector when automatic preferred option stops opening',
    () async {
      final registry = ResolverRegistry(
        resolvers: <ResolverPlugin>[_FlakyResolverPlugin()],
      );
      final resolver = ResolveSourceServerLinkUseCase(registry: registry);
      const source = _MultiServerSourcePlugin();
      final summary = await GetSourceAvailabilitySummaryUseCase(
        sourcePlugins: const <SourcePlugin>[source],
        matcher: const AnilistSourceMatcher(),
        selectionPolicy: const SourceSelectionPolicy(),
        registry: registry,
      ).call(_detail);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: source.manifest.id,
          preferredServerName: 'AutoFail',
          preferredResolverPluginId: 'kumoriya.resolver.fake.flaky',
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await StartEpisodePlaybackUseCase(
            sourcePlugins: <String, SourcePlugin>{source.manifest.id: source},
            registry: registry,
            resolver: resolver,
            progressStore: store,
            sourceSelectionPolicy: const SourceSelectionPolicy(),
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      expect(decision.type.name, 'selection');
      expect(decision.autoSelectionFailed, isTrue);
      expect(decision.options.single.serverLink.serverName, 'Backup');
    },
  );
}

const AnimeDetail _detail = AnimeDetail(
  anime: Anime(
    anilistId: 1,
    title: AnimeTitle(romaji: 'Frieren'),
    format: AnimeFormat.tv,
    releaseYear: 2023,
  ),
);

class _SingleServerSourcePlugin extends _BaseFakeSourcePlugin {
  const _SingleServerSourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.jkanime',
    displayName: 'JKAnime',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    iconUrl: 'https://example.com/jkanime.png',
  );

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'streamwish-1',
        serverName: 'Streamwish',
        initialUrl: Uri.parse('https://video.example/streamwish/1'),
        language: 'sub',
      ),
    ]);
  }
}

class _MultiServerSourcePlugin extends _BaseFakeSourcePlugin {
  const _MultiServerSourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.animeav1',
    displayName: 'AnimeAV1',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    iconUrl: 'https://example.com/animeav1.png',
  );

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'auto-fail',
        serverName: 'AutoFail',
        initialUrl: Uri.parse('https://video.example/fail/1'),
        language: 'dub',
      ),
      SourceServerLink(
        serverId: 'backup',
        serverName: 'Backup',
        initialUrl: Uri.parse('https://video.example/backup/1'),
        language: 'sub',
      ),
    ]);
  }
}

abstract class _BaseFakeSourcePlugin implements SourcePlugin {
  const _BaseFakeSourcePlugin();

  @override
  PluginManifest get manifest;

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    return const Success(
      SourceAnimeDetail(sourceId: 'frieren', title: 'Frieren'),
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: '1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/episode-1'),
      ),
    ]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'frieren', title: 'Frieren'),
    ]);
  }
}

class _FakeResolverPlugin implements ResolverPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.fake',
    displayName: 'Fake Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  int get priority => 100;

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    return Success(<ResolvedStream>[
      ResolvedStream(
        url: Uri.parse('https://cdn.example/master.m3u8'),
        isHls: true,
      ),
    ]);
  }

  @override
  bool supports(Uri url) => url.host == 'video.example';
}

class _FlakyResolverPlugin implements ResolverPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.fake.flaky',
    displayName: 'Flaky Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  int get priority => 100;

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    if (url.path.contains('/fail/')) {
      return const Failure(
        SimpleError(
          code: 'resolver.fake.failed',
          message: 'not available',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
    return Success(<ResolvedStream>[
      ResolvedStream(
        url: Uri.parse('https://cdn.example/backup.m3u8'),
        isHls: true,
      ),
    ]);
  }

  @override
  bool supports(Uri url) => url.host == 'video.example';
}
