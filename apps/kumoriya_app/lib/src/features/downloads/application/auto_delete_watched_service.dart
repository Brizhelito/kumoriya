import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/download_backend.dart';

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

  /// Serialize to a string key for persistence.
  String get key => name;

  /// Deserialize from a string key. Returns [never] for unknown values.
  static AutoDeleteDelay fromKey(String? key) {
    if (key == null) return AutoDeleteDelay.never;
    for (final value in AutoDeleteDelay.values) {
      if (value.name == key) return value;
    }
    return AutoDeleteDelay.never;
  }
}

/// Persists the auto-delete delay preference in a JSON file under the
/// application support directory.
class AutoDeleteDelayStore {
  AutoDeleteDelayStore({Future<File> Function()? fileProvider})
    : _fileProvider = fileProvider ?? _defaultFile;

  final Future<File> Function() _fileProvider;

  Future<AutoDeleteDelay> read() async {
    try {
      final file = await _fileProvider();
      if (!file.existsSync()) return AutoDeleteDelay.never;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return AutoDeleteDelay.never;
      return AutoDeleteDelay.fromKey(json['auto_delete_delay'] as String?);
    } catch (_) {
      return AutoDeleteDelay.never;
    }
  }

  Future<void> write(AutoDeleteDelay delay) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'auto_delete_delay': delay.key}),
      flush: true,
    );
  }

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'kumoriya', 'auto_delete_settings.json'));
  }
}

/// Scans completed downloads and deletes those whose episodes have been
/// watched (watchState == completed) for at least the configured delay.
class AutoDeleteWatchedService {
  const AutoDeleteWatchedService({
    required DownloadStore downloadStore,
    required AnimeProgressStore progressStore,
    required DownloadBackend downloadManager,
  }) : _downloadStore = downloadStore,
       _progressStore = progressStore,
       _downloadManager = downloadManager;

  final DownloadStore _downloadStore;
  final AnimeProgressStore _progressStore;
  final DownloadBackend _downloadManager;

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
