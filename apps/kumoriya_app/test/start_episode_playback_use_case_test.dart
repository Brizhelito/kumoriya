import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/episode_playback.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/playback_preference_policy.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_selection_policy.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/get_source_availability_summary_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/start_episode_playback_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late _FakeAnimeProgressStore store;
  late ResolverRegistry registry;
  late ResolveSourceServerLinkUseCase resolver;

  setUp(() {
    store = _FakeAnimeProgressStore();
    registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[_FakeResolverPlugin()],
    );
    resolver = ResolveSourceServerLinkUseCase(registry: registry);
  });

  test(
    'uses persisted source and server preference when still valid',
    () async {
      const source = _SingleServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

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
          await _buildUseCase(
            sourcePlugins: <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch, isNotNull);
      expect(decision.launch!.option.serverLink.serverName, 'Streamwish');
      expect(decision.launch!.option.isPreferred, isTrue);
    },
  );

  test(
    'durable preference drives auto-play even when episode progress differs',
    () async {
      const source = _MultiServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: source.manifest.id,
          preferredServerName: 'Backup',
          preferredResolverPluginId: 'kumoriya.resolver.fake',
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      await store.upsert(
        EpisodeProgress(
          anilistId: _detail.anime.anilistId,
          episodeNumber: 1,
          position: const Duration(minutes: 9),
          updatedAt: DateTime(2026, 2, 1),
          watchState: WatchState.watching,
          lastSourcePluginId: source.manifest.id,
          lastServerName: 'Streamwish',
          lastResolverPluginId: 'kumoriya.resolver.fake',
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      // Durable preference (Backup) drives auto-play, NOT episode progress.
      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch!.option.serverLink.serverName, 'Backup');
      expect(decision.launch!.option.isPreferred, isTrue);
    },
  );

  test(
    'shows server picker when only episode progress exists (no durable pref)',
    () async {
      const source = _MultiServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

      // No durable preference, only episode progress.
      await store.upsert(
        EpisodeProgress(
          anilistId: _detail.anime.anilistId,
          episodeNumber: 1,
          position: const Duration(minutes: 5),
          updatedAt: DateTime(2026, 2, 1),
          watchState: WatchState.watching,
          lastSourcePluginId: source.manifest.id,
          lastServerName: 'Streamwish',
          lastResolverPluginId: 'kumoriya.resolver.fake',
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      // Episode progress must NOT trigger auto-play; user sees the picker.
      expect(decision.type, EpisodePlaybackDecisionType.selection);
      expect(decision.options, hasLength(3));
      // The previously used server should still be ranked first.
      expect(decision.options.first.serverLink.serverName, 'Streamwish');
      expect(decision.options.first.isPreferred, isTrue);
    },
  );

  test(
    'invalidates broken preferred server and falls back on the same source',
    () async {
      final flakyRegistry = ResolverRegistry(
        resolvers: <ResolverPlugin>[_FlakyResolverPlugin()],
      );
      final flakyResolver = ResolveSourceServerLinkUseCase(
        registry: flakyRegistry,
      );
      const source = _MultiServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: flakyRegistry);

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
          await _buildUseCase(
            sourcePlugins: <SourcePlugin>[source],
            store: store,
            registry: flakyRegistry,
            resolver: flakyResolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      final stored = await store.getPlaybackPreference(_detail.anime.anilistId);
      final preference =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value!;

      // When exact-match preference fails, show selector with all available
      // options (not just remaining). User can manually select an alternative.
      expect(decision.type, EpisodePlaybackDecisionType.selection);
      expect(decision.options, hasLength(3));
      // AutoFail still ranked first as preferred, but not auto-selected.
      expect(decision.options.first.serverLink.serverName, 'AutoFail');
      expect(decision.options.first.isPreferred, isTrue);
      expect(decision.autoSelectionFailed, isTrue);
      // Preference remains unchanged since not cached via invalidation path.
      expect(preference.preferredSourcePluginId, source.manifest.id);
      expect(preference.preferredServerName, 'AutoFail');
      expect(
        preference.preferredResolverPluginId,
        'kumoriya.resolver.fake.flaky',
      );
    },
  );

  test(
    'clears a source preference that no longer exists for the episode',
    () async {
      const preferredSource = _MultiServerSourcePlugin();
      const fallbackSource = _SingleServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        fallbackSource,
      ], registry: registry);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: preferredSource.manifest.id,
          preferredServerName: 'Backup',
          preferredResolverPluginId: 'kumoriya.resolver.fake',
          preferredAudioPreference: PlaybackAudioPreference.dub,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[fallbackSource],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      final stored = await store.getPlaybackPreference(_detail.anime.anilistId);
      final preference =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value!;

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(
        decision.launch!.option.sourcePluginId,
        fallbackSource.manifest.id,
      );
      expect(preference.preferredSourcePluginId, isNull);
      expect(preference.preferredServerName, isNull);
      expect(preference.preferredResolverPluginId, isNull);
      expect(preference.preferredAudioPreference, PlaybackAudioPreference.dub);
    },
  );

  test('prefers DUB when that audio preference is available', () async {
    const source = _DualAudioSourcePlugin();
    final summary = await _summaryFor(const <SourcePlugin>[
      source,
    ], registry: registry);

    await store.upsertPlaybackPreference(
      PlaybackPreference(
        anilistId: _detail.anime.anilistId,
        preferredSourcePluginId: source.manifest.id,
        preferredAudioPreference: PlaybackAudioPreference.dub,
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    final decision =
        await _buildUseCase(
          sourcePlugins: const <SourcePlugin>[source],
          store: store,
          registry: registry,
          resolver: resolver,
        ).call(
          anilistId: _detail.anime.anilistId,
          episodeNumber: 1,
          availabilitySummary: summary,
        );

    expect(decision.type, EpisodePlaybackDecisionType.direct);
    expect(decision.launch!.option.audioKind, SourceAudioKind.dub);
    expect(decision.launch!.option.serverLink.serverName, 'DubStream');
  });

  test(
    'falls back to another source when a source-only preference exhausts its servers',
    () async {
      final flakyRegistry = ResolverRegistry(
        resolvers: <ResolverPlugin>[_FlakyResolverPlugin()],
      );
      final flakyResolver = ResolveSourceServerLinkUseCase(
        registry: flakyRegistry,
      );
      const failingSource = _FailingSourcePlugin();
      const fallbackSource = _SingleServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        failingSource,
        fallbackSource,
      ], registry: flakyRegistry);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: failingSource.manifest.id,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[failingSource, fallbackSource],
            store: store,
            registry: flakyRegistry,
            resolver: flakyResolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      final stored = await store.getPlaybackPreference(_detail.anime.anilistId);
      final preference =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value!;

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(
        decision.launch!.option.sourcePluginId,
        fallbackSource.manifest.id,
      );
      // Parallel race: autoSelectionFailed is false when any candidate wins.
      expect(decision.autoSelectionFailed, isFalse);
      // Parallel race does not invalidate preferences per-failure.
      expect(preference.preferredSourcePluginId, failingSource.manifest.id);
      expect(preference.preferredServerName, isNull);
      expect(preference.preferredResolverPluginId, isNull);
    },
  );

  test(
    'drops stale DUB preference and degrades to SUB when DUB resolution fails',
    () async {
      final flakyRegistry = ResolverRegistry(
        resolvers: <ResolverPlugin>[_FlakyResolverPlugin()],
      );
      final flakyResolver = ResolveSourceServerLinkUseCase(
        registry: flakyRegistry,
      );
      const source = _DualAudioFlakySourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: flakyRegistry);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: source.manifest.id,
          preferredAudioPreference: PlaybackAudioPreference.dub,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[source],
            store: store,
            registry: flakyRegistry,
            resolver: flakyResolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      final stored = await store.getPlaybackPreference(_detail.anime.anilistId);
      final preference =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value!;

      // When preferred audio (DUB) has no exact-match server and entire source
      // fails, show selector with all available options. User picks alternative.
      expect(decision.type, EpisodePlaybackDecisionType.selection);
      expect(decision.options, hasLength(2));
      // DUB option appears first due to audio preference ranking.
      expect(decision.options.first.audioKind, SourceAudioKind.dub);
      expect(decision.autoSelectionFailed, isTrue);
      // Preference remains unchanged.
      expect(preference.preferredAudioPreference, PlaybackAudioPreference.dub);
    },
  );

  test('shows selector when the preferred server fails to resolve', () async {
    final flakyRegistry = ResolverRegistry(
      resolvers: <ResolverPlugin>[_FlakyResolverPlugin()],
    );
    final flakyResolver = ResolveSourceServerLinkUseCase(
      registry: flakyRegistry,
    );
    const source = _MultiServerSourcePlugin();
    final summary = await _summaryFor(const <SourcePlugin>[
      source,
    ], registry: flakyRegistry);

    // Prefer 'AutoFail' server (which will fail to resolve).
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
        await _buildUseCase(
          sourcePlugins: <SourcePlugin>[source],
          store: store,
          registry: flakyRegistry,
          resolver: flakyResolver,
        ).call(
          anilistId: _detail.anime.anilistId,
          episodeNumber: 1,
          availabilitySummary: summary,
        );

    // When the exact-match preferred server fails, the user should see
    // all available servers ranked by preference, but not auto-selected.
    expect(decision.type, EpisodePlaybackDecisionType.selection);
    // All 3 servers are shown (not filtered as "attempted").
    expect(decision.options, hasLength(3));
    expect(decision.autoSelectionFailed, isTrue);
    // AutoFail ranked first (as preferred), but not auto-selected.
    expect(decision.options.first.serverLink.serverName, 'AutoFail');
    expect(decision.options.first.isPreferred, isTrue);
    // Backup and Streamwish are fallback options.
    expect(decision.options[1].serverLink.serverName, 'Backup');
    expect(decision.options[2].serverLink.serverName, 'Streamwish');
  });

  test(
    'shows selector when there is no preference and the top source has multiple usable servers',
    () async {
      const source = _MultiServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      expect(decision.type, EpisodePlaybackDecisionType.selection);
      expect(decision.options, hasLength(3));
      expect(
        decision.options.where((option) => option.isRecommended),
        hasLength(1),
      );
    },
  );

  test(
    'skips automatic resolution when interactive selection is required',
    () async {
      const source = _MultiServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: source.manifest.id,
          preferredServerName: 'Backup',
          preferredResolverPluginId: 'kumoriya.resolver.fake',
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
            allowAutomaticResolution: false,
          );

      expect(decision.type, EpisodePlaybackDecisionType.selection);
      expect(decision.autoSelectionFailed, isFalse);
      expect(decision.options, hasLength(3));
      expect(decision.options.first.serverLink.serverName, 'Backup');
      expect(decision.options.first.isPreferred, isTrue);
    },
  );

  test(
    'still opens directly when only one option exists and auto resolution is disabled',
    () async {
      const source = _SingleServerSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
            allowAutomaticResolution: false,
          );

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch, isNotNull);
      expect(decision.launch!.option.serverLink.serverName, 'Streamwish');
    },
  );

  test(
    'skips animeav1 uns host auto-open when a safer alternative exists',
    () async {
      const source = _AnimeAv1DubFallbackSourcePlugin();
      final summary = await _summaryFor(const <SourcePlugin>[
        source,
      ], registry: registry);

      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: _detail.anime.anilistId,
          preferredSourcePluginId: source.manifest.id,
          preferredServerName: 'AnimeAV1 DUB',
          preferredResolverPluginId: 'kumoriya.resolver.fake',
          preferredAudioPreference: PlaybackAudioPreference.dub,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final decision =
          await _buildUseCase(
            sourcePlugins: const <SourcePlugin>[source],
            store: store,
            registry: registry,
            resolver: resolver,
          ).call(
            anilistId: _detail.anime.anilistId,
            episodeNumber: 1,
            availabilitySummary: summary,
          );

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch, isNotNull);
      expect(decision.launch!.option.serverLink.serverName, 'Zilla');
      expect(
        decision.launch!.option.serverLink.initialUrl.host,
        'video.example',
      );
    },
  );
}

