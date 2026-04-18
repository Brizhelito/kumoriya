import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// Wipes every piece of local data that is scoped to the signed-in user
/// (favorites, subscriptions, auto-download prefs, per-episode progress,
/// watch history, playback preferences, and the pending sync queue) so that
/// when a new user signs in on the same device the previous user's data
/// cannot leak into the new account.
///
/// This class intentionally does not touch:
///   - Shared caches (AniList/Episode/Translation/SourceAvailability/AniSkip)
///     because those are not user-scoped.
///   - Downloaded media and their DB rows, because deleting files on disk
///     during logout is out of scope for this operation.
///   - Secure storage (tokens, lastSyncAt). Those are cleared separately by
///     [SecureTokenStore.clearAll] as part of the logout sequence.
final class LocalUserDataCleaner {
  LocalUserDataCleaner({
    required this.progressStore,
    required this.libraryStore,
    required this.syncQueue,
  });

  final AnimeProgressStore progressStore;
  final LibraryStore libraryStore;
  final SyncQueueStore syncQueue;

  /// Runs every wipe step sequentially. Failures are collected but the
  /// method keeps going so one failing store cannot prevent the rest from
  /// being cleared; the first failure (if any) is returned to the caller.
  Future<Result<void, KumoriyaError>> wipe() async {
    KumoriyaError? firstError;

    void capture(Result<void, KumoriyaError> r) {
      if (r.isFailure && firstError == null) {
        firstError = (r as Failure<void, KumoriyaError>).error;
      }
    }

    capture(await progressStore.clearAllProgress());
    capture(await progressStore.clearAllHistory());
    capture(await progressStore.clearAllPlaybackPreferences());
    capture(await libraryStore.clearAll());
    capture(await syncQueue.clearAll());

    if (firstError != null) {
      return Failure(firstError!);
    }
    return const Success(null);
  }
}
