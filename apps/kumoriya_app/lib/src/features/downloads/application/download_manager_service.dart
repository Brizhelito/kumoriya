import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hls_segment_downloader.dart';

/// Manages a queue of episode downloads with configurable concurrency.
///
/// Downloads are HTTP-streamed to the local filesystem with progress tracked
/// in the [DownloadStore]. Supports pause, resume, cancel, and retry.
class DownloadManagerService {
  DownloadManagerService({
    required DownloadStore store,
    int maxConcurrent = 3,
    http.Client? httpClient,
  }) : _store = store,
       _maxConcurrent = maxConcurrent,
       _httpClient = httpClient ?? http.Client();

  final DownloadStore _store;
  final http.Client _httpClient;
  int _maxConcurrent;

  final _activeDownloads = <String, _ActiveDownload>{};
  final _progressController =
      StreamController<DownloadProgressEvent>.broadcast();

  /// Emits progress events for all active downloads.
  Stream<DownloadProgressEvent> get progressStream =>
      _progressController.stream;

  int get maxConcurrent => _maxConcurrent;
  set maxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 8);
    _processQueue();
  }

  /// Enqueue a new download task. If already in the queue (same id), no-op.
  Future<void> enqueue(DownloadTask task) async {
    final existing = await _store.getTask(task.id);
    if (existing.fold(onSuccess: (t) => t, onFailure: (_) => null) != null) {
      return;
    }
    await _store.insertTask(task);
    _processQueue();
  }

  /// Pause an active download.
  Future<void> pause(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    active?.cancel();
    await _updateStatus(taskId, DownloadStatus.paused);
    _processQueue();
  }

  /// Resume a paused or failed download.
  Future<void> resume(String taskId) async {
    await _updateStatus(taskId, DownloadStatus.pending);
    _processQueue();
  }

  /// Cancel and delete a download (removes file too).
  Future<void> cancel(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    active?.cancel();

    final taskResult = await _store.getTask(taskId);
    final task = taskResult.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task?.filePath != null) {
      final file = File(task!.filePath!);
      if (await file.exists()) await file.delete();
    }

    await _store.deleteTask(taskId);
    _processQueue();
  }

  /// Retry a failed download.
  Future<void> retry(String taskId) async => resume(taskId);

  /// Delete a completed download (removes file + DB row).
  Future<void> deleteCompleted(String taskId) async {
    final taskResult = await _store.getTask(taskId);
    final task = taskResult.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task?.filePath != null) {
      final file = File(task!.filePath!);
      if (await file.exists()) await file.delete();
    }
    await _store.deleteTask(taskId);
  }

  /// Re-enqueue all pending/paused downloads from DB (call on app start).
  Future<void> restoreQueue() async {
    _processQueue();
  }

  /// Process the queue: start downloads up to [_maxConcurrent].
  Future<void> _processQueue() async {
    if (_activeDownloads.length >= _maxConcurrent) return;

    final pendingResult = await _store.getTasksByStatus(DownloadStatus.pending);
    final pending = pendingResult.fold(
      onSuccess: (t) => t,
      onFailure: (_) => <DownloadTask>[],
    );

    for (final task in pending) {
      if (_activeDownloads.length >= _maxConcurrent) break;
      if (_activeDownloads.containsKey(task.id)) continue;
      _startDownload(task);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    await _updateStatus(task.id, DownloadStatus.downloading);

    final cancelCompleter = Completer<void>();
    _activeDownloads[task.id] = _ActiveDownload(
      taskId: task.id,
      cancel: () {
        if (!cancelCompleter.isCompleted) cancelCompleter.complete();
      },
    );

    try {
      final dir = await _downloadsDir();
      final ext = task.isHls
          ? '.ts'
          : (task.fileName?.split('.').last ?? 'mp4');
      final sanitizedName =
          task.fileName ??
          '${task.anilistId}_ep${task.episodeNumber}.${ext.replaceAll('.', '')}';
      final filePath = p.join(dir.path, sanitizedName);

      if (task.isHls) {
        await _downloadHls(task, filePath, cancelCompleter.future);
      } else {
        await _downloadDirect(task, filePath, cancelCompleter.future);
      }

      if (cancelCompleter.isCompleted) {
        _activeDownloads.remove(task.id);
        return;
      }

      // Mark completed — get the final file size.
      final file = File(filePath);
      final fileSize = await file.exists() ? await file.length() : 0;

      await _store.updateTask(
        DownloadTask(
          id: task.id,
          anilistId: task.anilistId,
          episodeNumber: task.episodeNumber,
          sourceUrl: task.sourceUrl,
          status: DownloadStatus.completed,
          createdAt: task.createdAt,
          fileName: sanitizedName,
          filePath: filePath,
          totalBytes: fileSize,
          downloadedBytes: fileSize,
          sourcePluginId: task.sourcePluginId,
          serverName: task.serverName,
          detectedHost: task.detectedHost,
          headers: task.headers,
          isHls: task.isHls,
          updatedAt: DateTime.now(),
        ),
      );

      _progressController.add(
        DownloadProgressEvent(
          taskId: task.id,
          downloadedBytes: fileSize,
          totalBytes: fileSize,
          isComplete: true,
        ),
      );

      _log('Download complete: ${task.id} ($fileSize bytes)');
    } catch (e) {
      _log('Download failed: ${task.id} error=$e');
      await _updateStatus(task.id, DownloadStatus.failed, errorMessage: '$e');
    } finally {
      _activeDownloads.remove(task.id);
      _processQueue();
    }
  }

  /// Direct HTTP download for non-HLS streams.
  Future<void> _downloadDirect(
    DownloadTask task,
    String filePath,
    Future<void> cancelFuture,
  ) async {
    final file = File(filePath);
    final request = http.Request('GET', task.sourceUrl);
    if (task.headers.isNotEmpty) {
      request.headers.addAll(task.headers);
    }
    final response = await _httpClient.send(request);

    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    var downloadedBytes = 0;

    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        if (Completer<void>().future == cancelFuture) break;
        // Check cancel using a non-blocking approach.
        var cancelled = false;
        cancelFuture.then((_) => cancelled = true);
        await Future<void>.delayed(Duration.zero);
        if (cancelled) break;

        sink.add(chunk);
        downloadedBytes += chunk.length;

        _progressController.add(
          DownloadProgressEvent(
            taskId: task.id,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          ),
        );

        if (downloadedBytes % (256 * 1024) < chunk.length) {
          await _updateProgress(
            task.id,
            task: task,
            filePath: filePath,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          );
        }
      }
    } finally {
      await sink.close();
    }
  }

  /// HLS download: parse m3u8 playlist, download .ts segments, concatenate.
  Future<void> _downloadHls(
    DownloadTask task,
    String filePath,
    Future<void> cancelFuture,
  ) async {
    final hlsDownloader = HlsSegmentDownloader(httpClient: _httpClient);
    await hlsDownloader.download(
      masterUrl: task.sourceUrl,
      outputPath: filePath,
      headers: task.headers,
      cancelSignal: cancelFuture,
      onProgress: (downloaded, total) {
        _progressController.add(
          DownloadProgressEvent(
            taskId: task.id,
            downloadedBytes: downloaded,
            totalBytes: total,
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(
    String taskId,
    DownloadStatus status, {
    String? errorMessage,
  }) async {
    final result = await _store.getTask(taskId);
    final task = result.fold(onSuccess: (t) => t, onFailure: (_) => null);
    if (task == null) return;

    await _store.updateTask(
      DownloadTask(
        id: task.id,
        anilistId: task.anilistId,
        episodeNumber: task.episodeNumber,
        sourceUrl: task.sourceUrl,
        status: status,
        createdAt: task.createdAt,
        fileName: task.fileName,
        filePath: task.filePath,
        totalBytes: task.totalBytes,
        downloadedBytes: task.downloadedBytes,
        sourcePluginId: task.sourcePluginId,
        serverName: task.serverName,
        detectedHost: task.detectedHost,
        headers: task.headers,
        isHls: task.isHls,
        errorMessage: errorMessage ?? task.errorMessage,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _updateProgress(
    String taskId, {
    required DownloadTask task,
    required String filePath,
    required int downloadedBytes,
    required int totalBytes,
  }) async {
    await _store.updateTask(
      DownloadTask(
        id: task.id,
        anilistId: task.anilistId,
        episodeNumber: task.episodeNumber,
        sourceUrl: task.sourceUrl,
        status: DownloadStatus.downloading,
        createdAt: task.createdAt,
        fileName: task.fileName,
        filePath: filePath,
        totalBytes: totalBytes > 0 ? totalBytes : null,
        downloadedBytes: downloadedBytes,
        sourcePluginId: task.sourcePluginId,
        serverName: task.serverName,
        detectedHost: task.detectedHost,
        headers: task.headers,
        isHls: task.isHls,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<Directory> _downloadsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'kumoriya', 'downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  void _log(String message) {
    developer.log(message, name: 'DownloadManagerService');
  }

  void dispose() {
    for (final active in _activeDownloads.values) {
      active.cancel();
    }
    _activeDownloads.clear();
    _progressController.close();
    _httpClient.close();
  }
}

class _ActiveDownload {
  _ActiveDownload({required this.taskId, required this.cancel});
  final String taskId;
  final void Function() cancel;
}

/// Emitted for each chunk of download progress.
class DownloadProgressEvent {
  const DownloadProgressEvent({
    required this.taskId,
    required this.downloadedBytes,
    required this.totalBytes,
    this.isComplete = false,
  });

  final String taskId;
  final int downloadedBytes;
  final int totalBytes;
  final bool isComplete;

  double get fraction =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}
