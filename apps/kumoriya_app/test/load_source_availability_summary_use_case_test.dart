import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_availability_cache_codec.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_selection_policy.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/get_source_availability_summary_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/load_source_availability_summary_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;
  late DriftSourceAvailabilityStore store;
  late _CountingSourcePlugin plugin;
  late SourceAvailabilityCacheCodec codec;
  late GetSourceAvailabilitySummaryUseCase computeUseCase;
  late LoadSourceAvailabilitySummaryUseCase loadUseCase;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSourceAvailabilityStore(db);
    plugin = _CountingSourcePlugin();
    codec = SourceAvailabilityCacheCodec(
      sourcePlugins: <SourcePlugin>[plugin],
      selectionPolicy: const SourceSelectionPolicy(),
    );
    computeUseCase = GetSourceAvailabilitySummaryUseCase(
      sourcePlugins: <SourcePlugin>[plugin],
      matcher: const AnilistSourceMatcher(),
      selectionPolicy: const SourceSelectionPolicy(),
      registry: ResolverRegistry(resolvers: <ResolverPlugin>[]),
    );
    loadUseCase = LoadSourceAvailabilitySummaryUseCase(
      store: store,
      computeUseCase: computeUseCase,
      sourcePlugins: <SourcePlugin>[plugin],
      cacheCodec: codec,
      freshTtl: const Duration(hours: 6),
      maxStaleAge: const Duration(days: 3),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('reuses fresh cached availability without recomputing', () async {
    final detail = _detail();

    final first = await loadUseCase.call(detail);
    expect(first, isA<Success>());
    final searchesAfterFirstLoad = plugin.searchCalls;
    expect(searchesAfterFirstLoad, greaterThan(0));

    final second = await loadUseCase.call(detail);
    final loaded =
        (second as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
            .value;

    expect(loaded.fromCache, isTrue);
    expect(loaded.shouldRefreshInBackground, isFalse);
    expect(plugin.searchCalls, searchesAfterFirstLoad);
  });

  test('returns stale cache and marks it for background refresh', () async {
    final detail = _detail();
    final summary = await computeUseCase.call(detail);
    final persistResult = await store.replaceAvailability(
      detail.anime.anilistId,
      codec.encode(
        anilistId: detail.anime.anilistId,
        summary: summary,
        updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    );

    expect(persistResult, isA<Success>());
    plugin.resetCounters();

    final result = await loadUseCase.call(detail);
    final loaded =
        (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
            .value;

    expect(loaded.fromCache, isTrue);
    expect(loaded.shouldRefreshInBackground, isTrue);
    expect(plugin.searchCalls, 0);
  });

  test(
    'fresh cache without playable sources is revalidated in background',
    () async {
      final detail = _detail();
      final summary = const SourceAvailabilitySummary(
        sources: <SourceAvailability>[
          SourceAvailability(
            manifest: PluginManifest(
              id: 'fake.cache.source',
              displayName: 'Fake Cache Source',
              type: PluginType.source,
              capabilities: <PluginCapability>{PluginCapability.search},
            ),
            status: SourceAvailabilityStatus.unavailable,
            decision: SourceMatchDecision(
              verdict: false,
              confidence: MatchConfidence.low,
              reason: 'No match',
              acceptanceSignals: <String>[],
              rejectionSignals: <String>['title-mismatch'],
            ),
            unavailableReason: SourceUnavailableReason.noMatch,
          ),
        ],
      );

      await store.replaceAvailability(
        detail.anime.anilistId,
        codec.encode(
          anilistId: detail.anime.anilistId,
          summary: summary,
          updatedAt: DateTime.now(),
        ),
      );

      final result = await loadUseCase.call(detail);
      final loaded =
          (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
              .value;

      expect(loaded.fromCache, isTrue);
      expect(loaded.shouldRefreshInBackground, isTrue);
    },
  );

  test('legacy cache payload is ignored and recomputed', () async {
    final detail = _detail();
    await store.replaceAvailability(
      detail.anime.anilistId,
      <SourceAvailabilityCacheRecord>[
        SourceAvailabilityCacheRecord(
          anilistId: detail.anime.anilistId,
          sourcePluginId: 'fake.cache.source',
          payloadJson: '{"status":"available"}',
          updatedAt: DateTime.now(),
        ),
      ],
    );

    plugin.resetCounters();

    final result = await loadUseCase.call(detail);
    final loaded =
        (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
            .value;

    expect(loaded.fromCache, isFalse);
    expect(plugin.searchCalls, greaterThan(0));
  });

  test(
    'recomputes when cached availability is older than max stale age',
    () async {
      final detail = _detail();
      final summary = await computeUseCase.call(detail);
      await store.replaceAvailability(
        detail.anime.anilistId,
        codec.encode(
          anilistId: detail.anime.anilistId,
          summary: summary,
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      );

      plugin.resetCounters();

      final result = await loadUseCase.call(detail);
      final loaded =
          (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
              .value;

      expect(loaded.fromCache, isFalse);
      expect(loaded.shouldRefreshInBackground, isFalse);
      expect(plugin.searchCalls, greaterThan(0));
    },
  );

  test(
    'recomputes stale airing availability when an aired episode is missing',
    () async {
      final originalDetail = _detail(
        status: AnimeStatus.releasing,
        episodes: const <AnimeEpisode>[
          AnimeEpisode(number: 1, title: 'Episode 1'),
        ],
      );
      final summary = await computeUseCase.call(originalDetail);
      await store.replaceAvailability(
        originalDetail.anime.anilistId,
        codec.encode(
          anilistId: originalDetail.anime.anilistId,
          summary: summary,
          updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

      plugin.resetCounters();

      final result = await loadUseCase.call(
        _detail(
          status: AnimeStatus.releasing,
          episodes: const <AnimeEpisode>[
            AnimeEpisode(number: 1, title: 'Episode 1'),
            AnimeEpisode(number: 2, title: 'Episode 2'),
          ],
        ),
      );
      final loaded =
          (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
              .value;

      expect(loaded.fromCache, isFalse);
      expect(plugin.searchCalls, greaterThan(0));
    },
  );

  test('source lookup returns without waiting for a slow source', () async {
    final fastPlugin = _CountingSourcePlugin();
    final slowPlugin = _SlowSourcePlugin();
    final fastComputeUseCase = GetSourceAvailabilitySummaryUseCase(
      sourcePlugins: <SourcePlugin>[fastPlugin, slowPlugin],
      matcher: const AnilistSourceMatcher(),
      selectionPolicy: const SourceSelectionPolicy(),
      registry: ResolverRegistry(resolvers: <ResolverPlugin>[]),
      sourceTimeout: const Duration(milliseconds: 20),
    );

    final stopwatch = Stopwatch()..start();
    final summary = await fastComputeUseCase.call(_detail());
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 250)));
    expect(summary.playableSources.map((source) => source.manifest.id), [
      fastPlugin.manifest.id,
    ]);
    expect(
      summary.sources
          .where((source) => source.manifest.id == slowPlugin.manifest.id)
          .single
          .decision
          .rejectionSignals,
      contains('source-availability-timeout'),
    );
  });

  test(
    'load waits for full lookup when fast pass only timed out sources',
    () async {
      final slowPlugin = _SlowPlayableSourcePlugin();
      final slowCodec = SourceAvailabilityCacheCodec(
        sourcePlugins: <SourcePlugin>[slowPlugin],
        selectionPolicy: const SourceSelectionPolicy(),
      );
      final slowLoadUseCase = LoadSourceAvailabilitySummaryUseCase(
        store: store,
        computeUseCase: GetSourceAvailabilitySummaryUseCase(
          sourcePlugins: <SourcePlugin>[slowPlugin],
          matcher: const AnilistSourceMatcher(),
          selectionPolicy: const SourceSelectionPolicy(),
          registry: ResolverRegistry(resolvers: <ResolverPlugin>[]),
          sourceTimeout: const Duration(milliseconds: 20),
        ),
        sourcePlugins: <SourcePlugin>[slowPlugin],
        cacheCodec: slowCodec,
      );

      final result = await slowLoadUseCase.call(_detail());
      final loaded =
          (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
              .value;

      expect(loaded.fromCache, isFalse);
      expect(loaded.summary.playableSources, hasLength(1));
      expect(loaded.shouldRefreshInBackground, isFalse);
    },
  );

  test(
    'load returns partial playable sources and requests full background refresh',
    () async {
      final fastPlugin = _CountingSourcePlugin();
      final slowPlugin = _SlowPlayableSourcePlugin();
      final partialCodec = SourceAvailabilityCacheCodec(
        sourcePlugins: <SourcePlugin>[fastPlugin, slowPlugin],
        selectionPolicy: const SourceSelectionPolicy(),
      );
      final partialLoadUseCase = LoadSourceAvailabilitySummaryUseCase(
        store: store,
        computeUseCase: GetSourceAvailabilitySummaryUseCase(
          sourcePlugins: <SourcePlugin>[fastPlugin, slowPlugin],
          matcher: const AnilistSourceMatcher(),
          selectionPolicy: const SourceSelectionPolicy(),
          registry: ResolverRegistry(resolvers: <ResolverPlugin>[]),
          sourceTimeout: const Duration(milliseconds: 20),
        ),
        sourcePlugins: <SourcePlugin>[fastPlugin, slowPlugin],
        cacheCodec: partialCodec,
      );

      final result = await partialLoadUseCase.call(_detail());
      final loaded =
          (result as Success<LoadedSourceAvailabilitySummary, KumoriyaError>)
              .value;

      expect(loaded.summary.playableSources.map((s) => s.manifest.id), [
        fastPlugin.manifest.id,
      ]);
      expect(loaded.shouldRefreshInBackground, isTrue);

      final refreshed = await partialLoadUseCase.refresh(_detail());
      final summary =
          (refreshed as Success<SourceAvailabilitySummary, KumoriyaError>)
              .value;

      expect(summary.playableSources.map((s) => s.manifest.id), [
        fastPlugin.manifest.id,
        slowPlugin.manifest.id,
      ]);
    },
  );
}

AnimeDetail _detail({
  AnimeStatus status = AnimeStatus.unknown,
  List<AnimeEpisode> episodes = const <AnimeEpisode>[],
}) {
  return AnimeDetail(
    anime: Anime(
      anilistId: 7001,
      title: const AnimeTitle(romaji: 'Oshi no Ko'),
      format: AnimeFormat.tv,
      releaseYear: 2023,
      status: status,
    ),
    episodes: episodes,
  );
}

final class _CountingSourcePlugin implements SourcePlugin {
  int searchCalls = 0;
  int episodeCalls = 0;

  void resetCounters() {
    searchCalls = 0;
    episodeCalls = 0;
  }

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.cache.source',
    displayName: 'Fake Cache Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
    },
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
    episodeCalls++;
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: 'ep1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/oshi/1'),
      ),
    ]);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return const Success(<SourceServerLink>[]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    searchCalls++;
    if (query.query.toLowerCase().contains('oshi no ko')) {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'oshi-no-ko',
          title: 'Oshi no Ko',
          format: AnimeFormat.tv,
          releaseYear: 2023,
        ),
      ]);
    }

    return const Success(<SourceAnimeMatch>[]);
  }
}

final class _SlowSourcePlugin implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.slow.source',
    displayName: 'Slow Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
    },
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    return Failure(
      SimpleError(
        code: 'fake.slow.detail',
        message: 'Slow detail unavailable.',
        kind: KumoriyaErrorKind.notFound,
      ),
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return const Success(<SourceEpisode>[]);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return const Success(<SourceServerLink>[]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Success(<SourceAnimeMatch>[]);
  }
}

final class _SlowPlayableSourcePlugin implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.slow.playable.source',
    displayName: 'Slow Playable Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
    },
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    return Failure(
      SimpleError(
        code: 'fake.slow.detail',
        message: 'Slow detail unavailable.',
        kind: KumoriyaErrorKind.notFound,
      ),
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: '$sourceId-1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://slow.example.com/$sourceId/1'),
      ),
    ]);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return const Success(<SourceServerLink>[]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(
        sourceId: 'slow-oshi-no-ko',
        title: 'Oshi no Ko',
        format: AnimeFormat.tv,
        releaseYear: 2023,
      ),
    ]);
  }
}
