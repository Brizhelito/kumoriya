import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../manga_catalog/presentation/providers/manga_catalog_providers.dart';
import '../../../../shared/storage_providers.dart';
import '../../application/manga_download_manager.dart';
import '../../domain/manga_download_progress_event.dart';

/// Filesystem root for manga CBZs. Uses the application documents
/// directory by default — same approach as the anime download
/// directory service for the desktop in-process backend.
final mangaDownloadsRootDirProvider = Provider<Future<Directory> Function()>((
  ref,
) {
  return () async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'manga_downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  };
});

/// Singleton manager for manga downloads. Wired to the active manga
/// source plugin via the existing `mangaSourcePluginProvider`. When
/// more than one source plugin lands, lift this to a registry-based
/// resolver (the manager already accepts `MangaSourcePluginResolver`).
final mangaDownloadManagerProvider = Provider<MangaDownloadManager>((ref) {
  final store = ref.watch(mangaDownloadStoreProvider);
  final rootDirFn = ref.watch(mangaDownloadsRootDirProvider);
  final plugin = ref.watch(mangaSourcePluginProvider);

  final manager = MangaDownloadManager(
    store: store,
    downloadsRootDir: rootDirFn,
    pluginResolver: (sourceId) =>
        sourceId == plugin.manifest.id ? plugin : null,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// All download tasks, refreshed whenever the manager emits a status
/// transition. The UI watches this for the downloads list page.
final mangaDownloadTasksProvider =
    StreamProvider<Result<List<MangaDownloadTask>, KumoriyaError>>((ref) {
      final store = ref.watch(mangaDownloadStoreProvider);
      final manager = ref.watch(mangaDownloadManagerProvider);

      // Initial snapshot, then re-emit on every status change.
      Future<Result<List<MangaDownloadTask>, KumoriyaError>> read() =>
          store.getAllTasks();

      late final controller = ref.watch(_tasksControllerProvider);
      final sub = manager.statusStream.listen((_) async {
        controller.add(await read());
      });
      ref.onDispose(sub.cancel);

      // Seed the stream with the current snapshot.
      // ignore: discarded_futures
      read().then(controller.add);

      return controller.stream;
    });

/// Internal: a broadcast stream controller that survives provider
/// rebuilds while the user navigates between tabs.
final _tasksControllerProvider =
    Provider<
      _BroadcastController<Result<List<MangaDownloadTask>, KumoriyaError>>
    >((ref) {
      final c =
          _BroadcastController<
            Result<List<MangaDownloadTask>, KumoriyaError>
          >();
      ref.onDispose(c.close);
      return c;
    });

/// Live progress for one specific task. Returns the latest snapshot
/// from the manager's progress stream; stays at zero when the task
/// has not started yet.
final mangaDownloadProgressProvider = StreamProvider.autoDispose
    .family<MangaDownloadProgressEvent, String>((ref, taskId) {
      final manager = ref.watch(mangaDownloadManagerProvider);
      return manager.progressStream.where((e) => e.taskId == taskId);
    });

/// Convenience: returns the current download task for a chapter, or
/// `null` if the user has never queued it. Recomputed on any status
/// change so the chapter row's icon stays accurate.
final mangaDownloadTaskByChapterProvider = StreamProvider.autoDispose
    .family<MangaDownloadTask?, _ChapterRefKey>((ref, key) async* {
      final store = ref.watch(mangaDownloadStoreProvider);
      final manager = ref.watch(mangaDownloadManagerProvider);

      Future<MangaDownloadTask?> snapshot() async {
        final r = await store.getTaskByChapter(
          mangaAnilistId: key.mangaAnilistId,
          sourceId: key.sourceId,
          sourceChapterId: key.sourceChapterId,
        );
        return r.fold(onSuccess: (v) => v, onFailure: (_) => null);
      }

      yield await snapshot();
      await for (final _ in manager.statusStream) {
        yield await snapshot();
      }
    });

class _ChapterRefKey {
  const _ChapterRefKey({
    required this.mangaAnilistId,
    required this.sourceId,
    required this.sourceChapterId,
  });

  final int mangaAnilistId;
  final String sourceId;
  final String sourceChapterId;

  @override
  bool operator ==(Object other) =>
      other is _ChapterRefKey &&
      other.mangaAnilistId == mangaAnilistId &&
      other.sourceId == sourceId &&
      other.sourceChapterId == sourceChapterId;

  @override
  int get hashCode => Object.hash(mangaAnilistId, sourceId, sourceChapterId);
}

/// Public constructor wrapped so the file can keep `_ChapterRefKey`
/// private while still letting widgets create instances inline.
// ignore: library_private_types_in_public_api
_ChapterRefKey chapterRefKey({
  required int mangaAnilistId,
  required String sourceId,
  required String sourceChapterId,
}) => _ChapterRefKey(
  mangaAnilistId: mangaAnilistId,
  sourceId: sourceId,
  sourceChapterId: sourceChapterId,
);

/// Tiny replayable broadcast controller. Behaves like a regular
/// `StreamController.broadcast()` but caches the last value so a new
/// listener does not have to wait for the next status transition to
/// see something.
class _BroadcastController<T> {
  T? _last;
  final _ctrl = StreamController<T>.broadcast(sync: false);

  void add(T value) {
    _last = value;
    if (!_ctrl.isClosed) _ctrl.add(value);
  }

  Stream<T> get stream async* {
    if (_last != null) yield _last as T;
    yield* _ctrl.stream;
  }

  void close() {
    if (!_ctrl.isClosed) _ctrl.close();
  }
}
