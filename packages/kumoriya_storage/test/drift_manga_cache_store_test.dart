import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftMangaCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMangaCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upserts and reads a manga cache entry', () async {
    final entry = MangaCacheEntry(
      anilistId: 105778,
      titleRomaji: 'Chainsaw Man',
      titleEnglish: 'Chainsaw Man',
      synonyms: const ['チェンソーマン'],
      coverImageUrl: 'https://example.test/cover.jpg',
      status: 'RELEASING',
      format: 'MANGA',
      countryOfOrigin: 'JP',
      originalLanguage: 'ja',
      releaseYear: 2018,
      totalChapters: null,
      totalVolumes: 18,
      averageScore: 86,
      popularity: 200000,
      genres: const ['Action', 'Horror'],
      tagsJson: '[{"name":"Demons","rank":80}]',
      synopsis: 'A young man who is also part chainsaw devil…',
      relationsJson: '[]',
      updatedAt: DateTime(2026, 4, 28, 9),
    );

    final upsertResult = await store.upsert(entry);
    expect(upsertResult, isA<Success<void, KumoriyaError>>());

    final readResult = await store.get(105778);
    final cached =
        (readResult as Success<MangaCacheEntry?, KumoriyaError>).value;
    expect(cached, isNotNull);
    expect(cached!.titleRomaji, 'Chainsaw Man');
    expect(cached.synonyms, contains('チェンソーマン'));
    expect(cached.totalVolumes, 18);
    expect(cached.totalChapters, isNull);
    expect(cached.countryOfOrigin, 'JP');
    expect(cached.originalLanguage, 'ja');
    expect(cached.genres, equals(const ['Action', 'Horror']));
    expect(cached.tagsJson, contains('Demons'));
    expect(cached.relationsJson, '[]');
  });

  test(
    'list-level upsert without relations does not clobber relations',
    () async {
      final detail = MangaCacheEntry(
        anilistId: 1,
        titleRomaji: 'Foo',
        relationsJson: '[{"id":2,"type":"SEQUEL","mediaKind":"MANGA"}]',
        updatedAt: DateTime(2026),
      );
      await store.upsert(detail);

      final listLevel = MangaCacheEntry(
        anilistId: 1,
        titleRomaji: 'Foo',
        // relationsJson omitted — list endpoints don't carry relations.
        updatedAt: DateTime(2026, 1, 2),
      );
      await store.upsert(listLevel);

      final reread =
          (await store.get(1) as Success<MangaCacheEntry?, KumoriyaError>)
              .value;
      expect(reread!.relationsJson, contains('SEQUEL'));
    },
  );

  test('search by title matches romaji/english/native', () async {
    await store.upsert(
      MangaCacheEntry(
        anilistId: 30002,
        titleRomaji: 'Berserk',
        titleEnglish: 'Berserk',
        titleNative: 'ベルセルク',
        averageScore: 95,
        updatedAt: DateTime(2026, 3, 1),
      ),
    );
    await store.upsert(
      MangaCacheEntry(
        anilistId: 30013,
        titleRomaji: 'One Piece',
        averageScore: 90,
        updatedAt: DateTime(2026, 3, 2),
      ),
    );

    final r =
        (await store.searchByTitle('berserk')
                as Success<List<MangaCacheEntry>, KumoriyaError>)
            .value;
    expect(r.map((e) => e.anilistId), [30002]);
  });

  test('deleteOlderThan removes stale entries', () async {
    await store.upsert(
      MangaCacheEntry(
        anilistId: 1,
        titleRomaji: 'Old',
        updatedAt: DateTime(2024, 1, 1),
      ),
    );
    await store.upsert(
      MangaCacheEntry(
        anilistId: 2,
        titleRomaji: 'Fresh',
        updatedAt: DateTime.now(),
      ),
    );
    final removed =
        (await store.deleteOlderThan(const Duration(days: 180))
                as Success<int, KumoriyaError>)
            .value;
    expect(removed, 1);
    final stale =
        (await store.get(1) as Success<MangaCacheEntry?, KumoriyaError>).value;
    expect(stale, isNull);
  });
}
