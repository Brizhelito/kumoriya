import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage_providers.dart';
import '../domain/download_backend.dart';
import 'download_manager_service.dart';

/// Android-native download manager that delegates to Media3 DownloadManager.
///
/// Uses MethodChannel for commands and EventChannel for progress/events.
/// Replaces DownloadManagerService on Android platforms.
class NativeDownloadManagerService implements DownloadBackend {
  static const MethodChannel _channel = MethodChannel(
    'dev.kumoriya.exoplayer/downloads',
  );
  static const EventChannel _progressChannel = EventChannel(
    'dev.kumoriya.exoplayer/downloads/progress',
  );

  final Ref _ref;
  StreamSubscription? _progressSubscription;
  final _progressController = StreamController<DownloadProgressEvent>.broadcast();
  final _statusController = StreamController<DownloadStatusChange>.broadcast();

  NativeDownloadManagerService(this._ref);

  @override
  Stream<DownloadProgressEvent> get progressStream => _progressController.stream;

  /// Kept for backward-compat with callers that reference the old name.
  Stream<DownloadStatusChange> get statusStream => _statusController.stream;

  @override
  Stream<DownloadStatusChange> get statusChangeStream =>
      _statusController.stream;

  @override
  Stream<DownloadAggregateProgress> get aggregateProgressStream =>
      const Stream.empty();

  /// Initialize and listen to native events
  Future<void> initialize() async {
    _progressSubscription = _progressChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (error) {
        developer.log('Native download event error: $error', name: 'NativeDownload');
        _progressController.addError(error);
      },
    );

