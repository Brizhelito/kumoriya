import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftMangaLibraryStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftMangaLibraryStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('favorite + subscription + auto-download round-trip', () async {
    await store.setFavorite(1, isFavorite: true);
    await store.setSubscription(1, notify: true);
    await store.setAutoDownload(1, autoDownload: true);

    expect(
      (await store.getFavoriteMangaIds() as Success<Set<int>, KumoriyaError>)
          .value,
      {1},
    );
    expect(
      (await store.getSubscribedMangaIds() as Success<Set<int>, KumoriyaError>)
          .value,
      {1},
    );
    expect(
      (await store.getAutoDownloadMangaIds()
              as Success<Set<int>, KumoriyaError>)
          .value,
      {1},
    );

    final snap = (await store.getEntrySnapshot(1))!;
    expect(snap.isFavorite, isTrue);
    expect(snap.notifyNewChapters, isTrue);
    expect(snap.autoDownloadNewChapters, isTrue);
  });

  test('removing favorite keeps row when other tracking is on', () async {
    await store.setFavorite(1, isFavorite: true);
    await store.setSubscription(1, notify: true);
    await store.setFavorite(1, isFavorite: false);

    final snap = (await store.getEntrySnapshot(1))!;
    expect(snap.isFavorite, isFalse);
    expect(snap.notifyNewChapters, isTrue);
  });

  test('updateLastNotifiedChapter persists fractional chapter', () async {
    await store.setSubscription(1, notify: true);
    await store.updateLastNotifiedChapter(1, 12.5);
    final tracked =
        (await store.getTrackedMangaWithLastChapter()
                as Success<Map<int, double?>, KumoriyaError>)
            .value;
    expect(tracked[1], 12.5);
  });

  test('preferred language and scanlator persist standalone', () async {
    await store.setPreferredLanguage(1, 'es');
    await store.setPreferredScanlator(1, 'Lectores Anónimos');
    final snap = (await store.getEntrySnapshot(1))!;
    expect(snap.preferredLanguage, 'es');
    expect(snap.preferredScanlator, 'Lectores Anónimos');
    expect(snap.isFavorite, isFalse);
  });

  test('clearAll wipes everything', () async {
    await store.setFavorite(1, isFavorite: true);
    await store.setSubscription(2, notify: true);
    await store.clearAll();
    expect(await store.getEntrySnapshot(1), isNull);
    expect(await store.getEntrySnapshot(2), isNull);
  });
}
