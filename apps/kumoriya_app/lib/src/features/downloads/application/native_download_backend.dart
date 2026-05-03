import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage_providers.dart';
import '../domain/download_backend.dart';
import 'download_directory_service.dart';
import 'download_library_index_service.dart';
import 'download_manager_service.dart';
import 'hls_remux_mode_notifier.dart';

/// Android-native download backend that delegates to the Kotlin
/// [DownloadEngine] via the new MethodChannel/EventChannel pair.
///
/// Replaces [NativeDownloadManagerService] — the old service uses the
/// legacy Media3 DownloadManager channels. This backend talks to the
/// new `dev.kumoriya.exoplayer/downloads` channels wired in Fase 2.
class NativeDownloadBackend implements DownloadBackend {
  static const _methodChannel = MethodChannel(
    'dev.kumoriya.exoplayer/downloads',
  );
  static const _eventChannel = EventChannel(
    'dev.kumoriya.exoplayer/downloads/events',
  );

  final Ref _ref;
  final DownloadDirectoryService _directoryService;
  final DownloadLibraryIndexService _libraryIndexService;
  StreamSubscription? _eventSubscription;

  final _progressController =
      StreamController<DownloadProgressEvent>.broadcast();
  final _statusController = StreamController<DownloadStatusChange>.broadcast();
  final _aggregateController =
      StreamController<DownloadAggregateProgress>.broadcast();

  NativeDownloadBackend(
    this._ref,
    this._directoryService,
    this._libraryIndexService,
  );

  // ── Streams ─────────────────────────────────────────────────────────

  @override
  Stream<DownloadProgressEvent> get progressStream =>
      _progressController.stream;

  @override
  Stream<DownloadStatusChange> get statusChangeStream =>
      _statusController.stream;

  @override
  Stream<DownloadAggregateProgress> get aggregateProgressStream =>
      _aggregateController.stream;

