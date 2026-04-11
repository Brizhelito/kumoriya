import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as ioc;
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import 'chunked_direct_downloader.dart';
import 'download_debug_logger.dart';
import 'download_directory_service.dart';
import 'download_error_classifier.dart';
import 'download_foreground_service.dart';
import 'download_library_index_service.dart';
import 'hls_segment_downloader.dart';

/// Result of a successful link refresh.
final class DownloadRefreshResult {
  const DownloadRefreshResult({
    required this.sourceUrl,
    required this.headers,
    required this.isHls,
    this.serverName,
    this.detectedHost,
    this.qualityLabel,
  });

  final Uri sourceUrl;
  final Map<String, String> headers;
  final bool isHls;
  final String? serverName;
  final String? detectedHost;
  final String? qualityLabel;
}

/// Callback that obtains a fresh stream URL for a failed download.
///
/// When [tryAlternativeServer] is true the implementation should skip the
/// original server and pick the next best one.  [triedServers] contains all
/// server names already attempted for this task — the refresher should skip
/// all of them when picking an alternative.
typedef DownloadLinkRefresher =
    Future<DownloadRefreshResult?> Function({
      required int anilistId,
      required double episodeNumber,
      required String? sourcePluginId,
      required String? serverName,
      required bool tryAlternativeServer,
      Set<String> triedServers,
    });

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

// Pre-compiled RegExp for safe file-name sanitization — avoids re-creating
// RegExp objects on every directory resolution call.
final _unsafePathChars = RegExp(r'[<>:"/\\|?*]');
final _trailingDots = RegExp(r'\.+$');
final _contentRangeTotalRe = RegExp(r'/([0-9]+)$');

/// Creates an [http.Client] tuned for download throughput:
/// - Connection pool sized for parallel HLS segments.
/// - Disabled auto-decompression (segments are already compressed/binary).
/// - 15 s connection timeout to fail fast instead of hanging.
/// - 5 s idle timeout — release connections quickly after completion
///   to avoid holding CDN slots open unnecessarily.
http.Client _createDownloadHttpClient({int maxConnectionsPerHost = 16}) {
  final inner = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 5)
    ..maxConnectionsPerHost = maxConnectionsPerHost;
  return ioc.IOClient(inner);
}

http.Client _createInsecureDownloadHttpClient({
  int maxConnectionsPerHost = 16,
  Set<String>? approvedHosts,
}) {
  final inner = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 5)
    ..maxConnectionsPerHost = maxConnectionsPerHost
    ..badCertificateCallback = (certificate, host, port) =>
        approvedHosts?.contains(host) ?? false;
  return ioc.IOClient(inner);
}

int _defaultMaxConcurrentDownloads() {
  if (Platform.isAndroid) {
    return 2;
  }
  if (Platform.isWindows) {
    return 4;
  }
  return 2;
}

int _defaultMaxConnectionsPerHost() {
  if (Platform.isAndroid) {
    return 8;
  }
  if (Platform.isWindows) {
    return 12;
  }
  return 8;
}

/// Callback invoked when a download finishes with a definitive outcome.
///
/// [serverName] is the server that was used, [success] indicates whether
/// the download completed or failed permanently.
typedef DownloadServerOutcomeCallback =
    void Function(String serverName, {required bool success});

class DownloadManagerService {
  DownloadManagerService({
    required DownloadStore store,
    required DownloadDirectoryService directoryService,
    required DownloadLibraryIndexService libraryIndexService,
    HlsSegmentStore? hlsSegmentStore,
    int? maxConcurrent,
    http.Client? httpClient,
    http.Client Function()? insecureHttpClientFactory,
    int maxRetryAttempts = 3,
    DownloadLinkRefresher? linkRefresher,
    int maxReResolveAttempts = 4,
    DownloadForegroundService? foregroundService,
    DownloadServerOutcomeCallback? onServerOutcome,
  }) : _store = store,
       _foregroundService = foregroundService,
       _directoryService = directoryService,
       _libraryIndexService = libraryIndexService,
       _hlsSegmentStore = hlsSegmentStore,
       _maxConcurrent = (maxConcurrent ?? _defaultMaxConcurrentDownloads()),
       _httpClient =
           httpClient ??
           _createDownloadHttpClient(
             maxConnectionsPerHost: _defaultMaxConnectionsPerHost(),
           ),
       _insecureHttpClientFactory = insecureHttpClientFactory,
       _maxRetryAttempts = maxRetryAttempts.clamp(1, 5),
       _linkRefresher = linkRefresher,
       _maxReResolveAttempts = maxReResolveAttempts.clamp(0, 5),
       _onServerOutcome = onServerOutcome {
    unawaited(_cleanupOrphanedSegmentDirectoriesOnStartup());
  }

  final DownloadStore _store;
  final DownloadDirectoryService _directoryService;
  final DownloadLibraryIndexService _libraryIndexService;
  final DownloadForegroundService? _foregroundService;
  final HlsSegmentStore? _hlsSegmentStore;
  final http.Client _httpClient;
  final http.Client Function()? _insecureHttpClientFactory;
  final int _maxRetryAttempts;
  final DownloadLinkRefresher? _linkRefresher;
  final int _maxReResolveAttempts;
  final DownloadServerOutcomeCallback? _onServerOutcome;
  int _maxConcurrent;
  http.Client? _insecureHttpClient;
  bool _disposed = false;

  /// Tracks how many re-resolution attempts each task has consumed.
  /// Cleared when the task completes or is cancelled.
  final _reResolveAttempts = <String, int>{};

  /// Tracks which server names have already been tried per task to prevent
  /// ping-pong cycling between the same two failing servers.
  final _triedServersPerTask = <String, Set<String>>{};
  final _insecureTlsHostsByTask = <String, Set<String>>{};

  /// Hosts that have been explicitly approved for insecure TLS after a
  /// certificate-verify failure.  Shared across all tasks so the insecure
  /// HttpClient callback can gate on them.
  final _approvedInsecureHosts = <String>{};

  final _activeDownloads = <String, _ActiveDownload>{};
  final _latestProgressByTask = <String, DownloadProgressEvent>{};
  final _progressController =
      StreamController<DownloadProgressEvent>.broadcast();
  final _aggregateProgressController =
      StreamController<DownloadAggregateProgress>.broadcast();
  final _statusChangeController =
      StreamController<DownloadStatusChange>.broadcast();
  final _taskWriteChains = <String, Future<void>>{};
  final _pendingProgressSnapshots = <String, DownloadTask>{};
  final _progressWriteInFlight = <String>{};

  /// Counters for notification progress display.
  int _sessionCompletedCount = 0;
  int _sessionTotalEnqueued = 0;
  int _sessionFailedCount = 0;

  /// Aggregate progress is expensive (iterates all tasks). Throttle to ~1 Hz.
  final _aggregateThrottleSw = Stopwatch()..start();
  static const _aggregateThrottleMs = 1000;
  static const _progressEmissionMs = 500;
  static const _progressDbWriteMs = 3000;
  static const _directFlushMs = 2000;

  Stream<DownloadStatusChange> get statusChangeStream =>
      _statusChangeController.stream;
  Stream<DownloadProgressEvent> get progressStream =>
      _progressController.stream;
  Stream<DownloadAggregateProgress> get aggregateProgressStream =>
      _aggregateProgressController.stream;

