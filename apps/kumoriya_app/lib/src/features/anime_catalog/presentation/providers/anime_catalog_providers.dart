import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../application/use_cases/anime_catalog_use_cases.dart';

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
