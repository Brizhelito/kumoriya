import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/manga_download_store.dart';
import 'app_database.dart';
import 'daos/manga_download_dao.dart';

final class DriftMangaDownloadStore implements MangaDownloadStore {
  DriftMangaDownloadStore(AppDatabase db) : _dao = MangaDownloadDao(db);

  final MangaDownloadDao _dao;

  @override
  Future<Result<void, KumoriyaError>> insertTask(MangaDownloadTask task) async {
    try {
      await _dao.insertTask(_taskToCompanion(task));
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_insert_failed',
          message: 'Failed to insert manga download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> updateTask(MangaDownloadTask task) async {
    try {
      await _dao.updateTask(_taskToCompanion(task));
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_update_failed',
          message: 'Failed to update manga download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<MangaDownloadTask?, KumoriyaError>> getTask(String id) async {
    try {
      final row = await _dao.getTask(id);
      return Success(row != null ? _rowToTask(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_read_failed',
          message: 'Failed to read manga download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<MangaDownloadTask?, KumoriyaError>> getTaskByChapter({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  }) async {
    try {
      final row = await _dao.getTaskByChapter(
        mangaAnilistId: mangaAnilistId,
        sourceId: sourceId,
        sourceChapterId: sourceChapterId,
      );
      return Success(row != null ? _rowToTask(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_read_failed',
          message: 'Failed to read manga download by chapter: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getTasksByManga(
    int mangaAnilistId, {
    int? limit,
  }) async {
    try {
      final rows = await _dao.getTasksByManga(mangaAnilistId, limit: limit);
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_read_failed',
          message: 'Failed to read manga downloads by manga: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getTasksByStatus(
    MangaDownloadStatus status, {
    int? limit,
    bool ascending = true,
  }) async {
    try {
      final rows = await _dao.getTasksByStatus(
        status.name,
        limit: limit,
        ascending: ascending,
      );
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_read_failed',
          message: 'Failed to read manga downloads by status: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<MangaDownloadStatus> statuses, {
    int? limit,
    bool ascending = true,
  }) async {
    try {
      final rows = await _dao.getTasksByStatuses(
        statuses.map((s) => s.name).toList(),
        limit: limit,
        ascending: ascending,
      );
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_read_failed',
          message: 'Failed to read manga downloads by statuses: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getAllTasks({
    int? limit,
  }) async {
    try {
      final rows = await _dao.getAllTasks(limit: limit);
      return Success(rows.map(_rowToTask).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.manga_download_read_failed',
          message: 'Failed to read all manga downloads: $e',
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
          code: 'storage.manga_download_delete_failed',
          message: 'Failed to delete manga download task: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  MangaDownloadTableCompanion _taskToCompanion(MangaDownloadTask task) {
    return MangaDownloadTableCompanion(
      id: Value(task.id),
      mangaAnilistId: Value(task.mangaAnilistId),
      sourceId: Value(task.sourceId),
      sourceMangaId: Value(task.sourceMangaId),
      sourceChapterId: Value(task.sourceChapterId),
      chapterNumber: Value(task.chapterNumber),
      volume: Value(task.volume),
      language: Value(task.language),
      scanlator: Value(task.scanlator),
      mangaTitle: Value(task.mangaTitle),
      chapterTitle: Value(task.chapterTitle),
      status: Value(task.status.name),
      pageCount: Value(task.pageCount),
      pagesDownloaded: Value(task.pagesDownloaded),
      totalBytes: Value(task.totalBytes),
      downloadedBytes: Value(task.downloadedBytes),
      cbzPath: Value(task.cbzPath),
      errorMessage: Value(task.errorMessage),
      createdAt: Value(task.createdAt.millisecondsSinceEpoch),
      updatedAt: task.updatedAt != null
          ? Value(task.updatedAt!.millisecondsSinceEpoch)
          : const Value.absent(),
    );
  }

  MangaDownloadTask _rowToTask(MangaDownloadTableData row) {
    return MangaDownloadTask(
      id: row.id,
      mangaAnilistId: row.mangaAnilistId,
      sourceId: row.sourceId,
      sourceMangaId: row.sourceMangaId,
      sourceChapterId: row.sourceChapterId,
      chapterNumber: row.chapterNumber,
      volume: row.volume,
      language: row.language,
      scanlator: row.scanlator,
      mangaTitle: row.mangaTitle,
      chapterTitle: row.chapterTitle,
      status: MangaDownloadStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => MangaDownloadStatus.pending,
      ),
      pageCount: row.pageCount,
      pagesDownloaded: row.pagesDownloaded,
      totalBytes: row.totalBytes,
      downloadedBytes: row.downloadedBytes,
      cbzPath: row.cbzPath,
      errorMessage: row.errorMessage,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: row.updatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.updatedAt!)
          : null,
    );
  }
}
