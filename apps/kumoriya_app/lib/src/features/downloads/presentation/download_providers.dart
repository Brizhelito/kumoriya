import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../anime_catalog/application/services/source_availability_cache_codec.dart';
import '../../anime_catalog/application/use_cases/get_source_episode_server_links_use_case.dart';
import '../../anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import '../../anime_catalog/application/services/resolver_registry.dart';
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
  final sourcePluginMap = ref.watch(sourcePluginMapProvider);
  final registry = ref.watch(resolverRegistryProvider);
  final resolveUseCase = ref.watch(resolveSourceServerLinkUseCaseProvider);
  final sourceAvailabilityStore = ref.watch(sourceAvailabilityStoreProvider);
  final cacheCodec = ref.watch(sourceAvailabilityCacheCodecProvider);

  final manager = DownloadManagerService(
    store: store,
    directoryService: ref.watch(downloadDirectoryServiceProvider),
    libraryIndexService: ref.watch(downloadLibraryIndexServiceProvider),
    linkRefresher: _buildLinkRefresher(
      sourcePluginMap: sourcePluginMap,
      registry: registry,
      resolveUseCase: resolveUseCase,
      sourceAvailabilityStore: sourceAvailabilityStore,
      cacheCodec: cacheCodec,
    ),
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
final downloadCoverPathProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, anilistId) async {
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

// ─── Link refresher (recovery from 403 / expired CDN tokens) ────────────────

DownloadLinkRefresher _buildLinkRefresher({
  required Map<String, SourcePlugin> sourcePluginMap,
  required ResolverRegistry registry,
  required ResolveSourceServerLinkUseCase resolveUseCase,
  required SourceAvailabilityStore sourceAvailabilityStore,
  required SourceAvailabilityCacheCodec cacheCodec,
}) {
  return ({
    required int anilistId,
    required double episodeNumber,
    required String? sourcePluginId,
    required String? serverName,
    required bool tryAlternativeServer,
  }) async {
    // 1. Look up the source plugin.
    final plugin = sourcePluginId != null
        ? sourcePluginMap[sourcePluginId]
        : null;
    if (plugin == null) return null;

    // 2. Find the SourceEpisode from cached availability.
    final cached = await sourceAvailabilityStore.getAvailability(anilistId);
    final records = cached.fold(
      onSuccess: (value) => value,
      onFailure: (_) => <SourceAvailabilityCacheRecord>[],
    );
    final snapshot = cacheCodec.decode(records);
    if (snapshot == null) return null;

    final sourceAvailability = snapshot.summary.sources
        .where((s) => s.manifest.id == sourcePluginId && s.isAvailable)
        .firstOrNull;
    if (sourceAvailability == null) return null;

    final epKey = episodeNumber.round();
    final episode = sourceAvailability.episodes
        .where((e) => (e.number - epKey).abs() < 0.01)
        .firstOrNull;
    if (episode == null) return null;

    // 3. Fetch fresh server links from the source plugin.
    final linksResult = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: plugin,
      registry: registry,
    ).call(episode);
    final links = linksResult.fold(
      onSuccess: (value) => value,
      onFailure: (_) => <SourceServerLink>[],
    );
    if (links.isEmpty) return null;

    // 4. Pick the right server link.
    SourceServerLink? targetLink;
    if (tryAlternativeServer) {
      // Skip the original server, pick the first alternative.
      targetLink = links.where((l) => l.serverName != serverName).firstOrNull;
    }
    // Fall back to the same server (fresh URL) or first available.
    targetLink ??= links.where((l) => l.serverName == serverName).firstOrNull;
    targetLink ??= links.first;

    // 5. Resolve to get a fresh stream URL.
    final resolveResult = await resolveUseCase.call(targetLink);
    final resolved = resolveResult.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (resolved == null || resolved.streams.isEmpty) return null;

    // Pick best stream (prefer non-HLS for downloads).
    final nonHls = resolved.streams.where((s) => !s.isHls).toList();
    final stream = nonHls.isNotEmpty ? nonHls.first : resolved.streams.first;

    return DownloadRefreshResult(
      sourceUrl: stream.url,
      headers: stream.headers,
      isHls: stream.isHls,
      serverName: targetLink.serverName,
      detectedHost: stream.url.host,
      qualityLabel: stream.qualityLabel,
    );
  };
}
