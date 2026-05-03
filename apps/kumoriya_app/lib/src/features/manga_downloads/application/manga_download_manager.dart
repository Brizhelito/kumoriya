import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import '../domain/cbz_packer.dart';
import '../domain/manga_download_progress_event.dart';

/// Resolves a [MangaDownloadTask] to its source plugin. Wired by the
/// app to the manga plugin registry; tests inject a fake mapping.
typedef MangaSourcePluginResolver =
    MangaSourcePlugin? Function(String sourceId);

const mangaDownloadSidecarSuffix = '.kumoriya.json';

/// In-process foreground manga download engine.
///
/// Owns one serial worker that drains pending tasks from
/// [MangaDownloadStore]. Per task:
///
/// 1. Resolves the [MangaSourcePlugin] via [pluginResolver].
/// 2. Reconstructs a [SourceChapter] from the task fields and asks the
///    plugin for the page list.
/// 3. Streams each page image to a temp directory with a small retry
///    budget per page.
/// 4. Hands the temp dir to [CbzPacker] which builds the final `.cbz`.
/// 5. Persists status transitions (`pending → downloading → packaging →
///    completed`) and emits progress events.
///
/// Concurrency: one download at a time. The next pending task is
/// picked up after the previous either completes, fails, or is
/// cancelled. Manga page downloads are I/O bound and serial keeps the
/// implementation predictable; horizontal scaling can come later if
/// users request it.
class MangaDownloadManager {
  MangaDownloadManager({
    required MangaDownloadStore store,
    required Future<Directory> Function() downloadsRootDir,
    required MangaSourcePluginResolver pluginResolver,
    http.Client? httpClient,
    int perPageRetries = 2,
  }) : _store = store,
       _downloadsRootDir = downloadsRootDir,
       _pluginResolver = pluginResolver,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _perPageRetries = perPageRetries.clamp(0, 5);

  final MangaDownloadStore _store;
  final Future<Directory> Function() _downloadsRootDir;
  final MangaSourcePluginResolver _pluginResolver;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final int _perPageRetries;

  final _progressController =
      StreamController<MangaDownloadProgressEvent>.broadcast();
  final _statusController =
      StreamController<MangaDownloadStatusEvent>.broadcast();

  /// Tasks the user has explicitly cancelled. Checked at every page
  /// boundary so an in-flight download stops at the next page.
  final _cancelled = <String>{};

  bool _processing = false;
  bool _disposed = false;

  Stream<MangaDownloadProgressEvent> get progressStream =>
      _progressController.stream;
  Stream<MangaDownloadStatusEvent> get statusStream => _statusController.stream;

  // ── Public API ─────────────────────────────────────────────────────

  /// Adds a new task and immediately starts the worker if idle.
  /// Returns the persisted task on success.
  Future<Result<MangaDownloadTask, KumoriyaError>> enqueue(
    MangaDownloadTask task,
  ) async {
    final existing = await _store.getTask(task.id);
    final found = existing.fold(onSuccess: (v) => v, onFailure: (_) => null);
    if (found != null) return Success(found);

    final result = await _store.insertTask(task);
    if (result.isFailure) {
      return Failure((result as Failure<void, KumoriyaError>).error);
    }
    _emitStatus(task.id, task.status);
    unawaited(_drainQueue());
    return Success(task);
  }

  /// Marks the task as cancelled. If it is the active download, the
  /// worker stops at the next page boundary.
  Future<void> cancel(String taskId) async {
    _cancelled.add(taskId);
    final task = await _readTask(taskId);
    if (task == null) return;
    await _writeTask(
      task,
      status: MangaDownloadStatus.failed,
      errorMessage: 'cancelled',
    );
  }

