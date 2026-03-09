import 'package:kumoriya_core/kumoriya_core.dart';

enum DownloadStatus { pending, downloading, paused, completed, failed }

final class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.anilistId,
    required this.episodeNumber,
    required this.sourceUrl,
    required this.status,
    required this.createdAt,
    this.fileName,
    this.filePath,
    this.totalBytes,
    this.downloadedBytes,
    this.sourcePluginId,
    this.serverName,
    this.detectedHost,
    this.errorMessage,
    this.updatedAt,
  });

  final String id;
  final int anilistId;
  final double episodeNumber;
  final Uri sourceUrl;
  final DownloadStatus status;
  final DateTime createdAt;
  final String? fileName;
  final String? filePath;
  final int? totalBytes;
  final int? downloadedBytes;
  final String? sourcePluginId;
  final String? serverName;
  final String? detectedHost;
  final String? errorMessage;
  final DateTime? updatedAt;
}

abstract interface class DownloadStore {
  Future<Result<void, KumoriyaError>> insertTask(DownloadTask task);

  Future<Result<void, KumoriyaError>> updateTask(DownloadTask task);

  Future<Result<DownloadTask?, KumoriyaError>> getTask(String id);

  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId,
  );

  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status,
  );

  Future<Result<List<DownloadTask>, KumoriyaError>> getAllTasks();

  Future<Result<void, KumoriyaError>> deleteTask(String id);
}
