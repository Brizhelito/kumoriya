import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/runtime_config.dart';
import '../../../../shared/anilist_backend/anilist_home_backend_client.dart';
import '../../../../shared/anilist_backend/backend_first_anilist_gateway.dart';
import '../../application/use_cases/anime_catalog_use_cases.dart';
import '../../application/matching/anilist_source_matcher.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/seasonal_discovery_catalog.dart';
import '../../application/models/source_availability.dart';
import '../../application/services/anime_nexus_chapter_service.dart';
import '../../application/services/background_source_availability_warmup_service.dart';
import '../../application/services/cached_anime_catalog_repository.dart';
import '../../application/services/resolver_registry.dart';
import '../../application/services/mal_metadata_bridge_service.dart';
import '../../application/services/plugin_runtime_catalog.dart';
import '../../application/services/source_availability_cache_codec.dart';
import '../../application/services/playback_preference_policy.dart';
import '../../application/services/source_selection_policy.dart';
import '../../application/use_cases/get_source_availability_summary_use_case.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../../application/use_cases/load_source_availability_summary_use_case.dart';
import '../../application/use_cases/resolve_source_server_link_use_case.dart';
import '../../application/use_cases/start_episode_playback_use_case.dart';
import '../../../player/application/use_cases/clear_playback_preference_use_case.dart';
import 'storage_providers.dart';

final anilistGraphqlClientProvider = Provider<AnilistGraphqlClient>((ref) {
  return HttpAnilistGraphqlClient(config: KumoriyaRuntimeConfig.anilistClient);
});

/// Feature flag: when true, AniList home surfaces (trending + season
/// discovery) are fetched from the Kumoriya Go backend cache. On any
/// backend failure we transparently fall back to direct AniList.
///
/// Toggle at build time:
///   `flutter build ... --dart-define=KUMORIYA_GO_ANILIST_HOME=false`
const bool _kUseGoAnilistHome = bool.fromEnvironment(
  'KUMORIYA_GO_ANILIST_HOME',
  defaultValue: true,
);

final anilistHomeBackendClientProvider = Provider<AnilistHomeBackendClient>((
  ref,
) {
  final client = AnilistHomeBackendClient(
    baseUrl: KumoriyaRuntimeConfig.apiBaseUrl,
  );
  ref.onDispose(client.close);
  return client;
});

final anilistMetadataGatewayProvider = Provider<AnilistMetadataGateway>((ref) {
  final graphqlGateway = GraphqlAnilistMetadataGateway(
    client: ref.watch(anilistGraphqlClientProvider),
  );
  if (!_kUseGoAnilistHome) {
    return graphqlGateway;
  }
  return BackendFirstAnilistMetadataGateway(
    inner: graphqlGateway,
    backend: ref.watch(anilistHomeBackendClientProvider),
  );
});

final _cachedAnimeCatalogRepositoryProvider =
    Provider<CachedAnimeCatalogRepository>((ref) {
      return CachedAnimeCatalogRepository(
        delegate: AnilistAnimeCatalogRepository(
          gateway: ref.watch(anilistMetadataGatewayProvider),
        ),
        cacheStore: ref.watch(anilistCacheStoreProvider),
        episodeCacheStore: ref.watch(episodeCacheStoreProvider),
      );
    });

final animeCatalogRepositoryProvider = Provider<AnimeCatalogRepository>((ref) {
  return ref.watch(_cachedAnimeCatalogRepositoryProvider);
});

/// Indicates why the most recent catalog fetch fell back to locally-cached
/// data: [FallbackReason.offline], [FallbackReason.anilistDown], or
/// [FallbackReason.none] when operating normally.
final anilistCacheFallbackReasonProvider =
    Provider<ValueNotifier<FallbackReason>>((ref) {
      return ref.watch(_cachedAnimeCatalogRepositoryProvider).fallbackReason;
    });

final sourcePluginsProvider = Provider<List<SourcePlugin>>((ref) {
  return buildDefaultSourcePlugins();
});

final sourcePluginMapProvider = Provider<Map<String, SourcePlugin>>((ref) {
  return {
    for (final plugin in ref.watch(sourcePluginsProvider))
      plugin.manifest.id: plugin,
  };
});

