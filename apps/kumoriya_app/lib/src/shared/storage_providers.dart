import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

import '../features/downloads/application/download_aniskip_file_store.dart';
import '../features/downloads/application/download_directory_service.dart';
import 'auth/auth_providers.dart';
import 'notifications/fcm_aware_library_store.dart';
import 'notifications/fcm_providers.dart';
import 'sync/sync_providers.dart';
import 'sync/sync_refresh.dart';
import 'sync/sync_aware_library_store.dart';
import 'sync/sync_aware_progress_store.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'AppDatabase must be overridden at ProviderScope level via openAppDatabase().',
  );
});

final rawAnimeProgressStoreProvider = Provider<AnimeProgressStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAnimeProgressStore(db);
});

final animeProgressStoreProvider = Provider<AnimeProgressStore>((ref) {
  final inner = ref.watch(rawAnimeProgressStoreProvider);
  final syncQueue = ref.watch(syncQueueStoreProvider);
  return SyncAwareProgressStore(
    inner: inner,
    syncQueue: syncQueue,
    isAuthenticated: () => ref.read(isAuthenticatedProvider),
    onEnqueued: () => ref.read(syncCoordinatorProvider).notifyLocalWrite(),
  );
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

final hlsSegmentStoreProvider = Provider<HlsSegmentStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftHlsSegmentStore(db);
});

final rawLibraryStoreProvider = Provider<LibraryStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftLibraryStore(db);
});

final libraryStoreProvider = Provider<LibraryStore>((ref) {
  final inner = ref.watch(rawLibraryStoreProvider);
  final syncQueue = ref.watch(syncQueueStoreProvider);
  // Order matters: FCM decorates the sync-aware store so that
  // subscription changes are persisted + queued for sync first, and
  // only then mirrored to FCM. A topic-subscribe failure must not
  // block the local write nor the sync-queue enqueue.
  final syncAware = SyncAwareLibraryStore(
    inner: inner,
    syncQueue: syncQueue,
    isAuthenticated: () => ref.read(isAuthenticatedProvider),
    onEnqueued: () => ref.read(syncCoordinatorProvider).notifyLocalWrite(),
  );
  final fcm = ref.watch(fcmServiceProvider);
  return FcmAwareLibraryStore(inner: syncAware, fcm: fcm);
});

final syncQueueStoreProvider = Provider<SyncQueueStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSyncQueueStore(db);
});

final anilistCacheStoreProvider = Provider<AnilistCacheStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAnilistCacheStore(db);
});

final episodeCacheStoreProvider = Provider<EpisodeCacheStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftEpisodeCacheStore(db);
});

final mangaCacheStoreProvider = Provider<MangaCacheStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftMangaCacheStore(db);
});

final mangaProgressStoreProvider = Provider<MangaProgressStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftMangaProgressStore(db);
});

final translationCacheStoreProvider = Provider<TranslationCacheStore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftTranslationCacheStore(db);
});

final favoriteAnimeIdsProvider =
    FutureProvider.autoDispose<Result<Set<int>, KumoriyaError>>((ref) async {
      ref.watch(syncDataRefreshEpochProvider);
      return ref.watch(libraryStoreProvider).getFavoriteAnimeIds();
    });

final subscribedAnimeIdsProvider =
    FutureProvider.autoDispose<Result<Set<int>, KumoriyaError>>((ref) async {
      ref.watch(syncDataRefreshEpochProvider);
      return ref.watch(libraryStoreProvider).getSubscribedAnimeIds();
    });

final isFavoriteProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  anilistId,
) async {
  return ref.watch(
    favoriteAnimeIdsProvider.selectAsync(
      (result) => result.fold(
        onFailure: (_) => false,
        onSuccess: (ids) => ids.contains(anilistId),
      ),
    ),
  );
});

final isSubscribedProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  anilistId,
) async {
  return ref.watch(
    subscribedAnimeIdsProvider.selectAsync(
      (result) => result.fold(
        onFailure: (_) => false,
        onSuccess: (ids) => ids.contains(anilistId),
      ),
    ),
  );
});

final autoDownloadAudioPreferenceProvider = FutureProvider.autoDispose
    .family<String, int>((ref, anilistId) async {
      ref.watch(syncDataRefreshEpochProvider);
      final preference = await ref
          .watch(libraryStoreProvider)
          .getAutoDownloadAudioPreference(anilistId);
      return preference ?? 'none';
    });

final continueWatchingProvider =
    FutureProvider.autoDispose<Result<List<AnimeWatchHistory>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(syncDataRefreshEpochProvider);
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(animeProgressStoreProvider).getRecentHistory(limit: 10);
    });

final allWatchHistoryProvider =
    FutureProvider.autoDispose<Result<List<AnimeWatchHistory>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(syncDataRefreshEpochProvider);
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 5), link.close);
      ref.onDispose(timer.cancel);
      return ref.watch(animeProgressStoreProvider).getAllHistory();
    });

final latestEpisodeProgressProvider = FutureProvider.autoDispose
    .family<Result<EpisodeProgress?, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      ref.watch(syncDataRefreshEpochProvider);
      return ref.watch(animeProgressStoreProvider).getLatestProgress(anilistId);
    });

final animeEpisodeProgressListProvider = FutureProvider.autoDispose
    .family<Result<List<EpisodeProgress>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      ref.watch(syncDataRefreshEpochProvider);
      return ref.watch(animeProgressStoreProvider).getAllProgress(anilistId);
    });

final playbackPreferenceProvider = FutureProvider.autoDispose
    .family<Result<PlaybackPreference?, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      ref.watch(syncDataRefreshEpochProvider);
      return ref
          .watch(animeProgressStoreProvider)
          .getPlaybackPreference(anilistId);
    });

final episodeProgressProvider = FutureProvider.autoDispose
    .family<
      Result<EpisodeProgress?, KumoriyaError>,
      ({int anilistId, double episodeNumber})
    >((ref, args) async {
      ref.watch(syncDataRefreshEpochProvider);
      return ref
          .watch(animeProgressStoreProvider)
          .getProgress(args.anilistId, args.episodeNumber);
    });
