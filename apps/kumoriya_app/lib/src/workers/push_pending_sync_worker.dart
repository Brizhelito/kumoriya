import 'dart:developer' as developer;

import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

import '../shared/auth/authenticated_http_client.dart';
import '../shared/auth/secure_token_store.dart';

/// Workmanager task name for the periodic (and one-off expedited)
/// push-to-server worker that drains the sync queue even if the app is
/// backgrounded or killed.
///
/// Registered as:
/// - `registerPeriodicTask` with a 12h cadence as absolute fallback.
/// - `registerOneOffTask` by [SyncCoordinator.notifyAppPaused] when the
///   user sends the app to background with pending entries.
const kPushPendingSyncTask = 'kumoriya.push_pending_sync';

const _apiBaseUrl = 'https://api.kumoriya.online';

/// Runs a one-shot `pushPending` against the backend. Kept lean: does not
/// attempt a pull, does not touch caches, does not schedule dependent
/// work. The main isolate's [SyncCoordinator] handles the richer
/// fullSync on app resume.
///
/// Designed to run in the Workmanager isolate, hence builds its own
/// `SecureTokenStore` + `AuthenticatedHttpClient` without Riverpod.
Future<void> runPushPendingSyncWorker() async {
  final tokenStore = SecureTokenStore();
  final tokens = await tokenStore.loadTokens();
  final user = await tokenStore.loadUser();
  if (tokens == null || user == null) {
    // Anonymous session: nothing to push.
    return;
  }

  final db = await openAppDatabase();
  try {
    final httpClient = AuthenticatedHttpClient(
      tokenStore: tokenStore,
      baseUrl: _apiBaseUrl,
    );
    final queueStore = DriftSyncQueueStore(db);
    final progressStore = DriftAnimeProgressStore(db);
    final libraryStore = DriftLibraryStore(db);

    final syncService = HttpSyncService(
      httpClient: httpClient,
      queueStore: queueStore,
      progressStore: progressStore,
      libraryStore: libraryStore,
      baseUrl: _apiBaseUrl,
    );

    final result = await syncService.pushPending();
    result.fold(
      onSuccess: (r) {
        developer.log(
          'PushPendingSyncWorker: applied=${r.applied} '
          'conflicts=${r.conflicts.length}',
          name: 'PushPendingSyncWorker',
        );
      },
      onFailure: (e) {
        developer.log(
          'PushPendingSyncWorker: failed: ${e.message}',
          name: 'PushPendingSyncWorker',
        );
      },
    );
  } catch (e, st) {
    developer.log(
      'PushPendingSyncWorker: unexpected error: $e',
      name: 'PushPendingSyncWorker',
      error: e,
      stackTrace: st,
    );
  } finally {
    await db.close();
  }
}