final sourcePluginByIdProvider = Provider.family<SourcePlugin, String>((
  ref,
  sourcePluginId,
) {
  final plugin = ref.watch(sourcePluginMapProvider)[sourcePluginId];
  if (plugin == null) {
    throw StateError('Unknown source plugin id: $sourcePluginId');
  }
  return plugin;
});

final sourcePluginProvider = Provider<SourcePlugin>((ref) {
  return ref.watch(sourcePluginsProvider).first;
});

/// Shared HTTP client for resolver plugins. On Android, uses Chromium's Cronet
/// engine (HTTP/2, better TLS, lower latency). Falls back to the standard Dart
/// HttpClient on other platforms.
final resolverHttpClientProvider = Provider<http.Client>((ref) {
  if (!Platform.isAndroid) return http.Client();
  try {
    return CronetClient.fromCronetEngine(
      CronetEngine.build(cacheMode: CacheMode.disabled),
      closeEngine: true,
    );
  } catch (_) {
    return http.Client();
  }
});

final resolverPluginsProvider = Provider<List<ResolverPlugin>>((ref) {
  return buildDefaultResolverPlugins(
    httpClient: ref.watch(resolverHttpClientProvider),
  );
});

final resolverRegistryProvider = Provider<ResolverRegistry>((ref) {
  return ResolverRegistry(resolvers: ref.watch(resolverPluginsProvider));
});

