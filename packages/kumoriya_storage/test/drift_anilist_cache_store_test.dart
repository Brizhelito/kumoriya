import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftAnilistCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftAnilistCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  AnilistCacheEntry makeEntry({
    int anilistId = 100,
    DateTime? updatedAt,
    List<String>? genres = const ['Fantasy', 'Adventure'],
    bool genresNull = false,
  }) {
    return AnilistCacheEntry(
      anilistId: anilistId,
      titleRomaji: 'Frieren',
      titleEnglish: 'Frieren: Beyond Journey\'s End',
      titleNative: '葬送のフリーレン',
      coverImageUrl: 'https://img.example/cover.jpg',
      bannerImageUrl: 'https://img.example/banner.jpg',
      status: 'RELEASING',
      averageScore: 92,
      genres: genresNull ? null : genres,
      synopsis: 'A great anime.',
      format: 'TV',
      releaseYear: 2023,
      totalEpisodes: 28,
      updatedAt: updatedAt ?? DateTime(2025, 6, 1),
    );
  }

  group('DriftAnilistCacheStore', () {
    test('upsert and get cache entry', () async {
      final entry = makeEntry();
      final upsertResult = await store.upsert(entry);
      expect(upsertResult, isA<Success>());

      final getResult = await store.get(100);
      final saved =
          (getResult as Success<AnilistCacheEntry?, KumoriyaError>).value;
      expect(saved, isNotNull);
      expect(saved!.anilistId, 100);
      expect(saved.titleRomaji, 'Frieren');
      expect(saved.titleEnglish, 'Frieren: Beyond Journey\'s End');
      expect(saved.titleNative, '葬送のフリーレン');
      expect(saved.coverImageUrl, 'https://img.example/cover.jpg');
      expect(saved.status, 'RELEASING');
      expect(saved.averageScore, 92);
      expect(saved.genres, ['Fantasy', 'Adventure']);
      expect(saved.synopsis, 'A great anime.');
      expect(saved.format, 'TV');
      expect(saved.releaseYear, 2023);
      expect(saved.totalEpisodes, 28);
    });

    test('upsert overwrites existing entry', () async {
      await store.upsert(makeEntry(updatedAt: DateTime(2025, 1, 1)));
      await store.upsert(
        AnilistCacheEntry(
          anilistId: 100,
          titleRomaji: 'Frieren Updated',
          averageScore: 95,
          updatedAt: DateTime(2025, 6, 2),
        ),
      );

      final getResult = await store.get(100);
      final saved =
          (getResult as Success<AnilistCacheEntry?, KumoriyaError>).value!;
      expect(saved.titleRomaji, 'Frieren Updated');
      expect(saved.averageScore, 95);
    });

    test('get returns null for non-existent entry', () async {
      final getResult = await store.get(9999);
      final saved =
          (getResult as Success<AnilistCacheEntry?, KumoriyaError>).value;
      expect(saved, isNull);
    });

    test('remove deletes entry', () async {
      await store.upsert(makeEntry());
      final removeResult = await store.remove(100);
      expect(removeResult, isA<Success>());

      final getResult = await store.get(100);
      final saved =
          (getResult as Success<AnilistCacheEntry?, KumoriyaError>).value;
      expect(saved, isNull);
    });

    test('deleteOlderThan removes stale entries', () async {
      await store.upsert(
        makeEntry(anilistId: 1, updatedAt: DateTime(2024, 1, 1)),
      );
      await store.upsert(makeEntry(anilistId: 2, updatedAt: DateTime.now()));

      final result = await store.deleteOlderThan(const Duration(days: 180));
      final count = (result as Success<int, KumoriyaError>).value;
      expect(count, 1);

      final gone = await store.get(1);
      expect(
        (gone as Success<AnilistCacheEntry?, KumoriyaError>).value,
        isNull,
      );

      final kept = await store.get(2);
      expect(
        (kept as Success<AnilistCacheEntry?, KumoriyaError>).value,
        isNotNull,
      );
    });

    test('genres round-trip with null', () async {
      await store.upsert(makeEntry(anilistId: 300, genresNull: true));

      final getResult = await store.get(300);
      final saved =
          (getResult as Success<AnilistCacheEntry?, KumoriyaError>).value!;
      expect(saved.genres, isNull);
    });

    // ----- getRecent -----

    test('getRecent returns entries ordered by updatedAt desc', () async {
      await store.upsert(
        makeEntry(anilistId: 1, updatedAt: DateTime(2025, 1, 1)),
      );
      await store.upsert(
        makeEntry(anilistId: 2, updatedAt: DateTime(2025, 6, 1)),
      );
      await store.upsert(
        makeEntry(anilistId: 3, updatedAt: DateTime(2025, 3, 1)),
      );

      final result = await store.getRecent(limit: 10);
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.map((e) => e.anilistId).toList(), [2, 3, 1]);
    });

    test('getRecent respects limit and offset', () async {
      for (var i = 1; i <= 5; i++) {
        await store.upsert(
          makeEntry(anilistId: i, updatedAt: DateTime(2025, i, 1)),
        );
      }

      final result = await store.getRecent(limit: 2, offset: 1);
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      // Ordered desc by month: 5,4,3,2,1 → offset 1, limit 2 → [4, 3]
      expect(entries.map((e) => e.anilistId).toList(), [4, 3]);
    });

    // ----- getByStatus -----

    test('getByStatus filters by status', () async {
      await store.upsert(_entryWithStatus(1, 'RELEASING'));
      await store.upsert(_entryWithStatus(2, 'FINISHED'));
      await store.upsert(_entryWithStatus(3, 'RELEASING'));

      final result = await store.getByStatus('RELEASING');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.map((e) => e.anilistId).toSet(), {1, 3});
    });

    test('getByStatus returns empty list for no matches', () async {
      await store.upsert(_entryWithStatus(1, 'FINISHED'));

      final result = await store.getByStatus('NOT_YET_RELEASED');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries, isEmpty);
    });

    // ----- getByYearAndStatus -----

    test('getByYearAndStatus filters by year only', () async {
      await store.upsert(_entryWithYearStatus(1, 2024, 'RELEASING'));
      await store.upsert(_entryWithYearStatus(2, 2025, 'RELEASING'));
      await store.upsert(_entryWithYearStatus(3, 2025, 'FINISHED'));

      final result = await store.getByYearAndStatus(2025);
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.map((e) => e.anilistId).toSet(), {2, 3});
    });

    test('getByYearAndStatus filters by year and status', () async {
      await store.upsert(_entryWithYearStatus(1, 2025, 'RELEASING'));
      await store.upsert(_entryWithYearStatus(2, 2025, 'FINISHED'));
      await store.upsert(_entryWithYearStatus(3, 2024, 'RELEASING'));

      final result = await store.getByYearAndStatus(2025, status: 'RELEASING');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.length, 1);
      expect(entries.first.anilistId, 1);
    });

    // ----- searchByTitle -----

    test('searchByTitle matches romaji', () async {
      await store.upsert(_entryWithTitles(1, 'Frieren', null, null));
      await store.upsert(_entryWithTitles(2, 'Naruto', null, null));

      final result = await store.searchByTitle('frier');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.length, 1);
      expect(entries.first.anilistId, 1);
    });

    test('searchByTitle matches english title', () async {
      await store.upsert(_entryWithTitles(1, 'Romaji', 'Beyond Journey', null));

      final result = await store.searchByTitle('Journey');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.length, 1);
    });

    test('searchByTitle matches native title', () async {
      await store.upsert(_entryWithTitles(1, 'Romaji', null, '葬送のフリーレン'));

      final result = await store.searchByTitle('フリーレン');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries.length, 1);
    });

    test('searchByTitle returns empty for no match', () async {
      await store.upsert(_entryWithTitles(1, 'Frieren', 'Beyond', '葬送'));

      final result = await store.searchByTitle('Naruto');
      final entries =
          (result as Success<List<AnilistCacheEntry>, KumoriyaError>).value;
      expect(entries, isEmpty);
    });
  });
}

AnilistCacheEntry _entryWithStatus(int id, String status) {
  return AnilistCacheEntry(
    anilistId: id,
    titleRomaji: 'Title $id',
    status: status,
    updatedAt: DateTime(2025, 6, 1),
  );
}

AnilistCacheEntry _entryWithYearStatus(int id, int year, String status) {
  return AnilistCacheEntry(
    anilistId: id,
    titleRomaji: 'Title $id',
    status: status,
    releaseYear: year,
    averageScore: 80 + id,
    updatedAt: DateTime(2025, 6, 1),
  );
}

AnilistCacheEntry _entryWithTitles(
  int id,
  String romaji,
  String? english,
  String? native_,
) {
  return AnilistCacheEntry(
    anilistId: id,
    titleRomaji: romaji,
    titleEnglish: english,
    titleNative: native_,
    averageScore: 90,
    updatedAt: DateTime(2025, 6, 1),
  );
}
