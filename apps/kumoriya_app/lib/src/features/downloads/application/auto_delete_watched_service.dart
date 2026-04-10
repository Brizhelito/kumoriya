import 'dart:developer' as developer;
import 'dart:io';

import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'download_manager_service.dart';

/// Delay options for auto-deleting watched downloads.
enum AutoDeleteDelay {
  never(null),
  immediately(0),
  after1Day(1),
  after3Days(3),
  after7Days(7),
  after14Days(14),
  after30Days(30);

  const AutoDeleteDelay(this.days);

  /// Number of days to wait after episode completion. `null` means disabled.
  final int? days;
}

/// Scans completed downloads and deletes those whose episodes have been
/// watched (watchState == completed) for at least the configured delay.
class AutoDeleteWatchedService {
  const AutoDeleteWatchedService({
    required DownloadStore downloadStore,
    required AnimeProgressStore progressStore,
    required DownloadManagerService downloadManager,
  }) : _downloadStore = downloadStore,
       _progressStore = progressStore,
       _downloadManager = downloadManager;

  final DownloadStore _downloadStore;
  final AnimeProgressStore _progressStore;
  final DownloadManagerService _downloadManager;

  /// Runs one cleanup pass. Returns the number of tasks deleted.
  Future<int> run(AutoDeleteDelay delay) async {
    if (delay == AutoDeleteDelay.never || delay.days == null) return 0;

    final tasksResult = await _downloadStore.getTasksByStatus(
      DownloadStatus.completed,
    );
    final tasks = tasksResult.fold(
      onSuccess: (list) => list,
      onFailure: (_) => <DownloadTask>[],
    );
    if (tasks.isEmpty) return 0;

    final now = DateTime.now();
    var deleted = 0;

    for (final task in tasks) {
      final progressResult = await _progressStore.getProgress(
        task.anilistId,
        task.episodeNumber,
      );
      final progress = progressResult.fold(
        onSuccess: (p) => p,
        onFailure: (_) => null,
      );
      if (progress == null || progress.watchState != WatchState.completed) {
        continue;
      }

      final completedAt = progress.updatedAt;
      final threshold = completedAt.add(Duration(days: delay.days!));
      if (now.isBefore(threshold)) continue;

      // Delete on-disk file first, then remove task from DB.
      if (task.filePath != null) {
        final file = File(task.filePath!);
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (e) {
            _log('failed to delete file ${task.filePath}: $e');
            continue;
          }
        }
      }

      await _downloadManager.deleteCompleted(task.id);
      deleted++;
      _log(
        'auto-deleted anime=${task.anilistId} ep=${task.episodeNumber} '
        'delay=${delay.days}d',
      );
    }

    return deleted;
  }

  void _log(String msg) {
    developer.log(msg, name: 'AutoDeleteWatchedService');
  }
}