final animeNexusChapterServiceProvider = Provider<AnimeNexusChapterService>((
  ref,
) {
  final service = AnimeNexusChapterService(
    sourceAvailabilityStore: ref.watch(sourceAvailabilityStoreProvider),
    sourceAvailabilityCacheCodec: ref.watch(
      sourceAvailabilityCacheCodecProvider,
    ),
    loadAnimeDetail: (anilistId) {
      return ref.read(getAnimeDetailUseCaseProvider).call(anilistId);
    },
    loadSourceAvailability: (detail) async {
      final loaded = await ref
          .read(loadSourceAvailabilitySummaryUseCaseProvider)
          .call(detail);
      return loaded.fold(
        onFailure: Failure.new,
        onSuccess: (value) => Success(value.summary),
      );
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final malMetadataBridgeProvider = Provider<MalMetadataBridgeService>((ref) {
  final service = MalMetadataBridgeService(
    aniSkipCacheStore: ref.watch(aniSkipCacheStoreProvider),
    animeNexusSegmentLoader:
        ({required int anilistId, required int episodeNumber}) {
          return ref
              .read(animeNexusChapterServiceProvider)
              .getEpisodeSegments(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
              );
        },
  );
  ref.onDispose(service.dispose);
  return service;
});

final malIdByAnilistProvider = FutureProvider.autoDispose.family<int?, int>((
  ref,
  anilistId,
) async {
  return ref.watch(malMetadataBridgeProvider).getMalIdForAnilist(anilistId);
});

final malEpisodeMetadataProvider = FutureProvider.autoDispose
    .family<Map<int, MalEpisodeMetadata>, int>((ref, anilistId) async {
      final service = ref.watch(malMetadataBridgeProvider);
      final malId = await service.getMalIdForAnilist(anilistId);
      if (malId == null) {
        return const <int, MalEpisodeMetadata>{};
      }
      return service.getEpisodeMetadataByMalId(malId);
    });

final aniskipSegmentsProvider = FutureProvider.autoDispose
    .family<
      List<AniSkipSegment>,
      ({int anilistId, int episodeNumber, int episodeLengthSeconds})
    >((ref, args) async {
      final service = ref.watch(malMetadataBridgeProvider);
      if (args.episodeNumber <= 0 || args.episodeLengthSeconds <= 0) {
        return const <AniSkipSegment>[];
      }
      return service.getAniSkipSegments(
        anilistId: args.anilistId,
        episodeNumber: args.episodeNumber,
        episodeLengthSeconds: args.episodeLengthSeconds,
      );
    });

final anilistSourceMatcherProvider = Provider<AnilistSourceMatcher>((ref) {
  return const AnilistSourceMatcher();
});

final sourceSelectionPolicyProvider = Provider<SourceSelectionPolicy>((ref) {
  return const SourceSelectionPolicy();
});

final playbackPreferencePolicyProvider = Provider<PlaybackPreferencePolicy>((
  ref,
) {
  return const PlaybackPreferencePolicy();
});

final getHomeCatalogUseCaseProvider = Provider<GetHomeCatalogUseCase>((ref) {
  return GetHomeCatalogUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getTrendingCatalogUseCaseProvider = Provider<GetTrendingCatalogUseCase>((
  ref,
) {
  return GetTrendingCatalogUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getSeasonCatalogUseCaseProvider = Provider<GetSeasonCatalogUseCase>((
  ref,
) {
  return GetSeasonCatalogUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getUpcomingSeasonCatalogUseCaseProvider =
    Provider<GetUpcomingSeasonCatalogUseCase>((ref) {
      return GetUpcomingSeasonCatalogUseCase(
        ref.watch(animeCatalogRepositoryProvider),
      );
    });

final getSeasonRecommendationsUseCaseProvider =
    Provider<GetSeasonRecommendationsUseCase>((ref) {
      return GetSeasonRecommendationsUseCase(
        ref.watch(animeCatalogRepositoryProvider),
      );
    });

final getSeasonalDiscoveryCatalogUseCaseProvider =
    Provider<GetSeasonalDiscoveryCatalogUseCase>((ref) {
      return GetSeasonalDiscoveryCatalogUseCase(
        ref.watch(animeCatalogRepositoryProvider),
      );
    });

final getCalendarCatalogUseCaseProvider = Provider<GetCalendarCatalogUseCase>((
  ref,
) {
  return GetCalendarCatalogUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getAiringCalendarSlotsUseCaseProvider =
    Provider<GetAiringCalendarSlotsUseCase>((ref) {
      return GetAiringCalendarSlotsUseCase(
        ref.watch(animeCatalogRepositoryProvider),
      );
    });

final searchAnimeUseCaseProvider = Provider<SearchAnimeUseCase>((ref) {
  return SearchAnimeUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getAnimeDetailUseCaseProvider = Provider<GetAnimeDetailUseCase>((ref) {
  return GetAnimeDetailUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getAnimeEpisodesUseCaseProvider = Provider<GetAnimeEpisodesUseCase>((
  ref,
) {
  return GetAnimeEpisodesUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getBatchAnimeByIdsUseCaseProvider = Provider<GetBatchAnimeByIdsUseCase>((
  ref,
) {
  return GetBatchAnimeByIdsUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final browseAnimeUseCaseProvider = Provider<BrowseAnimeUseCase>((ref) {
  return BrowseAnimeUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getGenreCollectionUseCaseProvider = Provider<GetGenreCollectionUseCase>((
  ref,
) {
  return GetGenreCollectionUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getTagCollectionUseCaseProvider = Provider<GetTagCollectionUseCase>((
  ref,
) {
  return GetTagCollectionUseCase(ref.watch(animeCatalogRepositoryProvider));
});

final getSourceAvailabilitySummaryUseCaseProvider =
    Provider<GetSourceAvailabilitySummaryUseCase>((ref) {
      return GetSourceAvailabilitySummaryUseCase(
        sourcePlugins: ref.watch(sourcePluginsProvider),
        matcher: ref.watch(anilistSourceMatcherProvider),
        selectionPolicy: ref.watch(sourceSelectionPolicyProvider),
        registry: ref.watch(resolverRegistryProvider),
      );
    });

final sourceAvailabilityCacheCodecProvider =
    Provider<SourceAvailabilityCacheCodec>((ref) {
      return SourceAvailabilityCacheCodec(
        sourcePlugins: ref.watch(sourcePluginsProvider),
        selectionPolicy: ref.watch(sourceSelectionPolicyProvider),
      );
    });

final loadSourceAvailabilitySummaryUseCaseProvider =
    Provider<LoadSourceAvailabilitySummaryUseCase>((ref) {
      return LoadSourceAvailabilitySummaryUseCase(
        store: ref.watch(sourceAvailabilityStoreProvider),
        computeUseCase: ref.watch(getSourceAvailabilitySummaryUseCaseProvider),
        sourcePlugins: ref.watch(sourcePluginsProvider),
        cacheCodec: ref.watch(sourceAvailabilityCacheCodecProvider),
      );
    });

final backgroundSourceAvailabilityWarmupServiceProvider =
    Provider<BackgroundSourceAvailabilityWarmupService>((ref) {
      return BackgroundSourceAvailabilityWarmupService(
        loadAnimeDetail: (anilistId) {
          return ref.read(getAnimeDetailUseCaseProvider).call(anilistId);
        },
        loadSourceAvailability: ref.watch(
          loadSourceAvailabilitySummaryUseCaseProvider,
        ),
      );
    });

final resolveSourceServerLinkUseCaseProvider =
    Provider<ResolveSourceServerLinkUseCase>((ref) {
      return ResolveSourceServerLinkUseCase(
        registry: ref.watch(resolverRegistryProvider),
        streamVerifyClient: http.Client(),
      );
    });

final clearPlaybackPreferenceUseCaseProvider =
    Provider<ClearPlaybackPreferenceUseCase>((ref) {
      return ClearPlaybackPreferenceUseCase(
        store: ref.watch(animeProgressStoreProvider),
      );
    });

final startEpisodePlaybackUseCaseProvider =
    Provider<StartEpisodePlaybackUseCase>((ref) {
      return StartEpisodePlaybackUseCase(
        sourcePlugins: ref.watch(sourcePluginMapProvider),
        registry: ref.watch(resolverRegistryProvider),
        resolver: ref.watch(resolveSourceServerLinkUseCaseProvider),
        progressStore: ref.watch(animeProgressStoreProvider),
        sourceSelectionPolicy: ref.watch(sourceSelectionPolicyProvider),
        playbackPreferencePolicy: ref.watch(playbackPreferencePolicyProvider),
      );
    });

final homeCatalogProvider =
    FutureProvider.autoDispose<Result<List<Anime>, KumoriyaError>>((ref) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 15), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(getHomeCatalogUseCaseProvider).call();
    });

final trendingCatalogProvider = FutureProvider.autoDispose
    .family<Result<List<Anime>, KumoriyaError>, int>((ref, perPage) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 15), link.close);
      ref.onDispose(timer.cancel);
      return ref
          .watch(getTrendingCatalogUseCaseProvider)
          .call(perPage: perPage);
    });

final seasonalDiscoveryCatalogProvider = FutureProvider.autoDispose
    .family<
      Result<SeasonalDiscoveryCatalog, KumoriyaError>,
      SeasonalCatalogRequest
    >((ref, request) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 15), link.close);
      ref.onDispose(timer.cancel);
      return ref
          .watch(getSeasonalDiscoveryCatalogUseCaseProvider)
          .call(request);
    });

final calendarCatalogProvider =
    FutureProvider.autoDispose<Result<List<Anime>, KumoriyaError>>((ref) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), link.close);
      ref.onDispose(timer.cancel);
      final now = DateTime.now();
      final from = startOfLocalCalendarWeek(now);
      return ref
          .watch(getCalendarCatalogUseCaseProvider)
          .call(
            from: from,
            to: from.add(const Duration(days: 7)),
            perPage: 100,
          );
    });

DateTime startOfLocalCalendarWeek(DateTime value) {
  final startOfDay = DateTime(value.year, value.month, value.day);
  final daysFromMonday = (startOfDay.weekday - DateTime.monday + 7) % 7;
  return startOfDay.subtract(Duration(days: daysFromMonday));
}

DateTime calendarMonthKey(DateTime value) => DateTime(value.year, value.month);

// ---------------------------------------------------------------------------
// Month calendar providers
// ---------------------------------------------------------------------------

/// The month currently displayed in the calendar grid.
final calendarFocusMonthProvider =
    NotifierProvider<CalendarFocusMonthNotifier, DateTime>(
      CalendarFocusMonthNotifier.new,
    );

class CalendarFocusMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return calendarMonthKey(now);
  }

  void set(DateTime value) => state = calendarMonthKey(value);
}

/// The specific day selected by the user (defaults to today).
final calendarSelectedDayProvider =
    NotifierProvider<CalendarSelectedDayNotifier, DateTime>(
      CalendarSelectedDayNotifier.new,
    );

class CalendarSelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime value) => state = value;
}

/// Fetches airing entries for a single calendar month and keeps them warm in
/// memory for a short session window so moving back and forth does not refetch
/// immediately.
final calendarMonthSlotsProvider = FutureProvider.autoDispose
    .family<Result<List<Anime>, KumoriyaError>, DateTime>((ref, month) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 10), link.close);
      ref.onDispose(timer.cancel);

      final normalizedMonth = calendarMonthKey(month);
      final from = normalizedMonth;
      final to = DateTime(normalizedMonth.year, normalizedMonth.month + 1);

      return ref
          .watch(getAiringCalendarSlotsUseCaseProvider)
          .call(from: from, to: to, perPage: 100);
    });

final calendarFocusedMonthSlotsProvider =
    FutureProvider.autoDispose<Result<List<Anime>, KumoriyaError>>((ref) async {
      final focusMonth = ref.watch(calendarFocusMonthProvider);
      return ref.watch(
        calendarMonthSlotsProvider(calendarMonthKey(focusMonth)).future,
      );
    });

final searchCatalogProvider = FutureProvider.autoDispose
    .family<Result<List<Anime>, KumoriyaError>, String>((ref, query) async {
      if (query.trim().isEmpty) {
        return const Success(<Anime>[]);
      }

      return ref.watch(searchAnimeUseCaseProvider).call(query.trim());
    });

// ---------------------------------------------------------------------------
// Browse / Discover providers
// ---------------------------------------------------------------------------

final browseAnimeCatalogProvider = FutureProvider.autoDispose
    .family<Result<List<Anime>, KumoriyaError>, AnimeBrowseRequest>((
      ref,
      request,
    ) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 10), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(browseAnimeUseCaseProvider).call(request);
    });

final genreCollectionProvider =
    FutureProvider.autoDispose<Result<List<String>, KumoriyaError>>((
      ref,
    ) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 30), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(getGenreCollectionUseCaseProvider).call();
    });

final tagCollectionProvider =
    FutureProvider.autoDispose<Result<List<AnimeTag>, KumoriyaError>>((
      ref,
    ) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 30), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(getTagCollectionUseCaseProvider).call();
    });

