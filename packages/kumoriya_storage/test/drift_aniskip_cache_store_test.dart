import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftAniSkipCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftAniSkipCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upserts and reads AniSkip cache entries by episode', () async {
    final result = await store.upsert(
      AniSkipCacheRecord(
        anilistId: 321,
        episodeNumber: 7,
        payloadJson: '[{"kind":"opening","startMs":1000,"endMs":90000}]',
        updatedAt: DateTime(2026, 3, 19, 12),
        requestedEpisodeLengthSeconds: 1440,
      ),
    );

    expect(result, isA<Success<void, KumoriyaError>>());

    final readResult = await store.getEpisode(321, 7);
    final record =
        (readResult as Success<AniSkipCacheRecord?, KumoriyaError>).value;

    expect(record, isNotNull);
    expect(record!.anilistId, 321);
    expect(record.episodeNumber, 7);
    expect(record.requestedEpisodeLengthSeconds, 1440);
    expect(record.payloadJson, contains('"opening"'));
  });

  test('lists anime cache entries and deletes stale rows', () async {
    await store.upsert(
      AniSkipCacheRecord(
        anilistId: 777,
        episodeNumber: 1,
        payloadJson: '[]',
        updatedAt: DateTime(2024, 1, 1),
      ),
    );
    await store.upsert(
      AniSkipCacheRecord(
        anilistId: 777,
        episodeNumber: 2,
        payloadJson: '[]',
        updatedAt: DateTime.now(),
      ),
    );

    final listResult = await store.getEpisodesForAnime(777);
    final entries =
        (listResult as Success<List<AniSkipCacheRecord>, KumoriyaError>).value;
    expect(entries.map((entry) => entry.episodeNumber), <int>[1, 2]);

    final cleanupResult = await store.deleteOlderThan(
      const Duration(days: 180),
    );
    final deleted = (cleanupResult as Success<int, KumoriyaError>).value;
    expect(deleted, 1);

    final stale = await store.getEpisode(777, 1);
    expect(
      (stale as Success<AniSkipCacheRecord?, KumoriyaError>).value,
      isNull,
    );
    final fresh = await store.getEpisode(777, 2);
    expect(
      (fresh as Success<AniSkipCacheRecord?, KumoriyaError>).value,
      isNotNull,
    );
  });
}
