import 'dart:convert';

import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftAnimeProgressStore progressStore;
  late DriftLibraryStore libraryStore;
  late DriftSyncQueueStore queueStore;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    progressStore = DriftAnimeProgressStore(db);
    libraryStore = DriftLibraryStore(db);
    queueStore = DriftSyncQueueStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'pullSince applies remote data without enqueueing new sync work',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/sync/pull');
        return http.Response(
          jsonEncode({
            'server_time': 7000,
            'episode_progress': [
              {
                'anilist_id': 101,
                'episode_number': 3,
                'position_seconds': 240,
                'total_duration_seconds': 1440,
                'watch_state': 'watching',
                'updated_at': 5000,
              },
            ],
            'watch_history': [
              {
                'anilist_id': 101,
                'last_episode_number': 3,
                'last_position_seconds': 240,
                'last_total_duration_seconds': 1440,
                'last_accessed_at': 6000,
              },
            ],
            'playback_preferences': const [],
            'library_entries': [
              {
                'anilist_id': 101,
                'added_at': 4000,
                'notify_new_episodes': true,
                'auto_download_new_episodes': false,
                'auto_download_audio_preference': 'none',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = HttpSyncService(
        httpClient: client,
        queueStore: queueStore,
        progressStore: progressStore,
        libraryStore: libraryStore,
        baseUrl: 'https://api.kumoriya.online',
      );

      final result = await service.pullSince(
        DateTime.fromMillisecondsSinceEpoch(1),
      );
      expect(result.isSuccess, isTrue);

      final pending = await queueStore.getPendingEntries();
      expect(
        pending.fold(
          onSuccess: (value) => value,
          onFailure: (_) => throw StateError('queue read failed'),
        ),
        isEmpty,
      );

      final history = await progressStore.getAllHistory();
      final savedHistory = history.fold(
        onSuccess: (value) => value.single,
        onFailure: (_) => throw StateError('history read failed'),
      );
      expect(savedHistory.lastAccessedAt.millisecondsSinceEpoch, 6000);

      final favorites = await libraryStore.getFavoriteAnimeIds();
      expect(
        favorites.fold(
          onSuccess: (value) => value,
          onFailure: (_) => throw StateError('favorite read failed'),
        ),
        contains(101),
      );

      final lastSyncAt = await service.getLastSyncAt();
      expect(
        lastSyncAt
            .fold(onSuccess: (value) => value, onFailure: (_) => null)
            ?.millisecondsSinceEpoch,
        7000,
      );
    },
  );

  test(
    'pushPending keeps accepted entries in queue until durable_until confirms them',
    () async {
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.watchHistory,
          entityKey: jsonEncode({'anilistId': 101}),
          payload: jsonEncode({
            'anilist_id': 101,
            'last_episode_number': 3,
            'last_position_seconds': 240,
            'last_total_duration_seconds': 1440,
            'last_accessed_at': 6000,
          }),
          createdAt: DateTime.fromMillisecondsSinceEpoch(6000),
          status: SyncQueueEntryStatus.pending,
        ),
      );

      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/sync/push');
        // Server ack without durability — data is in RAM, not yet on Neon.
        return http.Response(
          jsonEncode({
            'applied': 1,
            'conflicts': const [],
            'durable_until': {
              'episode_progress': 0,
              'watch_history': 0,
              'playback_preference': 0,
              'library_entry': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = HttpSyncService(
        httpClient: client,
        queueStore: queueStore,
        progressStore: progressStore,
        libraryStore: libraryStore,
        baseUrl: 'https://api.kumoriya.online',
      );

      final result = await service.pushPending();
      expect(result.isSuccess, isTrue);

      // Entry must still be in the queue because durability was not confirmed.
      // It stays in `syncing` so a server restart (data lost from RAM buffer)
      // is survived by re-pushing on the next cycle.
      final pending = await queueStore.getPendingEntries();
      final entries = pending.fold(
        onSuccess: (value) => value,
        onFailure: (_) => throw StateError('queue read failed'),
      );
      expect(entries, hasLength(1));
      expect(entries.single.status, SyncQueueEntryStatus.syncing);
      expect(entries.single.retryCount, 0);
    },
  );

  test(
    'pushPending prunes entries whose timestamp is durable on the server',
    () async {
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.watchHistory,
          entityKey: jsonEncode({'anilistId': 101}),
          payload: jsonEncode({
            'anilist_id': 101,
            'last_episode_number': 3,
            'last_position_seconds': 240,
            'last_total_duration_seconds': 1440,
            'last_accessed_at': 6000,
          }),
          createdAt: DateTime.fromMillisecondsSinceEpoch(6000),
          status: SyncQueueEntryStatus.pending,
        ),
      );

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'applied': 1,
            'conflicts': const [],
            // Cursor at 6500 ms covers the 6000 ms entry above.
            'durable_until': {
              'episode_progress': 0,
              'watch_history': 6500,
              'playback_preference': 0,
              'library_entry': 0,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = HttpSyncService(
        httpClient: client,
        queueStore: queueStore,
        progressStore: progressStore,
        libraryStore: libraryStore,
        baseUrl: 'https://api.kumoriya.online',
      );

      final result = await service.pushPending();
      expect(result.isSuccess, isTrue);

      final pending = await queueStore.getPendingEntries();
      final entries = pending.fold(
        onSuccess: (value) => value,
        onFailure: (_) => throw StateError('queue read failed'),
      );
      expect(entries, isEmpty, reason: 'durable entries must be pruned');
    },
  );

  test(
    'enqueuing watch_history collapses an earlier pending deletion',
    () async {
      // Simulate: user deleted history, then re-added it before pushing.
      final key = jsonEncode({'anilistId': 101});
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.watchHistoryDeletion,
          entityKey: key,
          payload: jsonEncode({'anilist_id': 101, 'updated_at': 5000}),
          createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
          status: SyncQueueEntryStatus.pending,
        ),
      );
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.watchHistory,
          entityKey: key,
          payload: jsonEncode({
            'anilist_id': 101,
            'last_episode_number': 3,
            'last_position_seconds': 10,
            'last_accessed_at': 6000,
          }),
          createdAt: DateTime.fromMillisecondsSinceEpoch(6000),
          status: SyncQueueEntryStatus.pending,
        ),
      );

      final pending = await queueStore.getPendingEntries();
      final entries = pending.fold(
        onSuccess: (v) => v,
        onFailure: (_) => throw StateError('queue read failed'),
      );
      // Collapse must leave only the upsert; otherwise the server Flush would
      // apply both and erase the freshly-written history.
      expect(entries, hasLength(1));
      expect(entries.single.entityType, SyncEntityType.watchHistory);
    },
  );

  test(
    'pushPending skips manga entries entirely (Slice 10C-2 backend rollout)',
    () async {
      // Three manga writes that the local queue happily stores but the
      // Go backend cannot accept yet.
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaLibraryEntry,
          entityKey: jsonEncode({'mangaAnilistId': 1}),
          payload: jsonEncode({'manga_anilist_id': 1, 'updated_at': 1000}),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          status: SyncQueueEntryStatus.pending,
        ),
      );
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaChapterProgress,
          entityKey: jsonEncode({
            'mangaAnilistId': 1,
            'sourceId': 'mangadex',
            'sourceChapterId': 'ch-1',
          }),
          payload: jsonEncode({
            'manga_anilist_id': 1,
            'chapter_number': 1.0,
            'updated_at': 1100,
          }),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1100),
          status: SyncQueueEntryStatus.pending,
        ),
      );
      await queueStore.enqueue(
        SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.mangaReadHistory,
          entityKey: jsonEncode({'mangaAnilistId': 1}),
          payload: jsonEncode({
            'manga_anilist_id': 1,
            'last_chapter_number': 1.0,
            'last_accessed_at': 1200,
          }),
          createdAt: DateTime.fromMillisecondsSinceEpoch(1200),
          status: SyncQueueEntryStatus.pending,
        ),
      );

      // The HTTP client must NOT be invoked: with only manga entries in
      // the queue, `pushPending` short-circuits to idle.
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });

      final service = HttpSyncService(
        httpClient: client,
        queueStore: queueStore,
        progressStore: progressStore,
        libraryStore: libraryStore,
        baseUrl: 'https://api.kumoriya.online',
      );

      final result = await service.pushPending();
      expect(result.isSuccess, isTrue);
      expect(calls, 0, reason: 'no push when queue holds only manga entries');

      // Manga entries remain pending — the backend will drain them
      // once the endpoints land (Slice 10C-2).
      final stillPending = await queueStore.getPendingEntries();
      stillPending.fold(
        onSuccess: (entries) {
          expect(entries, hasLength(3));
          expect(
            entries.every(
              (e) => e.status == SyncQueueEntryStatus.pending,
            ),
            isTrue,
          );
        },
        onFailure: (_) => fail('queue read failed'),
      );
    },
  );

  test('pushPending includes watch history deletions in payload', () async {
    await queueStore.enqueue(
      SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.watchHistoryDeletion,
        entityKey: jsonEncode({'anilistId': 101}),
        payload: jsonEncode({'anilist_id': 101}),
        createdAt: DateTime.fromMillisecondsSinceEpoch(7000),
        status: SyncQueueEntryStatus.pending,
      ),
    );

    late Map<String, dynamic> pushedBody;
    final client = MockClient((request) async {
      pushedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'applied': 1, 'conflicts': const []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = HttpSyncService(
      httpClient: client,
      queueStore: queueStore,
      progressStore: progressStore,
      libraryStore: libraryStore,
      baseUrl: 'https://api.kumoriya.online',
    );

    final result = await service.pushPending();
    expect(result.isSuccess, isTrue);
    expect(pushedBody['watch_history_deletions'], [
      {'anilist_id': 101},
    ]);
  });
}
