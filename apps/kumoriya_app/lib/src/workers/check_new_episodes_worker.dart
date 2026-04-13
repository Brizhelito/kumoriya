import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

/// Workmanager task name for periodic new-episode checks.
const kCheckNewEpisodesTask = 'kumoriya.check_new_episodes';
const kCheckNewEpisodesDebugProbeTask =
    'kumoriya.check_new_episodes.debug_probe';

/// Notification channel configuration.
const _channelId = 'kumoriya_new_episodes';
const _channelName = 'New Episodes';
const _channelDescription =
    'Notifies when a subscribed anime has a new episode';

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
    if (task != kCheckNewEpisodesTask &&
        task != kCheckNewEpisodesDebugProbeTask) {
      return true;
    }

    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (task == kCheckNewEpisodesDebugProbeTask) {
        await _runDebugProbe();
      } else {
        await _runCheckNewEpisodes();
      }
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

Future<void> scheduleDebugBackgroundNotificationProbe() async {
  await Workmanager().registerOneOffTask(
    kCheckNewEpisodesDebugProbeTask,
    kCheckNewEpisodesDebugProbeTask,
    initialDelay: const Duration(seconds: 5),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

// ---------------------------------------------------------------------------
// Core worker logic
// ---------------------------------------------------------------------------

Future<void> _runCheckNewEpisodes() async {
  final db = await openAppDatabase();
  final store = DriftLibraryStore(db);

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
  final subscribedIds = await store.getSubscribedAnimeIds().then(
    (result) =>
        result.fold(onSuccess: (value) => value, onFailure: (_) => <int>{}),
  );

  if (tracked.isEmpty) {
    await db.close();
    return;
  }

  final ids = tracked.keys.toList();
  final airingData = await _fetchAiringStatus(ids);

  if (airingData == null) {
    await db.close();
    return;
  }

  final notifications = FlutterLocalNotificationsPlugin();
  await _initNotifications(notifications);
  final warmupIds = <int>{};
  final pendingNotifications = <({int anilistId, String title, int episode})>[];
  final locale = Platform.localeName;

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
      warmupIds.add(anilistId);
      // First run: initialize silently — don't notify past episodes.
      await store.updateLastNotifiedEpisode(anilistId, latestAired);
      continue;
    }

    // Notify for any newly discovered aired episode. nextAiringEpisode points
    // to the future episode, so gating by its timestamp suppresses valid
    // notifications for the latest already-aired episode.
    if (latestAired > lastNotified) {
      warmupIds.add(anilistId);
      pendingNotifications.add((
        anilistId: anilistId,
        title: title,
        episode: latestAired,
      ));
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
  }

  for (final notification in pendingNotifications) {
    if (!subscribedIds.contains(notification.anilistId)) {
      await store.updateLastNotifiedEpisode(
        notification.anilistId,
        notification.episode,
      );
      continue;
    }
    await _sendNotification(
      notifications,
      id: notification.anilistId,
      animeTitle: notification.title,
      episodeNumber: notification.episode,
      locale: locale,
    );
    await store.updateLastNotifiedEpisode(
      notification.anilistId,
      notification.episode,
    );

    developer.log(
      'Notified episode ${notification.episode} for "${notification.title}" (id=${notification.anilistId})',
      name: 'CheckNewEpisodesWorker',
    );
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

// ---------------------------------------------------------------------------
// Notification helpers
// ---------------------------------------------------------------------------

Future<void> _initNotifications(FlutterLocalNotificationsPlugin plugin) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    settings: const InitializationSettings(android: android),
  );

  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    ),
  );
}

Future<void> _runDebugProbe() async {
  final notifications = FlutterLocalNotificationsPlugin();
  await _initNotifications(notifications);
  await _sendNotification(
    notifications,
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    animeTitle: 'Kumoriya Debug',
    episodeNumber: 0,
    bodyOverride:
        'Background worker activo: la notificacion de prueba se envio correctamente.',
  );
}

Future<void> _sendNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String animeTitle,
  required int episodeNumber,
  String? episodeTitle,
  String? bodyOverride,
  String? locale,
}) async {
  final body =
      bodyOverride ??
      _formatNotificationBody(
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
        locale: locale,
      );

  const androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );

  await plugin.show(
    id: id,
    title: animeTitle,
    body: body,
    notificationDetails: const NotificationDetails(android: androidDetails),
  );
}

String _formatNotificationBody({
  required int episodeNumber,
  String? episodeTitle,
  String? locale,
}) {
  final isSpanish = locale?.startsWith('es') ?? false;

  if (episodeTitle != null && episodeTitle.isNotEmpty) {
    return isSpanish
        ? 'Episodio $episodeNumber - $episodeTitle ya esta disponible'
        : 'Episode $episodeNumber - $episodeTitle is now available';
  }
  return isSpanish
      ? 'Episodio $episodeNumber ya esta disponible'
      : 'Episode $episodeNumber is now available';
}
