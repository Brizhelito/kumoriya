import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channel / ID for completion notifications.
const _completionChannelId = 'kumoriya_download_complete';
const _completionChannelName = 'Download Complete';
const _completionChannelDescription = 'Notifies when episode downloads finish';
const _completionNotificationId = 9001;

/// Manages an Android foreground service that keeps the app alive and shows a
/// persistent notification while downloads are active.
///
/// On non-Android platforms all methods are no-ops.
///
/// The service automatically acquires a CPU wake lock and WiFi lock so the
/// device won't sleep mid-download.
class DownloadForegroundService {
  bool _running = false;

  /// Whether the foreground service is currently active.
  bool get isRunning => _running;

  /// One-time initialization. Call from `main()` on Android before any
  /// download can start. Safe to call on other platforms (no-op).
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kumoriya_downloads',
        channelName: 'Downloads',
        channelDescription: 'Shows progress while downloading episodes',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Create a separate high-importance channel for completion notifications.
    final plugin = FlutterLocalNotificationsPlugin();
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _completionChannelId,
        _completionChannelName,
        description: _completionChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  /// Start the foreground service with a "Downloading…" notification.
  /// Idempotent — calling while already running is a no-op.
  Future<void> start() async {
    if (!Platform.isAndroid || _running) return;

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'Kumoriya',
      notificationText: 'Preparing downloads…',
    );
    _running = result is ServiceRequestSuccess;
  }

  /// Update the notification text with current progress.
  Future<void> updateProgress({
    required int activeTasks,
    required int bytesPerSecond,
    int completedTasks = 0,
    int totalTasks = 0,
  }) async {
    if (!Platform.isAndroid || !_running) return;

    final speedMb = (bytesPerSecond / (1024 * 1024)).toStringAsFixed(1);

    final progressLabel = totalTasks > 0
        ? ' ($completedTasks/$totalTasks)'
        : '';

    final text = activeTasks == 1
        ? 'Downloading$progressLabel — $speedMb MB/s'
        : 'Downloading $activeTasks episodes$progressLabel — $speedMb MB/s';

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Kumoriya',
      notificationText: text,
    );
  }

  /// Show a completion notification after the foreground service stops.
  /// [completedCount] is how many episodes finished in this session.
  /// [failedCount] is how many failed.
  Future<void> showCompletionNotification({
    required int completedCount,
    int failedCount = 0,
  }) async {
    if (!Platform.isAndroid) return;
    if (completedCount <= 0 && failedCount <= 0) return;

    final plugin = FlutterLocalNotificationsPlugin();

    String title;
    String body;

    if (failedCount > 0 && completedCount > 0) {
      title = 'Downloads finished';
      body = '$completedCount episodes downloaded, $failedCount failed';
    } else if (failedCount > 0) {
      title = 'Downloads failed';
      body = '$failedCount episode downloads failed';
    } else if (completedCount == 1) {
      title = 'Download complete';
      body = '1 episode downloaded';
    } else {
      title = 'Downloads complete';
      body = '$completedCount episodes downloaded';
    }

    await plugin.show(
      id: _completionNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _completionChannelId,
          _completionChannelName,
          channelDescription: _completionChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
    );
  }

  /// Stop the foreground service and release the wake/wifi locks.
  /// Idempotent — calling while not running is a no-op.
  Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    _running = false;
    await FlutterForegroundTask.stopService();
  }
}
