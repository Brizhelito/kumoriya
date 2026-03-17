import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../anime_catalog/presentation/providers/storage_providers.dart';
import '../application/download_manager_service.dart';
import '../application/enqueue_download_use_case.dart';

// ─── Download Manager (singleton) ────────────────────────────────────────────

final downloadManagerProvider = Provider<DownloadManagerService>((ref) {
  final store = ref.watch(downloadStoreProvider);
  final manager = DownloadManagerService(store: store);
  ref.onDispose(manager.dispose);
  return manager;
});

// ─── Enqueue Use Case ────────────────────────────────────────────────────────

final enqueueDownloadUseCaseProvider = Provider<EnqueueDownloadUseCase>((ref) {
  return EnqueueDownloadUseCase(
    downloadManager: ref.watch(downloadManagerProvider),
    resolveUseCase: ref.watch(resolveSourceServerLinkUseCaseProvider),
  );
});

// ─── Download list providers ─────────────────────────────────────────────────

final allDownloadTasksProvider =
    FutureProvider.autoDispose<Result<List<DownloadTask>, KumoriyaError>>((
      ref,
    ) async {
      return ref.watch(downloadStoreProvider).getAllTasks();
    });

final downloadTasksByAnimeProvider = FutureProvider.autoDispose
    .family<Result<List<DownloadTask>, KumoriyaError>, int>((
      ref,
      anilistId,
    ) async {
      return ref.watch(downloadStoreProvider).getTasksByAnime(anilistId);
    });

final activeDownloadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
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

final autoDownloadAnimeIdsProvider =
    FutureProvider.autoDispose<Result<Set<int>, KumoriyaError>>((ref) async {
      return ref.watch(libraryStoreProvider).getAutoDownloadAnimeIds();
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