  bool _processingQueue = false;
  bool _pendingQueuePass = false;

  int get maxConcurrent => _maxConcurrent;
  set maxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 8);
    unawaited(_processQueue());
  }

  Future<DownloadTask?> findTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) async {
    final result = await _store.getTaskByEpisode(anilistId, episodeNumber);
    final task = result.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task == null) {
      return null;
    }

    if (task.status == DownloadStatus.completed &&
        task.filePath != null &&
        !File(task.filePath!).existsSync()) {
      await _store.deleteTask(task.id);
      _statusChangeController.add(
        DownloadStatusChange(
          taskId: task.id,
          anilistId: task.anilistId,
          oldStatus: DownloadStatus.completed,
        ),
      );
      return null;
    }
    return task;
  }

  Future<DownloadLibrarySyncReport> syncDownloadedLibrary() async {
    final report = await _libraryIndexService.syncCurrentLibrary();
    if (report.changed) {
      _statusChangeController.add(const DownloadStatusChange(taskId: ''));
    }
    return report;
  }

  Future<void> enqueue(DownloadTask task) async {
    if (_disposed) {
      return;
    }
    final existing = await _store.getTask(task.id);
    if (existing.fold(onSuccess: (value) => value, onFailure: (_) => null) !=
        null) {
      return;
    }
    await _store.insertTask(task);
    _sessionTotalEnqueued++;
    _emitStatusChange(
      taskId: task.id,
      anilistId: task.anilistId,
      newStatus: task.status,
    );
    unawaited(_processQueue());
  }

  Future<void> pause(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    active?.cancel();
    _removeProgress(taskId);
    _insecureTlsHostsByTask.remove(taskId);
    await _updateStatus(taskId, DownloadStatus.paused);
  }

  Future<void> resume(String taskId) async {
    await clearTaskError(taskId);
    _reResolveAttempts.remove(taskId);
    _triedServersPerTask.remove(taskId);
    _insecureTlsHostsByTask.remove(taskId);
    await _updateStatus(taskId, DownloadStatus.pending, errorMessage: null);
    await _processQueue();
  }

  Future<void> cancel(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    active?.cancel();
    _removeProgress(taskId);
    _reResolveAttempts.remove(taskId);
    _triedServersPerTask.remove(taskId);
    _insecureTlsHostsByTask.remove(taskId);
    _clearScheduledProgressPersistence(taskId);
    await _drainTaskWrites(taskId);

    final taskResult = await _store.getTask(taskId);
    final task = taskResult.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );

    // Delete from store and notify UI first for immediate feedback.
    await _store.deleteTask(taskId);
    _taskWriteChains.remove(taskId);
    _statusChangeController.add(
      DownloadStatusChange(
        taskId: taskId,
        anilistId: task?.anilistId,
        oldStatus: task?.status,
      ),
    );

    // File cleanup in background — does not block UI.
    if (task != null) {
      unawaited(_deleteTaskArtifacts(task));
    }
    unawaited(_processQueue());
  }

  Future<void> cancelAll() async {
    for (final active in _activeDownloads.values.toList()) {
      active.cancel();
    }
    _activeDownloads.clear();
    _latestProgressByTask.clear();
    _reResolveAttempts.clear();
    _triedServersPerTask.clear();
    _insecureTlsHostsByTask.clear();
    _emitAggregateProgress();

    final tasksToClean = <DownloadTask>[];
    for (final status in [DownloadStatus.pending, DownloadStatus.downloading]) {
      final result = await _store.getTasksByStatus(status);
      final tasks = result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => <DownloadTask>[],
      );
      for (final task in tasks) {
        _clearScheduledProgressPersistence(task.id);
        await _drainTaskWrites(task.id);
        await _store.deleteTask(task.id);
        _taskWriteChains.remove(task.id);
        tasksToClean.add(task);
      }
    }

    // Notify UI immediately, then clean up files in background.
    _statusChangeController.add(const DownloadStatusChange(taskId: ''));
    for (final task in tasksToClean) {
      unawaited(_deleteTaskArtifacts(task));
    }
  }

  Future<void> clearQueue() async {
    final tasksToClean = <DownloadTask>[];
    for (final status in [DownloadStatus.pending, DownloadStatus.failed]) {
      final result = await _store.getTasksByStatus(status);
      final tasks = result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => <DownloadTask>[],
      );
      for (final task in tasks) {
        _reResolveAttempts.remove(task.id);
        _triedServersPerTask.remove(task.id);
        _insecureTlsHostsByTask.remove(task.id);
        _clearScheduledProgressPersistence(task.id);
        await _drainTaskWrites(task.id);
        await _store.deleteTask(task.id);
        _taskWriteChains.remove(task.id);
        tasksToClean.add(task);
      }
    }

    // Notify UI immediately, then clean up files in background.
    _statusChangeController.add(const DownloadStatusChange(taskId: ''));
    for (final task in tasksToClean) {
      unawaited(_deleteTaskArtifacts(task));
    }
  }

  Future<void> retry(String taskId) async => resume(taskId);

  Future<void> retryFailed(String taskId) async => resume(taskId);

  /// Re-queues every failed download in one shot.
  Future<void> retryAllFailed() async {
    final result = await _store.getTasksByStatus(DownloadStatus.failed);
    final tasks = result.fold(
      onSuccess: (v) => v,
      onFailure: (_) => <DownloadTask>[],
    );
    for (final task in tasks) {
      await clearTaskError(task.id);
      _reResolveAttempts.remove(task.id);
      _triedServersPerTask.remove(task.id);
      _insecureTlsHostsByTask.remove(task.id);
      await _updateStatus(task.id, DownloadStatus.pending, errorMessage: null);
    }
    if (tasks.isNotEmpty) await _processQueue();
  }

  /// Pauses every currently downloading task.
  Future<void> pauseAll() async {
    final ids = _activeDownloads.keys.toList();
    for (final id in ids) {
      await pause(id);
    }
  }

  /// Resumes every paused task.
  Future<void> resumeAll() async {
    final result = await _store.getTasksByStatus(DownloadStatus.paused);
    final tasks = result.fold(
      onSuccess: (v) => v,
      onFailure: (_) => <DownloadTask>[],
    );
    for (final task in tasks) {
      _reResolveAttempts.remove(task.id);
      _triedServersPerTask.remove(task.id);
      _insecureTlsHostsByTask.remove(task.id);
      await _updateStatus(task.id, DownloadStatus.pending, errorMessage: null);
    }
    if (tasks.isNotEmpty) await _processQueue();
  }

  Future<void> deleteCompleted(String taskId) async {
    _reResolveAttempts.remove(taskId);
    _triedServersPerTask.remove(taskId);
    _insecureTlsHostsByTask.remove(taskId);
    _clearScheduledProgressPersistence(taskId);
    await _drainTaskWrites(taskId);
    final taskResult = await _store.getTask(taskId);
    final task = taskResult.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task != null) {
      await _deleteTaskArtifacts(task);
    }
    await _store.deleteTask(taskId);
    _taskWriteChains.remove(taskId);
    _statusChangeController.add(
      DownloadStatusChange(
        taskId: taskId,
        anilistId: task?.anilistId,
        oldStatus: task?.status,
      ),
    );
  }

  Future<void> restoreQueue() async {
    await syncDownloadedLibrary();

    final downloadingResult = await _store.getTasksByStatus(
      DownloadStatus.downloading,
    );
    final orphaned = downloadingResult.fold(
      onSuccess: (tasks) => tasks,
      onFailure: (_) => <DownloadTask>[],
    );
    for (final task in orphaned) {
      if (!_activeDownloads.containsKey(task.id)) {
        await _updateStatus(task.id, DownloadStatus.pending);
      }
    }
    await _processQueue();
  }

  Future<void> _processQueue() async {
    if (_disposed) {
      return;
    }
    if (_processingQueue) {
      _pendingQueuePass = true;
      return;
    }
    _processingQueue = true;
    try {
      do {
        _pendingQueuePass = false;
        final slotsAvailable = _maxConcurrent - _activeDownloads.length;
        if (slotsAvailable <= 0) break;
        final pendingResult = await _store.getTasksByStatus(
          DownloadStatus.pending,
          // Fetch only as many tasks as we have open slots — no point loading
          // the full backlog when we can only start a few downloads right now.
          limit: slotsAvailable,
        );
        final pending = pendingResult.fold(
          onSuccess: (tasks) => tasks,
          onFailure: (_) => <DownloadTask>[],
        );

        if (pending.isNotEmpty) {
          _log(
            'Queue: slots=$slotsAvailable active=${_activeDownloads.length} '
            'max=$_maxConcurrent pending=${pending.length}',
          );
        }

        for (final task in pending) {
          if (_disposed) {
            return;
          }
          if (_activeDownloads.length >= _maxConcurrent) {
            break;
          }
          if (_activeDownloads.containsKey(task.id)) {
            continue;
          }
          unawaited(_startDownload(task));
        }
      } while (_pendingQueuePass);
    } finally {
      _processingQueue = false;
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    final cancelCompleter = Completer<void>();
    _activeDownloads[task.id] = _ActiveDownload(
      taskId: task.id,
      cancel: () {
        if (!cancelCompleter.isCompleted) {
          cancelCompleter.complete();
        }
      },
    );

    // Start foreground service on the first active download.
    if (_activeDownloads.length == 1) {
      await _foregroundService?.start();
    }

    try {
      final target = await _resolveTargetPaths(task);
      final runningTask = _copyTask(
        task,
        status: DownloadStatus.downloading,
        fileName: target.finalFileName,
        filePath: target.tempPath,
        errorMessage: null,
      );
      _clearScheduledProgressPersistence(task.id);
      await _persistTaskSnapshot(runningTask);
      _emitStatusChange(
        taskId: task.id,
        anilistId: task.anilistId,
        oldStatus: task.status,
        newStatus: DownloadStatus.downloading,
      );

      var finalPath = target.finalPath;
      var finalFileName = target.finalFileName;

      if (task.isHls) {
        await dlLog.log(
          'Manager',
          '[start] HLS task=${task.id} server=${task.serverName} '
              'host=${task.detectedHost} quality=${task.qualityLabel} '
              'url=${task.sourceUrl}',
        );
        final hlsResult = await _downloadHls(
          runningTask,
          target.tempPath,
          cancelCompleter,
        );
        if (hlsResult.isFmp4 && finalPath.endsWith('.ts')) {
          finalPath = '${finalPath.substring(0, finalPath.length - 3)}.mp4';
          finalFileName = p.basename(finalPath);
        }
      } else {
        await dlLog.log(
          'Manager',
          '[start] direct task=${task.id} server=${task.serverName} '
              'host=${task.detectedHost} quality=${task.qualityLabel} '
              'url=${task.sourceUrl}',
        );
        await _downloadDirect(runningTask, target.tempPath, cancelCompleter);
      }

      if (cancelCompleter.isCompleted) {
        return;
      }

      _activeDownloads.remove(task.id);

      final completedTask = await _finalizeSuccessfulDownload(
        runningTask,
        tempPath: target.tempPath,
        finalPath: finalPath,
        finalFileName: finalFileName,
      );
      _emitProgress(
        DownloadProgressEvent(
          taskId: completedTask.id,
          downloadedBytes: completedTask.totalBytes ?? 0,
          totalBytes: completedTask.totalBytes ?? 0,
          isComplete: true,
        ),
      );
      _removeProgress(task.id);
      _reResolveAttempts.remove(task.id);
      _triedServersPerTask.remove(task.id);
      _insecureTlsHostsByTask.remove(task.id);
      _sessionCompletedCount++;
      _emitStatusChange(
        taskId: task.id,
        anilistId: task.anilistId,
        oldStatus: DownloadStatus.downloading,
        newStatus: DownloadStatus.completed,
      );
      _log('Download complete: ${task.id} (${completedTask.totalBytes} bytes)');
      if (task.serverName != null) {
        _onServerOutcome?.call(task.serverName!, success: true);
      }
      await dlLog.log(
        'Manager',
        'COMPLETE: ${task.id} bytes=${completedTask.totalBytes} path=${completedTask.filePath}',
      );
    } catch (error, stack) {
      _removeProgress(task.id);

      // If the cancel completer has fired, this task was intentionally
      // stopped (pause or cancel). Don't mark it as failed — the caller
      // (pause/cancel) already set the correct status or deleted the task.
      if (cancelCompleter.isCompleted) {
        _log('Download stopped (cancelled/paused): ${task.id}');
        return;
      }

      final errorKind = classifyDownloadError(error);
      _log('Download failed: ${task.id} kind=$errorKind error=$error');
      await dlLog.error(
        'Manager',
        'FAILED: ${task.id} kind=$errorKind url=${task.sourceUrl} '
            'isHls=${task.isHls} headers=${task.headers}',
        error,
        stack,
      );
      await dlLog.flush();

      // Attempt automatic recovery via re-resolution / server fallback.
      if (isReResolvable(errorKind) && _linkRefresher != null) {
        final recovered = await _tryRecoverDownload(task, errorKind);
        if (recovered) return; // recovery re-enqueued the task
      }

      final message = humanReadableDownloadError(errorKind, error);
      if (!_disposed) {
        _sessionFailedCount++;
        if (task.serverName != null) {
          _onServerOutcome?.call(task.serverName!, success: false);
        }
        await _updateStatus(
          task.id,
          DownloadStatus.failed,
          errorMessage: message,
        );
      }
    } finally {
      _activeDownloads.remove(task.id);
      // Only kick the queue when the task finished naturally (completed or
      // failed).  When the user explicitly paused or cancelled, we must NOT
      // start the next pending task — that would defeat the purpose of pause.
      if (!_disposed && !cancelCompleter.isCompleted) {
        unawaited(_processQueue());
      }
    }
  }

  /// Attempts to recover a failed download by re-resolving its stream URL.
  ///
  /// Returns `true` if the task was successfully refreshed and re-enqueued,
  /// `false` if recovery is not possible.
  Future<bool> _tryRecoverDownload(
    DownloadTask task,
    DownloadErrorKind errorKind,
  ) async {
    final attempts = _reResolveAttempts[task.id] ?? 0;
    if (attempts >= _maxReResolveAttempts) {
      _log(
        'Recovery exhausted for ${task.id} '
        '(attempts=$attempts/$_maxReResolveAttempts)',
      );
      return false;
    }

    _reResolveAttempts[task.id] = attempts + 1;

    // Exponential cooldown between re-resolve attempts to avoid hammering
    // the source plugin when multiple servers are failing in quick succession.
    if (attempts > 0) {
      final cooldownMs = 1000 * attempts; // 1s, 2s, 3s, ...
      _log(
        'Re-resolve cooldown ${cooldownMs}ms before attempt ${attempts + 1} '
        'for ${task.id}',
      );
      await Future<void>.delayed(Duration(milliseconds: cooldownMs));
    }

    // Record the current server so we don't cycle back to it.
    final triedServers = _triedServersPerTask.putIfAbsent(
      task.id,
      () => <String>{},
    );
    final currentServer = task.serverName;
    if (currentServer != null) {
      triedServers.add(currentServer);
    }

    // First attempt: re-resolve same server (fresh CDN token).
    // Subsequent attempts or 404: try an alternative server.
    // For network/certificate errors the current host itself is unreachable,
    // so always prefer an alternative server immediately.
    final tryAlternative =
        errorKind == DownloadErrorKind.notFound ||
        errorKind == DownloadErrorKind.networkError ||
        errorKind == DownloadErrorKind.certificateError ||
        attempts > 0;
    final strategyLabel = tryAlternative
        ? 'alternative server'
        : 'same-server re-resolve';
    _log(
      'Attempting recovery for ${task.id}: $strategyLabel '
      '(attempt=${attempts + 1}/$_maxReResolveAttempts)',
    );

    try {
      final refreshed = await _linkRefresher!(
        anilistId: task.anilistId,
        episodeNumber: task.episodeNumber,
        sourcePluginId: task.sourcePluginId,
        serverName: task.serverName,
        tryAlternativeServer: tryAlternative,
        triedServers: triedServers,
      );

      if (refreshed == null) {
        _log('Recovery returned null for ${task.id}');
        return false;
      }

      // Anti-ping-pong: reject if the refresher selected a server we already
      // tried and failed on.  This prevents A→B→A→B cycling.
      final refreshedServer = refreshed.serverName;
      if (refreshedServer != null && triedServers.contains(refreshedServer)) {
        _log(
          'Recovery ping-pong detected for ${task.id}: '
          'server "$refreshedServer" was already tried. Aborting recovery.',
        );
        return false;
      }

      // Delete partial file when switching to a different server/host —
      // the new URL likely serves different binary content.
      final hostChanged =
          refreshed.detectedHost != task.detectedHost ||
          refreshed.serverName != task.serverName;
      if (hostChanged && task.filePath != null) {
        final partFile = File(task.filePath!);
        if (await partFile.exists()) {
          await partFile.delete();
          _log('Deleted partial file for server switch: ${task.filePath}');
        }
      }

      // Rebuild the file name when the server or quality changed.
      String? refreshedFileName;
      if (refreshed.serverName != task.serverName ||
          refreshed.qualityLabel != task.qualityLabel) {
        final epNum = task.episodeNumber.toInt().toString().padLeft(2, '0');
        final q = refreshed.qualityLabel;
        final qualitySuffix = q != null ? ' [$q]' : '';
        final server = refreshed.serverName ?? task.serverName ?? 'Unknown';
        final ext = refreshed.isHls ? '.ts' : '.mp4';
        refreshedFileName = 'EP $epNum - $server$qualitySuffix$ext'
            .replaceAll(_unsafePathChars, '_')
            .trim();
      }

      final updatedTask = _copyTask(
        task,
        status: DownloadStatus.pending,
        sourceUrl: refreshed.sourceUrl,
        headers: refreshed.headers,
        isHls: refreshed.isHls,
        serverName: refreshed.serverName ?? task.serverName,
        detectedHost: refreshed.detectedHost ?? task.detectedHost,
        qualityLabel: refreshed.qualityLabel ?? task.qualityLabel,
        fileName: refreshedFileName ?? task.fileName,
        filePath: hostChanged ? null : task.filePath,
        errorMessage: null,
        downloadedBytes: hostChanged ? 0 : task.downloadedBytes,
        totalBytes: hostChanged ? 0 : task.totalBytes,
      );
      _clearScheduledProgressPersistence(task.id);
      await _persistTaskSnapshot(updatedTask);
      // Do NOT emit a status change here. The task immediately goes back to
      // pending→downloading via _processQueue, so emitting would cause a
      // visible flicker between the "Active" and "Queue" tabs. The UI will
      // refresh when _startDownload emits the next downloading status change.

      _log(
        'Recovery succeeded for ${task.id}: '
        'newUrl=${refreshed.sourceUrl} server=${refreshed.serverName}',
      );
      // The task is now pending — _processQueue will pick it up.
      return true;
    } catch (recoverError) {
      _log('Recovery error for ${task.id}: $recoverError');
      return false;
    }
  }

  /// Attempts a chunked parallel download using HTTP Range requests.
  ///
  /// Returns `true` if download completed (or cancelled), `false` if the
  /// server does not support Range or the file is too small to benefit.
  Future<bool> _tryChunkedDirectDownload(
    DownloadTask task,
    String tempPath,
    Completer<void> cancelCompleter,
  ) async {
    final chunked = ChunkedDirectDownloader(
      httpClient: _clientForTaskRequest(task.id, task.sourceUrl),
    );

    final sw = Stopwatch()..start();
    var lastDbWriteMs = 0;

    try {
      final success = await chunked.tryDownload(
        url: task.sourceUrl,
        outputPath: tempPath,
        headers: task.headers,
        cancelCompleter: cancelCompleter,
        onProgress: (downloadedBytes, totalBytes, bytesPerSecond) {
          _emitProgress(
            DownloadProgressEvent(
              taskId: task.id,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              bytesPerSecond: bytesPerSecond,
            ),
          );

          final elapsedMs = sw.elapsedMilliseconds;
          if (elapsedMs - lastDbWriteMs >= _progressDbWriteMs) {
            lastDbWriteMs = elapsedMs;
            _scheduleProgressPersistence(
              _copyTask(
                task,
                status: DownloadStatus.downloading,
                filePath: tempPath,
                totalBytes: totalBytes > 0 ? totalBytes : null,
                downloadedBytes: downloadedBytes,
              ),
            );
          }
        },
      );

      if (success) {
        _log('Chunked download completed for ${task.id}: $tempPath');
      }
      return success;
    } catch (error) {
      _log(
        'Chunked download failed for ${task.id}, '
        'falling back to single-connection: $error',
      );
      // Clean up any chunk files on error before fallback.
      try {
        final dir = File(tempPath).parent;
        if (await dir.exists()) {
          await for (final entity in dir.list()) {
            if (entity is File && entity.path.contains('.chunk')) {
              await entity.delete();
            }
          }
        }
      } catch (_) {}
      return false;
    }
  }

  Future<void> _downloadDirect(
    DownloadTask task,
    String tempPath,
    Completer<void> cancelCompleter,
  ) async {
    // Try chunked parallel download first — significantly faster on hosts
    // that throttle per-connection bandwidth (e.g. Streamtape CDN).
    final chunkedSuccess = await _tryChunkedDirectDownload(
      task,
      tempPath,
      cancelCompleter,
    );
    if (chunkedSuccess || cancelCompleter.isCompleted) return;

    // Fallback: single-connection download (Range not supported or file
    // too small to benefit from chunking).
    final tempFile = File(tempPath);
    await tempFile.parent.create(recursive: true);

    var downloadedBytes = await _existingBytesFor(tempFile);
    var knownTotalBytes = task.totalBytes ?? 0;
    var bytesAtLastSample = downloadedBytes;
    var currentSpeed = 0;
    // Use Stopwatch instead of DateTime.now() — monotonic, cheaper syscall
    // on mobile (avoids repeated gettimeofday kernel calls per chunk).
    final sw = Stopwatch()..start();
    var lastSpeedMs = 0;
    var lastProgressMs = 0;
    var lastDbWriteMs = 0;
    var lastFlushMs = 0;
    var recoveryAttempts = 0;

    while (!cancelCompleter.isCompleted) {
      final existingBytes = await _existingBytesFor(tempFile);
      downloadedBytes = existingBytes;

      http.StreamedResponse response;
      try {
        response = await _sendDirectRequestWithRetries(
          task,
          offset: existingBytes,
        );
      } on _RestartDownloadFromZeroException {
        await tempFile.writeAsBytes(const <int>[], flush: true);
        downloadedBytes = 0;
        knownTotalBytes = 0;
        bytesAtLastSample = 0;
        currentSpeed = 0;
        recoveryAttempts = 0;
        continue;
      }

      final append = response.statusCode == 206 && existingBytes > 0;
      if (existingBytes > 0 && !append) {
        await tempFile.writeAsBytes(const <int>[], flush: true);
        downloadedBytes = 0;
        bytesAtLastSample = 0;
        currentSpeed = 0;
      }

      knownTotalBytes = _resolveExpectedTotalBytes(response, downloadedBytes);

      // Defensive gzip handling: some servers send gzip despite our
      // `Accept-Encoding: identity` header.  With `autoUncompress = false`
      // the raw bytes would corrupt the video file.  Detect and decompress.
      final contentEncoding =
          response.headers['content-encoding']?.toLowerCase().trim() ?? '';
      final isGzipped =
          contentEncoding == 'gzip' || contentEncoding == 'x-gzip';
      Stream<List<int>> bodyStream = response.stream;
      if (isGzipped) {
        _log(
          'Server sent gzip despite identity request for ${task.id}; '
          'decompressing on the fly',
        );
        bodyStream = bodyStream.transform(gzip.decoder);
        // Content-Length from the response refers to the compressed size,
        // so total-bytes tracking becomes unreliable.  Reset to unknown so
        // the progress UI shows an indeterminate bar instead of a wrong %.
        knownTotalBytes = 0;
      }

      final sink = tempFile.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      Object? interruptionError;

      try {
        await for (final chunk in bodyStream) {
          if (cancelCompleter.isCompleted) break;

          sink.add(chunk);
          downloadedBytes += chunk.length;

          final elapsedMs = sw.elapsedMilliseconds;

          // Speed calculation (~1 Hz).
          final speedDelta = elapsedMs - lastSpeedMs;
          if (speedDelta >= 1000) {
            final bytesDelta = downloadedBytes - bytesAtLastSample;
            currentSpeed = (bytesDelta * 1000 / speedDelta).round();
            bytesAtLastSample = downloadedBytes;
            lastSpeedMs = elapsedMs;
          }

          // Progress emission (~3 Hz).
          if (elapsedMs - lastProgressMs >= _progressEmissionMs) {
            lastProgressMs = elapsedMs;
            _emitProgress(
              DownloadProgressEvent(
                taskId: task.id,
                downloadedBytes: downloadedBytes,
                totalBytes: knownTotalBytes,
                bytesPerSecond: currentSpeed,
              ),
            );
          }

          // DB persistence (~0.5 Hz).
          if (elapsedMs - lastDbWriteMs >= _progressDbWriteMs) {
            lastDbWriteMs = elapsedMs;
            _scheduleProgressPersistence(
              _copyTask(
                task,
                status: DownloadStatus.downloading,
                filePath: tempPath,
                totalBytes: knownTotalBytes > 0 ? knownTotalBytes : null,
                downloadedBytes: downloadedBytes,
              ),
            );
          }

          // Periodic flush prevents unbounded IOSink buffering on slow
          // mobile storage, reducing GC pressure from accumulated writes.
          if (elapsedMs - lastFlushMs >= _directFlushMs) {
            lastFlushMs = elapsedMs;
            await sink.flush();
          }
        }
      } catch (error) {
        interruptionError = error;
      } finally {
        await sink.close();
      }

      if (cancelCompleter.isCompleted) {
        return;
      }

      final isIncomplete =
          knownTotalBytes > 0 && downloadedBytes < knownTotalBytes;
      if (interruptionError == null && !isIncomplete) {
        return;
      }

      final retryError =
          interruptionError ??
          HttpException(
            'Download interrupted before completion '
            '($downloadedBytes/$knownTotalBytes bytes)',
          );
      if (!_isRetryableDirectStreamError(retryError) ||
          recoveryAttempts >= _maxRetryAttempts) {
        throw retryError;
      }

      recoveryAttempts++;
      _log(
        'Recovering direct download stream: ${task.id} '
        'attempt=$recoveryAttempts offset=$downloadedBytes error=$retryError',
      );
      await Future<void>.delayed(_directRecoveryBackoff(recoveryAttempts));
    }
  }

  Future<HlsDownloadResult> _downloadHls(
    DownloadTask task,
    String tempPath,
    Completer<void> cancelCompleter,
  ) async {
    // Don't delete partial file — the new engine resumes from persisted
    // segment state. Only individual segment files matter now.

    final hlsDownloader = HlsSegmentDownloader(
      httpClient: _clientForTaskRequest(task.id, task.sourceUrl),
      parallelSegments: _resolveParallelSegmentsPerDownload(),
      maxRetries: _maxRetryAttempts,
      segmentStore: _hlsSegmentStore,
    );
    var bytesAtLastSample = 0;
    var currentSpeed = 0;
    final sw = Stopwatch()..start();
    var lastSpeedMs = 0;
    var lastDbWriteMs = 0;
    var lastProgressMs = 0;

    return hlsDownloader.download(
      masterUrl: task.sourceUrl,
      outputPath: tempPath,
      taskId: task.id,
      headers: task.headers,
      cancelCompleter: cancelCompleter,
      onProgress:
          (downloadedBytes, downloadedSegments, totalSegments, totalBytes) {
            final elapsedMs = sw.elapsedMilliseconds;

            final speedDelta = elapsedMs - lastSpeedMs;
            if (speedDelta >= 1000) {
              final bytesDelta = downloadedBytes - bytesAtLastSample;
              currentSpeed = (bytesDelta * 1000 / speedDelta).round();
              bytesAtLastSample = downloadedBytes;
              lastSpeedMs = elapsedMs;
            }

            final resolvedTotalBytes = totalBytes > 0 ? totalBytes : 0;

            if (resolvedTotalBytes > 0 &&
                elapsedMs - lastDbWriteMs >= _progressDbWriteMs) {
              lastDbWriteMs = elapsedMs;
              _scheduleProgressPersistence(
                _copyTask(
                  task,
                  status: DownloadStatus.downloading,
                  filePath: tempPath,
                  totalBytes: resolvedTotalBytes,
                  downloadedBytes: downloadedBytes,
                ),
              );
            }

            if (elapsedMs - lastProgressMs >= _progressEmissionMs) {
              lastProgressMs = elapsedMs;
              _emitProgress(
                DownloadProgressEvent(
                  taskId: task.id,
                  downloadedBytes: downloadedBytes,
                  totalBytes: resolvedTotalBytes,
                  bytesPerSecond: currentSpeed,
                ),
              );
            }
          },
    );
  }

  Future<DownloadTask> _finalizeSuccessfulDownload(
    DownloadTask task, {
    required String tempPath,
    required String finalPath,
    required String finalFileName,
  }) async {
    final tempFile = File(tempPath);
    if (!await tempFile.exists()) {
      throw const FileSystemException('Temporary download file is missing');
    }

    final finalFile = File(finalPath);
    await finalFile.parent.create(recursive: true);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }

    final movedFile = await tempFile.rename(finalPath);
    final fileSize = await movedFile.length();
    final completedTask = _copyTask(
      task,
      status: DownloadStatus.completed,
      fileName: finalFileName,
      filePath: movedFile.path,
      totalBytes: fileSize,
      downloadedBytes: fileSize,
      errorMessage: null,
    );
    _clearScheduledProgressPersistence(task.id);
    await _drainTaskWrites(task.id);
    await _persistTaskSnapshot(completedTask);
    await _libraryIndexService.writeManifest(
      task: completedTask,
      mediaPath: movedFile.path,
      totalBytes: fileSize,
    );
    return completedTask;
  }

  Future<http.StreamedResponse> _sendDirectRequestWithRetries(
    DownloadTask task, {
    required int offset,
  }) async {
    Object? lastError;
    int? lastStatusCode;
    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final request = http.Request('GET', task.sourceUrl);
        if (task.headers.isNotEmpty) {
          request.headers.addAll(task.headers);
        }
        request.headers.putIfAbsent('User-Agent', () => _defaultUserAgent);
        // Skip gzip/deflate — we want raw bytes, not decompressed content
        // that inflates memory and misrepresents Content-Length for resume.
        request.headers.putIfAbsent('Accept-Encoding', () => 'identity');
        if (offset > 0) {
          request.headers['Range'] = 'bytes=$offset-';
        }

        final response = await _sendTaskRequest(
          task,
          request,
          timeout: const Duration(seconds: 12),
        );
        if (response.statusCode == 200 || response.statusCode == 206) {
          return response;
        }
        if (response.statusCode == 416 && offset > 0) {
          await response.stream.drain<void>();
          throw const _RestartDownloadFromZeroException();
        }

        lastStatusCode = response.statusCode;
        lastError = HttpException('HTTP ${response.statusCode}');
        if (!_isRetryableStatus(response.statusCode) ||
            attempt == _maxRetryAttempts) {
          // Provide a clear message when 403 persists — URL likely expired.
          if (response.statusCode == 403) {
            throw HttpException(
              'HTTP 403 Forbidden – the download link has likely expired. '
              'Delete this download and re-enqueue it.',
            );
          }
          throw lastError;
        }
        await response.stream.drain<void>();
      } on TimeoutException {
        lastError = const HttpException('Connection timed out');
        // Fail fast on timeouts — retrying a dead host just wastes time.
        // One timeout is enough evidence; let recovery switch servers.
        if (attempt >= 2 || attempt == _maxRetryAttempts) {
          throw lastError;
        }
      } catch (error) {
        lastError = error;
        if (attempt == _maxRetryAttempts) {
          rethrow;
        }
      }
      // Longer backoff for 403 (transient CDN challenges take a moment).
      final backoffMs = lastStatusCode == 403 ? 800 * attempt : 350 * attempt;
      await Future<void>.delayed(Duration(milliseconds: backoffMs));
    }
    throw lastError ?? const HttpException('Download request failed');
  }

  int _resolveExpectedTotalBytes(
    http.StreamedResponse response,
    int existingBytes,
  ) {
    final totalFromHeader = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    final totalFromRange = _tryParseContentRangeTotal(
      response.headers['content-range'],
    );
    if (totalFromRange != null) {
      return totalFromRange;
    }
    if (response.statusCode == 206) {
      return existingBytes + (totalFromHeader ?? response.contentLength ?? 0);
    }
    return totalFromHeader ?? response.contentLength ?? 0;
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 403 ||
        statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  Future<int> _existingBytesFor(File file) async {
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }

  int? _tryParseContentRangeTotal(String? contentRange) {
    if (contentRange == null || contentRange.isEmpty) {
      return null;
    }
    final totalMatch = _contentRangeTotalRe.firstMatch(contentRange);
    if (totalMatch == null) {
      return null;
    }
    return int.tryParse(totalMatch.group(1)!);
  }

  bool _isRetryableDirectStreamError(Object error) {
    return error is TimeoutException ||
        error is HandshakeException ||
        error is SocketException ||
        error is HttpException ||
        error is IOException ||
        error is http.ClientException;
  }

  Future<http.StreamedResponse> _sendTaskRequest(
    DownloadTask task,
    http.BaseRequest request, {
    required Duration timeout,
  }) async {
    try {
      final client = _clientForTaskRequest(task.id, request.url);
      return await client.send(request).timeout(timeout);
    } on HandshakeException catch (error) {
      if (!_isCertificateVerifyFailure(error) ||
          request.url.scheme != 'https') {
        rethrow;
      }

      final insecureClient = _ensureInsecureHttpClient();
      if (insecureClient == null) {
        rethrow;
      }

      _insecureTlsHostsByTask
          .putIfAbsent(task.id, () => <String>{})
          .add(request.url.host);
      _approvedInsecureHosts.add(request.url.host);
      _log(
        'Retrying ${request.url.host} with insecure TLS fallback '
        'for task=${task.id}',
      );

      final retryRequest = _cloneRequest(request);
      return await insecureClient.send(retryRequest).timeout(timeout);
    }
  }

  http.Client _clientForTaskRequest(String taskId, Uri url) {
    final insecureHosts = _insecureTlsHostsByTask[taskId];
    if (url.scheme == 'https' && insecureHosts?.contains(url.host) == true) {
      final insecureClient = _ensureInsecureHttpClient();
      if (insecureClient != null) {
        return insecureClient;
      }
    }
    return _httpClient;
  }

  http.Client? _ensureInsecureHttpClient() {
    final existing = _insecureHttpClient;
    if (existing != null) {
      return existing;
    }

    final created =
        _insecureHttpClientFactory?.call() ??
        _createInsecureDownloadHttpClient(
          maxConnectionsPerHost: _defaultMaxConnectionsPerHost(),
          approvedHosts: _approvedInsecureHosts,
        );
    _insecureHttpClient = created;
    return created;
  }

  bool _isCertificateVerifyFailure(HandshakeException error) {
    // .message only has the short label (e.g. "Handshake error in client");
    // the CERTIFICATE_VERIFY_FAILED detail lives in .osError.
    // Use toString() which includes both.
    final full = error.toString().toLowerCase();
    return full.contains('certificate_verify_failed') ||
        full.contains('certificate verify failed') ||
        full.contains('certificateverifyfailed');
  }

  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    if (request is! http.Request) {
      throw UnsupportedError(
        'TLS fallback only supports retrying http.Request instances',
      );
    }

    final cloned = http.Request(request.method, request.url)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return cloned;
  }

  Duration _directRecoveryBackoff(int attempt) {
    return Duration(milliseconds: 450 * attempt);
  }

  Future<void> _updateStatus(
    String taskId,
    DownloadStatus status, {
    String? errorMessage,
  }) async {
    if (_disposed) {
      return;
    }
    final result = await _store.getTask(taskId);
    final task = result.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task == null) {
      return;
    }

    if (status != DownloadStatus.downloading) {
      _removeProgress(taskId);
    }

    _clearScheduledProgressPersistence(taskId);
    await _persistTaskSnapshot(
      _copyTask(task, status: status, errorMessage: errorMessage),
    );
    _emitStatusChange(
      taskId: taskId,
      anilistId: task.anilistId,
      oldStatus: task.status,
      newStatus: status,
    );
  }

  Future<void> clearTaskError(String taskId) async {
    if (_disposed) {
      return;
    }
    final result = await _store.getTask(taskId);
    final task = result.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task == null || task.errorMessage == null) {
      return;
    }

    _clearScheduledProgressPersistence(taskId);
    await _persistTaskSnapshot(
      _copyTask(task, errorMessage: null, updatedAt: DateTime.now()),
    );
    _emitStatusChange(
      taskId: taskId,
      anilistId: task.anilistId,
      oldStatus: task.status,
      newStatus: task.status,
    );
  }

  Future<void> _deleteTaskArtifacts(DownloadTask task) async {
    try {
      final paths = _artifactPathsForTask(task);

      for (final path in paths) {
        final file = File(path);
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } on FileSystemException {
          // File may be locked or already deleted — best-effort.
        }
        // Clean up HLS segment directory (created by the isolate engine).
        final segDir = Directory('${path}_segments');
        try {
          if (await segDir.exists()) {
            await segDir.delete(recursive: true);
          }
        } on FileSystemException {
          // Directory may be locked or already deleted — best-effort.
        }
      }

      // Clean up persisted HLS segment records.
      if (_hlsSegmentStore != null && task.isHls) {
        await _hlsSegmentStore.deleteSegmentsForTask(task.id);
      }

      final filePath = task.filePath;
      if (filePath != null) {
        await _libraryIndexService.deleteManifestForMedia(
          filePath.endsWith('.part')
              ? filePath.substring(0, filePath.length - 5)
              : filePath,
        );
      }
    } catch (_) {
      // Best-effort cleanup — errors must not propagate when called via
      // unawaited since the task is already removed from the store.
    }
  }

  Set<String> _artifactPathsForTask(DownloadTask task) {
    final filePath = task.filePath;
    if (filePath == null || filePath.trim().isEmpty) {
      return <String>{};
    }
    return _artifactPathsForStoredPath(filePath);
  }

  Set<String> _artifactPathsForStoredPath(String filePath) {
    final paths = <String>{filePath};
    if (filePath.endsWith('.part')) {
      paths.add(filePath.substring(0, filePath.length - 5));
    } else {
      paths.add('$filePath.part');
    }
    return paths;
  }

  String _pathKey(String value) {
    final normalized = p.normalize(value);
    if (Platform.isWindows) {
      return normalized.toLowerCase();
    }
    return normalized;
  }

  Future<void> _cleanupOrphanedSegmentDirectoriesOnStartup() async {
    try {
      final root = await _downloadsDir();
      if (!await root.exists()) {
        return;
      }

      final tasksResult = await _store.getAllTasks();
      final tasks = tasksResult.fold(
        onSuccess: (value) => value,
        onFailure: (_) => <DownloadTask>[],
      );

      final expectedSegmentDirs = <String>{};
      for (final task in tasks) {
        for (final path in _artifactPathsForTask(task)) {
          expectedSegmentDirs.add(_pathKey('${path}_segments'));
        }
      }

      var deletedCount = 0;
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! Directory) {
          continue;
        }
        if (!p.basename(entity.path).endsWith('_segments')) {
          continue;
        }
        final key = _pathKey(entity.path);
        if (expectedSegmentDirs.contains(key)) {
          continue;
        }
        try {
          await entity.delete(recursive: true);
          deletedCount++;
        } on FileSystemException {
          // Best-effort startup cleanup.
        }
      }

      if (deletedCount > 0) {
        _log('Startup cleanup removed $deletedCount orphan segment dirs');
      }
    } catch (error, stack) {
      await dlLog.error(
        'Manager',
        'startup orphan segment cleanup failed',
        error,
        stack,
      );
    }
  }

  DownloadTask _copyTask(
    DownloadTask task, {
    DownloadStatus? status,
    Uri? sourceUrl,
    String? fileName,
    String? filePath,
    int? totalBytes,
    int? downloadedBytes,
    String? sourcePluginId,
    String? serverName,
    String? detectedHost,
    Map<String, String>? headers,
    bool? isHls,
    String? qualityLabel,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return DownloadTask(
      id: task.id,
      anilistId: task.anilistId,
      episodeNumber: task.episodeNumber,
      sourceUrl: sourceUrl ?? task.sourceUrl,
      status: status ?? task.status,
      createdAt: task.createdAt,
      fileName: fileName ?? task.fileName,
      filePath: filePath ?? task.filePath,
      totalBytes: totalBytes ?? task.totalBytes,
      downloadedBytes: downloadedBytes ?? task.downloadedBytes,
      sourcePluginId: sourcePluginId ?? task.sourcePluginId,
      serverName: serverName ?? task.serverName,
      detectedHost: detectedHost ?? task.detectedHost,
      headers: headers ?? task.headers,
      isHls: isHls ?? task.isHls,
      animeTitle: task.animeTitle,
      qualityLabel: qualityLabel ?? task.qualityLabel,
      errorMessage: errorMessage,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Future<_ResolvedDownloadPaths> _resolveTargetPaths(DownloadTask task) async {
    final dir = await _animeDirFor(task);
    final finalFileName =
        task.fileName ??
        '${task.anilistId}_ep${task.episodeNumber.toInt().toString().padLeft(2, '0')}.mp4';
    final defaultFinalPath = p.join(dir.path, finalFileName);

    if (task.filePath == null || task.filePath!.trim().isEmpty) {
      return _ResolvedDownloadPaths(
        finalPath: defaultFinalPath,
        tempPath: '$defaultFinalPath.part',
        finalFileName: p.basename(defaultFinalPath),
      );
    }

    final storedPath = task.filePath!;
    if (storedPath.endsWith('.part')) {
      return _ResolvedDownloadPaths(
        finalPath: storedPath.substring(0, storedPath.length - 5),
        tempPath: storedPath,
        finalFileName: p.basename(
          storedPath.substring(0, storedPath.length - 5),
        ),
      );
    }

    final tempPath = '$storedPath.part';
    final storedFile = File(storedPath);
    final tempFile = File(tempPath);
    if (await storedFile.exists() &&
        !await tempFile.exists() &&
        task.status != DownloadStatus.completed) {
      await storedFile.rename(tempPath);
    }

    return _ResolvedDownloadPaths(
      finalPath: storedPath,
      tempPath: tempPath,
      finalFileName: p.basename(storedPath),
    );
  }

  Future<Directory> _downloadsDir() async {
    return _directoryService.resolveDownloadsDirectory();
  }

  Future<Directory> _animeDirFor(DownloadTask task) async {
    final base = await _downloadsDir();
    if (task.animeTitle == null || task.animeTitle!.trim().isEmpty) {
      return base;
    }
    final safe = task.animeTitle!
        .replaceAll(_unsafePathChars, '_')
        .replaceAll(_trailingDots, '')
        .trim();
    final dir = Directory(p.join(base.path, safe));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  void _emitStatusChange({
    required String taskId,
    int? anilistId,
    DownloadStatus? oldStatus,
    DownloadStatus? newStatus,
  }) {
    if (_disposed || _statusChangeController.isClosed) {
      return;
    }
    _statusChangeController.add(
      DownloadStatusChange(
        taskId: taskId,
        anilistId: anilistId,
        oldStatus: oldStatus,
        newStatus: newStatus,
      ),
    );
  }

  void _emitProgress(DownloadProgressEvent event) {
    if (_disposed || _progressController.isClosed) {
      return;
    }
    _latestProgressByTask[event.taskId] = event;
    if (_progressController.hasListener) {
      _progressController.add(event);
    }
    // Throttle aggregate recomputation — it iterates all active tasks.
    if (_aggregateProgressController.hasListener &&
        _aggregateThrottleSw.elapsedMilliseconds >= _aggregateThrottleMs) {
      _aggregateThrottleSw.reset();
      _emitAggregateProgress();
    }
  }

  void _removeProgress(String taskId) {
    if (_disposed) {
      return;
    }
    _latestProgressByTask.remove(taskId);
    if (_aggregateProgressController.hasListener) {
      _emitAggregateProgress();
    }
  }

  void _emitAggregateProgress() {
    if (_disposed || _aggregateProgressController.isClosed) {
      return;
    }
    if (!_aggregateProgressController.hasListener) {
      return;
    }
    if (_latestProgressByTask.isEmpty) {
      _aggregateProgressController.add(const DownloadAggregateProgress.empty());
      return;
    }

    var downloadedBytes = 0;
    var totalBytes = 0;
    var bytesPerSecond = 0;
    var tasksWithKnownTotal = 0;
    for (final event in _latestProgressByTask.values) {
      downloadedBytes += event.downloadedBytes;
      bytesPerSecond += event.bytesPerSecond;
      if (event.totalBytes > 0) {
        totalBytes += event.totalBytes;
        tasksWithKnownTotal++;
      }
    }

    final activeTasks = _latestProgressByTask.length;
    _aggregateProgressController.add(
      DownloadAggregateProgress(
        activeTasks: activeTasks,
        downloadedBytes: downloadedBytes,
        totalBytes: tasksWithKnownTotal > 0 ? totalBytes : 0,
        bytesPerSecond: bytesPerSecond,
      ),
    );

    if (activeTasks > 0) {
      unawaited(
        _foregroundService?.updateProgress(
          activeTasks: activeTasks,
          bytesPerSecond: bytesPerSecond,
          completedTasks: _sessionCompletedCount,
          totalTasks: _sessionTotalEnqueued,
        ),
      );
    } else {
      // Show completion notification before resetting counters.
      final completed = _sessionCompletedCount;
      final failed = _sessionFailedCount;
      unawaited(
        _foregroundService?.showCompletionNotification(
          completedCount: completed,
          failedCount: failed,
        ),
      );
      // Reset session counters when all downloads finish.
      _sessionCompletedCount = 0;
      _sessionTotalEnqueued = 0;
      _sessionFailedCount = 0;
      unawaited(_foregroundService?.stop());
    }
  }

  void _log(String message) {
    developer.log(message, name: 'kumoriya.download.Manager');
  }

  int _resolveParallelSegmentsPerDownload() {
    if (Platform.isAndroid) {
      return _activeDownloads.length >= 2 ? 4 : 6;
    }
    if (Platform.isWindows) {
      return _activeDownloads.length >= 2 ? 6 : 8;
    }
    return _activeDownloads.length >= 2 ? 4 : 6;
  }

  void _scheduleProgressPersistence(DownloadTask task) {
    _pendingProgressSnapshots[task.id] = task;
    if (!_progressWriteInFlight.add(task.id)) {
      return;
    }
    unawaited(_flushProgressPersistence(task.id));
  }

  Future<void> _flushProgressPersistence(String taskId) async {
    try {
      while (true) {
        final snapshot = _pendingProgressSnapshots.remove(taskId);
        if (snapshot == null) {
          return;
        }
        await _persistTaskSnapshot(snapshot);
      }
    } finally {
      _progressWriteInFlight.remove(taskId);
      if (_pendingProgressSnapshots.containsKey(taskId)) {
        _scheduleProgressPersistence(_pendingProgressSnapshots[taskId]!);
      }
    }
  }

  Future<void> _persistTaskSnapshot(DownloadTask task) {
    final previous = _taskWriteChains[task.id] ?? Future<void>.value();
    final next = previous
        .catchError((_) {})
        .then((_) => _store.updateTask(task))
        .then((_) {});
    _taskWriteChains[task.id] = next;
    return next.whenComplete(() {
      if (identical(_taskWriteChains[task.id], next)) {
        _taskWriteChains.remove(task.id);
      }
    });
  }

  void _clearScheduledProgressPersistence(String taskId) {
    _pendingProgressSnapshots.remove(taskId);
  }

  Future<void> _drainTaskWrites(String taskId) async {
    final chain = _taskWriteChains[taskId];
    if (chain == null) {
      return;
    }
    await chain.catchError((_) {});
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_foregroundService?.stop());
    for (final active in _activeDownloads.values) {
      active.cancel();
    }
    _activeDownloads.clear();
    _latestProgressByTask.clear();
    _reResolveAttempts.clear();
    _triedServersPerTask.clear();
    _insecureTlsHostsByTask.clear();
    _pendingProgressSnapshots.clear();
    _taskWriteChains.clear();
    _progressWriteInFlight.clear();
    _progressController.close();
    _aggregateProgressController.close();
    _statusChangeController.close();
    _httpClient.close();
    _insecureHttpClient?.close();
  }
}

class _ActiveDownload {
  _ActiveDownload({required this.taskId, required this.cancel});
  final String taskId;
  final void Function() cancel;
}

class _ResolvedDownloadPaths {
  const _ResolvedDownloadPaths({
    required this.finalPath,
    required this.tempPath,
    required this.finalFileName,
  });

  final String finalPath;
  final String tempPath;
  final String finalFileName;
}

class _RestartDownloadFromZeroException implements Exception {
  const _RestartDownloadFromZeroException();
}

class DownloadProgressEvent {
  const DownloadProgressEvent({
    required this.taskId,
    required this.downloadedBytes,
    required this.totalBytes,
    this.bytesPerSecond = 0,
    this.isComplete = false,
  });

  final String taskId;
  final int downloadedBytes;
  final int totalBytes;
  final int bytesPerSecond;
  final bool isComplete;

  double get fraction =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class DownloadAggregateProgress {
  const DownloadAggregateProgress({
    required this.activeTasks,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.bytesPerSecond,
  });

  const DownloadAggregateProgress.empty()
    : activeTasks = 0,
      downloadedBytes = 0,
      totalBytes = 0,
      bytesPerSecond = 0;

  final int activeTasks;
  final int downloadedBytes;
  final int totalBytes;
  final int bytesPerSecond;
}

class DownloadStatusChange {
  const DownloadStatusChange({
    required this.taskId,
    this.anilistId,
    this.oldStatus,
    this.newStatus,
  });
  final String taskId;
  final int? anilistId;

  /// Status before the change. Null for new tasks, global events, or unknown.
  final DownloadStatus? oldStatus;

  /// Status after the change. Null for deletions or global events.
  final DownloadStatus? newStatus;
}
