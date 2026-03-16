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

    // ─── Subscription tests ──────────────────────────────────────────────

    test('subscribe to a favorite', () async {
      await store.setFavorite(100, isFavorite: true);
      final result = await store.setSubscription(100, notify: true);
      expect(result, isA<Success>());

      final idsResult = await store.getSubscribedAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, contains(100));
    });

    test('unsubscribe removes from subscribed set', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setSubscription(100, notify: true);
      await store.setSubscription(100, notify: false);

      final idsResult = await store.getSubscribedAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, isNot(contains(100)));
    });

    test('subscription only on existing favorite', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setFavorite(200, isFavorite: true);
      await store.setSubscription(100, notify: true);

      final idsResult = await store.getSubscribedAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, contains(100));
      expect(ids, isNot(contains(200)));
    });

    test('subscription is cleared when favorite is removed', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setSubscription(100, notify: true);

      // Remove from favorites — library row deleted, subscription gone too
      await store.setFavorite(100, isFavorite: false);

      final subResult = await store.getSubscribedAnimeIds();
      final subIds = (subResult as Success<Set<int>, KumoriyaError>).value;
      expect(subIds, isNot(contains(100)));

      final favResult = await store.getFavoriteAnimeIds();
      final favIds = (favResult as Success<Set<int>, KumoriyaError>).value;
      expect(favIds, isNot(contains(100)));
    });

    test('setSubscription on non-existent row is silent no-op', () async {
      final result = await store.setSubscription(999, notify: true);
      expect(result, isA<Success>());

      final idsResult = await store.getSubscribedAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, isNot(contains(999)));
    });

    test('empty subscriptions returns empty set', () async {
      final idsResult = await store.getSubscribedAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids, isEmpty);
    });

    test('subscription is idempotent', () async {
      await store.setFavorite(100, isFavorite: true);
      await store.setSubscription(100, notify: true);
      await store.setSubscription(100, notify: true);

      final idsResult = await store.getSubscribedAnimeIds();
      final ids = (idsResult as Success<Set<int>, KumoriyaError>).value;
      expect(ids.length, 1);
    });
  });
}
