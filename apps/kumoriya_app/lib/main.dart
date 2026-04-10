import 'dart:async';
import 'dart:io';

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
  late final AppDatabase db;
  if (Platform.isAndroid) {
    final results = await (
      openAppDatabase(),
      _initNotifications(),
      _initWorkmanager(),
      DownloadForegroundService.initialize(),
    ).wait;
    db = results.$1;
  } else {
    db = await openAppDatabase();
  }

  if (kDebugMode) {
    debugPrint('[Startup] DB ready in ${startupWatch.elapsedMilliseconds}ms');
  }

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
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

Future<void> _initNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
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