    // Sync state on initialization to catch any missed events
    await syncDownloadedLibrary();
  }

  /// Enqueue a download: persists to Drift first, then delegates to native.
  ///
  /// Mirrors [DownloadManagerService.enqueue] so the UI reacts immediately
  /// via [statusStream] and all task-list providers rebuild correctly.
  @override
  Future<void> enqueue(DownloadTask task) async {
    final store = _ref.read(downloadStoreProvider);

    // Idempotent: skip if already present (duplicate guard).
    final existing = await store.getTask(task.id);
    if (existing.fold(onSuccess: (t) => t, onFailure: (_) => null) != null) {
      return;
    }

    await store.insertTask(task);

    // Notify UI immediately so the queue tab shows the new task.
    _statusController.add(DownloadStatusChange(
      taskId: task.id,
      anilistId: task.anilistId,
      newStatus: task.status,
    ));

    await _enqueueNative(
      taskId: task.id,
      streamUrl: task.sourceUrl.toString(),
      headers: task.headers,
      fileName: task.fileName ?? task.id,
      isHls: task.isHls,
    );
  }

  /// Low-level call to the native MethodChannel. Use [enqueue] instead.
  Future<void> _enqueueNative({
    required String taskId,
    required String streamUrl,
    required Map<String, String> headers,
    required String fileName,
    bool isHls = false,
  }) async {
    // Headers encoded as JSON in URI query param (native expects this format)
    final uri = Uri.parse(streamUrl);
    final headersJson = jsonEncode(headers);
    final uriWithHeaders = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        '_kumoriya_headers': headersJson,
      },
    );

    await _channel.invokeMethod('enqueueDownload', {
      'taskId': taskId,
      'url': uriWithHeaders.toString(),
      'fileName': fileName,
      'isHls': isHls,
    });
  }

  /// Enqueue a download in the native downloader (legacy — use [enqueue]).
  ///
  /// Does NOT persist to Drift. Kept for backward compatibility with any
  /// callers that manage persistence themselves.
  @Deprecated('Use enqueue(DownloadTask) instead — it persists to Drift first.')
  Future<void> enqueueDownload({
    required String taskId,
    required String streamUrl,
    required Map<String, String> headers,
    required String fileName,
    bool isHls = false,
  }) async {
    await _enqueueNative(
      taskId: taskId,
      streamUrl: streamUrl,
      headers: headers,
      fileName: fileName,
      isHls: isHls,
    );
  }

  @override
  Future<void> pause(String taskId) async => pauseDownload(taskId);

  /// Pause a specific download
  Future<void> pauseDownload(String taskId) async {
    await _channel.invokeMethod('pauseDownload', {'taskId': taskId});
  }

  @override
  Future<void> resume(String taskId) async => resumeDownload(taskId);

  /// Resume a specific download
  Future<void> resumeDownload(String taskId) async {
    await _channel.invokeMethod('resumeDownload', {'taskId': taskId});
  }

  @override
  Future<void> cancel(String taskId) async => cancelDownload(taskId);

  /// Cancel/remove a download.
  ///
  /// Semantics: cancel = delete. We tell native to remove the download (which
  /// cleans cached segments + partial MP4) and immediately drop the task from
  /// Drift. The UI reacts via [DownloadStatusChange] with `newStatus == null`.
  Future<void> cancelDownload(String taskId) async {
    await _channel.invokeMethod('cancelDownload', {'taskId': taskId});
    await _deleteTask(taskId);
  }

  @override
  Future<void> setWifiOnly(bool enabled) async => setWiFiOnlyMode(enabled);

  /// Set WiFi-only mode
  Future<void> setWiFiOnlyMode(bool enabled) async {
    await _channel.invokeMethod('setWiFiOnlyMode', {'enabled': enabled});
  }

  /// Find a task by episode (delegates to download store)
  @override
  Future<DownloadTask?> findTaskByEpisode(int animeId, double episodeNumber) async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTaskByEpisode(animeId, episodeNumber);
    return result.fold(
      onSuccess: (task) => task,
      onFailure: (_) => null,
    );
  }

  /// Synchronize Drift state with native download manager state.
  ///
  /// Called on app startup to sync Drift with native state.
  /// Essential because EventChannel events are lost when app is backgrounded.
  @override
  Future<void> syncDownloadedLibrary() async {
    try {
      final nativeDownloads = await _channel.invokeListMethod<Map>('syncDownloadedLibrary');
      final store = _ref.read(downloadStoreProvider);

      // Get all local tasks
      final localResult = await store.getAllTasks();
      final localTasks = localResult.fold(
        onSuccess: (tasks) => tasks,
        onFailure: (_) => <DownloadTask>[],
      );

      // Reconcile native state with local state
      for (final native in nativeDownloads ?? []) {
        final taskId = native['taskId'] as String;
        final nativeState = _mapNativeState(native['state'] as int);
        final filePath = native['filePath'] as String?;
        final bytesDownloaded = native['bytesDownloaded'] as int? ?? 0;
        final totalBytes = native['totalBytes'] as int?;

        final localTask = localTasks.where((t) => t.id == taskId).firstOrNull;

        if (localTask != null) {
          // Update if state differs
          if (localTask.status != nativeState) {
            await store.updateTask(
              _copyTaskWith(localTask, status: nativeState),
            );
            _statusController.add(DownloadStatusChange(
              taskId: taskId,
              oldStatus: localTask.status,
              newStatus: nativeState,
            ));
          }

          // Update filePath if completed and has path
          if (nativeState == DownloadStatus.completed && filePath != null) {
            if (localTask.filePath != filePath) {
              await store.updateTask(
                _copyTaskWith(localTask, filePath: filePath),
              );
            }
          }

          // Update progress for active downloads
          if (nativeState == DownloadStatus.downloading) {
            _progressController.add(DownloadProgressEvent(
              taskId: taskId,
              downloadedBytes: bytesDownloaded,
              totalBytes: totalBytes ?? 0,
            ));
          }
        }
      }
    } catch (e) {
      developer.log('Error syncing library: $e', name: 'NativeDownload');
    }
  }

  /// Handle events from native layer
  void _handleNativeEvent(dynamic event) {
    final type = event['type'] as String;
    final taskId = event['taskId'] as String;

    switch (type) {
      case 'state':
        final stateInt = event['state'] as int? ?? 0;
        final downloadedBytes = event['downloadedBytes'] as int? ?? 0;
        final totalBytes = event['totalBytes'] as int? ?? 0;
        unawaited(_applyStateTransition(
          taskId,
          _mapNativeState(stateInt),
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        ));
        break;

      case 'progress':
        final downloadedBytes = event['downloadedBytes'] as int? ?? 0;
        final totalBytes = event['totalBytes'] as int? ?? 0;

        _progressController.add(DownloadProgressEvent(
          taskId: taskId,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
        ));

        // Update Drift periodically
        _updateProgressInDrift(taskId, downloadedBytes, totalBytes);
        break;

      case 'completed':
        final filePath = event['filePath'] as String?;
        _updateCompletedInDrift(taskId, filePath);
        _progressController.add(DownloadProgressEvent(
          taskId: taskId,
          isComplete: true,
          downloadedBytes: event['totalBytes'] as int? ?? 0,
          totalBytes: event['totalBytes'] as int? ?? 0,
        ));
        _statusController.add(DownloadStatusChange(
          taskId: taskId,
          newStatus: DownloadStatus.completed,
        ));
        break;

      case 'failed':
        final errorMsg = event['error'] as String?;
        _updateFailedInDrift(taskId, errorMsg);
        // Emit a zero-progress event to signal failure
        _progressController.add(DownloadProgressEvent(
          taskId: taskId,
          downloadedBytes: 0,
          totalBytes: 0,
        ));
        _statusController.add(DownloadStatusChange(
          taskId: taskId,
          newStatus: DownloadStatus.failed,
        ));
        break;

      case 'cancelled':
        // User chose cancel = delete semantics. Remove from Drift and emit a
        // deletion-shaped DownloadStatusChange (no newStatus).
        unawaited(_deleteTask(taskId));
        break;

      case 'warning':
        // Log warning but don't change state
        final message = event['message'] as String?;
        developer.log('Native download warning for $taskId: $message',
            name: 'NativeDownload');
        break;
    }
  }

  /// Apply a state transition coming from the native layer.
  ///
  /// Updates Drift only when the status actually changed and broadcasts a
  /// [DownloadStatusChange] so the tab providers refresh. This is the single
  /// source of truth that flips `pending → downloading → completed/failed`.
  Future<void> _applyStateTransition(
    String taskId,
    DownloadStatus newStatus, {
    required int downloadedBytes,
    required int totalBytes,
  }) async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTask(taskId);
      final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
      if (task == null) return;

      if (task.status == newStatus) {
        // Still persist byte counts if they advanced meaningfully.
        if (totalBytes > 0 && task.totalBytes != totalBytes) {
          await store.updateTask(
            _copyTaskWith(
              task,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
        return;
      }

      await store.updateTask(
        _copyTaskWith(
          task,
          status: newStatus,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes > 0 ? totalBytes : null,
        ),
      );
      _statusController.add(DownloadStatusChange(
        taskId: taskId,
        anilistId: task.anilistId,
        oldStatus: task.status,
        newStatus: newStatus,
      ));
    } catch (e) {
      developer.log('Error applying state transition: $e',
          name: 'NativeDownload');
    }
  }

  /// Remove a task from Drift and broadcast a deletion change.
  Future<void> _deleteTask(String taskId) async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTask(taskId);
      final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
      await store.deleteTask(taskId);
      _statusController.add(DownloadStatusChange(
        taskId: taskId,
        anilistId: task?.anilistId,
        oldStatus: task?.status,
      ));
    } catch (e) {
      developer.log('Error deleting task: $e', name: 'NativeDownload');
    }
  }

  Future<void> _updateProgressInDrift(
    String taskId,
    int downloadedBytes,
    int totalBytes,
  ) async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTask(taskId);
      final task = result.fold(
        onSuccess: (t) => t,
        onFailure: (_) => null,
      );

      // Progress can arrive while the task is still in pending or paused
      // (Media3 fires onDownloadChanged on every byte). Accept any non-terminal
      // status — terminal statuses (completed / failed) are handled elsewhere.
      const nonTerminal = {
        DownloadStatus.pending,
        DownloadStatus.downloading,
        DownloadStatus.paused,
      };
      if (task != null && nonTerminal.contains(task.status)) {
        // Only update if significant progress change (>5% or >1MB)
        final currentProgress = task.downloadedBytes ?? 0;
        final threshold = (totalBytes * 0.05).toInt().clamp(0, 1048576); // 5% or 1MB

        if ((downloadedBytes - currentProgress).abs() > threshold) {
          await store.updateTask(
            _copyTaskWith(
              task,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Error updating progress: $e', name: 'NativeDownload');
    }
  }

  Future<void> _updateCompletedInDrift(String taskId, String? filePath) async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTask(taskId);
      final task = result.fold(
        onSuccess: (t) => t,
        onFailure: (_) => null,
      );

      if (task != null) {
        await store.updateTask(
          _copyTaskWith(
            task,
            status: DownloadStatus.completed,
            filePath: filePath,
          ),
        );
      }
    } catch (e) {
      developer.log('Error updating completed: $e', name: 'NativeDownload');
    }
  }

  Future<void> _updateFailedInDrift(String taskId, String? error) async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTask(taskId);
      final task = result.fold(
        onSuccess: (t) => t,
        onFailure: (_) => null,
      );
      if (task != null) {
        await store.updateTask(
          _copyTaskWith(task, status: DownloadStatus.failed),
        );
      }
    } catch (e) {
      developer.log('Error updating failed: $e', name: 'NativeDownload');
    }
  }

  DownloadStatus _mapNativeState(int nativeState) {
    // Media3 Download states:
    // 0 = STATE_QUEUED
    // 1 = STATE_STOPPED
    // 2 = STATE_DOWNLOADING
    // 3 = STATE_COMPLETED
    // 4 = STATE_FAILED
    // 5 = STATE_REMOVING (map to failed)
    switch (nativeState) {
      case 0:
        return DownloadStatus.pending;
      case 1:
        return DownloadStatus.paused;
      case 2:
        return DownloadStatus.downloading;
      case 3:
        return DownloadStatus.completed;
      case 4:
        return DownloadStatus.failed;
      case 5:
        return DownloadStatus.failed; // STATE_REMOVING maps to failed
      default:
        return DownloadStatus.pending;
    }
  }

  /// Creates a new [DownloadTask] with the given fields overridden.
  ///
  /// [DownloadTask] is immutable and has no `copyWith`, so we reconstruct it
  /// manually here.
  DownloadTask _copyTaskWith(
    DownloadTask task, {
    DownloadStatus? status,
    String? filePath,
    int? downloadedBytes,
    int? totalBytes,
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
      errorMessage: task.errorMessage,
      updatedAt: task.updatedAt,
      headers: task.headers,
      isHls: task.isHls,
      animeTitle: task.animeTitle,
      qualityLabel: task.qualityLabel,
      episodeTitle: task.episodeTitle,
    );
  }

  // ─── Methods required by shared UI code ──────────────────────────────────

  @override
  Future<void> retry(String taskId) async => resumeDownload(taskId);

  @override
  Future<void> pauseAll() async {
    final store = _ref.read(downloadStoreProvider);
    final result = await store.getTasksByStatus(DownloadStatus.downloading);
    final tasks = result.fold(
      onSuccess: (t) => t,
      onFailure: (_) => <DownloadTask>[],
    );
    for (final task in tasks) {
      await pauseDownload(task.id);
    }
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
      await resumeDownload(task.id);
    }
  }

  /// Restores pending downloads after app restart.
  ///
  /// On Android, Media3 DownloadManager persists state natively, so we only
  /// need to sync Drift with the current native state.
  @override
  Future<void> restoreQueue() async {
    await syncDownloadedLibrary();
  }

  /// Deletes a completed download record from Drift.
  ///
  /// The actual file deletion is handled by the native layer when the download
  /// is cancelled. This only removes the DB record.
  @override
  Future<void> deleteCompleted(String taskId) async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTask(taskId);
      final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
      await store.deleteTask(taskId);
      _statusController.add(DownloadStatusChange(
        taskId: taskId,
        anilistId: task?.anilistId,
        oldStatus: task?.status,
      ));
    } catch (e) {
      developer.log('Error deleting completed: $e', name: 'NativeDownload');
    }
  }

  /// Retries all failed downloads by re-enqueuing them.
  @override
  Future<void> retryAllFailed() async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTasksByStatus(DownloadStatus.failed);
      final tasks = result.fold(
        onSuccess: (t) => t,
        onFailure: (_) => <DownloadTask>[],
      );
      for (final task in tasks) {
        await store.updateTask(_copyTaskWith(task, status: DownloadStatus.pending));
        await resumeDownload(task.id);
      }
      if (tasks.isNotEmpty) {
        _statusController.add(const DownloadStatusChange(taskId: ''));
      }
    } catch (e) {
      developer.log('Error retrying failed: $e', name: 'NativeDownload');
    }
  }

  /// Clears all pending and failed downloads from the queue.
  @override
  Future<void> clearQueue() async {
    try {
      final store = _ref.read(downloadStoreProvider);
      for (final status in [DownloadStatus.pending, DownloadStatus.failed]) {
        final result = await store.getTasksByStatus(status);
        final tasks = result.fold(
          onSuccess: (t) => t,
          onFailure: (_) => <DownloadTask>[],
        );
        for (final task in tasks) {
          await cancelDownload(task.id);
          await store.deleteTask(task.id);
        }
      }
      _statusController.add(const DownloadStatusChange(taskId: ''));
    } catch (e) {
      developer.log('Error clearing queue: $e', name: 'NativeDownload');
    }
  }

  /// Cancels all active downloads.
  @override
  Future<void> cancelAll() async {
    try {
      final store = _ref.read(downloadStoreProvider);
      final result = await store.getTasksByStatus(DownloadStatus.downloading);
      final tasks = result.fold(
        onSuccess: (t) => t,
        onFailure: (_) => <DownloadTask>[],
      );
      for (final task in tasks) {
        await cancelDownload(task.id);
      }
      _statusController.add(const DownloadStatusChange(taskId: ''));
    } catch (e) {
      developer.log('Error cancelling all: $e', name: 'NativeDownload');
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _progressController.close();
    _statusController.close();
  }
}
