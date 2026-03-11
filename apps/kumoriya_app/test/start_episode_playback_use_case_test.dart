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
    're-entry prefers the last successful server for the current episode',
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

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch!.option.serverLink.serverName, 'Streamwish');
      expect(decision.launch!.option.isPreferred, isTrue);
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

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch!.option.serverLink.serverName, 'Backup');
      expect(decision.autoSelectionFailed, isTrue);
      expect(preference.preferredSourcePluginId, source.manifest.id);
      expect(preference.preferredServerName, isNull);
      expect(preference.preferredResolverPluginId, isNull);
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
      expect(decision.autoSelectionFailed, isTrue);
      expect(preference.preferredSourcePluginId, isNull);
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

      expect(decision.type, EpisodePlaybackDecisionType.direct);
      expect(decision.launch!.option.audioKind, SourceAudioKind.sub);
      expect(decision.autoSelectionFailed, isTrue);
      expect(preference.preferredAudioPreference, isNull);
    },
  );

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
        url: Uri.parse('https://cdn.example/${url.pathSegments.last}.m3u8'),
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
        url: Uri.parse('https://cdn.example${url.path}.m3u8'),
        isHls: true,
      ),
    ]);
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
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(
    int anilistId,
  ) async {
    _preferencesByAnime.remove(anilistId);
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
  }) async {
    _historyByAnime[anilistId] = AnimeWatchHistory(
      anilistId: anilistId,
      lastEpisodeNumber: episodeNumber,
      lastAccessedAt: DateTime.now(),
      lastSourcePluginId: lastSourcePluginId,
      lastPositionSeconds: positionSeconds,
      lastTotalDurationSeconds: totalDurationSeconds,
    );
    return const Success(null);
  }
}
