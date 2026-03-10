import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftDownloadStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftDownloadStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  DownloadTask makeTask({
    String id = 'dl-1',
    int anilistId = 100,
    double episodeNumber = 1.0,
    DownloadStatus status = DownloadStatus.pending,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id,
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      sourceUrl: Uri.parse('https://example.com/stream.m3u8'),
      status: status,
      createdAt: DateTime(2025, 1, 1),
      sourcePluginId: 'jkanime',
      serverName: 'Streamwish',
      detectedHost: 'streamwish.to',
      errorMessage: errorMessage,
    );
  }

  group('DriftDownloadStore CRUD', () {
    test('insert and get task', () async {
      final task = makeTask();
      final insertResult = await store.insertTask(task);
      expect(insertResult, isA<Success>());

      final getResult = await store.getTask('dl-1');
      final saved = (getResult as Success<DownloadTask?, KumoriyaError>).value;
      expect(saved, isNotNull);
      expect(saved!.id, 'dl-1');
      expect(saved.anilistId, 100);
      expect(saved.episodeNumber, 1.0);
      expect(saved.status, DownloadStatus.pending);
      expect(saved.sourcePluginId, 'jkanime');
      expect(saved.serverName, 'Streamwish');
      expect(saved.detectedHost, 'streamwish.to');
    });

    test('update task status and progress', () async {
      await store.insertTask(makeTask());

      final updated = makeTask(status: DownloadStatus.downloading);
      await store.updateTask(updated);

      final getResult = await store.getTask('dl-1');
      final saved = (getResult as Success<DownloadTask?, KumoriyaError>).value!;
      expect(saved.status, DownloadStatus.downloading);
    });

    test('delete task', () async {
      await store.insertTask(makeTask());
      final deleteResult = await store.deleteTask('dl-1');
      expect(deleteResult, isA<Success>());

      final getResult = await store.getTask('dl-1');
      final saved = (getResult as Success<DownloadTask?, KumoriyaError>).value;
      expect(saved, isNull);
    });

    test('get returns null for non-existent task', () async {
      final getResult = await store.getTask('non-existent');
      final saved = (getResult as Success<DownloadTask?, KumoriyaError>).value;
      expect(saved, isNull);
    });
  });

  group('DriftDownloadStore queries', () {
    test('getTasksByAnime filters by anilistId', () async {
      await store.insertTask(makeTask(id: 'dl-1', anilistId: 100));
      await store.insertTask(
        makeTask(id: 'dl-2', anilistId: 100, episodeNumber: 2.0),
      );
      await store.insertTask(makeTask(id: 'dl-3', anilistId: 200));

      final result = await store.getTasksByAnime(100);
      final tasks =
          (result as Success<List<DownloadTask>, KumoriyaError>).value;
      expect(tasks.length, 2);
      expect(tasks.every((t) => t.anilistId == 100), isTrue);
    });

    test('getTasksByStatus filters by status', () async {
      await store.insertTask(
        makeTask(id: 'dl-1', status: DownloadStatus.pending),
      );
      await store.insertTask(
        makeTask(id: 'dl-2', status: DownloadStatus.completed),
      );
      await store.insertTask(
        makeTask(id: 'dl-3', status: DownloadStatus.pending),
      );

      final result = await store.getTasksByStatus(DownloadStatus.pending);
      final tasks =
          (result as Success<List<DownloadTask>, KumoriyaError>).value;
      expect(tasks.length, 2);
      expect(tasks.every((t) => t.status == DownloadStatus.pending), isTrue);
    });

    test('getAllTasks returns all', () async {
      await store.insertTask(makeTask(id: 'dl-1'));
      await store.insertTask(makeTask(id: 'dl-2'));
      await store.insertTask(makeTask(id: 'dl-3'));

      final result = await store.getAllTasks();
      final tasks =
          (result as Success<List<DownloadTask>, KumoriyaError>).value;
      expect(tasks.length, 3);
    });

    test('stores error message on failed task', () async {
      await store.insertTask(
        makeTask(
          id: 'dl-err',
          status: DownloadStatus.failed,
          errorMessage: 'Network timeout',
        ),
      );

      final getResult = await store.getTask('dl-err');
      final saved = (getResult as Success<DownloadTask?, KumoriyaError>).value!;
      expect(saved.status, DownloadStatus.failed);
      expect(saved.errorMessage, 'Network timeout');
    });
  });
}
