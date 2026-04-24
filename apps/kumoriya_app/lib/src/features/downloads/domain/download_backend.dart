import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../application/download_manager_service.dart';

/// Platform-agnostic contract for the download engine.
///
/// Android implements this via [NativeDownloadBackend] (MethodChannel →
/// Kotlin/OkHttp). Desktop implements it via [DartDownloadBackend] (wraps
/// the existing [DownloadManagerService]).
///
/// The UI layer, [EnqueueDownloadUseCase], [AutoDeleteWatchedService], and
/// [WifiOnlyModeNotifier] depend **only** on this interface — never on a
/// concrete backend.
abstract class DownloadBackend {
  // ── Task lifecycle ──────────────────────────────────────────────────

  Future<void> enqueue(DownloadTask task);
  Future<void> pause(String taskId);
  Future<void> resume(String taskId);

  /// Cancel semantics = delete. Removes the task, cleans up artifacts.
  Future<void> cancel(String taskId);

  Future<void> cancelAll();
  Future<void> pauseAll();
  Future<void> resumeAll();

  // ── Queue management ────────────────────────────────────────────────

  Future<void> retry(String taskId);
  Future<void> retryAllFailed();
  Future<void> clearQueue();

  // ── Completed ───────────────────────────────────────────────────────

  Future<void> deleteCompleted(String taskId);

  // ── Query ───────────────────────────────────────────────────────────

  Future<DownloadTask?> findTaskByEpisode(int anilistId, double episodeNumber);

  // ── Sync & restore ──────────────────────────────────────────────────

  /// Reconcile persisted state with the engine's truth (native state on
  /// Android, filesystem on desktop). Called on app startup.
  Future<void> restoreQueue();

  /// Verify completed downloads still exist on disk, clean orphans.
  Future<void> syncDownloadedLibrary();

  // ── Settings ────────────────────────────────────────────────────────

  Future<void> setWifiOnly(bool enabled);

  // ── Streams ─────────────────────────────────────────────────────────

  Stream<DownloadProgressEvent> get progressStream;
  Stream<DownloadStatusChange> get statusChangeStream;
  Stream<DownloadAggregateProgress> get aggregateProgressStream;

  // ── Lifecycle ───────────────────────────────────────────────────────

  void dispose();
}
