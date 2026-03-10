import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'continueWatchingProvider returns persisted history in recency order',
    () async {
      final store = container.read(animeProgressStoreProvider);

      await store.upsertWatchHistory(
        anilistId: 101,
        episodeNumber: 1.0,
        positionSeconds: 120,
        totalDurationSeconds: 1440,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await store.upsertWatchHistory(
        anilistId: 202,
        episodeNumber: 3.0,
        positionSeconds: 600,
        totalDurationSeconds: 1440,
      );

      final result = await container.read(continueWatchingProvider.future);
      final history =
          (result as Success<List<AnimeWatchHistory>, KumoriyaError>).value;

      expect(history, hasLength(2));
      expect(history.first.anilistId, 202);
      expect(history.first.lastEpisodeNumber, 3.0);
      expect(history.first.progressFraction, closeTo(600 / 1440, 0.01));
      expect(history.last.anilistId, 101);
    },
  );

  test('continueWatchingProvider refreshes after invalidation', () async {
    final store = container.read(animeProgressStoreProvider);

    final initial = await container.read(continueWatchingProvider.future);
    expect(
      (initial as Success<List<AnimeWatchHistory>, KumoriyaError>).value,
      isEmpty,
    );

    await store.upsertWatchHistory(
      anilistId: 303,
      episodeNumber: 7.0,
      positionSeconds: 480,
      totalDurationSeconds: 1500,
      lastSourcePluginId: 'kumoriya.source.jkanime',
    );

    container.invalidate(continueWatchingProvider);
    final refreshed = await container.read(continueWatchingProvider.future);
    final history =
        (refreshed as Success<List<AnimeWatchHistory>, KumoriyaError>).value;

    expect(history, hasLength(1));
    expect(history.single.anilistId, 303);
    expect(history.single.lastSourcePluginId, 'kumoriya.source.jkanime');
    expect(history.single.lastPositionSeconds, 480);
  });
}