  /// Deletes the task row and any CBZ on disk.
  Future<void> delete(String taskId) async {
    final task = await _readTask(taskId);
    _cancelled.add(taskId);
    if (task != null && task.cbzPath != null) {
      final f = File(task.cbzPath!);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {
          /* swallow */
        }
      }
      final sidecar = File(_sidecarPathForCbz(task.cbzPath!));
      if (await sidecar.exists()) {
        try {
          await sidecar.delete();
        } catch (_) {
          /* swallow */
        }
      }
    }
    await _store.deleteTask(taskId);
    _emitStatus(taskId, null, oldStatus: task?.status);
  }

  /// Clears the failed flag on a task and re-enqueues it for the
  /// worker. No-op if the task is not failed.
  Future<void> retry(String taskId) async {
    final task = await _readTask(taskId);
    if (task == null) return;
    if (task.status != MangaDownloadStatus.failed &&
        task.status != MangaDownloadStatus.partial) {
      return;
    }
    _cancelled.remove(taskId);
    await _writeTask(
      task,
      status: MangaDownloadStatus.pending,
      errorMessage: null,
    );
    unawaited(_drainQueue());
  }

  /// Convenience query — `null` when the chapter has never been queued.
  /// The completed task is returned with [MangaDownloadTask.cbzPath] set.
  Future<MangaDownloadTask?> findTaskByChapter({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  }) async {
    final result = await _store.getTaskByChapter(
      mangaAnilistId: mangaAnilistId,
      sourceId: sourceId,
      sourceChapterId: sourceChapterId,
    );
    return result.fold(onSuccess: (v) => v, onFailure: (_) => null);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    _progressController.close();
    _statusController.close();
  }

  // ── Worker ────────────────────────────────────────────────────────

  Future<void> _drainQueue() async {
    if (_processing || _disposed) return;
    _processing = true;
    try {
      while (!_disposed) {
        final next = await _pickNextPending();
        if (next == null) break;
        await _runTask(next);
      }
    } finally {
      _processing = false;
    }
  }

  Future<MangaDownloadTask?> _pickNextPending() async {
    final pending = await _store.getTasksByStatus(
      MangaDownloadStatus.pending,
      limit: 1,
      ascending: true,
    );
    return pending.fold(
      onSuccess: (list) => list.isEmpty ? null : list.first,
      onFailure: (_) => null,
    );
  }

  Future<void> _runTask(MangaDownloadTask task) async {
    if (_cancelled.contains(task.id)) {
      await _writeTask(
        task,
        status: MangaDownloadStatus.failed,
        errorMessage: 'cancelled',
      );
      return;
    }

    final plugin = _pluginResolver(task.sourceId);
    if (plugin == null) {
      await _writeTask(
        task,
        status: MangaDownloadStatus.failed,
        errorMessage: 'manga_downloads.plugin_unavailable',
      );
      return;
    }

    await _writeTask(task, status: MangaDownloadStatus.downloading);

    // ── 1. Resolve pages ───────────────────────────────────────────
    final source = SourceChapter(
      sourceMangaId: task.sourceMangaId,
      sourceChapterId: task.sourceChapterId,
      number: task.chapterNumber,
      volume: task.volume,
      language: task.language,
      scanlator: task.scanlator,
      title: task.chapterTitle,
    );
    final pagesResult = await plugin.getChapterPages(source);
    if (pagesResult.isFailure) {
      await _writeTask(
        task,
        status: MangaDownloadStatus.failed,
        errorMessage: (pagesResult as Failure).error.code,
      );
      return;
    }
    final pages =
        (pagesResult as Success<List<SourcePage>, KumoriyaError>).value;
    if (pages.isEmpty) {
      await _writeTask(
        task,
        status: MangaDownloadStatus.failed,
        errorMessage: 'manga_downloads.empty_chapter',
      );
      return;
    }

    // Persist total page count for the UI.
    var current = task;
    current = await _writeTask(
      current,
      status: MangaDownloadStatus.downloading,
      pageCount: pages.length,
      pagesDownloaded: 0,
    );
    _emitProgress(current);

    // ── 2. Fetch each page ─────────────────────────────────────────
    final tmpDir = await _ensureTmpDir(task.id);
    final parts = <CbzPagePart>[];
    for (var i = 0; i < pages.length; i++) {
      if (_cancelled.contains(task.id)) {
        await _writeTask(
          current,
          status: MangaDownloadStatus.failed,
          errorMessage: 'cancelled',
        );
        return;
      }

      final page = pages[i];
      final ext = _extensionFor(page.imageUrl);
      final outFile = File(p.join(tmpDir.path, 'page_$i.$ext'));

      final ok = await _fetchPage(page, outFile);
      if (!ok) {
        await _writeTask(
          current,
          status: MangaDownloadStatus.failed,
          errorMessage: 'manga_downloads.page_fetch_failed',
        );
        return;
      }

      parts.add(
        CbzPagePart(pageIndex: i, localFile: outFile, fileExtension: ext),
      );
      current = await _writeTask(current, pagesDownloaded: i + 1);
      _emitProgress(current);
    }

    // ── 3. Pack CBZ ────────────────────────────────────────────────
    current = await _writeTask(current, status: MangaDownloadStatus.packaging);
    final cbzPath = await _cbzPathFor(task);
    final cbzFile = File(cbzPath);
    await cbzFile.parent.create(recursive: true);
    final packResult = await CbzPacker.pack(
      targetCbzFile: cbzFile,
      pages: parts,
      metadata: <String, Object?>{
        'manga_anilist_id': task.mangaAnilistId,
        'manga_title': task.mangaTitle ?? '',
        'source_id': task.sourceId,
        'source_manga_id': task.sourceMangaId,
        'source_chapter_id': task.sourceChapterId,
        'chapter_number': task.chapterNumber,
        'chapter_title': task.chapterTitle ?? '',
        'language': task.language,
        'scanlator': task.scanlator ?? '',
        'page_count': pages.length,
      },
    );

    if (packResult.isFailure) {
      await _writeTask(
        current,
        status: MangaDownloadStatus.partial,
        errorMessage: (packResult as Failure).error.code,
      );
      return;
    }

    // Pack succeeded — drop the per-page tmp dir to reclaim space.
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {
      /* non-fatal */
    }

    final cbzSize = await cbzFile.length();
    final completedTask = await _writeTask(
      current,
      status: MangaDownloadStatus.completed,
      cbzPath: cbzPath,
      totalBytes: cbzSize,
      downloadedBytes: cbzSize,
      errorMessage: null,
    );
    await _writeSidecarManifest(completedTask, cbzFile);
  }

  // ── HTTP fetch with bounded retry ─────────────────────────────────

  Future<bool> _fetchPage(SourcePage page, File out) async {
    var attempts = 0;
    while (attempts <= _perPageRetries) {
      attempts++;
      try {
        final res = await _httpClient.get(page.imageUrl, headers: page.headers);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          await out.writeAsBytes(res.bodyBytes, flush: true);
          if (await out.length() > 0) return true;
        }
      } catch (_) {
        // Treat any error as transient and retry until budget exhausted.
      }
      // Linear backoff: 200ms, 400ms, 600ms… capped at 1s.
      final delayMs = (200 * attempts).clamp(0, 1000);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return false;
  }

  // ── Persistence helpers ───────────────────────────────────────────

  Future<MangaDownloadTask?> _readTask(String id) async {
    final r = await _store.getTask(id);
    return r.fold(onSuccess: (v) => v, onFailure: (_) => null);
  }

  /// Persists a partial update and returns the new task value. Fields
  /// not passed are kept as-is.
  Future<MangaDownloadTask> _writeTask(
    MangaDownloadTask current, {
    MangaDownloadStatus? status,
    int? pagesDownloaded,
    int? pageCount,
    int? totalBytes,
    int? downloadedBytes,
    String? cbzPath,
    Object? errorMessage = _unset,
  }) async {
    final next = MangaDownloadTask(
      id: current.id,
      mangaAnilistId: current.mangaAnilistId,
      sourceId: current.sourceId,
      sourceMangaId: current.sourceMangaId,
      sourceChapterId: current.sourceChapterId,
      chapterNumber: current.chapterNumber,
      volume: current.volume,
      language: current.language,
      scanlator: current.scanlator,
      mangaTitle: current.mangaTitle,
      chapterTitle: current.chapterTitle,
      status: status ?? current.status,
      pageCount: pageCount ?? current.pageCount,
      pagesDownloaded: pagesDownloaded ?? current.pagesDownloaded,
      totalBytes: totalBytes ?? current.totalBytes,
      downloadedBytes: downloadedBytes ?? current.downloadedBytes,
      cbzPath: cbzPath ?? current.cbzPath,
      errorMessage: identical(errorMessage, _unset)
          ? current.errorMessage
          : errorMessage as String?,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    await _store.updateTask(next);
    if (status != null && status != current.status) {
      _emitStatus(
        next.id,
        status,
        oldStatus: current.status,
        errorMessage: next.errorMessage,
      );
    }
    return next;
  }

  void _emitProgress(MangaDownloadTask task) {
    if (_progressController.isClosed) return;
    _progressController.add(
      MangaDownloadProgressEvent(
        taskId: task.id,
        status: task.status,
        pagesDownloaded: task.pagesDownloaded ?? 0,
        totalPages: task.pageCount ?? 0,
      ),
    );
  }

  void _emitStatus(
    String taskId,
    MangaDownloadStatus? status, {
    MangaDownloadStatus? oldStatus,
    String? errorMessage,
  }) {
    if (_statusController.isClosed) return;
    _statusController.add(
      MangaDownloadStatusEvent(
        taskId: taskId,
        oldStatus: oldStatus,
        newStatus: status,
        errorMessage: errorMessage,
      ),
    );
  }

  // ── Filesystem layout ─────────────────────────────────────────────

  Future<Directory> _ensureTmpDir(String taskId) async {
    final root = await _downloadsRootDir();
    final dir = Directory(p.join(root.path, '_tmp', taskId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _cbzPathFor(MangaDownloadTask task) async {
    final root = await _downloadsRootDir();
    // Filename uses opaque ids — human-readable titles live in
    // metadata.json. This avoids cross-platform filename pitfalls.
    final fileName =
        '${_sanitize(task.sourceId)}__${_sanitize(task.sourceChapterId)}.cbz';
    return p.join(root.path, task.mangaAnilistId.toString(), fileName);
  }

  Future<void> _writeSidecarManifest(
    MangaDownloadTask task,
    File cbzFile,
  ) async {
    final totalBytes = await cbzFile.length();
    final identityKey =
        '${task.mangaAnilistId}:${task.sourceId}:${task.sourceChapterId}';
    final manifest = <String, Object?>{
      'version': 1,
      'mediaKind': 'manga',
      'taskId': task.id,
      'identityKey': identityKey,
      'signature': sha256
          .convert(utf8.encode('$identityKey|${cbzFile.path}'))
          .toString(),
      'anilistId': task.mangaAnilistId,
      'mangaAnilistId': task.mangaAnilistId,
      'mangaTitle': task.mangaTitle,
      'sourceId': task.sourceId,
      'sourceMangaId': task.sourceMangaId,
      'sourceChapterId': task.sourceChapterId,
      'chapterNumber': task.chapterNumber,
      'chapterTitle': task.chapterTitle,
      'volume': task.volume,
      'language': task.language,
      'scanlator': task.scanlator,
      'pageCount': task.pageCount,
      'cbzPath': cbzFile.path,
      'fileName': p.basename(cbzFile.path),
      'totalBytes': totalBytes,
      'completedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
    };
    final sidecar = File(_sidecarPathForCbz(cbzFile.path));
    await sidecar.parent.create(recursive: true);
    await sidecar.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
  }

  static String _sidecarPathForCbz(String cbzPath) {
    return '$cbzPath$mangaDownloadSidecarSuffix';
  }

  /// Picks an extension based on the URL or falls back to `jpg`.
  static String _extensionFor(Uri url) {
    final last = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    final dot = last.lastIndexOf('.');
    if (dot < 0 || dot == last.length - 1) return 'jpg';
    final raw = last.substring(dot + 1).toLowerCase();
    // Filter to a small allowlist; unknown extensions become 'jpg'.
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'avif', 'gif'};
    return allowed.contains(raw) ? raw : 'jpg';
  }

  static String _sanitize(String input) {
    // Keep alnum, dash, underscore, dot. Replace the rest with `_` so
    // arbitrary source ids never break the filesystem.
    return input.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  // Sentinel: lets `_writeTask` distinguish "leave error untouched"
  // from "explicitly clear it".
  static const Object _unset = Object();
}