final animeDetailProvider = FutureProvider.autoDispose
    .family<Result<AnimeDetail, KumoriyaError>, int>((ref, anilistId) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 20), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(getAnimeDetailUseCaseProvider).call(anilistId);
    });

final animeEpisodesProvider = FutureProvider.autoDispose
    .family<Result<List<AnimeEpisode>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 20), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(getAnimeEpisodesUseCaseProvider).call(anilistId);
    });

final sourceAvailabilitySummaryProvider = FutureProvider.autoDispose
    .family<Result<SourceAvailabilitySummary, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), link.close);
      ref.onDispose(timer.cancel);
      final detailResult = await ref.watch(
        animeDetailProvider(anilistId).future,
      );
      if (detailResult is Failure<AnimeDetail, KumoriyaError>) {
        return Failure(detailResult.error);
      }

      final detail =
          (detailResult as Success<AnimeDetail, KumoriyaError>).value;
      final loaded = await ref
          .watch(loadSourceAvailabilitySummaryUseCaseProvider)
          .call(detail);

      return loaded.fold(
        onFailure: Failure.new,
        onSuccess: (value) {
          _debugSourceAvailability(
            'provider-loaded anilist=$anilistId '
            'animeStatus=${detail.anime.status.name} '
            'animeEpisodes=${_debugEpisodeRange(detail.episodes)} '
            'fromCache=${value.fromCache} '
            'shouldRefreshInBackground=${value.shouldRefreshInBackground} '
            'sources=${_debugSummaryRanges(value.summary)}',
          );
          if (value.shouldRefreshInBackground) {
            unawaited(
              Future<void>(() async {
                _debugSourceAvailability(
                  'provider-background-refresh-start anilist=$anilistId',
                );
                final refreshResult = await ref
                    .read(loadSourceAvailabilitySummaryUseCaseProvider)
                    .refresh(detail);
                _debugSourceAvailability(
                  'provider-background-refresh-done anilist=$anilistId '
                  'success=${refreshResult.isSuccess}',
                );
                if (refreshResult.isSuccess) {
                  ref.invalidateSelf();
                }
              }),
            );
          }
          return Success(value.summary);
        },
      );
    });

