import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;
  late DriftAnimeProgressStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftAnimeProgressStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftAnimeProgressStore.upsert', () {
    test('saves and retrieves progress', () async {
      final progress = EpisodeProgress(
        anilistId: 101,
        episodeNumber: 5.0,
        position: const Duration(minutes: 10),
        totalDuration: const Duration(minutes: 24),
        watchState: WatchState.watching,
        updatedAt: DateTime(2025, 1, 1),
      );

      final upsertResult = await store.upsert(progress);
      expect(upsertResult, isA<Success>());

      final getResult = await store.getProgress(101, 5.0);
      expect(getResult, isA<Success>());
      final saved =
          (getResult as Success<EpisodeProgress?, KumoriyaError>).value;
      expect(saved, isNotNull);
      expect(saved!.anilistId, 101);
      expect(saved.episodeNumber, 5.0);
      expect(saved.position, const Duration(minutes: 10));
      expect(saved.totalDuration, const Duration(minutes: 24));
      expect(saved.watchState, WatchState.watching);
    });

    test('upsert overwrites existing progress for same key', () async {
      final first = EpisodeProgress(
        anilistId: 101,
        episodeNumber: 5.0,
        position: const Duration(minutes: 5),
        watchState: WatchState.watching,
        updatedAt: DateTime(2025, 1, 1),
      );
      final second = EpisodeProgress(
        anilistId: 101,
        episodeNumber: 5.0,
        position: const Duration(minutes: 20),
        watchState: WatchState.completed,
        updatedAt: DateTime(2025, 1, 2),
      );

      await store.upsert(first);
      await store.upsert(second);

      final result = await store.getProgress(101, 5.0);
      final saved = (result as Success<EpisodeProgress?, KumoriyaError>).value!;
      expect(saved.position, const Duration(minutes: 20));
      expect(saved.watchState, WatchState.completed);
    });

    test('upsert does not write watch history entry', () async {
      final progress = EpisodeProgress(
        anilistId: 202,
        episodeNumber: 3.0,
        position: const Duration(minutes: 8),
        watchState: WatchState.watching,
        updatedAt: DateTime(2025, 6, 1),
        lastSourcePluginId: 'jkanime',
      );

      await store.upsert(progress);

      final historyResult = await store.getRecentHistory(limit: 5);
      final history =
          (historyResult as Success<List<AnimeWatchHistory>, KumoriyaError>)
              .value;
      expect(history, isEmpty);
    });

    test('upsert clears server metadata when next save omits it', () async {
      await store.upsert(
        EpisodeProgress(
          anilistId: 203,
          episodeNumber: 4.0,
          position: const Duration(minutes: 12),
          watchState: WatchState.watching,
          updatedAt: DateTime(2025, 6, 1),
          lastSourcePluginId: 'jkanime',
          lastServerName: 'Streamwish',
          lastResolverPluginId: 'kumoriya.resolver.streamwish',
        ),
      );

      await store.upsert(
        EpisodeProgress(
          anilistId: 203,
          episodeNumber: 4.0,
          position: const Duration(minutes: 13),
          watchState: WatchState.watching,
          updatedAt: DateTime(2025, 6, 2),
        ),
      );

      final result = await store.getProgress(203, 4.0);
      final saved = (result as Success<EpisodeProgress?, KumoriyaError>).value!;
      expect(saved.lastSourcePluginId, isNull);
      expect(saved.lastServerName, isNull);
      expect(saved.lastResolverPluginId, isNull);
    });
  });

  group('DriftAnimeProgressStore.getLatestProgress', () {
    test('returns most recently updated episode', () async {
      final ep1 = EpisodeProgress(
        anilistId: 303,
        episodeNumber: 1.0,
        position: const Duration(minutes: 20),
        watchState: WatchState.completed,
        updatedAt: DateTime(2025, 1, 1),
      );
      final ep5 = EpisodeProgress(
        anilistId: 303,
        episodeNumber: 5.0,
        position: const Duration(minutes: 10),
        watchState: WatchState.watching,
        updatedAt: DateTime(2025, 2, 1),
      );

      await store.upsert(ep1);
      await store.upsert(ep5);

      final result = await store.getLatestProgress(303);
      final latest =
          (result as Success<EpisodeProgress?, KumoriyaError>).value!;
      expect(latest.episodeNumber, 5.0);
    });

    test('returns null when no progress for anilistId', () async {
      final result = await store.getLatestProgress(9999);
      final value = (result as Success<EpisodeProgress?, KumoriyaError>).value;
      expect(value, isNull);
    });
  });

  group('DriftAnimeProgressStore.getAllProgress', () {
    test('returns all episodes ordered by episode number', () async {
      for (final ep in [3.0, 1.0, 2.0]) {
        await store.upsert(
          EpisodeProgress(
            anilistId: 404,
            episodeNumber: ep,
            position: Duration(minutes: ep.toInt()),
            watchState: WatchState.watching,
            updatedAt: DateTime(2025, 1, ep.toInt()),
          ),
        );
      }

      final result = await store.getAllProgress(404);
      final list =
          (result as Success<List<EpisodeProgress>, KumoriyaError>).value;
      expect(list.length, 3);
      expect(list.map((e) => e.episodeNumber).toList(), [1.0, 2.0, 3.0]);
    });
  });

  group('DriftAnimeProgressStore.upsertWatchHistory', () {
    test('saves and retrieves watch history with position', () async {
      final result = await store.upsertWatchHistory(
        anilistId: 202,
        episodeNumber: 3.0,
        positionSeconds: 480,
        totalDurationSeconds: 1440,
        lastSourcePluginId: 'jkanime',
      );
      expect(result, isA<Success>());

      final historyResult = await store.getRecentHistory(limit: 5);
      final history =
          (historyResult as Success<List<AnimeWatchHistory>, KumoriyaError>)
              .value;
      expect(history.length, 1);
      expect(history.first.anilistId, 202);
      expect(history.first.lastEpisodeNumber, 3.0);
      expect(history.first.lastSourcePluginId, 'jkanime');
      expect(history.first.lastPositionSeconds, 480);
      expect(history.first.lastTotalDurationSeconds, 1440);
    });

    test('progressFraction is computed correctly', () async {
      await store.upsertWatchHistory(
        anilistId: 203,
        episodeNumber: 1.0,
        positionSeconds: 600,
        totalDurationSeconds: 1200,
      );

      final historyResult = await store.getRecentHistory(limit: 5);
      final history =
          (historyResult as Success<List<AnimeWatchHistory>, KumoriyaError>)
              .value;
      expect(history.first.progressFraction, closeTo(0.5, 0.01));
    });

    test('progressFraction is null when totalDuration is null', () async {
      await store.upsertWatchHistory(
        anilistId: 204,
        episodeNumber: 1.0,
        positionSeconds: 600,
      );

      final historyResult = await store.getRecentHistory(limit: 5);
      final history =
          (historyResult as Success<List<AnimeWatchHistory>, KumoriyaError>)
              .value;
      expect(history.first.progressFraction, isNull);
    });
  });

  group('DriftAnimeProgressStore.getRecentHistory', () {
    test('returns entries ordered by most recent access', () async {
      for (int i = 1; i <= 5; i++) {
        await store.upsertWatchHistory(
          anilistId: i * 100,
          episodeNumber: 1.0,
          positionSeconds: 300,
        );
        // Small delay so timestamps differ.
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final result = await store.getRecentHistory(limit: 3);
      final list =
          (result as Success<List<AnimeWatchHistory>, KumoriyaError>).value;
      expect(list.length, 3);
      expect(list.first.anilistId, 500);
    });

    test('history is updated when same anime has new episode access', () async {
      await store.upsertWatchHistory(
        anilistId: 777,
        episodeNumber: 1.0,
        positionSeconds: 600,
      );
      await store.upsertWatchHistory(
        anilistId: 777,
        episodeNumber: 2.0,
        positionSeconds: 300,
      );

      final result = await store.getRecentHistory(limit: 5);
      final list =
          (result as Success<List<AnimeWatchHistory>, KumoriyaError>).value;
      expect(list.length, 1);
      expect(list.first.lastEpisodeNumber, 2.0);
    });
  });

  group('DriftAnimeProgressStore.playbackPreference', () {
    test('saves and retrieves playback preference', () async {
      final result = await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: 901,
          preferredSourcePluginId: 'kumoriya.source.animeav1',
          preferredServerName: 'Streamwish',
          preferredResolverPluginId: 'kumoriya.resolver.streamwish',
          preferredAudioPreference: PlaybackAudioPreference.dub,
          updatedAt: DateTime(2025, 7, 1),
        ),
      );

      expect(result, isA<Success>());

      final stored = await store.getPlaybackPreference(901);
      final value =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value!;
      expect(value.preferredSourcePluginId, 'kumoriya.source.animeav1');
      expect(value.preferredServerName, 'Streamwish');
      expect(value.preferredResolverPluginId, 'kumoriya.resolver.streamwish');
      expect(value.preferredAudioPreference, PlaybackAudioPreference.dub);
    });

    test('returns null when no playback preference exists', () async {
      final stored = await store.getPlaybackPreference(999);
      final value =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value;
      expect(value, isNull);
    });

    test(
      'allows clearing broken source/server fields while keeping audio',
      () async {
        await store.upsertPlaybackPreference(
          PlaybackPreference(
            anilistId: 902,
            preferredSourcePluginId: 'kumoriya.source.animeav1',
            preferredServerName: 'Broken Server',
            preferredResolverPluginId: 'kumoriya.resolver.broken',
            preferredAudioPreference: PlaybackAudioPreference.dub,
            updatedAt: DateTime(2025, 7, 1),
          ),
        );

        await store.upsertPlaybackPreference(
          PlaybackPreference(
            anilistId: 902,
            preferredAudioPreference: PlaybackAudioPreference.dub,
            updatedAt: DateTime(2025, 7, 2),
          ),
        );

        final stored = await store.getPlaybackPreference(902);
        final value =
            (stored as Success<PlaybackPreference?, KumoriyaError>).value!;
        expect(value.preferredSourcePluginId, isNull);
        expect(value.preferredServerName, isNull);
        expect(value.preferredResolverPluginId, isNull);
        expect(value.preferredAudioPreference, PlaybackAudioPreference.dub);
      },
    );

    test('clears persisted playback preference row', () async {
      await store.upsertPlaybackPreference(
        PlaybackPreference(
          anilistId: 903,
          preferredSourcePluginId: 'kumoriya.source.animeflv',
          preferredServerName: 'YourUpload',
          preferredResolverPluginId: 'kumoriya.resolver.yourupload',
          updatedAt: DateTime(2025, 7, 3),
        ),
      );

      final clearResult = await store.clearPlaybackPreference(903);
      expect(clearResult, isA<Success>());

      final stored = await store.getPlaybackPreference(903);
      final value =
          (stored as Success<PlaybackPreference?, KumoriyaError>).value;
      expect(value, isNull);
    });
  });
}
