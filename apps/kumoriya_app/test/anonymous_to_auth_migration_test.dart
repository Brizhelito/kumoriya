import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/sync/anonymous_to_auth_migration.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// In-memory [SyncService] stub that records whether `fullSync` was invoked
/// without performing any network I/O.
final class _FakeSyncService implements SyncService {
  bool fullSyncCalled = false;
  List<SyncQueueEntry>? queueSnapshotAtFullSync;
  final SyncQueueStore queueStore;

  _FakeSyncService(this.queueStore);

  @override
  Future<Result<void, KumoriyaError>> fullSync() async {
    fullSyncCalled = true;
    final pending = await queueStore.getPendingEntries();
    queueSnapshotAtFullSync = pending.fold(
      onSuccess: (e) => List.unmodifiable(e),
      onFailure: (_) => const <SyncQueueEntry>[],
    );
    return const Success(null);
  }

  @override
  Future<Result<SyncPushResult, KumoriyaError>> pushPending() async {
    return const Success(SyncPushResult(applied: 0, conflicts: []));
  }

  @override
  Future<Result<SyncPullResponse, KumoriyaError>> pullSince(DateTime since) {
    throw UnimplementedError();
  }

  @override
  Future<Result<SyncStatus, KumoriyaError>> getStatus() async {
    return const Success(SyncStatus.idle);
  }
}

void main() {
  late AppDatabase db;
  late DriftAnimeProgressStore progressStore;
  late DriftLibraryStore libraryStore;
  late DriftSyncQueueStore queueStore;
  late _FakeSyncService syncService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    progressStore = DriftAnimeProgressStore(db);
    libraryStore = DriftLibraryStore(db);
    queueStore = DriftSyncQueueStore(db);
    syncService = _FakeSyncService(queueStore);
  });

  tearDown(() async {
    await db.close();
  });

  test('migrate() drops residual queue entries from a previous session before '
      'enqueueing local data', () async {
    // Simulate a stale queue entry left over from a crashed logout of a
    // different user. This entry must NOT be pushed on the next login.
    await queueStore.enqueue(
      SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.libraryEntry,
        entityKey: jsonEncode({'anilistId': 404}),
        payload: jsonEncode({
          'anilist_id': 404,
          'is_favorite': true,
          'added_at': 1,
          'notify_new_episodes': false,
          'auto_download_new_episodes': false,
          'auto_download_audio_preference': 'none',
        }),
        createdAt: DateTime.now(),
        status: SyncQueueEntryStatus.pending,
      ),
    );

    // Seed fresh local data that DOES belong to the current user.
    await libraryStore.setFavorite(
      101,
      isFavorite: true,
      addedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final migration = AnonymousToAuthMigration(
      progressStore: progressStore,
      libraryStore: libraryStore,
      syncQueue: queueStore,
      syncService: syncService,
    );
    final result = await migration.migrate();
    expect(result.isSuccess, isTrue);

    // Stale entry (id=404) must be gone; only the fresh id=101 entry should
    // have been enqueued (and snapshot-captured by the fake sync service).
    final snapshot = syncService.queueSnapshotAtFullSync!;
    final keys = snapshot.map((e) => e.entityKey).toSet();
    expect(keys, contains(jsonEncode({'anilistId': 101})));
    expect(keys, isNot(contains(jsonEncode({'anilistId': 404}))));
  });

  test('migrate() still calls fullSync when there is no local data', () async {
    final migration = AnonymousToAuthMigration(
      progressStore: progressStore,
      libraryStore: libraryStore,
      syncQueue: queueStore,
      syncService: syncService,
    );
    final result = await migration.migrate();

    expect(result.isSuccess, isTrue);
    expect(syncService.fullSyncCalled, isTrue);
    expect(syncService.queueSnapshotAtFullSync, isEmpty);
  });
}
