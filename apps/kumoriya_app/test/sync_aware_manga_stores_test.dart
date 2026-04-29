import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/sync/sync_aware_manga_library_store.dart';
import 'package:kumoriya_app/src/shared/sync/sync_aware_manga_progress_store.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

void main() {
  late AppDatabase db;
  late SyncQueueStore queue;
  late MangaLibraryStore library;
  late MangaProgressStore progress;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queue = DriftSyncQueueStore(db);
    library = SyncAwareMangaLibraryStore(
      inner: DriftMangaLibraryStore(db),
      syncQueue: queue,
      isAuthenticated: () => true,
    );
    progress = SyncAwareMangaProgressStore(
      inner: DriftMangaProgressStore(db),
      syncQueue: queue,
      isAuthenticated: () => true,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<SyncQueueEntry>> readPending() async {
    final res = await queue.getPendingEntries();
    return (res as Success<List<SyncQueueEntry>, KumoriyaError>).value;
  }

  // ---------------------------------------------------------------------------
  // Library
  // ---------------------------------------------------------------------------

  test('setFavorite enqueues a mangaLibraryEntry', () async {
    await library.setFavorite(101, isFavorite: true);
    final entries = await readPending();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, SyncEntityType.mangaLibraryEntry);

    final payload = jsonDecode(entries.single.payload) as Map<String, dynamic>;
    expect(payload['manga_anilist_id'], 101);
    expect(payload['added_at'], isNot(0));
    expect(payload['notify_new_chapters'], isFalse);
  });

  test(
    'unfavoriting after a subscription keeps a single mangaLibraryEntry',
    () async {
      // Subscribe first so the row is not purged when we unfavorite.
      await library.setSubscription(202, notify: true);
      await library.setFavorite(202, isFavorite: true);
      await library.setFavorite(202, isFavorite: false);

      final entries = await readPending();
      // Latest entry should be a non-favorite snapshot, still LibraryEntry
      // (not Deletion) because the subscription keeps the row alive.
      expect(entries, isNotEmpty);
      expect(entries.last.entityType, SyncEntityType.mangaLibraryEntry);
      final payload = jsonDecode(entries.last.payload) as Map<String, dynamic>;
      expect(payload['added_at'], 0);
      expect(payload['notify_new_chapters'], isTrue);
    },
  );

  test(
    'wiping a row (no fav, no sub, no auto-dl) enqueues a deletion',
    () async {
      // First favorite (creates row), then unfavorite (drops row).
      await library.setFavorite(303, isFavorite: true);
      await library.setFavorite(303, isFavorite: false);

      final entries = await readPending();
      // The collapse logic in the queue store should leave the deletion
      // (or both, depending on key match — both are observable here).
      expect(
        entries.any(
          (e) => e.entityType == SyncEntityType.mangaLibraryEntryDeletion,
        ),
        isTrue,
        reason: 'expected a mangaLibraryEntryDeletion in the pending queue',
      );
    },
  );

  test('writes are NOT enqueued when the user is anonymous', () async {
    final anonLibrary = SyncAwareMangaLibraryStore(
      inner: DriftMangaLibraryStore(db),
      syncQueue: queue,
      isAuthenticated: () => false,
    );
    await anonLibrary.setFavorite(404, isFavorite: true);
    final entries = await readPending();
    expect(entries, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  test('upsert chapter progress enqueues a mangaChapterProgress', () async {
    final now = DateTime.now();
    await progress.upsert(
      MangaChapterProgress(
        mangaAnilistId: 1,
        sourceId: 'mangadex',
        sourceChapterId: 'ch-1',
        chapterNumber: 1.0,
        pageIndex: 5,
        scrollOffset: 320.5,
        readState: MangaReadState.reading,
        updatedAt: now,
      ),
    );

    final entries = await readPending();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, SyncEntityType.mangaChapterProgress);

    final payload = jsonDecode(entries.single.payload) as Map<String, dynamic>;
    expect(payload['manga_anilist_id'], 1);
    expect(payload['page_index'], 5);
    expect(payload['scroll_offset'], 320.5);
    expect(payload['read_state'], 'reading');
    expect(payload['updated_at'], now.millisecondsSinceEpoch);
  });

  test('upsertReadHistory enqueues a mangaReadHistory entry', () async {
    await progress.upsertReadHistory(
      mangaAnilistId: 7,
      chapterNumber: 12.5,
      lastSourceId: 'mangadex',
      lastSourceChapterId: 'ch-12.5',
      lastPageIndex: 22,
    );

    final entries = await readPending();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, SyncEntityType.mangaReadHistory);

    final payload = jsonDecode(entries.single.payload) as Map<String, dynamic>;
    expect(payload['manga_anilist_id'], 7);
    expect(payload['last_chapter_number'], 12.5);
    expect(payload['last_page_index'], 22);
  });

  test('deleteHistoryEntry enqueues a mangaReadHistoryDeletion', () async {
    await progress.upsertReadHistory(mangaAnilistId: 9, chapterNumber: 1.0);
    await progress.deleteHistoryEntry(9);

    final entries = await readPending();
    // Collapse may drop the upsert when it sees a deletion targeting
    // the same key; either way a deletion must be present.
    expect(
      entries.any(
        (e) => e.entityType == SyncEntityType.mangaReadHistoryDeletion,
      ),
      isTrue,
    );
  });
}
