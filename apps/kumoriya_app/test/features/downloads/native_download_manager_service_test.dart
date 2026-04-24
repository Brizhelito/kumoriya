// Tests for the event-handling side of [NativeDownloadManagerService].
//
// We can not exercise the MethodChannel path without an Android engine, but
// the critical reactivity logic (state transitions, progress writes, cancel =
// delete) lives in `_applyStateTransition`, `_handleNativeEvent`'s cancelled
// branch and `_updateProgressInDrift`. Those are reachable by feeding events
// through the EventChannel mock, which is what this test does.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_manager_service.dart'
    show DownloadProgressEvent, DownloadStatusChange;
import 'package:kumoriya_app/src/features/downloads/application/native_download_manager_service.dart';
import 'package:kumoriya_app/src/shared/storage_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = 'dev.kumoriya.exoplayer/downloads/progress';
  const methodChannel = 'dev.kumoriya.exoplayer/downloads';

  late _InMemoryDownloadStore store;
  late ProviderContainer container;
  late NativeDownloadManagerService service;
  late StreamController<dynamic> eventsController;

  DownloadTask baseTask({
    String id = 'task-1',
    int anilist = 100,
    DownloadStatus status = DownloadStatus.pending,
  }) =>
      DownloadTask(
        id: id,
        anilistId: anilist,
        episodeNumber: 1.0,
        sourceUrl: Uri.parse('https://example.com/video.mp4'),
        status: status,
        createdAt: DateTime(2024, 1, 1),
      );

  setUp(() async {
    store = _InMemoryDownloadStore();
    container = ProviderContainer(
      overrides: [
        downloadStoreProvider.overrideWithValue(store),
      ],
    );

    // Intercept MethodChannel calls (enqueueDownload, cancelDownload, etc.) so
    // the service does not try to hit the native plugin during tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(methodChannel),
      (_) async => null,
    );

    // Mock the EventChannel so we can inject native events at will. The
    // EventChannel under the hood uses a MethodChannel named the same.
    eventsController = StreamController<dynamic>.broadcast();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(eventChannel),
      (call) async {
        if (call.method == 'listen') {
          eventsController.stream.listen((event) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              eventChannel,
              const StandardMethodCodec().encodeSuccessEnvelope(event),
              (_) {},
            );
          });
          return null;
        }
        if (call.method == 'cancel') {
          return null;
        }
        return null;
      },
    );

    final serviceProvider =
        Provider<NativeDownloadManagerService>((ref) => NativeDownloadManagerService(ref));
    service = container.read(serviceProvider);
    await service.initialize();
  });

  tearDown(() async {
    await eventsController.close();
    service.dispose();
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(methodChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(eventChannel), null);
  });

  test('state event flips pending → downloading and broadcasts the change',
      () async {
    await store.insertTask(baseTask());

    final changes = <DownloadStatusChange>[];
    final sub = service.statusStream.listen(changes.add);

    eventsController.add({
      'type': 'state',
      'taskId': 'task-1',
      'state': 2, // Media3 STATE_DOWNLOADING
      'downloadedBytes': 0,
      'totalBytes': 100,
    });

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(changes, isNotEmpty);
    expect(changes.first.newStatus, DownloadStatus.downloading);
    expect(changes.first.oldStatus, DownloadStatus.pending);

    final stored = await store.getTask('task-1');
    expect(stored.requireSuccess!.status, DownloadStatus.downloading);
  });

  test('progress event persists bytes while non-terminal', () async {
    await store.insertTask(
      baseTask(status: DownloadStatus.downloading),
    );

    final progress = <DownloadProgressEvent>[];
    final sub = service.progressStream.listen(progress.add);

    eventsController.add({
      'type': 'progress',
      'taskId': 'task-1',
      'downloadedBytes': 2 * 1024 * 1024, // 2 MB — above 1 MB threshold
      'totalBytes': 10 * 1024 * 1024,
    });

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(progress, hasLength(1));
    expect(progress.first.downloadedBytes, 2 * 1024 * 1024);

    final stored = await store.getTask('task-1');
    expect(stored.requireSuccess!.downloadedBytes, 2 * 1024 * 1024);
  });

  test('cancelled event deletes the task from Drift', () async {
    await store.insertTask(
      baseTask(status: DownloadStatus.downloading),
    );

    final changes = <DownloadStatusChange>[];
    final sub = service.statusStream.listen(changes.add);

    eventsController.add({'type': 'cancelled', 'taskId': 'task-1'});

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    final stored = await store.getTask('task-1');
    final storedTask = stored.requireSuccess;
    expect(storedTask, isNull);
    expect(changes.any((c) => c.newStatus == null && c.taskId == 'task-1'),
        isTrue);
  });

  test('state event with unchanged status only updates byte counts', () async {
    await store.insertTask(
      baseTask(status: DownloadStatus.downloading),
    );

    final changes = <DownloadStatusChange>[];
    final sub = service.statusStream.listen(changes.add);

    eventsController.add({
      'type': 'state',
      'taskId': 'task-1',
      'state': 2, // STATE_DOWNLOADING — same as current
      'downloadedBytes': 500,
      'totalBytes': 1000,
    });

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(changes, isEmpty); // No transition → no status change broadcast.
    final stored = await store.getTask('task-1');
    expect(stored.requireSuccess!.totalBytes, 1000);
  });
}

extension _SuccessOf<T> on Result<T?, KumoriyaError> {
  T? get requireSuccess => switch (this) {
        Success(value: final v) => v,
        Failure(error: final e) => throw StateError('expected success, got $e'),
      };
}

/// Minimal in-memory [DownloadStore] sufficient for the transition tests.
class _InMemoryDownloadStore implements DownloadStore {
  final Map<String, DownloadTask> _tasks = {};

  @override
  Future<Result<void, KumoriyaError>> insertTask(DownloadTask task) async {
    _tasks[task.id] = task;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> updateTask(DownloadTask task) async {
    _tasks[task.id] = task;
    return const Success(null);
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTask(String id) async {
    return Success(_tasks[id]);
  }

  @override
  Future<Result<DownloadTask?, KumoriyaError>> getTaskByEpisode(
    int anilistId,
    double episodeNumber,
  ) async {
    final match = _tasks.values
        .where((t) =>
            t.anilistId == anilistId && t.episodeNumber == episodeNumber)
        .firstOrNullSafe;
    return Success(match);
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId, {
    int? limit,
  }) async {
    final list = _tasks.values.where((t) => t.anilistId == anilistId).toList();
    return Success(limit == null ? list : list.take(limit).toList());
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatus(
    DownloadStatus status, {
    int? limit,
    bool ascending = true,
  }) async {
    final list = _tasks.values.where((t) => t.status == status).toList();
    return Success(limit == null ? list : list.take(limit).toList());
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByStatuses(
    List<DownloadStatus> statuses, {
    int? limit,
    bool ascending = true,
  }) async {
    final list =
        _tasks.values.where((t) => statuses.contains(t.status)).toList();
    return Success(limit == null ? list : list.take(limit).toList());
  }

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getAllTasks({
    int? limit,
  }) async {
    final list = _tasks.values.toList();
    return Success(limit == null ? list : list.take(limit).toList());
  }

  @override
  Future<Result<void, KumoriyaError>> deleteTask(String id) async {
    _tasks.remove(id);
    return const Success(null);
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNullSafe {
    final iter = iterator;
    return iter.moveNext() ? iter.current : null;
  }
}
