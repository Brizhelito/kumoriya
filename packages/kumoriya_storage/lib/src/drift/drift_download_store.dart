import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/download_store.dart';
import 'app_database.dart';
import 'daos/download_task_dao.dart';

final class DriftDownloadStore implements DownloadStore {
  DriftDownloadStore(AppDatabase db) : _dao = DownloadTaskDao(db);

  final DownloadTaskDao _dao;

  @override
  Future<Result<void, KumoriyaError>> insertTask(DownloadTask task) async {
    try {
      await _dao.insertTask(_taskToCompanion(task));
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_insert_failed',
          message: 'Failed to insert download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateTask(DownloadTask task) async {
    try {
      await _dao.updateTask(_taskToCompanion(task));
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_update_failed',
          message: 'Failed to update download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTask(String id) async {
    try {
      final row = await _dao.getTask(id);
      return Success(row != null ? _rowToTask(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_read_failed',
          message: 'Failed to read download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) async {
    try {
      final row = await _dao.getTaskByEpisode(anilistId, episodeNumber);
      return Success(row != null ? _rowToTask(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_read_failed',
          message: 'Failed to read download task by episode: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId, {
    int? limit,
  }) async {
    try {
      final rows = await _dao.getTasksByAnime(anilistId, limit: limit);
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_read_failed',
          message: 'Failed to read download tasks by anime: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status, {
    int? limit,
  }) async {
    try {
      final rows = await _dao.getTasksByStatus(status.name, limit: limit);
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_read_failed',
          message: 'Failed to read download tasks by status: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<DownloadStatus> statuses, {
    int? limit,
  }) async {
    try {
      final rows = await _dao.getTasksByStatuses(
        statuses.map((s) => s.name).toList(),
        limit: limit,
      );
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_read_failed',
          message: 'Failed to read download tasks by statuses: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getAllTasks({
    int? limit,
  }) async {
    try {
      final rows = await _dao.getAllTasks(limit: limit);
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_read_failed',
          message: 'Failed to read all download tasks: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteTask(String id) async {
    try {
      await _dao.deleteTask(id);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.download_delete_failed',
          message: 'Failed to delete download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  DownloadTaskTableCompanion _taskToCompanion(DownloadTask task) {
    return DownloadTaskTableCompanion(
      id: Value(task.id),
      anilistId: Value(task.anilistId),
      episodeNumber: Value(task.episodeNumber),
      sourceUrl: Value(task.sourceUrl.toString()),
      status: Value(task.status.name),
      fileName: Value(task.fileName),
      filePath: Value(task.filePath),
      totalBytes: Value(task.totalBytes),
      downloadedBytes: Value(task.downloadedBytes),
      sourcePluginId: Value(task.sourcePluginId),
      serverName: Value(task.serverName),
      detectedHost: Value(task.detectedHost),
      errorMessage: Value(task.errorMessage),
      createdAt: Value(task.createdAt.millisecondsSinceEpoch),
      updatedAt: task.updatedAt != null
          ? Value(task.updatedAt!.millisecondsSinceEpoch)
          : const Value.absent(),
      headers: Value(task.headers.isNotEmpty ? jsonEncode(task.headers) : null),
      isHls: Value(task.isHls),
      animeTitle: Value(task.animeTitle),
      qualityLabel: Value(task.qualityLabel),
      episodeTitle: Value(task.episodeTitle),
    );
  }

  DownloadTask _rowToTask(DownloadTaskTableData row) {
    Map<String, String> headers = const <String, String>{};
    if (row.headers != null) {
      try {
        final decoded = jsonDecode(row.headers!) as Map<String, dynamic>;
        headers = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        // Ignore malformed header JSON.
      }
    }

    Uri sourceUrl;
    try {
      sourceUrl = Uri.parse(row.sourceUrl);
    } catch (e) {
      throw FormatException(
        'Bad sourceUrl in DB for task "${row.id}": "${row.sourceUrl}" — $e',
      );
    }

    return DownloadTask(
      id: row.id,
      anilistId: row.anilistId,
      episodeNumber: row.episodeNumber,
      sourceUrl: sourceUrl,
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => DownloadStatus.pending,
      ),
      fileName: row.fileName,
      filePath: row.filePath,
      totalBytes: row.totalBytes,
      downloadedBytes: row.downloadedBytes,
      sourcePluginId: row.sourcePluginId,
      serverName: row.serverName,
      detectedHost: row.detectedHost,
      errorMessage: row.errorMessage,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: row.updatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.updatedAt!)
          : null,
      headers: headers,
      isHls: row.isHls ?? false,
      animeTitle: row.animeTitle,
      qualityLabel: row.qualityLabel,
      episodeTitle: row.episodeTitle,
    );
  }
}
