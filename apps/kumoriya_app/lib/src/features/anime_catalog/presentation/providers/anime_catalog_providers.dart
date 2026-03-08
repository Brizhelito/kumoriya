import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_filemoon/kumoriya_resolver_filemoon.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:kumoriya_resolver_mixdrop/kumoriya_resolver_mixdrop.dart';
import 'package:kumoriya_resolver_mp4upload/kumoriya_resolver_mp4upload.dart';
import 'package:kumoriya_resolver_streamwish/kumoriya_resolver_streamwish.dart';
import 'package:kumoriya_resolver_voe/kumoriya_resolver_voe.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';

import '../../application/use_cases/anime_catalog_use_cases.dart';
import '../../application/matching/anilist_jkanime_matcher.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../application/models/source_availability.dart';
import '../../application/services/resolver_registry.dart';
import '../../application/use_cases/check_jkanime_availability_use_case.dart';
import '../../application/use_cases/get_jkanime_episode_server_links_use_case.dart';
import '../../application/use_cases/resolve_source_server_link_use_case.dart';

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

final sourcePluginProvider = Provider<SourcePlugin>((ref) {
  return JkAnimeSourcePlugin();
});

final resolverPluginsProvider = Provider<List<ResolverPlugin>>((ref) {
  return <ResolverPlugin>[
    JkPlayerJkResolverPlugin(),
    JkPlayerResolverPlugin(),
    VoeResolverPlugin(),
    FilemoonResolverPlugin(),
    StreamwishResolverPlugin(),
    MixdropResolverPlugin(),
    Mp4uploadResolverPlugin(),
  ];
});

final resolverRegistryProvider = Provider<ResolverRegistry>((ref) {
  return ResolverRegistry(resolvers: ref.watch(resolverPluginsProvider));
});

final anilistJkanimeMatcherProvider = Provider<AnilistJkanimeMatcher>((ref) {
  return const AnilistJkanimeMatcher();
});

final getHomeCatalogUseCaseProvider = Provider<GetHomeCatalogUseCase>((ref) {
  return GetHomeCatalogUseCase(ref.watch(animeCatalogRepositoryProvider));
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

final checkJkanimeAvailabilityUseCaseProvider =
    Provider<CheckJkanimeAvailabilityUseCase>((ref) {
      return CheckJkanimeAvailabilityUseCase(
        sourcePlugin: ref.watch(sourcePluginProvider),
        matcher: ref.watch(anilistJkanimeMatcherProvider),
      );
    });

final getJkanimeEpisodeServerLinksUseCaseProvider =
    Provider<GetJkanimeEpisodeServerLinksUseCase>((ref) {
      return GetJkanimeEpisodeServerLinksUseCase(
        sourcePlugin: ref.watch(sourcePluginProvider),
      );
    });

final resolveSourceServerLinkUseCaseProvider =
    Provider<ResolveSourceServerLinkUseCase>((ref) {
      return ResolveSourceServerLinkUseCase(
        registry: ref.watch(resolverRegistryProvider),
      );
    });

final homeCatalogProvider =
    FutureProvider.autoDispose<Result<List<Anime>, KumoriyaError>>((ref) async {
      return ref.watch(getHomeCatalogUseCaseProvider).call();
    });

final searchCatalogProvider = FutureProvider.autoDispose
    .family<Result<List<Anime>, KumoriyaError>, String>((ref, query) async {
      if (query.trim().isEmpty) {
        return const Success(<Anime>[]);
      }

      return ref.watch(searchAnimeUseCaseProvider).call(query.trim());
    });

final animeDetailProvider = FutureProvider.autoDispose
    .family<Result<AnimeDetail, KumoriyaError>, int>((ref, anilistId) async {
      return ref.watch(getAnimeDetailUseCaseProvider).call(anilistId);
    });

final animeEpisodesProvider = FutureProvider.autoDispose
    .family<Result<List<AnimeEpisode>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      return ref.watch(getAnimeEpisodesUseCaseProvider).call(anilistId);
    });

final jkanimeAvailabilityProvider = FutureProvider.autoDispose
    .family<Result<SourceAvailability, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      final detailResult = await ref.watch(
        animeDetailProvider(anilistId).future,
      );
      if (detailResult is Failure<AnimeDetail, KumoriyaError>) {
        return Failure(detailResult.error);
      }

      final detail =
          (detailResult as Success<AnimeDetail, KumoriyaError>).value;
      return ref.watch(checkJkanimeAvailabilityUseCaseProvider).call(detail);
    });

final jkanimeEpisodeServerLinksProvider = FutureProvider.autoDispose
    .family<Result<List<SourceServerLink>, KumoriyaError>, SourceEpisode>((
      ref,
      episode,
    ) async {
      return ref
          .watch(getJkanimeEpisodeServerLinksUseCaseProvider)
          .call(episode);
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