StartEpisodePlaybackUseCase _buildUseCase({
  required List<SourcePlugin> sourcePlugins,
  required AnimeProgressStore store,
  required ResolverRegistry registry,
  required ResolveSourceServerLinkUseCase resolver,
}) {
  return StartEpisodePlaybackUseCase(
    sourcePlugins: {
      for (final plugin in sourcePlugins) plugin.manifest.id: plugin,
    },
    registry: registry,
    resolver: resolver,
    progressStore: store,
    sourceSelectionPolicy: const SourceSelectionPolicy(),
    playbackPreferencePolicy: const PlaybackPreferencePolicy(),
  );
}

Future<SourceAvailabilitySummary> _summaryFor(
  List<SourcePlugin> sourcePlugins, {
  required ResolverRegistry registry,
}) {
  return GetSourceAvailabilitySummaryUseCase(
    sourcePlugins: sourcePlugins,
    matcher: const AnilistSourceMatcher(),
    selectionPolicy: const SourceSelectionPolicy(),
    registry: registry,
  ).call(_detail);
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
      SourceServerLink(
        serverId: 'streamwish',
        serverName: 'Streamwish',
        initialUrl: Uri.parse('https://video.example/streamwish/1'),
        language: 'sub',
      ),
    ]);
  }
}

class _DualAudioSourcePlugin extends _BaseFakeSourcePlugin {
  const _DualAudioSourcePlugin();

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
        serverId: 'sub-stream',
        serverName: 'SubStream',
        initialUrl: Uri.parse('https://video.example/sub/1'),
        language: 'sub',
      ),
      SourceServerLink(
        serverId: 'dub-stream',
        serverName: 'DubStream',
        initialUrl: Uri.parse('https://video.example/dub/1'),
        language: 'dub',
      ),
    ]);
  }
}

