import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/kumoriya_app.dart';
import 'src/config/app_config.dart';
import 'src/features/downloads/application/auto_delete_watched_service.dart';
import 'src/features/downloads/application/download_foreground_service.dart';
import 'src/features/downloads/presentation/download_providers.dart';
import 'src/features/watch_party/infrastructure/party_debug_logger.dart';
import 'src/shared/notifications/fcm_providers.dart';
import 'src/shared/notifications/fcm_service.dart';
import 'src/shared/storage_providers.dart';
import 'src/workers/check_new_episodes_worker.dart';

Future<void> main() async {
  await SentryFlutter.init((options) {
    options.dsn = AppConfig.sentryDsn;
    options.environment = AppConfig.sentryEnvironment;
    options.release = AppConfig.sentryRelease;

    // Performance: sample 20% of transactions.
    options.tracesSampleRate = 0.2;
    options.enableAutoPerformanceTracing = true;

    // Attachments: capture screenshot and view hierarchy on errors.
    options.attachScreenshot = true;
    options.screenshotQuality = SentryScreenshotQuality.medium;
    // ignore: experimental_member_use
    options.attachViewHierarchy = true;

    // Session Replay: capture all error replays, 10% of normal sessions.
    options.replay.sessionSampleRate = 0.1;
    options.replay.onErrorSampleRate = 1.0;

    // ANR detection (Android).
    options.anrEnabled = true;
    options.anrTimeoutInterval = const Duration(seconds: 5);

    // Breadcrumbs: increase cap for richer context.
    options.maxBreadcrumbs = 150;

    // Drop known media_kit disposal race-condition assertion errors.
    options.beforeSend = (event, hint) {
      final exceptions = event.exceptions;
      if (exceptions != null && exceptions.isNotEmpty) {
        final value = exceptions.first.value ?? '';
        if (value.contains('[Player] has been disposed')) {
          return null; // drop — known media_kit race, not actionable
        }
        if (value.contains('Resolver failure: resolver.') ||
            value.contains('Download resolve failure: resolver.') ||
            value.contains('resolver.no_resolver') ||
            value.contains('resolver.empty') ||
            value.contains('download.no_streams')) {
          // Expected "no resolvable stream" paths should not create Sentry issues.
          return null;
        }
      }
      return event;
    };
  }, appRunner: _appMain);
}

Future<void> _appMain() async {
  final startupWatch = Stopwatch()..start();

  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  MediaKit.ensureInitialized();

  // Open DB and platform-specific init in parallel — both are independent.
  // Firebase must initialise BEFORE we register the background FCM handler;
  // kept sequential (fast: single native call reading google-services.json).
  late final AppDatabase db;
  late final FcmService? fcmService;
  if (Platform.isAndroid) {
    await _initFirebase();
    final results = await (
      openAppDatabase(),
      _initNotifications(),
      _initWorkmanager(),
      DownloadForegroundService.initialize(),
      _initFcm(),
    ).wait;
    db = results.$1;
    fcmService = results.$5;

    // When FCM is up, the airing-episode pushes come from the API's
    // FCM worker. Cancel the legacy Workmanager poller to avoid
    // double-notifications. The worker file itself is removed in
    // Slice 6 once FCM is proven stable on device.
    if (fcmService != null) {
      unawaited(
        Workmanager().cancelByUniqueName(kCheckNewEpisodesTask).catchError((
          Object err,
        ) {
          if (kDebugMode) {
            debugPrint('[Startup] cancel legacy worker failed: $err');
          }
        }),
      );
    }
  } else {
    db = await openAppDatabase();
    fcmService = null;
  }

  if (kDebugMode) {
    debugPrint('[Startup] DB ready in ${startupWatch.elapsedMilliseconds}ms');
  }

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (fcmService != null) fcmServiceProvider.overrideWithValue(fcmService),
    ],
  );

  // Restore pending downloads after the first frame to avoid blocking paint.
  Future.microtask(
    () => container.read(downloadManagerProvider).restoreQueue(),
  );

  // Run auto-delete cleanup for watched downloads (fire-and-forget).
  unawaited(
    Future.microtask(() async {
      final store = container.read(autoDeleteDelayStoreProvider);
      final delay = await store.read();
      if (delay != AutoDeleteDelay.never) {
        await container.read(autoDeleteWatchedServiceProvider).run(delay);
      }
    }),
  );

  // Purge stale cache entries (fire-and-forget, non-blocking).
  unawaited(_purgeExpiredCaches(container));

  // Initialize party debug logger (non-blocking).
  unawaited(PartyDebugLogger.initialize());

  runApp(
    SentryWidget(
      child: UncontrolledProviderScope(
        container: container,
        child: const KumoriyaApp(),
      ),
    ),
  );

  if (kDebugMode) {
    debugPrint('[Startup] runApp in ${startupWatch.elapsedMilliseconds}ms');
  }
}

/// Boots Firebase on Android before any Firebase API is used. On Android
/// `Firebase.initializeApp()` with no options picks up the configuration
/// from `android/app/google-services.json` via the google-services
/// Gradle plugin — no generated `firebase_options.dart` is required.
///
/// Registers the background FCM handler while the main isolate is still
/// active; this is safe even though the actual handler runs on a
/// separate isolate when a push is delivered with the app backgrounded.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(kumoriyaFcmBackgroundHandler);
  } catch (err, st) {
    // Never block app boot on a Firebase failure. The app continues to
    // work without notifications; Sentry captures the failure for
    // diagnosis.
    debugPrint('[Startup] Firebase init failed: $err');
    unawaited(Sentry.captureException(err, stackTrace: st));
  }
}

/// Boots the domain-level FCM wrapper. Must run after `_initFirebase`.
/// Returns `null` if initialisation fails so downstream code can treat
/// notifications as an optional capability instead of a hard dependency.
Future<FcmService?> _initFcm() async {
  try {
    final service = FcmService();
    await service.initialize();
    return service;
  } catch (err, st) {
    debugPrint('[Startup] FCM init failed: $err');
    unawaited(Sentry.captureException(err, stackTrace: st));
    return null;
  }
}

Future<void> _initNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@drawable/ic_stat_download');
  await plugin.initialize(
    settings: const InitializationSettings(android: android),
  );

  // Create the notification channel explicitly so it exists before any worker fires.
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'kumoriya_new_episodes',
      'New Episodes',
      description: 'Notifies when a subscribed anime has a new episode',
      importance: Importance.defaultImportance,
    ),
  );
}

Future<void> _initWorkmanager() async {
  await Workmanager().initialize(checkNewEpisodesCallbackDispatcher);

  await Workmanager().registerPeriodicTask(
    kCheckNewEpisodesTask,
    kCheckNewEpisodesTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

Future<void> _purgeExpiredCaches(ProviderContainer container) async {
  try {
    final sourceStore = container.read(sourceAvailabilityStoreProvider);
    final anilistStore = container.read(anilistCacheStoreProvider);
    final aniskipStore = container.read(aniSkipCacheStoreProvider);
    final translationStore = container.read(translationCacheStoreProvider);

    await Future.wait(<Future<void>>[
      sourceStore.deleteOlderThan(const Duration(days: 7)),
      anilistStore.deleteOlderThan(const Duration(days: 30)),
      aniskipStore.deleteOlderThan(const Duration(days: 14)),
      translationStore.deleteOlderThan(const Duration(days: 30)),
    ]);
  } catch (_) {
    // Best-effort cleanup; failures are non-critical.
  }
}
