import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
  static void initialize() {
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

  /// Stop the foreground service and release the wake/wifi locks.
  /// Idempotent — calling while not running is a no-op.
  Future<void> stop() async {
    if (!Platform.isAndroid || !_running) return;
    _running = false;
    await FlutterForegroundTask.stopService();
  }
}
