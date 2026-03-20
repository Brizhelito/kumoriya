import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as ioc;
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import 'download_directory_service.dart';
import 'download_library_index_service.dart';
import 'hls_segment_downloader.dart';

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

// Pre-compiled RegExp for safe file-name sanitization — avoids re-creating
// RegExp objects on every directory resolution call.
final _unsafePathChars = RegExp(r'[<>:"/\\|?*]');
final _trailingDots = RegExp(r'\.+$');

/// Creates an [http.Client] tuned for download throughput:
/// - Connection pool sized for parallel HLS segments.
/// - Disabled auto-decompression (segments are already compressed/binary).
/// - 15 s connection timeout to fail fast instead of hanging.
/// - 60 s idle timeout for connection reuse between segments.
http.Client _createDownloadHttpClient({int maxConnectionsPerHost = 16}) {
  final inner = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 60)
    ..maxConnectionsPerHost = maxConnectionsPerHost;
  return ioc.IOClient(inner);
}

int _defaultMaxConcurrentDownloads() {
  if (Platform.isAndroid) {
    return 2;
  }
  if (Platform.isWindows) {
    return 3;
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

class DownloadManagerService {
  DownloadManagerService({
    required DownloadStore store,
    required DownloadDirectoryService directoryService,
    required DownloadLibraryIndexService libraryIndexService,
    int? maxConcurrent,
    http.Client? httpClient,
    int maxRetryAttempts = 3,
  }) : _store = store,
       _directoryService = directoryService,
       _libraryIndexService = libraryIndexService,
       _maxConcurrent = (maxConcurrent ?? _defaultMaxConcurrentDownloads()),
       _httpClient =
           httpClient ??
           _createDownloadHttpClient(
             maxConnectionsPerHost: _defaultMaxConnectionsPerHost(),
           ),
       _maxRetryAttempts = maxRetryAttempts.clamp(1, 5);

  final DownloadStore _store;
  final DownloadDirectoryService _directoryService;
  final DownloadLibraryIndexService _libraryIndexService;
  final http.Client _httpClient;
  final int _maxRetryAttempts;
  int _maxConcurrent;

  final _activeDownloads = <String, _ActiveDownload>{};
  final _latestProgressByTask = <String, DownloadProgressEvent>{};
  final _progressController =
      StreamController<DownloadProgressEvent>.broadcast();
  final _aggregateProgressController =
      StreamController<DownloadAggregateProgress>.broadcast();
  final _statusChangeController =
      StreamController<DownloadStatusChange>.broadcast();

  /// Aggregate progress is expensive (iterates all tasks). Throttle to ~4 Hz.
  final _aggregateThrottleSw = Stopwatch()..start();
  static const _aggregateThrottleMs = 250;

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
        DownloadStatusChange(taskId: task.id, anilistId: task.anilistId),
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
    final existing = await _store.getTask(task.id);
    if (existing.fold(onSuccess: (value) => value, onFailure: (_) => null) !=
        null) {
      return;
    }
    await _store.insertTask(task);
    _statusChangeController.add(
      DownloadStatusChange(taskId: task.id, anilistId: task.anilistId),
    );
    unawaited(_processQueue());
  }

  Future<void> pause(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    active?.cancel();
    _removeProgress(taskId);
    await _updateStatus(taskId, DownloadStatus.paused);
  }

  Future<void> resume(String taskId) async {
    await clearTaskError(taskId);
    await _updateStatus(taskId, DownloadStatus.pending, errorMessage: null);
    await _processQueue();
  }

  Future<void> cancel(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    active?.cancel();
    _removeProgress(taskId);

    final taskResult = await _store.getTask(taskId);
    final task = taskResult.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task != null) {
      await _deleteTaskArtifacts(task);
    }

    await _store.deleteTask(taskId);
    _statusChangeController.add(
      DownloadStatusChange(taskId: taskId, anilistId: task?.anilistId),
    );
    unawaited(_processQueue());
  }

  Future<void> cancelAll() async {
    for (final active in _activeDownloads.values.toList()) {
      active.cancel();
    }
    _activeDownloads.clear();
    _latestProgressByTask.clear();
    _emitAggregateProgress();

    for (final status in [DownloadStatus.pending, DownloadStatus.downloading]) {
      final result = await _store.getTasksByStatus(status);
      final tasks = result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => <DownloadTask>[],
      );
      for (final task in tasks) {
        await _deleteTaskArtifacts(task);
        await _store.deleteTask(task.id);
      }
    }
    _statusChangeController.add(const DownloadStatusChange(taskId: ''));
  }

  Future<void> retry(String taskId) async => resume(taskId);

  Future<void> retryFailed(String taskId) async => resume(taskId);

  Future<void> deleteCompleted(String taskId) async {
    final taskResult = await _store.getTask(taskId);
    final task = taskResult.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task != null) {
      await _deleteTaskArtifacts(task);
    }
    await _store.deleteTask(taskId);
    _statusChangeController.add(
      DownloadStatusChange(taskId: taskId, anilistId: task?.anilistId),
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
    if (_processingQueue) {
      _pendingQueuePass = true;
      return;
    }
    _processingQueue = true;
    try {
      do {
        _pendingQueuePass = false;
        final pendingResult = await _store.getTasksByStatus(
          DownloadStatus.pending,
        );
        final pending = pendingResult.fold(
          onSuccess: (tasks) => tasks,
          onFailure: (_) => <DownloadTask>[],
        );

        for (final task in pending) {
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

    try {
      final target = await _resolveTargetPaths(task);
      final runningTask = _copyTask(
        task,
        status: DownloadStatus.downloading,
        fileName: target.finalFileName,
        filePath: target.tempPath,
        errorMessage: null,
      );
      await _store.updateTask(runningTask);
      _statusChangeController.add(
        DownloadStatusChange(taskId: task.id, anilistId: task.anilistId),
      );

      var finalPath = target.finalPath;
      var finalFileName = target.finalFileName;

      if (task.isHls) {
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
        await _downloadDirect(runningTask, target.tempPath, cancelCompleter);
      }

      if (cancelCompleter.isCompleted) {
        return;
      }

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
      _statusChangeController.add(
        DownloadStatusChange(taskId: task.id, anilistId: task.anilistId),
      );
      _log('Download complete: ${task.id} (${completedTask.totalBytes} bytes)');
    } catch (error) {
      _log('Download failed: ${task.id} error=$error');
      _removeProgress(task.id);
      await _updateStatus(
        task.id,
        DownloadStatus.failed,
        errorMessage: '$error',
      );
    } finally {
      _activeDownloads.remove(task.id);
      unawaited(_processQueue());
    }
  }

  Future<void> _downloadDirect(
    DownloadTask task,
    String tempPath,
    Completer<void> cancelCompleter,
  ) async {
    final tempFile = File(tempPath);
    await tempFile.parent.create(recursive: true);

    var existingBytes = 0;
    if (await tempFile.exists()) {
      existingBytes = await tempFile.length();
    }

    final response = await _sendDirectRequestWithRetries(
      task,
      offset: existingBytes,
    );

    final append = response.statusCode == 206 && existingBytes > 0;
    if (existingBytes > 0 && !append) {
      await tempFile.writeAsBytes(const <int>[], flush: true);
      existingBytes = 0;
    }

    final totalBytes = _resolveExpectedTotalBytes(response, existingBytes);
    var downloadedBytes = existingBytes;
    var bytesAtLastSample = existingBytes;
    var currentSpeed = 0;
    // Use Stopwatch instead of DateTime.now() — monotonic, cheaper syscall
    // on mobile (avoids repeated gettimeofday kernel calls per chunk).
    final sw = Stopwatch()..start();
    var lastSpeedMs = 0;
    var lastProgressMs = 0;
    var lastDbWriteMs = 0;
    var lastFlushMs = 0;

    final sink = tempFile.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.stream) {
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
        if (elapsedMs - lastProgressMs >= 350) {
          lastProgressMs = elapsedMs;
          _emitProgress(
            DownloadProgressEvent(
              taskId: task.id,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              bytesPerSecond: currentSpeed,
            ),
          );
        }

        // DB persistence (~0.5 Hz).
        if (elapsedMs - lastDbWriteMs >= 2000) {
          lastDbWriteMs = elapsedMs;
          unawaited(
            _store.updateTask(
              _copyTask(
                task,
                status: DownloadStatus.downloading,
                filePath: tempPath,
                totalBytes: totalBytes > 0 ? totalBytes : null,
                downloadedBytes: downloadedBytes,
              ),
            ),
          );
        }

        // Periodic flush prevents unbounded IOSink buffering on slow
        // mobile storage, reducing GC pressure from accumulated writes.
        if (elapsedMs - lastFlushMs >= 2000) {
          lastFlushMs = elapsedMs;
          await sink.flush();
        }
      }
    } finally {
      await sink.close();
    }
  }

  Future<HlsDownloadResult> _downloadHls(
    DownloadTask task,
    String tempPath,
    Completer<void> cancelCompleter,
  ) async {
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final hlsDownloader = HlsSegmentDownloader(
      httpClient: _httpClient,
      parallelSegments: _resolveParallelSegmentsPerDownload(),
      maxRetries: _maxRetryAttempts,
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

            if (resolvedTotalBytes > 0 && elapsedMs - lastDbWriteMs >= 2000) {
              lastDbWriteMs = elapsedMs;
              unawaited(
                _store.updateTask(
                  _copyTask(
                    task,
                    status: DownloadStatus.downloading,
                    filePath: tempPath,
                    totalBytes: resolvedTotalBytes,
                    downloadedBytes: downloadedBytes,
                  ),
                ),
              );
            }

            if (elapsedMs - lastProgressMs >= 350) {
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
    await _store.updateTask(completedTask);
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

        final response = await _httpClient
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200 || response.statusCode == 206) {
          return response;
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
        if (attempt == _maxRetryAttempts) {
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
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      final totalMatch = RegExp(r'/([0-9]+)$').firstMatch(contentRange);
      if (totalMatch != null) {
        return int.tryParse(totalMatch.group(1)!) ?? 0;
      }
    }
    if (response.statusCode == 206) {
      return existingBytes + (response.contentLength ?? 0);
    }
    return response.contentLength ?? 0;
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

  Future<void> _updateStatus(
    String taskId,
    DownloadStatus status, {
    String? errorMessage,
  }) async {
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

    await _store.updateTask(
      _copyTask(task, status: status, errorMessage: errorMessage),
    );
    _statusChangeController.add(
      DownloadStatusChange(taskId: taskId, anilistId: task.anilistId),
    );
  }

  Future<void> clearTaskError(String taskId) async {
    final result = await _store.getTask(taskId);
    final task = result.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (task == null || task.errorMessage == null) {
      return;
    }

    await _store.updateTask(
      _copyTask(task, errorMessage: null, updatedAt: DateTime.now()),
    );
    _statusChangeController.add(
      DownloadStatusChange(taskId: taskId, anilistId: task.anilistId),
    );
  }

  Future<void> _deleteTaskArtifacts(DownloadTask task) async {
    final paths = <String>{};
    if (task.filePath != null && task.filePath!.trim().isNotEmpty) {
      paths.add(task.filePath!);
      if (task.filePath!.endsWith('.part')) {
        paths.add(task.filePath!.substring(0, task.filePath!.length - 5));
      } else {
        paths.add('${task.filePath!}.part');
      }
    }

    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (task.filePath != null) {
      await _libraryIndexService.deleteManifestForMedia(
        task.filePath!.endsWith('.part')
            ? task.filePath!.substring(0, task.filePath!.length - 5)
            : task.filePath!,
      );
    }
  }

  DownloadTask _copyTask(
    DownloadTask task, {
    DownloadStatus? status,
    String? fileName,
    String? filePath,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return DownloadTask(
      id: task.id,
      anilistId: task.anilistId,
      episodeNumber: task.episodeNumber,
      sourceUrl: task.sourceUrl,
      status: status ?? task.status,
      createdAt: task.createdAt,
      fileName: fileName ?? task.fileName,
      filePath: filePath ?? task.filePath,
      totalBytes: totalBytes ?? task.totalBytes,
      downloadedBytes: downloadedBytes ?? task.downloadedBytes,
      sourcePluginId: task.sourcePluginId,
      serverName: task.serverName,
      detectedHost: task.detectedHost,
      headers: task.headers,
      isHls: task.isHls,
      animeTitle: task.animeTitle,
      qualityLabel: task.qualityLabel,
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

  void _emitProgress(DownloadProgressEvent event) {
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
    _latestProgressByTask.remove(taskId);
    if (_aggregateProgressController.hasListener) {
      _emitAggregateProgress();
    }
  }

  void _emitAggregateProgress() {
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

    _aggregateProgressController.add(
      DownloadAggregateProgress(
        activeTasks: _latestProgressByTask.length,
        downloadedBytes: downloadedBytes,
        totalBytes: tasksWithKnownTotal > 0 ? totalBytes : 0,
        bytesPerSecond: bytesPerSecond,
      ),
    );
  }

  void _log(String message) {
    developer.log(message, name: 'DownloadManagerService');
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

  void dispose() {
    for (final active in _activeDownloads.values) {
      active.cancel();
    }
    _activeDownloads.clear();
    _latestProgressByTask.clear();
    _progressController.close();
    _aggregateProgressController.close();
    _statusChangeController.close();
    _httpClient.close();
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
  const DownloadStatusChange({required this.taskId, this.anilistId});
  final String taskId;
  final int? anilistId;
}
