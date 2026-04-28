import 'package:kumoriya_core/kumoriya_core.dart';

/// Lifecycle of a chapter download. `partial` is a soft state for
/// chapters that completed page-by-page but failed to package into a
/// CBZ — they remain resumable instead of being marked failed.
enum MangaDownloadStatus {
  pending,
  downloading,
  paused,
  packaging,
  disconnected,
  partial,
  completed,
  failed,
}

final class MangaDownloadTask {
  const MangaDownloadTask({
    required this.id,
    required this.mangaAnilistId,
    required this.sourceId,
    required this.sourceMangaId,
    required this.sourceChapterId,
    required this.chapterNumber,
    required this.status,
    required this.createdAt,
    this.volume,
    this.language = 'en',
    this.scanlator,
    this.mangaTitle,
    this.chapterTitle,
    this.pageCount,
    this.pagesDownloaded,
    this.totalBytes,
    this.downloadedBytes,
    this.cbzPath,
    this.errorMessage,
    this.updatedAt,
  });

  final String id;
  final int mangaAnilistId;
  final String sourceId;
  final String sourceMangaId;
  final String sourceChapterId;
  final double chapterNumber;
  final int? volume;
  final String language;
  final String? scanlator;
  final String? mangaTitle;
  final String? chapterTitle;
  final MangaDownloadStatus status;
  final int? pageCount;
  final int? pagesDownloaded;
  final int? totalBytes;
  final int? downloadedBytes;
  final String? cbzPath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

abstract interface class MangaDownloadStore {
  Future<Result<void, KumoriyaError>> insertTask(MangaDownloadTask task);

  Future<Result<void, KumoriyaError>> updateTask(MangaDownloadTask task);

  Future<Result<MangaDownloadTask?, KumoriyaError>> getTask(String id);

  Future<Result<MangaDownloadTask?, KumoriyaError>> getTaskByChapter({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
  });

  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getTasksByManga(
    int mangaAnilistId, {
    int? limit,
  });

  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getTasksByStatus(
    MangaDownloadStatus status, {
    int? limit,
    bool ascending = true,
  });

  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<MangaDownloadStatus> statuses, {
    int? limit,
    bool ascending = true,
  });

  Future<Result<List<MangaDownloadTask>, KumoriyaError>> getAllTasks({
    int? limit,
  });

  Future<Result<void, KumoriyaError>> deleteTask(String id);
}
