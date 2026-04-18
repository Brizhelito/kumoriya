import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../features/anime_catalog/application/matching/anilist_source_matcher.dart';
import '../features/anime_catalog/application/use_cases/get_source_episode_server_links_use_case.dart';
import '../features/anime_catalog/application/services/background_source_availability_warmup_service.dart';
import '../features/anime_catalog/application/services/mal_metadata_bridge_service.dart';
import '../features/anime_catalog/application/services/plugin_runtime_catalog.dart';
import '../features/anime_catalog/application/services/resolver_registry.dart';
import '../features/anime_catalog/application/services/source_availability_cache_codec.dart';
import '../features/anime_catalog/application/services/source_selection_policy.dart';
import '../features/anime_catalog/application/use_cases/anime_catalog_use_cases.dart';
import '../features/anime_catalog/application/use_cases/get_source_availability_summary_use_case.dart';
import '../features/anime_catalog/application/use_cases/load_source_availability_summary_use_case.dart';
import '../features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import '../features/downloads/application/auto_download_new_episodes_service.dart';
import '../features/downloads/application/download_aniskip_file_store.dart';
import '../features/downloads/application/download_directory_service.dart';
import '../features/downloads/application/download_library_index_service.dart';
import '../features/downloads/application/download_manager_service.dart';
import '../features/downloads/application/enqueue_download_use_case.dart';
import '../app/runtime_config.dart';

/// Workmanager task name for the periodic auto-download-of-new-episodes
/// worker.
///
/// **Scope (post-FCM migration, Slice 6):**
///
/// User-facing episode notifications now come from the Kumoriya Go
/// backend via Firebase Cloud Messaging (see `AiringWorker` +
/// `FcmSender`), so this worker no longer shows local notifications.
///
/// What it still does: for each anime with
/// `auto_download_new_episodes=true`, detect newly-aired episodes by
/// comparing `nextAiringEpisode.episode - 1` to `lastNotifiedEpisode`,
/// warm up source-availability cache, and enqueue downloads via
/// [AutoDownloadNewEpisodesService].
///
/// It runs on a **4-hour cadence** (down from 1h) because the source
/// sites typically upload episodes 30 min – 24 h after the AniList
/// airing timestamp; a tighter cadence wastes scraping budget and
/// hits rate limits. FCM push gives the user near-instant
/// notification; auto-download tolerates the 0–4 h latency.
///
/// Only anime that have `auto_download_new_episodes=true` are fetched
/// from AniList and scraped from sources, so idle users produce zero
/// traffic to third-party sites.
const kCheckNewEpisodesTask = 'kumoriya.check_new_episodes';

const _batchAiringStatusQuery = r'''
query BatchAiringStatus($ids: [Int]) {
  Page(perPage: 50) {
    media(id_in: $ids, type: ANIME) {
      id
      title {
        romaji
        english
      }
      nextAiringEpisode {
        episode
        airingAt
      }
    }
  }
}
''';

// ---------------------------------------------------------------------------
// Callback dispatcher — runs in a separate isolate; must be a top-level fn.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
void checkNewEpisodesCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kCheckNewEpisodesTask) {
      return true;
    }

    WidgetsFlutterBinding.ensureInitialized();

    try {
      await _runCheckNewEpisodes();
    } catch (e, st) {
      developer.log(
        'CheckNewEpisodesWorker unhandled error: $e',
        name: 'CheckNewEpisodesWorker',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  });
}

// ---------------------------------------------------------------------------
// Core worker logic
// ---------------------------------------------------------------------------

