import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftChapterPageCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftChapterPageCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  ChapterPageCacheEntry page({
    required int index,
    int? bytes,
    DateTime? expiresAt,
  }) {
    return ChapterPageCacheEntry(
      sourceId: 'mangadex',
      sourceChapterId: 'c1',
      pageIndex: index,
      imageUrl: 'https://example.test/p$index.webp',
      headers: const {'Referer': 'https://example.test/'},
      bytes: bytes,
      expiresAt: expiresAt,
      updatedAt: DateTime(2026, 4, 28, 9),
    );
  }

  test('upsertAll + listForChapter returns ordered by pageIndex', () async {
    await store.upsertAll([
      page(index: 2, bytes: 100),
      page(index: 0, bytes: 200),
      page(index: 1, bytes: 150),
    ]);

    final list =
        (await store.listForChapter('mangadex', 'c1')
                as Success<List<ChapterPageCacheEntry>, KumoriyaError>)
            .value;
    expect(list.map((p) => p.pageIndex), [0, 1, 2]);
    expect(list.first.headers['Referer'], 'https://example.test/');
  });

  test('totalBytes sums the bytes column across all rows', () async {
    await store.upsertAll([
      page(index: 0, bytes: 100),
      page(index: 1, bytes: 250),
    ]);
    final total =
        (await store.totalBytes() as Success<int, KumoriyaError>).value;
    expect(total, 350);
  });

  test('evictExpired removes only rows past expiry', () async {
    final past = DateTime.now().subtract(const Duration(days: 1));
    final future = DateTime.now().add(const Duration(days: 1));
    await store.upsertAll([
      page(index: 0, expiresAt: past),
      page(index: 1, expiresAt: future),
      page(index: 2),
    ]);

    final evicted =
        (await store.evictExpired(DateTime.now())
                as Success<int, KumoriyaError>)
            .value;
    expect(evicted, 1);
    final remaining =
        (await store.listForChapter('mangadex', 'c1')
                as Success<List<ChapterPageCacheEntry>, KumoriyaError>)
            .value;
    expect(remaining.map((p) => p.pageIndex).toSet(), {1, 2});
  });

  test('deleteForChapter removes all pages of that chapter', () async {
    await store.upsertAll([page(index: 0), page(index: 1)]);
    await store.deleteForChapter('mangadex', 'c1');
    final list =
        (await store.listForChapter('mangadex', 'c1')
                as Success<List<ChapterPageCacheEntry>, KumoriyaError>)
            .value;
    expect(list, isEmpty);
  });
}
