import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/kumoriya_app.dart';
import 'src/features/downloads/application/download_foreground_service.dart';
import 'src/features/downloads/presentation/download_providers.dart';
import 'src/shared/storage_providers.dart';
import 'src/workers/check_new_episodes_worker.dart';

void main() async {
  final startupWatch = Stopwatch()..start();

  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  MediaKit.ensureInitialized();

  // Open DB and platform-specific init in parallel — both are independent.
  late final AppDatabase db;
  if (Platform.isAndroid) {
    DownloadForegroundService.initialize();
    final results = await (
      openAppDatabase(),
      _initNotifications(),
      _initWorkmanager(),
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

  // Purge stale cache entries (fire-and-forget, non-blocking).
  unawaited(_purgeExpiredCaches(container));

  runApp(
    UncontrolledProviderScope(container: container, child: const KumoriyaApp()),
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

    await Future.wait(<Future<void>>[
      sourceStore.deleteOlderThan(const Duration(days: 7)),
    ]);
  } catch (_) {
    // Best-effort cleanup; failures are non-critical.
  }
}