class _DualAudioFlakySourcePlugin extends _BaseFakeSourcePlugin {
  const _DualAudioFlakySourcePlugin();

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
        serverId: 'dub-auto-fail',
        serverName: 'DubFail',
        initialUrl: Uri.parse('https://video.example/fail/1?audio=dub'),
        language: 'dub',
      ),
      SourceServerLink(
        serverId: 'sub-stream',
        serverName: 'SubStream',
        initialUrl: Uri.parse('https://video.example/sub/1'),
        language: 'sub',
      ),
    ]);
  }
}

class _FailingSourcePlugin extends _BaseFakeSourcePlugin {
  const _FailingSourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.failingsource',
    displayName: 'Failing Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    iconUrl: 'https://example.com/failing.png',
  );

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'auto-fail-1',
        serverName: 'AutoFail',
        initialUrl: Uri.parse('https://video.example/fail/1'),
        language: 'sub',
      ),
      SourceServerLink(
        serverId: 'auto-fail-2',
        serverName: 'AutoFail 2',
        initialUrl: Uri.parse('https://video.example/fail/2'),
        language: 'sub',
      ),
    ]);
  }
}

class _AnimeAv1DubFallbackSourcePlugin extends _BaseFakeSourcePlugin {
  const _AnimeAv1DubFallbackSourcePlugin();

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
        serverId: 'animeav1-dub',
        serverName: 'AnimeAV1 DUB',
        initialUrl: Uri.parse('https://animeav1.uns.bio/#xhutzl'),
        language: 'dub',
      ),
      SourceServerLink(
        serverId: 'zilla',
        serverName: 'Zilla',
        initialUrl: Uri.parse('https://video.example/zilla/1'),
        language: 'dub',
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
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    final streamId = url.pathSegments.isNotEmpty
        ? url.pathSegments.last
        : (url.fragment.isNotEmpty ? url.fragment : 'stream');
    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse('https://cdn.example/$streamId.m3u8'),
            isHls: true,
          ),
        ],
      ),
    );
  }

  @override
  bool supports(Uri url) =>
      url.host == 'video.example' || url.host == 'animeav1.uns.bio';
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
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    if (url.path.contains('/fail/')) {
      return const Failure(
        SimpleError(
          code: 'resolver.fake.failed',
          message: 'not available',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(
            url: Uri.parse('https://cdn.example${url.path}.m3u8'),
            isHls: true,
          ),
        ],
      ),
    );
  }

  @override
  bool supports(Uri url) => url.host == 'video.example';
}

