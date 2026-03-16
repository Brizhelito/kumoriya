import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';

import 'src/app/kumoriya_app.dart';
import 'src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'src/workers/check_new_episodes_worker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final db = await openAppDatabase();

  // Initialize local notifications (creates the Android channel).
  if (Platform.isAndroid) {
    await _initNotifications();
    await _initWorkmanager();
  }

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const KumoriyaApp(),
    ),
  );
}

Future<void> _initNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));

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
  await Workmanager().initialize(
    checkNewEpisodesCallbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    kCheckNewEpisodesTask,
    kCheckNewEpisodesTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}
