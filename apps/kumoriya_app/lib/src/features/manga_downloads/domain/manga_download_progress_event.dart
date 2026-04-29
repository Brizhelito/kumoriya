import 'package:kumoriya_storage/kumoriya_storage.dart';

/// Per-task progress signal emitted by [MangaDownloadManager.progressStream].
///
/// `pagesDownloaded` / `totalPages` are unified across the resolve,
/// fetch, and pack phases so the UI can show one continuous bar.
class MangaDownloadProgressEvent {
  const MangaDownloadProgressEvent({
    required this.taskId,
    required this.status,
    required this.pagesDownloaded,
    required this.totalPages,
  });

  final String taskId;
  final MangaDownloadStatus status;
  final int pagesDownloaded;
  final int totalPages;

  double get fraction => totalPages == 0 ? 0 : pagesDownloaded / totalPages;
}

/// Coarse-grained event stream entry describing a status transition.
/// UI listens to it to refresh task lists without re-querying every
/// time a progress tick fires.
class MangaDownloadStatusEvent {
  const MangaDownloadStatusEvent({
    required this.taskId,
    required this.newStatus,
    this.errorMessage,
  });

  final String taskId;
  final MangaDownloadStatus newStatus;
  final String? errorMessage;
}
