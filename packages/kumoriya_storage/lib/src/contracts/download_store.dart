import 'package:kumoriya_core/kumoriya_core.dart';

/// Lifecycle states a download task can be in.
///
/// [remuxing] is emitted by the native HLS pipeline while Media3's
/// Transformer transmuxes the concatenated `.ts` into the final `.mp4`
/// — no bytes are added to [DownloadTask.downloadedBytes] during this
/// phase, so the UI should treat it like "downloading, buffer at 100%".
enum DownloadStatus {
  pending,
  downloading,
  paused,
  remuxing,
  /// Network dropped mid-download (not a server error, not a user pause).
  /// Distinct from [paused] so the UI can show "Sin conexión" and from
  /// [failed] so the user doesn't feel punished for something outside
  /// their control. The native engine preserves partial bytes; a future
  /// NetworkMonitor auto-resumes when connectivity returns.
  disconnected,
  completed,
  failed,
}

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
    this.headers = const <String, String>{},
    this.isHls = false,
    this.animeTitle,
    this.qualityLabel,
    this.episodeTitle,
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

  /// HTTP headers required for downloading (referer, origin, etc.)
  final Map<String, String> headers;

  /// Whether this download is an HLS stream requiring segment download.
  final bool isHls;

  /// Human-readable anime title (used for folder name and UI display).
  final String? animeTitle;

  /// Stream quality label (e.g. "1080p", "720p").
  final String? qualityLabel;

  /// Human-readable episode title from the source.
  final String? episodeTitle;
}

abstract interface class DownloadStore {
  Future<Result<void, KumoriyaError>> insertTask(DownloadTask task);

  Future<Result<void, KumoriyaError>> updateTask(DownloadTask task);

  Future<Result<DownloadTask?, KumoriyaError>> getTask(String id);

  Future<Result<DownloadTask?, KumoriyaError>> getTaskByEpisode(
    int anilistId,
    double episodeNumber,
  );

  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId, {
    int? limit,
  });

  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status, {
    int? limit,
    bool ascending = true,
  });

  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<DownloadStatus> statuses, {
    int? limit,
    bool ascending = true,
  });

  Future<Result<List<DownloadTask>, KumoriyaError>> getAllTasks({int? limit});

  Future<Result<void, KumoriyaError>> deleteTask(String id);
}