void _debugSourceAvailability(String message) {
  if (kDebugMode) {
    debugPrint('[KUMO_SOURCE_AVAIL] $message');
  }
}

String _debugSummaryRanges(SourceAvailabilitySummary summary) {
  if (summary.sources.isEmpty) {
    return 'none';
  }
  return summary.sources
      .map(
        (source) =>
            '${source.manifest.id}:status=${source.status.name}:eps=${_debugEpisodeRange(source.episodes)}:accept=${source.decision.acceptanceSignals.join('|')}:reject=${source.decision.rejectionSignals.join('|')}',
      )
      .join(';');
}

String _debugEpisodeRange(Iterable<dynamic> episodes) {
  var count = 0;
  double? min;
  double? max;
  String? lastId;
  for (final episode in episodes) {
    final (number, sourceId) = switch (episode) {
      AnimeEpisode e => (e.number, null),
      SourceEpisode e => (e.number, e.sourceEpisodeId),
      _ => (null, null),
    };
    if (number == null) {
      continue;
    }
    count++;
    min = min == null || number < min ? number : min;
    max = max == null || number > max ? number : max;
    lastId = sourceId ?? lastId;
  }
  if (count == 0) {
    return '0';
  }
  final idSuffix = lastId == null ? '' : ':last=$lastId';
  return '$count(${_debugNumberLabel(min!)}-${_debugNumberLabel(max!)})$idSuffix';
}

