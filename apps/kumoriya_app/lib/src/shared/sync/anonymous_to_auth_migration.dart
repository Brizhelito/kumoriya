import 'dart:convert';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// On first login, force-enqueue all local data into the sync queue so that
/// the first push sends everything to the server (local data wins over empty
/// server state).
final class AnonymousToAuthMigration {
  AnonymousToAuthMigration({
    required this.progressStore,
    required this.libraryStore,
    required this.syncQueue,
    required this.syncService,
  });

  final AnimeProgressStore progressStore;
  final LibraryStore libraryStore;
  final SyncQueueStore syncQueue;
  final SyncService syncService;

  Future<Result<void, KumoriyaError>> migrate() async {
    // 1. Enqueue all episode progress.
    final allHistoryResult = await progressStore.getAllHistory();
    if (allHistoryResult.isSuccess) {
      final history =
          (allHistoryResult as Success<List<AnimeWatchHistory>, KumoriyaError>)
              .value;
      for (final wh in history) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await syncQueue.enqueue(SyncQueueEntry(
          id: 0,
          entityType: SyncEntityType.watchHistory,
          entityKey: jsonEncode({'anilistId': wh.anilistId}),
          payload: jsonEncode({
            'anilist_id': wh.anilistId,
            'last_episode_number': wh.lastEpisodeNumber,
            'last_source_plugin_id': wh.lastSourcePluginId,
            'last_position_seconds': wh.lastPositionSeconds,
            'last_total_duration_seconds': wh.lastTotalDurationSeconds,
            'last_accessed_at': now,
          }),
          createdAt: DateTime.now(),
          status: SyncQueueEntryStatus.pending,
        ));

        // Also enqueue any per-episode progress for this anime.
        final epResult =
            await progressStore.getAllProgress(wh.anilistId);
        if (epResult.isSuccess) {
          final episodes =
              (epResult as Success<List<EpisodeProgress>, KumoriyaError>).value;
          for (final ep in episodes) {
            await syncQueue.enqueue(SyncQueueEntry(
              id: 0,
              entityType: SyncEntityType.episodeProgress,
              entityKey: jsonEncode({
                'anilistId': ep.anilistId,
                'episodeNumber': ep.episodeNumber,
              }),
              payload: jsonEncode({
                'anilist_id': ep.anilistId,
                'episode_number': ep.episodeNumber,
                'position_seconds': ep.position.inSeconds,
                'total_duration_seconds': ep.totalDuration?.inSeconds,
                'watch_state': ep.watchState.name,
                'last_source_plugin_id': ep.lastSourcePluginId,
                'last_server_name': ep.lastServerName,
                'last_resolver_plugin_id': ep.lastResolverPluginId,
                'updated_at': ep.updatedAt.millisecondsSinceEpoch,
              }),
              createdAt: DateTime.now(),
              status: SyncQueueEntryStatus.pending,
            ));
          }
        }
      }
    }

    // 2. Enqueue all library entries.
    final favResult = await libraryStore.getFavoriteAnimeIds();
    final subResult = await libraryStore.getSubscribedAnimeIds();
    final autoResult = await libraryStore.getAutoDownloadAnimeIds();

    final allIds = <int>{};
    favResult.fold(onSuccess: allIds.addAll, onFailure: (_) {});
    subResult.fold(onSuccess: allIds.addAll, onFailure: (_) {});
    autoResult.fold(onSuccess: allIds.addAll, onFailure: (_) {});

    final favSet =
        favResult.fold(onSuccess: (s) => s, onFailure: (_) => <int>{});
    final subSet =
        subResult.fold(onSuccess: (s) => s, onFailure: (_) => <int>{});
    final autoSet =
        autoResult.fold(onSuccess: (s) => s, onFailure: (_) => <int>{});

    for (final id in allIds) {
      final audioPref =
          await libraryStore.getAutoDownloadAudioPreference(id);
      final now = DateTime.now().millisecondsSinceEpoch;
      await syncQueue.enqueue(SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.libraryEntry,
        entityKey: jsonEncode({'anilistId': id}),
        payload: jsonEncode({
          'anilist_id': id,
          'is_favorite': favSet.contains(id),
          'added_at': now,
          'notify_new_episodes': subSet.contains(id),
          'auto_download_new_episodes': autoSet.contains(id),
          'auto_download_audio_preference': audioPref ?? 'none',
        }),
        createdAt: DateTime.now(),
        status: SyncQueueEntryStatus.pending,
      ));
    }

    // 3. Enqueue all playback preferences.
    // We iterate over all anime IDs we know about (from history/library).
    final knownAnimeIds = <int>{};
    allHistoryResult.fold(
      onSuccess: (history) {
        for (final wh in history) {
          knownAnimeIds.add(wh.anilistId);
        }
      },
      onFailure: (_) {},
    );
    knownAnimeIds.addAll(allIds);

    for (final anilistId in knownAnimeIds) {
      final prefResult =
          await progressStore.getPlaybackPreference(anilistId);
      prefResult.fold(
        onSuccess: (pref) async {
          if (pref != null) {
            await syncQueue.enqueue(SyncQueueEntry(
              id: 0,
              entityType: SyncEntityType.playbackPreference,
              entityKey: jsonEncode({'anilistId': anilistId}),
              payload: jsonEncode({
                'anilist_id': anilistId,
                'preferred_source_plugin_id': pref.preferredSourcePluginId,
                'preferred_server_name': pref.preferredServerName,
                'preferred_resolver_plugin_id':
                    pref.preferredResolverPluginId,
                'preferred_audio_preference':
                    pref.preferredAudioPreference?.name,
                'updated_at': pref.updatedAt.millisecondsSinceEpoch,
              }),
              createdAt: DateTime.now(),
              status: SyncQueueEntryStatus.pending,
            ));
          }
        },
        onFailure: (_) {},
      );
    }

    // 4. Push everything, then pull.
    return syncService.fullSync();
  }
}
