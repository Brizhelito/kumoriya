import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/sync/sync_coordinator.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _FakeConnectivity implements ConnectivityProbe {
  bool connected = true;
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnected => _controller.stream;

  @override
  Future<bool> get isConnected async => connected;

  void emit(bool value) {
    connected = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

final class _FakeSyncService implements SyncService {
  int pushCalls = 0;
  int fullSyncCalls = 0;
  int pullCalls = 0;
  bool failNextPush = false;
  DateTime? lastSyncAt;

  @override
  Future<Result<SyncPushResult, KumoriyaError>> pushPending() async {
    pushCalls++;
    if (failNextPush) {
      failNextPush = false;
      return Failure(
        SimpleError(
          code: 'x',
          message: 'boom',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
    return const Success(SyncPushResult(applied: 1, conflicts: []));
  }

  @override
  Future<Result<void, KumoriyaError>> fullSync() async {
    fullSyncCalls++;
    pushCalls++;
    return const Success(null);
  }

  @override
  Future<Result<SyncPullResponse, KumoriyaError>> pullSince(
    DateTime since,
  ) async {
    pullCalls++;
    lastSyncAt = DateTime.now();
    return Success(
      SyncPullResponse(
        serverTime: lastSyncAt!,
        episodeProgress: const [],
        watchHistory: const [],
        playbackPreferences: const [],
        libraryEntries: const [],
        durableUntil: const DurableUntil(),
      ),
    );
  }

  @override
  Future<Result<SyncStatus, KumoriyaError>> getStatus() async =>
      const Success(SyncStatus.idle);

  @override
  Future<Result<DateTime?, KumoriyaError>> getLastSyncAt() async =>
      Success(lastSyncAt);

  @override
  void restoreLastSyncAt(DateTime? value) {
    lastSyncAt = value;
  }
}

final class _FakeQueueStore implements SyncQueueStore {
  int pending = 0;

  @override
  Future<Result<List<SyncQueueEntry>, KumoriyaError>> getPendingEntries() async {
    return Success(
      List.generate(
        pending,
        (i) => SyncQueueEntry(
          id: i,
          entityType: SyncEntityType.episodeProgress,
          entityKey: '$i',
          payload: '{}',
          createdAt: DateTime.now(),
          status: SyncQueueEntryStatus.pending,
        ),
      ),
    );
  }

  @override
  Future<Result<SyncQueueEntry, KumoriyaError>> enqueue(SyncQueueEntry entry) =>
      throw UnimplementedError();

  @override
  Future<Result<void, KumoriyaError>> updateStatus({
    required int id,
    required SyncQueueEntryStatus status,
    int? retryCount,
    String? lastError,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void, KumoriyaError>> deleteEntry(int id) =>
      throw UnimplementedError();

  @override
  Future<Result<void, KumoriyaError>> deleteEntries(List<int> ids) =>
      throw UnimplementedError();

  @override
  Future<Result<void, KumoriyaError>> clearSyncedEntries() =>
      throw UnimplementedError();

  @override
  Future<Result<void, KumoriyaError>> clearAll() async => const Success(null);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SyncCoordinator _buildCoordinator({
  required _FakeSyncService svc,
  required _FakeQueueStore queue,
  required _FakeConnectivity conn,
  bool authed = true,
  DateTime? lastSyncAt,
  Duration debounce = const Duration(milliseconds: 50),
  SchedulePushJob? schedulePushJob,
}) {
  return SyncCoordinator(
    syncService: svc,
    queueStore: queue,
    isAuthenticated: () => authed,
    loadLastSyncAt: () async => lastSyncAt,
    saveLastSyncAt: (_) async {},
    onDataRefreshed: () {},
    connectivity: conn,
    schedulePushJob: schedulePushJob,
    debounceWindow: debounce,
    backoffSteps: const [Duration(milliseconds: 300)],
  );
}

// ---------------------------------------------------------------------------

void main() {
  late _FakeSyncService svc;
  late _FakeQueueStore queue;
  late _FakeConnectivity conn;

  setUp(() {
    svc = _FakeSyncService();
    queue = _FakeQueueStore();
    conn = _FakeConnectivity();
  });

  tearDown(() async {
    await conn.close();
  });

  test('debounce coalesces multiple local writes into one push', () async {
    final c = _buildCoordinator(svc: svc, queue: queue, conn: conn);
    c.notifyLocalWrite();
    c.notifyLocalWrite();
    c.notifyLocalWrite();
    expect(svc.pushCalls, 0);
    await Future.delayed(const Duration(milliseconds: 120));
    expect(svc.pushCalls, 1);
    await c.dispose();
  });

  test('no-op when not authenticated', () async {
    final c = _buildCoordinator(
      svc: svc,
      queue: queue,
      conn: conn,
      authed: false,
    );
    c.notifyLocalWrite();
    await c.notifyAppResumed();
    await Future.delayed(const Duration(milliseconds: 120));
    expect(svc.pushCalls, 0);
    await c.dispose();
  });

  test('offline skip: no push when connectivity is none', () async {
    conn.connected = false;
    final c = _buildCoordinator(svc: svc, queue: queue, conn: conn);
    c.notifyLocalWrite();
    await Future.delayed(const Duration(milliseconds: 120));
    expect(svc.pushCalls, 0);
    await c.dispose();
  });

  test(
    'connectivity regained only fires when transitioning from offline',
    () async {
      final c = _buildCoordinator(svc: svc, queue: queue, conn: conn);
      conn.emit(false);
      await Future.delayed(const Duration(milliseconds: 10));
      conn.emit(true);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(svc.pushCalls, 1);
      // A second connected event without going offline first should not
      // retrigger.
      conn.emit(true);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(svc.pushCalls, 1);
      await c.dispose();
    },
  );

  test('resume fullSyncs when last sync is stale', () async {
    final stale = DateTime.now().subtract(const Duration(hours: 12));
    final c = _buildCoordinator(
      svc: svc,
      queue: queue,
      conn: conn,
      lastSyncAt: stale,
    );
    await c.notifyAppResumed();
    expect(svc.fullSyncCalls, 1);
    await c.dispose();
  });

  test(
    'resume pulls remote changes when fresh; pushes only if queue non-empty',
    () async {
      final recent = DateTime.now().subtract(const Duration(minutes: 1));
      queue.pending = 0;
      final c = _buildCoordinator(
        svc: svc,
        queue: queue,
        conn: conn,
        lastSyncAt: recent,
      );
      await c.notifyAppResumed();
      expect(svc.fullSyncCalls, 0);
      expect(svc.pullCalls, 1);
      expect(svc.pushCalls, 0);

      queue.pending = 3;
      await c.notifyAppResumed();
      // pull was very recent (<30s) so it's skipped; push fires.
      expect(svc.pullCalls, 1);
      expect(svc.pushCalls, 1);
      await c.dispose();
    },
  );

  test('triggerPull calls pullSince once and is re-entrant safe', () async {
    final c = _buildCoordinator(svc: svc, queue: queue, conn: conn);
    // Sequential calls each run (no reason to collapse).
    await c.triggerPull();
    await c.triggerPull();
    expect(svc.pullCalls, 2);
    // Overlapping in-flight calls DO collapse via the _pulling lock.
    final a = c.triggerPull();
    final b = c.triggerPull();
    await Future.wait([a, b]);
    expect(svc.pullCalls, 3);
    await c.dispose();
  });

  test('triggerPull is no-op when not authenticated', () async {
    final c = _buildCoordinator(
      svc: svc,
      queue: queue,
      conn: conn,
      authed: false,
    );
    await c.triggerPull();
    expect(svc.pullCalls, 0);
    await c.dispose();
  });

  test('flushBeforeLogout calls pushPending', () async {
    final c = _buildCoordinator(svc: svc, queue: queue, conn: conn);
    await c.flushBeforeLogout();
    expect(svc.pushCalls, 1);
    await c.dispose();
  });

  test('pause schedules job only when there are pending entries', () async {
    var scheduled = 0;
    final c = _buildCoordinator(
      svc: svc,
      queue: queue,
      conn: conn,
      schedulePushJob: () async {
        scheduled++;
      },
    );
    queue.pending = 0;
    await c.notifyAppPaused();
    expect(scheduled, 0);
    queue.pending = 2;
    await c.notifyAppPaused();
    expect(scheduled, 1);
    await c.dispose();
  });

  test('failure arms backoff; next debounced write waits it out', () async {
    svc.failNextPush = true;
    final c = _buildCoordinator(svc: svc, queue: queue, conn: conn);
    c.notifyLocalWrite();
    await Future.delayed(const Duration(milliseconds: 120));
    expect(svc.pushCalls, 1); // failed
    // Another write during backoff is deferred.
    c.notifyLocalWrite();
    await Future.delayed(const Duration(milliseconds: 120));
    // Debounce fired but backoff still active → no new push yet.
    expect(svc.pushCalls, 1);
    // Wait for backoff window to elapse (300ms total).
    await Future.delayed(const Duration(milliseconds: 350));
    expect(svc.pushCalls, 2);
    await c.dispose();
  });
}
