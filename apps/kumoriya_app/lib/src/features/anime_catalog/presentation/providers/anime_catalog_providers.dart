import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../application/use_cases/anime_catalog_use_cases.dart';
import '../../application/matching/anilist_source_matcher.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/source_availability.dart';
import '../../application/services/anime_nexus_chapter_service.dart';
import '../../application/services/background_source_availability_warmup_service.dart';
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
  return HttpAnilistGraphqlClient();
});

final anilistMetadataGatewayProvider = Provider<AnilistMetadataGateway>((ref) {
  return GraphqlAnilistMetadataGateway(
    client: ref.watch(anilistGraphqlClientProvider),
  );
});

final animeCatalogRepositoryProvider = Provider<AnimeCatalogRepository>((ref) {
  return AnilistAnimeCatalogRepository(
    gateway: ref.watch(anilistMetadataGatewayProvider),
  );
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

final resolverPluginsProvider = Provider<List<ResolverPlugin>>((ref) {
  return buildDefaultResolverPlugins();
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

final getCalendarCatalogUseCaseProvider = Provider<GetCalendarCatalogUseCase>((
  ref,
) {
  return GetCalendarCatalogUseCase(ref.watch(animeCatalogRepositoryProvider));
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
      return ref.watch(getHomeCatalogUseCaseProvider).call();
    });

final calendarCatalogProvider =
    FutureProvider.autoDispose<Result<List<Anime>, KumoriyaError>>((ref) async {
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

final searchCatalogProvider = FutureProvider.autoDispose
    .family<Result<List<Anime>, KumoriyaError>, String>((ref, query) async {
      if (query.trim().isEmpty) {
        return const Success(<Anime>[]);
      }

      return ref.watch(searchAnimeUseCaseProvider).call(query.trim());
    });

final animeDetailProvider = FutureProvider.autoDispose
    .family<Result<AnimeDetail, KumoriyaError>, int>((ref, anilistId) async {
      ref.keepAlive();
      return ref.watch(getAnimeDetailUseCaseProvider).call(anilistId);
    });

final animeEpisodesProvider = FutureProvider.autoDispose
    .family<Result<List<AnimeEpisode>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      return ref.watch(getAnimeEpisodesUseCaseProvider).call(anilistId);
    });

final sourceAvailabilitySummaryProvider = FutureProvider.autoDispose
    .family<Result<SourceAvailabilitySummary, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      ref.keepAlive();
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
          if (value.shouldRefreshInBackground) {
            unawaited(
              Future<void>(() async {
                final refreshResult = await ref
                    .read(loadSourceAvailabilitySummaryUseCaseProvider)
                    .refresh(detail);
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

final sourceEpisodeServerLinksProvider = FutureProvider.autoDispose
    .family<
      Result<List<SourceServerLink>, KumoriyaError>,
      ({String sourcePluginId, SourceEpisode episode})
    >((ref, args) async {
      return GetSourceEpisodeServerLinksUseCase(
        sourcePlugin: ref.watch(sourcePluginByIdProvider(args.sourcePluginId)),
        registry: ref.watch(resolverRegistryProvider),
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
