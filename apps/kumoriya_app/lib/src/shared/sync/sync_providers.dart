import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

import '../auth/auth_providers.dart';
import '../storage_providers.dart';

const _apiBaseUrl = 'https://api.kumoriya.online';

final syncServiceProvider = Provider<SyncService>((ref) {
  final httpClient = ref.watch(authenticatedHttpClientProvider);
  final queueStore = ref.watch(syncQueueStoreProvider);
  final progressStore = ref.watch(animeProgressStoreProvider);
  final libraryStore = ref.watch(libraryStoreProvider);

  return HttpSyncService(
    httpClient: httpClient,
    queueStore: queueStore,
    progressStore: progressStore,
    libraryStore: libraryStore,
    baseUrl: _apiBaseUrl,
  );
});

final lastSyncAtProvider =
    AsyncNotifierProvider<LastSyncAtNotifier, DateTime?>(
  LastSyncAtNotifier.new,
);

class LastSyncAtNotifier extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() async {
    final store = ref.read(secureTokenStoreProvider);
    return store.loadLastSyncAt();
  }

  Future<void> setLastSyncAt(DateTime time) async {
    final store = ref.read(secureTokenStoreProvider);
    await store.saveLastSyncAt(time);
    state = AsyncData(time);
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  void set(SyncStatus value) {
    state = value;
  }
}

final syncTriggerProvider = Provider<SyncTrigger>((ref) {
  return SyncTrigger(ref);
});

/// Orchestrates sync push/pull cycle, respecting auth state.
class SyncTrigger {
  SyncTrigger(this._ref);

  final Ref _ref;

  Future<void> fullSync() async {
    final isAuth = _ref.read(isAuthenticatedProvider);
    if (!isAuth) return;

    _ref.read(syncStatusProvider.notifier).set(SyncStatus.pushing);

    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.fullSync();

    result.fold(
      onSuccess: (_) async {
        _ref.read(syncStatusProvider.notifier).set(SyncStatus.success);
        // Update lastSyncAt from the service's internal state.
        final statusResult = await syncService.getStatus();
        statusResult.fold(
          onSuccess: (_) {
            _ref.read(lastSyncAtProvider.notifier).setLastSyncAt(DateTime.now());
          },
          onFailure: (_) {},
        );
      },
      onFailure: (_) {
        _ref.read(syncStatusProvider.notifier).set(SyncStatus.failed);
      },
    );
  }

  Future<void> pushOnly() async {
    final isAuth = _ref.read(isAuthenticatedProvider);
    if (!isAuth) return;

    _ref.read(syncStatusProvider.notifier).set(SyncStatus.pushing);
    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.pushPending();
    result.fold(
      onSuccess: (_) {
        _ref.read(syncStatusProvider.notifier).set(SyncStatus.success);
      },
      onFailure: (_) {
        _ref.read(syncStatusProvider.notifier).set(SyncStatus.failed);
      },
    );
  }
}