String _debugNumberLabel(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3);
}

final sourceEpisodeServerLinksProvider = FutureProvider.autoDispose
    .family<
      Result<List<SourceServerLink>, KumoriyaError>,
      ({String sourcePluginId, SourceEpisode episode})
    >((ref, args) async {
      return GetSourceEpisodeServerLinksUseCase(
        sourcePlugin: ref.watch(sourcePluginByIdProvider(args.sourcePluginId)),
        registry: ref.watch(resolverRegistryProvider),
        // Include download-type links (Mediafire) so they show up in the
        // manual server picker and watch-party resolution paths. Hosts
        // without a streaming resolver are filtered out by the use case.
        includeDownloadLinks: true,
      ).call(args.episode);
    });

final jkanimeAvailabilityProvider = FutureProvider.autoDispose
    .family<Result<SourceAvailability, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      final summary = await ref.watch(
        sourceAvailabilitySummaryProvider(anilistId).future,
      );
      return summary.fold(
        onFailure: Failure.new,
        onSuccess: (value) {
          final source = value.sources.firstWhere(
            (entry) => entry.manifest.id == 'kumoriya.source.jkanime',
            orElse: () => SourceAvailability(
              manifest: ref.watch(sourcePluginProvider).manifest,
              status: SourceAvailabilityStatus.unavailable,
              decision: const SourceMatchDecision(
                verdict: false,
                confidence: MatchConfidence.low,
                reason: 'JKAnime availability was not evaluated.',
                acceptanceSignals: <String>[],
                rejectionSignals: <String>['missing-jkanime-summary'],
              ),
              unavailableReason: SourceUnavailableReason.noMatch,
            ),
          );
          return Success(source);
        },
      );
    });

final jkanimeEpisodeServerLinksProvider = FutureProvider.autoDispose
    .family<Result<List<SourceServerLink>, KumoriyaError>, SourceEpisode>((
      ref,
      episode,
    ) async {
      return ref.watch(
        sourceEpisodeServerLinksProvider((
          sourcePluginId: 'kumoriya.source.jkanime',
          episode: episode,
        )).future,
      );
    });

final resolveSourceServerLinkProvider = FutureProvider.autoDispose
    .family<Result<ResolvedServerLinkResult, KumoriyaError>, SourceServerLink>((
      ref,
      sourceServerLink,
    ) async {
      return ref
          .watch(resolveSourceServerLinkUseCaseProvider)
          .call(sourceServerLink);
    });

final episodePlaybackDecisionProvider = FutureProvider.autoDispose
    .family<
      EpisodePlaybackDecision,
      ({int anilistId, double episodeNumber, SourceAvailabilitySummary summary})
    >((ref, args) async {
      return ref
          .watch(startEpisodePlaybackUseCaseProvider)
          .call(
            anilistId: args.anilistId,
            episodeNumber: args.episodeNumber,
            availabilitySummary: args.summary,
          );
    });