final class _FakeAnimeProgressStore implements AnimeProgressStore {
  final Map<(int, double), EpisodeProgress> _progressByEpisode =
      <(int, double), EpisodeProgress>{};
  final Map<int, PlaybackPreference> _preferencesByAnime =
      <int, PlaybackPreference>{};
  final Map<int, AnimeWatchHistory> _historyByAnime =
      <int, AnimeWatchHistory>{};

  @override
  Future<Result<void, KumoriyaError>> clearAllPlaybackPreferences() async {
    _preferencesByAnime.clear();
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(
    int anilistId,
  ) async {
    _preferencesByAnime.remove(anilistId);
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllProgress() async {
    _progressByEpisode.clear();
    return const Success(null);
  }

  @override
  Future<Result<List<EpisodeProgress>, KumoriyaError>> getAllProgress(
    int anilistId,
  ) async {
    final values =
        _progressByEpisode.values
            .where((progress) => progress.anilistId == anilistId)
            .toList(growable: false)
          ..sort(
            (left, right) => left.episodeNumber.compareTo(right.episodeNumber),
          );
    return Success(values);
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getLatestProgress(
    int anilistId,
  ) async {
    EpisodeProgress? latest;
    for (final progress in _progressByEpisode.values) {
      if (progress.anilistId != anilistId) {
        continue;
      }
      if (latest == null || progress.updatedAt.isAfter(latest.updatedAt)) {
        latest = progress;
      }
    }
    return Success(latest);
  }

  @override
  Future<Result<PlaybackPreference?, KumoriyaError>> getPlaybackPreference(
    int anilistId,
  ) async {
    return Success(_preferencesByAnime[anilistId]);
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  ) async {
    return Success(_progressByEpisode[(anilistId, episodeNumber)]);
  }

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) async {
    final history = _historyByAnime.values.toList(growable: false)
      ..sort(
        (left, right) => right.lastAccessedAt.compareTo(left.lastAccessedAt),
      );
    return Success(history.take(limit).toList(growable: false));
  }

  @override
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress) async {
    _progressByEpisode[(progress.anilistId, progress.episodeNumber)] = progress;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference preference,
  ) async {
    _preferencesByAnime[preference.anilistId] = preference;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertWatchHistory({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    int? totalDurationSeconds,
    String? lastSourcePluginId,
    DateTime? lastAccessedAt,
  }) async {
    _historyByAnime[anilistId] = AnimeWatchHistory(
      anilistId: anilistId,
      lastEpisodeNumber: episodeNumber,
      lastAccessedAt: lastAccessedAt ?? DateTime.now(),
      lastSourcePluginId: lastSourcePluginId,
      lastPositionSeconds: positionSeconds,
      lastTotalDurationSeconds: totalDurationSeconds,
    );
    return const Success(null);
  }

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getAllHistory() async {
    final history = _historyByAnime.values.toList(growable: false)
      ..sort(
        (left, right) => right.lastAccessedAt.compareTo(left.lastAccessedAt),
      );
    return Success(history);
  }

  @override
  Future<Result<void, KumoriyaError>> deleteHistoryEntry(int anilistId) async {
    _historyByAnime.remove(anilistId);
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllHistory() async {
    _historyByAnime.clear();
    return const Success(null);
  }
}