  // ── Lifecycle ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (error) {
        developer.log(
          'Native download event error: $error',
          name: 'NativeDownloadBackend',
        );
      },
    );
    await syncDownloadedLibrary();
    // Pull latest state from native BEFORE reconcile. While Flutter
    // was detached every `progress` and `status` event hit a null
    // EventSink.sink and was dropped. The native side cached the
    // last-known snapshot per task so we can replay it into Drift
    // here — this is the only path that surfaces tasks which
    // completed / failed / made progress entirely in the background.
    await _applyNativeSnapshots();
    // Reconcile: on a cold start (app was killed by the system / user
    // force-stopped / device rebooted) the native engine lost its
    // in-memory queue but Drift still has rows marked downloading /
    // pending / remuxing / disconnected. Re-enqueue those — the
    // downloaders resume from their on-disk manifest and pick up
    // where they left off. Runs AFTER snapshot apply so terminal
    // tasks are already updated and won't be spuriously re-enqueued.
    await _reconcileOnCold();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _progressController.close();
    _statusController.close();
    _aggregateController.close();
  }

  // ── Permissions ─────────────────────────────────────────────────────

  Future<void> _ensureNotificationPermission() async {
    if (_notificationPermissionChecked) return;
    _notificationPermissionChecked = true;
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (e, st) {
      developer.log(
        'notification permission request failed',
        name: 'NativeDownloadBackend',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Task lifecycle ──────────────────────────────────────────────────

  /// One-time flag — we only ask for POST_NOTIFICATIONS once per process.
  /// If the user denied, subsequent enqueues proceed without pestering
  /// them; the engine silently skips `notify()` when notifications are
  /// disabled. `true` until the first request resolves.
  bool _notificationPermissionChecked = false;

  @override
  Future<void> enqueue(DownloadTask task) async {
    final store = _ref.read(downloadStoreProvider);

    // Idempotent: skip if already present.
    final existing = await store.getTask(task.id);
    if (existing.fold(onSuccess: (t) => t, onFailure: (_) => null) != null) {
      return;
    }

    // Android 13+ requires runtime POST_NOTIFICATIONS permission before
    // the FGS can display progress. Request once; a denial is permanent
    // for this process — downloads continue silently.
    await _ensureNotificationPermission();

    await store.insertTask(task);

    // Notify UI immediately.
    _statusController.add(
      DownloadStatusChange(
        taskId: task.id,
        anilistId: task.anilistId,
        newStatus: task.status,
      ),
    );

    // Resolve target directory.
    final targetDir = await _directoryService.resolveDownloadsDirectory();

    // Snapshot the remux preference at enqueue time — changing the toggle
    // later shouldn't retroactively affect a task already scheduled with
    // the old setting. Reading the store directly (rather than awaiting
    // the Notifier) avoids a chicken-and-egg dependency on provider state.
    final remuxToMp4 = await _ref.read(hlsRemuxModeStoreProvider).read();

    await _methodChannel.invokeMethod('enqueue', {
      'taskId': task.id,
      'url': task.sourceUrl.toString(),
      'headers': task.headers,
      'fileName': task.fileName ?? task.id,
      'isHls': task.isHls,
      'targetDir': targetDir.path,
      'animeTitle': task.animeTitle ?? '',
      'serverName': task.serverName,
      'qualityLabel': task.qualityLabel,
      'remuxToMp4': remuxToMp4,
    });
  }

  @override
  Future<void> pause(String taskId) async {
    await _methodChannel.invokeMethod('pause', {'taskId': taskId});
  }

  @override
  Future<void> resume(String taskId) async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTask(taskId);
    final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task == null) return;

    final targetDir = await _directoryService.resolveDownloadsDirectory();

    await _methodChannel.invokeMethod('resume', {
      'taskId': task.id,
      'url': task.sourceUrl.toString(),
      'headers': task.headers,
      'fileName': task.fileName ?? task.id,
      'isHls': task.isHls,
      'targetDir': targetDir.path,
      'animeTitle': task.animeTitle ?? '',
      'serverName': task.serverName,
      'qualityLabel': task.qualityLabel,
    });
  }

  @override
  Future<void> cancel(String taskId) async {
    await _methodChannel.invokeMethod('cancel', {'taskId': taskId});
    await _deleteTask(taskId);
  }

  @override
  Future<void> cancelAll() async {
    await _methodChannel.invokeMethod('cancelAll');
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTasksByStatus(DownloadStatus.downloading);
    final tasks = result.fold(
      onSuccess: (t) => t,
      onFailure: (_) => <DownloadTask>[],
    );
    for (final task in tasks) {
      await _deleteTask(task.id);
    }
    _statusController.add(const DownloadStatusChange(taskId: ''));
  }

  @override
  Future<void> pauseAll() async {
    await _methodChannel.invokeMethod('pauseAll');
  }

  @override
  Future<void> resumeAll() async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTasksByStatus(DownloadStatus.paused);
    final tasks = result.fold(
      onSuccess: (t) => t,
      onFailure: (_) => <DownloadTask>[],
    );
    for (final task in tasks) {
      await resume(task.id);
    }
  }

  @override
  Future<void> retry(String taskId) async => resume(taskId);

  @override
  Future<void> retryAllFailed() async {
    final store = _ref.read(downloadStoreProvider);
    // `disconnected` is a soft-failure state — retry-all should sweep
    // both it and the hard `failed` state in one pass.
    final failedResult = await store.getTasksByStatus(DownloadStatus.failed);
    final disconnectedResult = await store.getTasksByStatus(
      DownloadStatus.disconnected,
    );
    final tasks = <DownloadTask>[
      ...failedResult.fold(onSuccess: (t) => t, onFailure: (_) => const []),
      ...disconnectedResult.fold(
        onSuccess: (t) => t,
        onFailure: (_) => const [],
      ),
    ];
    for (final task in tasks) {
      await store.updateTask(
        _copyTaskWith(task, status: DownloadStatus.pending, errorMessage: null),
      );
      await resume(task.id);
    }
    if (tasks.isNotEmpty) {
      _statusController.add(const DownloadStatusChange(taskId: ''));
    }
  }

  @override
  Future<void> clearQueue() async {
    final store = _ref.read(downloadStoreProvider);
    for (final status in [DownloadStatus.pending, DownloadStatus.failed]) {
      final result = await store.getTasksByStatus(status);
      final tasks = result.fold(
        onSuccess: (t) => t,
        onFailure: (_) => <DownloadTask>[],
      );
      for (final task in tasks) {
        await store.deleteTask(task.id);
      }
    }
    _statusController.add(const DownloadStatusChange(taskId: ''));
  }

  @override
  Future<void> deleteCompleted(String taskId) async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTask(taskId);
    final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task != null) {
      await _deleteFileArtifacts(task);
    }
    await store.deleteTask(taskId);
    _statusController.add(
      DownloadStatusChange(
        taskId: taskId,
        anilistId: task?.anilistId,
        oldStatus: task?.status,
      ),
    );
  }

  @override
  Future<DownloadTask?> findTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTaskByEpisode(anilistId, episodeNumber);
    return result.fold(onSuccess: (t) => t, onFailure: (_) => null);
  }

  @override
  Future<void> restoreQueue() async {
    await syncDownloadedLibrary();
    await _reconcileOnCold();
  }

  @override
  Future<void> syncDownloadedLibrary() async {
    final report = await _libraryIndexService.syncCurrentLibrary();
    if (report.changed) {
      _statusController.add(const DownloadStatusChange(taskId: ''));
    }
  }

  /// Pull the native engine's last-known snapshot per task and replay
  /// it into Drift. This is the reattach-reconcile path: while Flutter
  /// was detached every `progress`/`status` event hit a null EventSink
  /// and was dropped, so Drift holds state as of the last time Flutter
  /// was attached. On the native side an in-memory snapshot cache
  /// survives the detach because engine + sink live in the
  /// process-scope [DownloadCore].
  ///
  /// Terminal snapshots (completed / failed) are acknowledged via
  /// `forgetSnapshot` after applying so we don't loop-apply them on
  /// every subsequent reattach.
  Future<void> _applyNativeSnapshots() async {
    final raw = await _methodChannel.invokeMethod<List<dynamic>>('sync');
    if (raw == null || raw.isEmpty) return;

    final store = _ref.read(downloadStoreProvider);
    developer.log(
      'applying ${raw.length} native snapshot(s)',
      name: 'NativeDownloadBackend',
    );

    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final taskId = map['taskId'] as String?;
      if (taskId == null || taskId.isEmpty) continue;

      final status = _parseStatus(map['status'] as String? ?? '');
      final downloadedBytes = (map['downloadedBytes'] as num?)?.toInt();
      final totalBytes = (map['totalBytes'] as num?)?.toInt();
      final bytesPerSecond = (map['bytesPerSecond'] as num?)?.toInt() ?? 0;
      final filePath = map['filePath'] as String?;
      final errorMessage = map['errorMessage'] as String?;

      final existing = await store.getTask(taskId);
      final task = existing.fold(onSuccess: (t) => t, onFailure: (_) => null);
      if (task == null) {
        // Drift row already gone (typical for a cancel that landed
        // while Flutter was attached in a previous session). Still
        // acknowledge so the native tombstone / snapshot cache don't
        // keep replaying this id on every reattach.
        await _methodChannel.invokeMethod('forgetSnapshot', {'taskId': taskId});
        continue;
      }

      // Emit a progress event for UI livelines even if nothing changed
      // in Drift — the downloads tab pipes this straight into its
      // per-task progress provider.
      if (downloadedBytes != null && totalBytes != null) {
        _progressController.add(
          DownloadProgressEvent(
            taskId: taskId,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            bytesPerSecond: bytesPerSecond,
          ),
        );
      }

      final oldStatus = task.status;
      // Cancelled status on native side means "deleted" in Drift terms.
      if (map['status'] == 'cancelled') {
        await store.deleteTask(taskId);
        _statusController.add(
          DownloadStatusChange(
            taskId: taskId,
            anilistId: task.anilistId,
            oldStatus: oldStatus,
            newStatus: null,
          ),
        );
        await _methodChannel.invokeMethod('forgetSnapshot', {'taskId': taskId});
        continue;
      }

      await store.updateTask(
        _copyTaskWith(
          task,
          status: status,
          errorMessage: errorMessage,
          filePath: filePath,
          totalBytes: totalBytes,
          downloadedBytes: downloadedBytes,
        ),
      );
      await _writeManifestIfCompleted(taskId, status, filePath, totalBytes);

      if (status != null && status != oldStatus) {
        _statusController.add(
          DownloadStatusChange(
            taskId: taskId,
            anilistId: task.anilistId,
            oldStatus: oldStatus,
            newStatus: status,
          ),
        );
      }

      // Prune the native cache for terminal states — they won't emit
      // again and we don't want to re-apply them on the next reattach.
      final terminal =
          status == DownloadStatus.completed || status == DownloadStatus.failed;
      if (terminal) {
        await _methodChannel.invokeMethod('forgetSnapshot', {'taskId': taskId});
      }
    }
  }

  /// Re-enqueue Drift rows that were active before the process died so
  /// downloads continue after a cold start. Paused rows stay paused —
  /// the user explicitly stopped those and we don't override their
  /// intent. Completed / failed / cancelled are left alone.
  ///
  /// Idempotent against warm starts: the native engine guards
  /// `jobs[taskId]?.isActive == true` and skips duplicates, so calling
  /// this while the engine is already running is a safe no-op.
  Future<void> _reconcileOnCold() async {
    final store = _ref.read(downloadStoreProvider);
    final statuses = <DownloadStatus>[
      DownloadStatus.downloading,
      DownloadStatus.pending,
      DownloadStatus.remuxing,
      DownloadStatus.disconnected,
    ];
    final result = await store.getTasksByStatuses(statuses);
    final tasks = result.fold(
      onSuccess: (t) => t,
      onFailure: (_) => const <DownloadTask>[],
    );
    if (tasks.isEmpty) return;

    developer.log(
      'cold-start reconcile: ${tasks.length} task(s)',
      name: 'NativeDownloadBackend',
    );

    final targetDir = await _directoryService.resolveDownloadsDirectory();
    final remuxToMp4 = await _ref.read(hlsRemuxModeStoreProvider).read();

    for (final task in tasks) {
      try {
        await _methodChannel.invokeMethod('enqueue', {
          'taskId': task.id,
          'url': task.sourceUrl.toString(),
          'headers': task.headers,
          'fileName': task.fileName ?? task.id,
          'isHls': task.isHls,
          'targetDir': targetDir.path,
          'animeTitle': task.animeTitle ?? '',
          'serverName': task.serverName,
          'qualityLabel': task.qualityLabel,
          'remuxToMp4': remuxToMp4,
        });
      } catch (e, st) {
        developer.log(
          'cold-start enqueue failed for ${task.id}: $e',
          name: 'NativeDownloadBackend',
          error: e,
          stackTrace: st,
        );
      }
    }
    _statusController.add(const DownloadStatusChange(taskId: ''));
  }

  @override
  Future<void> setWifiOnly(bool enabled) async {
    await _methodChannel.invokeMethod('setWifiOnly', {'enabled': enabled});
  }

  // ── Native event handling ─────────────────────────────────────────────

  Future<void> _handleNativeEvent(dynamic event) async {
    if (event is! Map) return;
    final map = Map<String, dynamic>.from(event);
    final type = map['type'] as String?;
    final taskId = map['taskId'] as String? ?? '';

    switch (type) {
      case 'progress':
        _progressController.add(
          DownloadProgressEvent(
            taskId: taskId,
            downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
            totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
            bytesPerSecond: (map['bytesPerSecond'] as num?)?.toInt() ?? 0,
          ),
        );
        break;

      case 'status':
        final statusStr = map['status'] as String? ?? '';
        final newStatus = _parseStatus(statusStr);
        final errorMessage = map['errorMessage'] as String?;
        final errorCode = map['errorCode'] as String?;
        final filePath = map['filePath'] as String?;
        final totalBytes = (map['totalBytes'] as num?)?.toInt();

        if (errorCode != null) {
          developer.log(
            'Download [$taskId] errorCode=$errorCode msg=$errorMessage',
            name: 'NativeDownloadBackend',
          );
        }

        // Persist to Drift BEFORE broadcasting. UI providers (e.g. the
        // downloads tab list) re-query Drift on every status change —
        // broadcasting first races the async write and leaves the UI
        // stuck on the previous status (the classic paused-stays-paused
        // bug on resume).
        //
        // Capture oldStatus + anilistId from the pre-update row so the
        // per-tab filter in `download_providers.dart` can tell that e.g.
        // a `downloading → completed` transition is relevant to BOTH the
        // active and completed tabs. Without oldStatus the active tab
        // never re-queries Drift on completion and the row stays stuck
        // on "descargando" until a manual refresh.
        final (oldStatus, anilistId) = await _updateTaskInStore(
          taskId,
          newStatus,
          errorMessage,
          filePath,
          totalBytes,
        );
        await _writeManifestIfCompleted(
          taskId,
          newStatus,
          filePath,
          totalBytes,
        );
        _statusController.add(
          DownloadStatusChange(
            taskId: taskId,
            anilistId: anilistId,
            oldStatus: oldStatus,
            newStatus: newStatus,
          ),
        );
        break;

      case 'warning':
        developer.log(
          'Download warning [$taskId]: ${map['code']} — ${map['message']}',
          name: 'NativeDownloadBackend',
        );
        break;
    }
  }

  DownloadStatus? _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return DownloadStatus.pending;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'paused':
        return DownloadStatus.paused;
      case 'completed':
        return DownloadStatus.completed;
      case 'failed':
        return DownloadStatus.failed;
      case 'remuxing':
        return DownloadStatus.remuxing;
      case 'disconnected':
        return DownloadStatus.disconnected;
      case 'cancelled':
        return null; // Deletion
      default:
        return null;
    }
  }

  /// Returns `(oldStatus, anilistId)` captured from the row BEFORE the
  /// update, so the caller can broadcast a correctly-scoped status change.
  /// Both are null when the task doesn't exist in Drift (already deleted).
  Future<(DownloadStatus?, int?)> _updateTaskInStore(
    String taskId,
    DownloadStatus? newStatus,
    String? errorMessage,
    String? filePath,
    int? totalBytes,
  ) async {
    if (taskId.isEmpty) return (null, null);
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTask(taskId);
    final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task == null) return (null, null);

    final oldStatus = task.status;
    final anilistId = task.anilistId;

    if (newStatus == null) {
      // Cancelled — delete from store.
      await store.deleteTask(taskId);
      return (oldStatus, anilistId);
    }

    await store.updateTask(
      _copyTaskWith(
        task,
        status: newStatus,
        errorMessage: errorMessage,
        filePath: filePath,
        totalBytes: totalBytes,
        // On COMPLETED, downloaded == total so the UI shows 100%.
        downloadedBytes: newStatus == DownloadStatus.completed
            ? totalBytes
            : null,
      ),
    );
    return (oldStatus, anilistId);
  }

  Future<void> _writeManifestIfCompleted(
    String taskId,
    DownloadStatus? status,
    String? filePath,
    int? totalBytes,
  ) async {
    if (status != DownloadStatus.completed ||
        taskId.isEmpty ||
        filePath == null ||
        filePath.isEmpty) {
      return;
    }
    final mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      return;
    }
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTask(taskId);
    final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task == null) {
      return;
    }
    await _libraryIndexService.writeManifest(
      task: task,
      mediaPath: mediaFile.path,
      totalBytes: totalBytes ?? await mediaFile.length(),
    );
  }

  /// [DownloadTask] is immutable with no `copyWith`; reconstruct manually.
  DownloadTask _copyTaskWith(
    DownloadTask task, {
    DownloadStatus? status,
    String? filePath,
    String? errorMessage,
    int? totalBytes,
    int? downloadedBytes,
  }) {
    return DownloadTask(
      id: task.id,
      anilistId: task.anilistId,
      episodeNumber: task.episodeNumber,
      sourceUrl: task.sourceUrl,
      status: status ?? task.status,
      createdAt: task.createdAt,
      fileName: task.fileName,
      filePath: filePath ?? task.filePath,
      totalBytes: totalBytes ?? task.totalBytes,
      downloadedBytes: downloadedBytes ?? task.downloadedBytes,
      sourcePluginId: task.sourcePluginId,
      serverName: task.serverName,
      detectedHost: task.detectedHost,
      errorMessage: errorMessage ?? task.errorMessage,
      updatedAt: task.updatedAt,
      headers: task.headers,
      isHls: task.isHls,
      animeTitle: task.animeTitle,
      qualityLabel: task.qualityLabel,
      episodeTitle: task.episodeTitle,
    );
  }

  Future<void> _deleteTask(String taskId) async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTask(taskId);
    final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
    // Kotlin already deletes .partial / final artifacts for any task it
    // still has params for. This is the Dart fallback — covers tasks
    // cancelled after an app restart (Kotlin map is empty) and any
    // filePath persisted in Drift from a prior completion.
    if (task != null) {
      await _deleteFileArtifacts(task);
    }
    await store.deleteTask(taskId);
    _statusController.add(
      DownloadStatusChange(
        taskId: taskId,
        anilistId: task?.anilistId,
        oldStatus: task?.status,
      ),
    );
  }

  /// Best-effort removal of on-disk artifacts for [task]. Safe to call
  /// multiple times and on tasks whose files never materialized.
  Future<void> _deleteFileArtifacts(DownloadTask task) async {
    final filePath = task.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        developer.log(
          'deleteFileArtifacts: failed to delete $filePath: $e',
          name: 'NativeDownloadBackend',
        );
      }
      // Also sweep the .partial sibling and the parallel-download
      // chunk manifest if any lingered from an earlier run.
      for (final suffix in const [
        '.partial',
        '.chunks.json',
        '.chunks.json.tmp',
        downloadSidecarSuffix,
      ]) {
        try {
          final f = File('$filePath$suffix');
          if (await f.exists()) await f.delete();
        } catch (_) {
          /* ignore */
        }
      }
    }
  }
}
