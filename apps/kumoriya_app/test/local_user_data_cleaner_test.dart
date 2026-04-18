import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/sync/local_user_data_cleaner.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

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

  Future<void> seedUserData() async {
    // Watch history + per-episode progress.
    await progressStore.upsertWatchHistory(
      anilistId: 101,
      episodeNumber: 2.0,
      positionSeconds: 120,
      totalDurationSeconds: 1440,
      lastSourcePluginId: 'kumoriya.source.jkanime',
    );
    await progressStore.upsert(
      EpisodeProgress(
        anilistId: 101,
        episodeNumber: 2.0,
        position: const Duration(seconds: 120),
        totalDuration: const Duration(seconds: 1440),
        watchState: WatchState.watching,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );

    // Playback preference.
    await progressStore.upsertPlaybackPreference(
      PlaybackPreference(
        anilistId: 101,
        preferredSourcePluginId: 'kumoriya.source.jkanime',
        preferredServerName: 'jkplayer',
        preferredResolverPluginId: 'kumoriya.resolver.jkplayer',
        preferredAudioPreference: PlaybackAudioPreference.sub,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      ),
    );

    // Library entries (favorite + subscription + auto-download).
    await libraryStore.setFavorite(101, isFavorite: true);
    await libraryStore.setSubscription(202, notify: true);
    await libraryStore.setAutoDownload(303, autoDownload: true);

    // Pending sync queue entry (simulates residual work from a prior session).
    final enq = await queueStore.enqueue(
      SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.libraryEntry,
        entityKey: jsonEncode({'anilistId': 999}),
        payload: jsonEncode({'anilist_id': 999, 'is_favorite': true}),
        createdAt: DateTime.now(),
        status: SyncQueueEntryStatus.pending,
      ),
    );
    expect(enq.isSuccess, isTrue, reason: 'seed enqueue must succeed');
  }

  test('wipe() empties every user-scoped store', () async {
    await seedUserData();

    // Sanity: data is present before wipe.
    expect(
      (await libraryStore.getFavoriteAnimeIds()
              as Success<Set<int>, KumoriyaError>)
          .value,
      isNotEmpty,
    );
    expect(
      (await progressStore.getAllHistory()
              as Success<List<AnimeWatchHistory>, KumoriyaError>)
          .value,
      isNotEmpty,
    );
    expect(
      (await queueStore.getPendingEntries()
              as Success<List<SyncQueueEntry>, KumoriyaError>)
          .value,
      isNotEmpty,
    );

    final cleaner = LocalUserDataCleaner(
      progressStore: progressStore,
      libraryStore: libraryStore,
      syncQueue: queueStore,
    );
    final result = await cleaner.wipe();
    expect(result.isSuccess, isTrue);

    // Favorites / subscriptions / auto-download.
    expect(
      (await libraryStore.getFavoriteAnimeIds()
              as Success<Set<int>, KumoriyaError>)
          .value,
      isEmpty,
    );
    expect(
      (await libraryStore.getSubscribedAnimeIds()
              as Success<Set<int>, KumoriyaError>)
          .value,
      isEmpty,
    );
    expect(
      (await libraryStore.getAutoDownloadAnimeIds()
              as Success<Set<int>, KumoriyaError>)
          .value,
      isEmpty,
    );

    // Watch history + per-episode progress + playback preference.
    expect(
      (await progressStore.getAllHistory()
              as Success<List<AnimeWatchHistory>, KumoriyaError>)
          .value,
      isEmpty,
    );
    expect(
      (await progressStore.getAllProgress(101)
              as Success<List<EpisodeProgress>, KumoriyaError>)
          .value,
      isEmpty,
    );
    expect(
      (await progressStore.getPlaybackPreference(101)
              as Success<PlaybackPreference?, KumoriyaError>)
          .value,
      isNull,
    );

    // Sync queue.
    expect(
      (await queueStore.getPendingEntries()
              as Success<List<SyncQueueEntry>, KumoriyaError>)
          .value,
      isEmpty,
    );
  });

  test('wipe() is idempotent on an already-empty database', () async {
    final cleaner = LocalUserDataCleaner(
      progressStore: progressStore,
      libraryStore: libraryStore,
      syncQueue: queueStore,
    );

    final first = await cleaner.wipe();
    final second = await cleaner.wipe();

    expect(first.isSuccess, isTrue);
    expect(second.isSuccess, isTrue);
  });
}
