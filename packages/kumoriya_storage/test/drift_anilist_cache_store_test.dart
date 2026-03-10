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
  });
}
