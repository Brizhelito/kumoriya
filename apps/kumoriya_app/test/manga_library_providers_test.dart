import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/storage_providers.dart';
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
    'favoriteMangaIdsProvider exposes ids written through the library store',
    () async {
      final store = container.read(mangaLibraryStoreProvider);
      await store.setFavorite(101, isFavorite: true);
      await store.setFavorite(202, isFavorite: true);
      await store.setFavorite(303, isFavorite: true);
      // Toggling off must remove the id from the favorites set.
      await store.setFavorite(303, isFavorite: false);

      container.invalidate(favoriteMangaIdsProvider);
      final result = await container.read(favoriteMangaIdsProvider.future);
      final ids = (result as Success<Set<int>, KumoriyaError>).value;

      expect(ids, equals(<int>{101, 202}));
    },
  );

  test(
    'subscribedMangaIdsProvider exposes ids written through the library store',
    () async {
      final store = container.read(mangaLibraryStoreProvider);
      await store.setSubscription(11, notify: true);
      await store.setSubscription(22, notify: true);

      container.invalidate(subscribedMangaIdsProvider);
      final result = await container.read(subscribedMangaIdsProvider.future);
      final ids = (result as Success<Set<int>, KumoriyaError>).value;

      expect(ids, equals(<int>{11, 22}));
    },
  );

  test('isFavoriteMangaProvider returns true only for favorited ids', () async {
    final store = container.read(mangaLibraryStoreProvider);
    await store.setFavorite(7, isFavorite: true);

    container.invalidate(favoriteMangaIdsProvider);
    final isFav7 = await container.read(isFavoriteMangaProvider(7).future);
    final isFav8 = await container.read(isFavoriteMangaProvider(8).future);

    expect(isFav7, isTrue);
    expect(isFav8, isFalse);
  });

  test('mangaRecentHistoryProvider returns rows ordered by recency', () async {
    final progress = container.read(mangaProgressStoreProvider);
    await progress.upsertReadHistory(
      mangaAnilistId: 101,
      chapterNumber: 1.0,
      lastSourceId: 'mangadex',
      lastSourceChapterId: 'ch-101-1',
      lastPageIndex: 0,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await progress.upsertReadHistory(
      mangaAnilistId: 202,
      chapterNumber: 3.5,
      lastSourceId: 'mangadex',
      lastSourceChapterId: 'ch-202-3.5',
      lastPageIndex: 12,
    );

    container.invalidate(mangaRecentHistoryProvider);
    final result = await container.read(mangaRecentHistoryProvider.future);
    final history =
        (result as Success<List<MangaReadHistory>, KumoriyaError>).value;

    expect(history, hasLength(2));
    expect(history.first.mangaAnilistId, 202);
    expect(history.first.lastChapterNumber, 3.5);
    expect(history.last.mangaAnilistId, 101);
  });
}
