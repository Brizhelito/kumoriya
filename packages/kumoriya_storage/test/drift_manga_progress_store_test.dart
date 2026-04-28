import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftMangaProgressStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMangaProgressStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsert + getProgress round-trip', () async {
    final progress = MangaChapterProgress(
      mangaAnilistId: 1,
      sourceId: 'mangadex',
      sourceChapterId: 'c1',
      chapterNumber: 1,
      pageIndex: 7,
      scrollOffset: 1280.5,
      readState: MangaReadState.reading,
      updatedAt: DateTime(2026, 4, 28, 9),
    );
    await store.upsert(progress);

    final result =
        (await store.getProgress(
                  mangaAnilistId: 1,
                  sourceId: 'mangadex',
                  sourceChapterId: 'c1',
                )
                as Success<MangaChapterProgress?, KumoriyaError>)
            .value;
    expect(result, isNotNull);
    expect(result!.pageIndex, 7);
    expect(result.scrollOffset, 1280.5);
    expect(result.readState, MangaReadState.reading);
  });

  test('getLatestProgress returns most recently updated row', () async {
    await store.upsert(
      MangaChapterProgress(
        mangaAnilistId: 1,
        sourceId: 'mangadex',
        sourceChapterId: 'c1',
        chapterNumber: 1,
        updatedAt: DateTime(2026, 4, 27),
      ),
    );
    await store.upsert(
      MangaChapterProgress(
        mangaAnilistId: 1,
        sourceId: 'mangadex',
        sourceChapterId: 'c2',
        chapterNumber: 2,
        updatedAt: DateTime(2026, 4, 28),
      ),
    );

    final latest =
        (await store.getLatestProgress(1)
                as Success<MangaChapterProgress?, KumoriyaError>)
            .value!;
    expect(latest.sourceChapterId, 'c2');
  });

  test(
    'upsertReadHistory + getRecentHistory order by lastAccessedAt',
    () async {
      await store.upsertReadHistory(
        mangaAnilistId: 1,
        chapterNumber: 5,
        lastSourceId: 'mangadex',
        lastSourceChapterId: 'c5',
        lastAccessedAt: DateTime(2026, 4, 27),
      );
      await store.upsertReadHistory(
        mangaAnilistId: 2,
        chapterNumber: 8,
        lastAccessedAt: DateTime(2026, 4, 28),
      );

      final recent =
          (await store.getRecentHistory()
                  as Success<List<MangaReadHistory>, KumoriyaError>)
              .value;
      expect(recent.map((h) => h.mangaAnilistId), [2, 1]);
    },
  );

  test('clearAllProgress empties the progress table only', () async {
    await store.upsert(
      MangaChapterProgress(
        mangaAnilistId: 1,
        sourceId: 'mangadex',
        sourceChapterId: 'c1',
        chapterNumber: 1,
        updatedAt: DateTime.now(),
      ),
    );
    await store.upsertReadHistory(mangaAnilistId: 1, chapterNumber: 1);

    await store.clearAllProgress();

    expect(
      (await store.getAllProgress(1)
              as Success<List<MangaChapterProgress>, KumoriyaError>)
          .value,
      isEmpty,
    );
    expect(
      (await store.getRecentHistory()
              as Success<List<MangaReadHistory>, KumoriyaError>)
          .value,
      isNotEmpty,
    );
  });
}
