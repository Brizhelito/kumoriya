import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftMangaDownloadStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMangaDownloadStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  MangaDownloadTask task({
    required String id,
    MangaDownloadStatus status = MangaDownloadStatus.pending,
    DateTime? createdAt,
    String chapterId = 'c1',
  }) {
    return MangaDownloadTask(
      id: id,
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      sourceMangaId: 'm-1',
      sourceChapterId: chapterId,
      chapterNumber: 1,
      mangaTitle: 'Manga',
      chapterTitle: 'Chapter 1',
      status: status,
      createdAt: createdAt ?? DateTime(2026, 4, 28, 9),
    );
  }

  test('insert + getTask + getTaskByChapter round-trip', () async {
    await store.insertTask(task(id: 'a'));

    final byId =
        (await store.getTask('a') as Success<MangaDownloadTask?, KumoriyaError>)
            .value;
    expect(byId, isNotNull);

    final byChapter =
        (await store.getTaskByChapter(
                  mangaAnilistId: 1,
                  sourceId: 'mangadex',
                  sourceChapterId: 'c1',
                )
                as Success<MangaDownloadTask?, KumoriyaError>)
            .value;
    expect(byChapter!.id, 'a');
  });

  test('updateTask updates status and bytes', () async {
    await store.insertTask(task(id: 'a'));
    final updated = MangaDownloadTask(
      id: 'a',
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      sourceMangaId: 'm-1',
      sourceChapterId: 'c1',
      chapterNumber: 1,
      status: MangaDownloadStatus.downloading,
      pagesDownloaded: 5,
      pageCount: 20,
      downloadedBytes: 12345,
      totalBytes: 49382,
      createdAt: DateTime(2026, 4, 28, 9),
      updatedAt: DateTime(2026, 4, 28, 10),
    );
    await store.updateTask(updated);

    final read =
        (await store.getTask('a') as Success<MangaDownloadTask?, KumoriyaError>)
            .value!;
    expect(read.status, MangaDownloadStatus.downloading);
    expect(read.pagesDownloaded, 5);
    expect(read.downloadedBytes, 12345);
  });

  test('getTasksByStatus filters by status', () async {
    await store.insertTask(
      task(id: 'a', status: MangaDownloadStatus.completed),
    );
    await store.insertTask(
      task(id: 'b', chapterId: 'c2', status: MangaDownloadStatus.failed),
    );

    final failed =
        (await store.getTasksByStatus(MangaDownloadStatus.failed)
                as Success<List<MangaDownloadTask>, KumoriyaError>)
            .value;
    expect(failed.map((t) => t.id), ['b']);
  });

  test('getTasksByStatuses returns the union', () async {
    await store.insertTask(
      task(id: 'a', status: MangaDownloadStatus.completed),
    );
    await store.insertTask(
      task(id: 'b', chapterId: 'c2', status: MangaDownloadStatus.partial),
    );
    await store.insertTask(
      task(id: 'c', chapterId: 'c3', status: MangaDownloadStatus.failed),
    );

    final terminalish =
        (await store.getTasksByStatuses([
                  MangaDownloadStatus.completed,
                  MangaDownloadStatus.partial,
                ])
                as Success<List<MangaDownloadTask>, KumoriyaError>)
            .value;
    expect(terminalish.map((t) => t.id).toSet(), {'a', 'b'});
  });

  test('deleteTask removes the row', () async {
    await store.insertTask(task(id: 'a'));
    await store.deleteTask('a');
    expect(
      (await store.getTask('a') as Success<MangaDownloadTask?, KumoriyaError>)
          .value,
      isNull,
    );
  });
}