Future<void> _runCheckNewEpisodes() async {
  final db = await openAppDatabase();
  final store = DriftLibraryStore(db);

  // Only series the user asked to auto-download. Everything else
  // produces zero network traffic — including zero AniList calls
  // and zero source-site scraping.
  final autoDownloadResult = await store.getAutoDownloadAnimeIds();
  final autoDownloadIds = autoDownloadResult.fold<Set<int>>(
    onSuccess: (ids) => ids,
    onFailure: (_) => const <int>{},
  );
  if (autoDownloadIds.isEmpty) {
    await db.close();
    return;
  }

  final trackedResult = await store.getTrackedAnimeWithLastEpisode();
  if (trackedResult is! Success) {
    developer.log(
      'getTrackedAnimeWithLastEpisode failed',
      name: 'CheckNewEpisodesWorker',
    );
    await db.close();
    return;
  }
  final tracked = (trackedResult as Success<Map<int, int?>, dynamic>).value;

  // Intersect: only anime that are both tracked and auto-download enabled.
  final ids = tracked.keys.where(autoDownloadIds.contains).toList();
  if (ids.isEmpty) {
    await db.close();
    return;
  }

  final airingData = await _fetchAiringStatus(ids);
  if (airingData == null) {
    await db.close();
    return;
  }

  final warmupIds = <int>{};

  final sourcePlugins = buildDefaultSourcePlugins();
  http.Client? resolverClient;
  if (Platform.isAndroid) {
    try {
      resolverClient = CronetClient.fromCronetEngine(
        CronetEngine.build(cacheMode: CacheMode.disabled),
        closeEngine: true,
      );
    } catch (_) {
      // Fall through to default http.Client in buildDefaultResolverPlugins.
    }
  }
  final resolverPlugins = buildDefaultResolverPlugins(
    httpClient: resolverClient,
  );
  final selectionPolicy = const SourceSelectionPolicy();
  final resolverRegistry = ResolverRegistry(resolvers: resolverPlugins);
  final sourceAvailabilityStore = DriftSourceAvailabilityStore(db);
  final sourceAvailabilityCacheCodec = SourceAvailabilityCacheCodec(
    sourcePlugins: sourcePlugins,
    selectionPolicy: selectionPolicy,
  );
  final repository = AnilistAnimeCatalogRepository(
    gateway: GraphqlAnilistMetadataGateway(
      client: HttpAnilistGraphqlClient(
        config: KumoriyaRuntimeConfig.anilistClient,
      ),
    ),
  );
  final warmupService = BackgroundSourceAvailabilityWarmupService(
    loadAnimeDetail: (anilistId) =>
        GetAnimeDetailUseCase(repository).call(anilistId),
    loadSourceAvailability: LoadSourceAvailabilitySummaryUseCase(
      store: sourceAvailabilityStore,
      computeUseCase: GetSourceAvailabilitySummaryUseCase(
        sourcePlugins: sourcePlugins,
        matcher: const AnilistSourceMatcher(),
        selectionPolicy: selectionPolicy,
        registry: resolverRegistry,
      ),
      sourcePlugins: sourcePlugins,
      cacheCodec: sourceAvailabilityCacheCodec,
    ),
  );
  final downloadStore = DriftDownloadStore(db);
  final downloadDirectoryService = DownloadDirectoryService(
    store: FileDownloadDirectoryStore(),
  );
  final aniSkipCacheStore = DownloadAniSkipFileStore(
    directoryService: downloadDirectoryService,
  );
  final malMetadataBridge = MalMetadataBridgeService(
    aniSkipCacheStore: aniSkipCacheStore,
  );
  final downloadManager = DownloadManagerService(
    store: downloadStore,
    directoryService: downloadDirectoryService,
    httpClient: resolverClient,
    libraryIndexService: DownloadLibraryIndexService(
      store: downloadStore,
      directoryService: downloadDirectoryService,
    ),
  );
  final enqueueDownloadUseCase = EnqueueDownloadUseCase(
    downloadManager: downloadManager,
    resolveUseCase: ResolveSourceServerLinkUseCase(registry: resolverRegistry),
  );
  final autoDownloadService = AutoDownloadNewEpisodesService(
    libraryStore: store,
    downloadStore: downloadStore,
    sourceAvailabilityStore: sourceAvailabilityStore,
    sourceAvailabilityCacheCodec: sourceAvailabilityCacheCodec,
    sourcePlugins: sourcePlugins,
    loadServerLinks:
        ({
          required SourcePlugin sourcePlugin,
          required SourceEpisode sourceEpisode,
        }) {
          return GetSourceEpisodeServerLinksUseCase(
            sourcePlugin: sourcePlugin,
            registry: resolverRegistry,
          ).call(sourceEpisode);
        },
    enqueueDownload:
        ({
          required int anilistId,
          required double episodeNumber,
          required SourceServerLink serverLink,
          required String sourcePluginId,
          String? animeTitle,
          String? coverImageUrl,
          String? episodeTitle,
        }) {
          return enqueueDownloadUseCase.call(
            anilistId: anilistId,
            episodeNumber: episodeNumber,
            serverLink: serverLink,
            sourcePluginId: sourcePluginId,
            animeTitle: animeTitle,
            coverImageUrl: coverImageUrl,
            episodeTitle: episodeTitle,
          );
        },
    prefetchAniSkip: ({required int anilistId, required int episodeNumber}) {
      return malMetadataBridge.getAniSkipSegments(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: 1440,
      );
    },
  );

  // Entries pending auto-download after warmup completes.
  final autoDownloadEntries =
      <({int anilistId, String title, int from, int to})>[];

  for (final entry in airingData.entries) {
    final anilistId = entry.key;
    final title = entry.value['title'] as String;
    final nextEpisode = entry.value['nextEpisode'] as int?;

    if (nextEpisode == null) continue;

    // Episode that just aired = nextAiringEpisode.episode - 1
    final latestAired = nextEpisode - 1;
    if (latestAired <= 0) continue;

    final lastNotified = tracked[anilistId];

    if (lastNotified == null) {
      // First run for this series: mark current episode as baseline
      // so we never retro-download past episodes.
      warmupIds.add(anilistId);
      await store.updateLastNotifiedEpisode(anilistId, latestAired);
      continue;
    }

    if (latestAired > lastNotified) {
      warmupIds.add(anilistId);
      autoDownloadEntries.add((
        anilistId: anilistId,
        title: title,
        from: lastNotified + 1,
        to: latestAired,
      ));
    }
  }

  if (warmupIds.isNotEmpty) {
    await warmupService.warmUp(warmupIds);
  }

  for (final ad in autoDownloadEntries) {
    final report = await autoDownloadService.enqueueEpisodes(
      anilistId: ad.anilistId,
      episodeNumbers: <int>[
        for (var episode = ad.from; episode <= ad.to; episode++) episode,
      ],
      animeTitle: ad.title,
    );
    if (report.enqueuedEpisodes > 0) {
      developer.log(
        'Auto-downloaded ${report.enqueuedEpisodes} episode(s) for "${ad.title}" (id=${ad.anilistId})',
        name: 'CheckNewEpisodesWorker',
      );
    }
    // Mark as processed regardless of enqueue outcome: if the source
    // isn't available yet, the next 4-hour pass will retry naturally
    // only if latestAired advances further; otherwise we skip so we
    // don't hammer the source. `updateLastNotifiedEpisode` is updated
    // only on successful enqueue to allow retries on source lag.
    if (report.enqueuedEpisodes > 0) {
      await store.updateLastNotifiedEpisode(ad.anilistId, ad.to);
    }
  }

  downloadManager.dispose();
  malMetadataBridge.dispose();
  await db.close();
}

