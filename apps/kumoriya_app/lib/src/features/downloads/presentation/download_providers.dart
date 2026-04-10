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
import '../application/auto_delete_watched_service.dart';
import '../application/download_cover_service.dart';
import '../application/download_directory_service.dart';
import '../application/download_foreground_service.dart';
import '../application/download_library_index_service.dart';
import '../application/download_manager_service.dart';
import '../application/download_server_scorer.dart';
import '../application/enqueue_download_use_case.dart';

// ─── Server Scorer (session-scoped singleton) ───────────────────────────────

final downloadServerScorerProvider = Provider<DownloadServerScorer>((ref) {
  return DownloadServerScorer();
});

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
  final scorer = ref.watch(downloadServerScorerProvider);

  final manager = DownloadManagerService(
    store: store,
    directoryService: ref.watch(downloadDirectoryServiceProvider),
    libraryIndexService: ref.watch(downloadLibraryIndexServiceProvider),
    hlsSegmentStore: ref.watch(hlsSegmentStoreProvider),
    foregroundService: DownloadForegroundService(),
    linkRefresher: _buildLinkRefresher(
      sourcePluginMap: sourcePluginMap,
      registry: registry,
      resolveUseCase: resolveUseCase,
      sourceAvailabilityStore: sourceAvailabilityStore,
      cacheCodec: cacheCodec,
      scorer: scorer,
    ),
    onServerOutcome: (serverName, {required success}) {
      if (success) {
        scorer.recordSuccess(serverName);
      } else {
        scorer.recordFailure(serverName);
      }
    },
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

// ─── Auto-delete watched downloads ──────────────────────────────────────────

final autoDeleteDelayStoreProvider = Provider<AutoDeleteDelayStore>((ref) {
  return AutoDeleteDelayStore();
});

/// Current auto-delete delay preference. Loaded from disk on first read,
/// persisted on every change.
class AutoDeleteDelayNotifier extends AsyncNotifier<AutoDeleteDelay> {
  @override
  Future<AutoDeleteDelay> build() async {
    final store = ref.watch(autoDeleteDelayStoreProvider);
    return store.read();
  }

  Future<void> set(AutoDeleteDelay value) async {
    state = AsyncData(value);
    await ref.read(autoDeleteDelayStoreProvider).write(value);
  }
}

final autoDeleteDelayProvider =
    AsyncNotifierProvider<AutoDeleteDelayNotifier, AutoDeleteDelay>(
      AutoDeleteDelayNotifier.new,
    );

final autoDeleteWatchedServiceProvider = Provider<AutoDeleteWatchedService>((
  ref,
) {
  return AutoDeleteWatchedService(
    downloadStore: ref.watch(downloadStoreProvider),
    progressStore: ref.watch(animeProgressStoreProvider),
    downloadManager: ref.watch(downloadManagerProvider),
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

// ─── Per-tab status change streams ──────────────────────────────────────────

const _completedStatuses = {DownloadStatus.completed};
const _activeStatuses = {DownloadStatus.downloading, DownloadStatus.paused};
const _queueStatuses = {DownloadStatus.pending, DownloadStatus.failed};

/// Returns true when a status change is relevant to a given tab's status group.
bool _isRelevantToTab(DownloadStatusChange e, Set<DownloadStatus> tabStatuses) {
  // Global events (taskId empty or both statuses null) are always relevant.
  if (e.taskId.isEmpty) return true;
  if (e.oldStatus == null && e.newStatus == null) return true;
  // A task entering or leaving this tab's status group is relevant.
  if (e.oldStatus != null && tabStatuses.contains(e.oldStatus)) return true;
  if (e.newStatus != null && tabStatuses.contains(e.newStatus)) return true;
  return false;
}

/// Fires only when the completed tab's data may have changed.
final completedTabStatusChangeProvider =
    StreamProvider.autoDispose<DownloadStatusChange>((ref) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.statusChangeStream.where(
        (e) => _isRelevantToTab(e, _completedStatuses),
      );
    });

/// Fires only when the active (downloading/paused) tab's data may have changed.
final activeTabStatusChangeProvider =
    StreamProvider.autoDispose<DownloadStatusChange>((ref) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.statusChangeStream.where(
        (e) => _isRelevantToTab(e, _activeStatuses),
      );
    });

/// Fires only when the queue (pending/failed) tab's data may have changed.
final queueTabStatusChangeProvider =
    StreamProvider.autoDispose<DownloadStatusChange>((ref) {
      final manager = ref.watch(downloadManagerProvider);
      return manager.statusChangeStream.where(
        (e) => _isRelevantToTab(e, _queueStatuses),
      );
    });

// ─── Download list providers ─────────────────────────────────────────────────

/// All tasks — kept for settings page invalidation and backward compat.
/// The downloads page tabs use the per-tab providers below instead.
final allDownloadTasksProvider =
    FutureProvider.autoDispose<Result<List<DownloadTask>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(downloadStatusChangeStreamProvider);
      return ref.watch(downloadStoreProvider).getAllTasks();
    });

/// Completed tasks — only refreshes when the completed tab stream fires.
final completedDownloadTasksProvider =
    FutureProvider.autoDispose<Result<List<DownloadTask>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(completedTabStatusChangeProvider);
      return ref
          .watch(downloadStoreProvider)
          .getTasksByStatus(DownloadStatus.completed, ascending: false);
    });

/// Active tasks (downloading + paused) — only refreshes when the active tab
/// stream fires.
final activeDownloadTasksProvider =
    FutureProvider.autoDispose<Result<List<DownloadTask>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(activeTabStatusChangeProvider);
      return ref.watch(downloadStoreProvider).getTasksByStatuses([
        DownloadStatus.downloading,
        DownloadStatus.paused,
      ], ascending: false);
    });

/// Queued tasks (pending + failed) — only refreshes when the queue tab stream
/// fires.
final queuedDownloadTasksProvider =
    FutureProvider.autoDispose<Result<List<DownloadTask>, KumoriyaError>>((
      ref,
    ) async {
      ref.watch(queueTabStatusChangeProvider);
      return ref.watch(downloadStoreProvider).getTasksByStatuses([
        DownloadStatus.pending,
        DownloadStatus.failed,
      ], ascending: false);
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
  ref.watch(activeTabStatusChangeProvider);
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
  required DownloadServerScorer scorer,
}) {
  return ({
    required int anilistId,
    required double episodeNumber,
    required String? sourcePluginId,
    required String? serverName,
    required bool tryAlternativeServer,
    Set<String> triedServers = const <String>{},
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
      // Skip ALL servers already tried for this task (not just the original).
      // This prevents A→B→A cycling when multiple servers fail.
      // Pick the best-scored untried server.
      final untried = scorer.rankByScore(
        links.where((l) => !triedServers.contains(l.serverName)).toList(),
        (l) => l.serverName,
      );
      targetLink = untried.firstOrNull;
      // Fall back to skipping only the current server if all were tried.
      if (targetLink == null) {
        final fallback = scorer.rankByScore(
          links.where((l) => l.serverName != serverName).toList(),
          (l) => l.serverName,
        );
        targetLink = fallback.firstOrNull;
      }
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
