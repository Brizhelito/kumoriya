import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../downloads/application/download_aniskip_file_store.dart';
import '../../../downloads/application/download_directory_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'AppDatabase must be overridden at ProviderScope level via openAppDatabase().',
  );
});

final animeProgressStoreProvider = Provider<AnimeProgressStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAnimeProgressStore(db);
});

final aniSkipCacheStoreProvider = Provider<AniSkipCacheStore>((ref) {
  return DownloadAniSkipFileStore(
    directoryService: DownloadDirectoryService(
      store: FileDownloadDirectoryStore(),
    ),
  );
});

final sourceAvailabilityStoreProvider = Provider<SourceAvailabilityStore>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSourceAvailabilityStore(db);
});

final downloadStoreProvider = Provider<DownloadStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDownloadStore(db);
});

final libraryStoreProvider = Provider<LibraryStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftLibraryStore(db);
});

final anilistCacheStoreProvider = Provider<AnilistCacheStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAnilistCacheStore(db);
});

final favoriteAnimeIdsProvider =
    FutureProvider.autoDispose<Result<Set<int>, KumoriyaError>>((ref) async {
      return ref.watch(libraryStoreProvider).getFavoriteAnimeIds();
    });

final subscribedAnimeIdsProvider =
    FutureProvider.autoDispose<Result<Set<int>, KumoriyaError>>((ref) async {
      return ref.watch(libraryStoreProvider).getSubscribedAnimeIds();
    });

final isFavoriteProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  anilistId,
) async {
  final result = await ref.watch(favoriteAnimeIdsProvider.future);
  return result.fold(
    onFailure: (_) => false,
    onSuccess: (ids) => ids.contains(anilistId),
  );
});

final isSubscribedProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  anilistId,
) async {
  final result = await ref.watch(subscribedAnimeIdsProvider.future);
  return result.fold(
    onFailure: (_) => false,
    onSuccess: (ids) => ids.contains(anilistId),
  );
});

final autoDownloadAudioPreferenceProvider = FutureProvider.autoDispose
    .family<String, int>((ref, anilistId) async {
      final preference = await ref
          .watch(libraryStoreProvider)
          .getAutoDownloadAudioPreference(anilistId);
      return preference ?? 'none';
    });

final continueWatchingProvider =
    FutureProvider.autoDispose<Result<List<AnimeWatchHistory>, KumoriyaError>>((
      ref,
    ) async {
      return ref.watch(animeProgressStoreProvider).getRecentHistory(limit: 10);
    });

final latestEpisodeProgressProvider = FutureProvider.autoDispose
    .family<Result<EpisodeProgress?, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      return ref.watch(animeProgressStoreProvider).getLatestProgress(anilistId);
    });

final animeEpisodeProgressListProvider = FutureProvider.autoDispose
    .family<Result<List<EpisodeProgress>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      return ref.watch(animeProgressStoreProvider).getAllProgress(anilistId);
    });

final playbackPreferenceProvider = FutureProvider.autoDispose
    .family<Result<PlaybackPreference?, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      return ref
          .watch(animeProgressStoreProvider)
          .getPlaybackPreference(anilistId);
    });

final episodeProgressProvider = FutureProvider.autoDispose
    .family<
      Result<EpisodeProgress?, KumoriyaError>,
      ({int anilistId, double episodeNumber})
    >((ref, args) async {
      return ref
          .watch(animeProgressStoreProvider)
          .getProgress(args.anilistId, args.episodeNumber);
    });
