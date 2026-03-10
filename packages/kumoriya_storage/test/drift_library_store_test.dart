import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftLibraryStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLibraryStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftLibraryStore', () {
    test('add and retrieve favorite', () async {
      final result = await store.setFavorite(100, isFavorite: true);
      expect(result, isA<Success>());

      final idsResult = await store.getFavoriteAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, contains(100));
    });

    test('remove favorite', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setFavorite(100, isFavorite: false);

      final idsResult = await store.getFavoriteAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, isNot(contains(100)));
    });

    test('multiple favorites', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setFavorite(200, isFavorite: true);
      await store.setFavorite(300, isFavorite: true);

      final idsResult = await store.getFavoriteAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, containsAll([100, 200, 300]));
    });

    test('setFavorite true is idempotent', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setFavorite(100, isFavorite: true);

      final idsResult = await store.getFavoriteAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids.length, 1);
      expect(ids, contains(100));
    });

    test('setFavorite false on non-existent is no-op', () async {
      final result = await store.setFavorite(999, isFavorite: false);
      expect(result, isA<Success>());
    });

    test('empty favorites returns empty set', () async {
      final idsResult = await store.getFavoriteAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, isEmpty);
    });
  });
}