// ---------------------------------------------------------------------------
// AniList batch fetch
// ---------------------------------------------------------------------------

Future<Map<int, Map<String, dynamic>>?> _fetchAiringStatus(
  List<int> ids,
) async {
  try {
    final response = await http
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'query': _batchAiringStatusQuery,
            'variables': {'ids': ids},
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      developer.log(
        'AniList batch airing status returned ${response.statusCode}',
        name: 'CheckNewEpisodesWorker',
      );
      return null;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;

    final mediaList =
        (decoded['data']?['Page']?['media'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    final result = <int, Map<String, dynamic>>{};
    for (final media in mediaList) {
      final id = media['id'] as int?;
      if (id == null) continue;

      final titleMap = media['title'] as Map<String, dynamic>?;
      final title =
          (titleMap?['english'] as String?) ??
          (titleMap?['romaji'] as String?) ??
          'Unknown Anime';

      final next = media['nextAiringEpisode'] as Map<String, dynamic>?;
      final nextEp = next?['episode'] as int?;
      final airingAtSec = next?['airingAt'] as int?;
      final airingAt = airingAtSec != null
          ? DateTime.fromMillisecondsSinceEpoch(airingAtSec * 1000)
          : null;

      result[id] = {
        'title': title,
        'nextEpisode': nextEp,
        'airingAt': airingAt,
      };
    }

    return result;
  } catch (e) {
    developer.log(
      'fetchAiringStatus error: $e',
      name: 'CheckNewEpisodesWorker',
    );
    return null;
  }
}
