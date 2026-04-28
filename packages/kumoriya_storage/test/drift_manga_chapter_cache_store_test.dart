import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftMangaChapterCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMangaChapterCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  MangaChapterCacheEntry chapter({
    required String chapterId,
    required double number,
    String language = 'en',
    String sourceMangaId = 'src-1',
    int mangaId = 100,
    String? scanlator,
  }) {
    return MangaChapterCacheEntry(
      sourceId: 'mangadex',
      sourceChapterId: chapterId,
      mangaAnilistId: mangaId,
      sourceMangaId: sourceMangaId,
      number: number,
      language: language,
      scanlator: scanlator,
      updatedAt: DateTime(2026, 4, 28, 9),
    );
  }

  test(
    'upsertAll inserts and listForManga returns ascending by number',
    () async {
      await store.upsertAll([
        chapter(chapterId: 'c2', number: 2),
        chapter(chapterId: 'c1', number: 1),
        chapter(chapterId: 'c1-5', number: 1.5),
      ]);

      final list =
          (await store.listForManga(100)
                  as Success<List<MangaChapterCacheEntry>, KumoriyaError>)
              .value;
      expect(list.map((c) => c.number), [1.0, 1.5, 2.0]);
    },
  );

  test('listForManga filters by language', () async {
    await store.upsertAll([
      chapter(chapterId: 'c1-en', number: 1, language: 'en'),
      chapter(chapterId: 'c1-es', number: 1, language: 'es'),
    ]);

    final en =
        (await store.listForManga(100, language: 'en')
                as Success<List<MangaChapterCacheEntry>, KumoriyaError>)
            .value;
    expect(en.map((c) => c.sourceChapterId), ['c1-en']);
    final es =
        (await store.listForManga(100, language: 'es')
                as Success<List<MangaChapterCacheEntry>, KumoriyaError>)
            .value;
    expect(es.map((c) => c.sourceChapterId), ['c1-es']);
  });

  test('replaceForManga deletes rows for the same (manga,source,sourceManga) '
      'triple but spares others', () async {
    await store.upsertAll([
      chapter(chapterId: 'a-1', number: 1, sourceMangaId: 'A'),
      chapter(chapterId: 'a-2', number: 2, sourceMangaId: 'A'),
      chapter(chapterId: 'b-1', number: 1, sourceMangaId: 'B'),
    ]);

    await store.replaceForManga(
      mangaAnilistId: 100,
      sourceId: 'mangadex',
      sourceMangaId: 'A',
      entries: [chapter(chapterId: 'a-3', number: 3, sourceMangaId: 'A')],
    );

    final remaining =
        (await store.listForManga(100)
                as Success<List<MangaChapterCacheEntry>, KumoriyaError>)
            .value;
    expect(remaining.map((c) => c.sourceChapterId).toSet(), {'a-3', 'b-1'});
  });

  test('preserves fractional chapter numbers exactly', () async {
    await store.upsertAll([chapter(chapterId: 'c12-5', number: 12.5)]);
    final c =
        (await store.get('mangadex', 'c12-5')
                as Success<MangaChapterCacheEntry?, KumoriyaError>)
            .value!;
    expect(c.number, 12.5);
  });
}
