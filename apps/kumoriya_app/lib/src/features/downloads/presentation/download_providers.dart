import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../anime_catalog/presentation/providers/storage_providers.dart';
import '../application/download_cover_service.dart';
import '../application/download_directory_service.dart';
import '../application/download_library_index_service.dart';
import '../application/download_manager_service.dart';
import '../application/enqueue_download_use_case.dart';

// ─── Download Manager (singleton) ────────────────────────────────────────────

final downloadDirectoryStoreProvider = Provider<DownloadDirectoryStore>((ref) {
  return FileDownloadDirectoryStore();
});

final downloadDirectoryServiceProvider = Provider<DownloadDirectoryService>((
  ref,
) {
  return DownloadDirectoryService(
    store: ref.watch(downloadDirectoryStoreProvider),
  );
});

final downloadDirectoryInfoProvider =
    FutureProvider.autoDispose<DownloadDirectoryInfo>((ref) async {
      return ref.watch(downloadDirectoryServiceProvider).getDirectoryInfo();
    });

final downloadCoverServiceProvider = Provider<DownloadCoverService>((ref) {
  return DownloadCoverService(
    directoryService: ref.watch(downloadDirectoryServiceProvider),
  );
});

final downloadLibraryIndexServiceProvider =
    Provider<DownloadLibraryIndexService>((ref) {
      return DownloadLibraryIndexService(
        store: ref.watch(downloadStoreProvider),
        directoryService: ref.watch(downloadDirectoryServiceProvider),
      );
    });

final downloadManagerProvider = Provider<DownloadManagerService>((ref) {
  final store = ref.watch(downloadStoreProvider);
  final manager = DownloadManagerService(
    store: store,
    directoryService: ref.watch(downloadDirectoryServiceProvider),
    libraryIndexService: ref.watch(downloadLibraryIndexServiceProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

// ─── Enqueue Use Case ────────────────────────────────────────────────────────

final enqueueDownloadUseCaseProvider = Provider<EnqueueDownloadUseCase>((ref) {
  return EnqueueDownloadUseCase(
    downloadManager: ref.watch(downloadManagerProvider),
    resolveUseCase: ref.watch(resolveSourceServerLinkUseCaseProvider),
    coverService: ref.watch(downloadCoverServiceProvider),
  );
});

// ─── Status change stream (drives reactivity for download list providers) ───

/// Global status change stream — broadcasts every download status change.
final downloadStatusChangeStreamProvider =
    StreamProvider.autoDispose<DownloadStatusChange>((ref) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.statusChangeStream;
    });

/// Scoped status change stream — only fires when a specific anime's downloads
/// change (or on global events like library sync where anilistId is null).
/// This prevents episode cards for anime A from rebuilding when anime B's
/// download status changes.
final downloadStatusChangeForAnimeProvider = StreamProvider.autoDispose
    .family<DownloadStatusChange, int>((ref, anilistId) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.statusChangeStream.where(
        (e) => e.anilistId == null || e.anilistId == anilistId,
      );
    });

// ─── Download list providers ─────────────────────────────────────────────────

/// All tasks — used only by the downloads page. Re-reads on any status change.
final allDownloadTasksProvider =
    FutureProvider.autoDispose<Result<List<DownloadTask>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(downloadStatusChangeStreamProvider);
      return ref.watch(downloadStoreProvider).getAllTasks();
    });

/// Per-anime task list — only refreshes when the specific anime's downloads
/// change, NOT on every global status change. This is the key fix for
/// preventing O(N×M) rebuilds on episode list pages.
final downloadTasksByAnimeProvider = FutureProvider.autoDispose
    .family<Result<List<DownloadTask>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      ref.watch(downloadStatusChangeForAnimeProvider(anilistId));
      return ref.watch(downloadStoreProvider).getTasksByAnime(anilistId);
    });

final activeDownloadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  ref.watch(downloadStatusChangeStreamProvider);
  final result = await ref
      .watch(downloadStoreProvider)
      .getTasksByStatus(DownloadStatus.downloading);
  return result.fold(onSuccess: (tasks) => tasks.length, onFailure: (_) => 0);
});

// ─── Download progress stream ────────────────────────────────────────────────

final downloadProgressStreamProvider =
    StreamProvider.autoDispose<DownloadProgressEvent>((ref) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.progressStream;
    });

final downloadAggregateProgressProvider =
    StreamProvider.autoDispose<DownloadAggregateProgress>((ref) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.aggregateProgressStream;
    });

/// Per-task live progress — filters the shared broadcast stream so each
/// download widget receives only its own events without missing updates.
final downloadProgressByTaskProvider = StreamProvider.autoDispose
    .family<DownloadProgressEvent, String>((ref, taskId) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.progressStream.where((e) => e.taskId == taskId);
    });

final autoDownloadAnimeIdsProvider =
    FutureProvider.autoDispose<Result<Set<int>, KumoriyaError>>((ref) async {
      return ref.watch(libraryStoreProvider).getAutoDownloadAnimeIds();
    });

/// Resolves the local cover image path for a downloaded anime.
/// Returns null when no persisted cover exists.
final downloadCoverPathProvider =
    FutureProvider.autoDispose.family<String?, int>((ref, anilistId) async {
      return ref.watch(downloadCoverServiceProvider).getCoverPath(anilistId);
    });

final isAutoDownloadProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  anilistId,
) async {
  final result = await ref.watch(autoDownloadAnimeIdsProvider.future);
  return result.fold(
    onFailure: (_) => false,
    onSuccess: (ids) => ids.contains(anilistId),
  );
});
