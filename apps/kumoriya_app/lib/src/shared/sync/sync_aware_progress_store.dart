import 'dart:convert';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_sync/kumoriya_sync.dart';

/// Wraps an [AnimeProgressStore] to automatically enqueue changes to the
/// sync queue when the user is authenticated.
final class SyncAwareProgressStore implements AnimeProgressStore {
  SyncAwareProgressStore({
    required AnimeProgressStore inner,
    required SyncQueueStore syncQueue,
    required bool Function() isAuthenticated,
  })  : _inner = inner,
        _syncQueue = syncQueue,
        _isAuthenticated = isAuthenticated;

  final AnimeProgressStore _inner;
  final SyncQueueStore _syncQueue;
  final bool Function() _isAuthenticated;

  @override
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress) async {
    final result = await _inner.upsert(progress);
    if (result.isSuccess && _isAuthenticated()) {
      await _syncQueue.enqueue(SyncQueueEntry(
        id: 0, // auto-generated
        entityType: SyncEntityType.episodeProgress,
        entityKey: jsonEncode({
          'anilistId': progress.anilistId,
          'episodeNumber': progress.episodeNumber,
        }),
        payload: jsonEncode({
          'anilist_id': progress.anilistId,
          'episode_number': progress.episodeNumber,
          'position_seconds': progress.position.inSeconds,
          'total_duration_seconds': progress.totalDuration?.inSeconds,
          'watch_state': progress.watchState.name,
          'last_source_plugin_id': progress.lastSourcePluginId,
          'last_server_name': progress.lastServerName,
          'last_resolver_plugin_id': progress.lastResolverPluginId,
          'updated_at': progress.updatedAt.millisecondsSinceEpoch,
        }),
        createdAt: DateTime.now(),
        status: SyncQueueEntryStatus.pending,
      ));
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> upsertWatchHistory({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    int? totalDurationSeconds,
    String? lastSourcePluginId,
    DateTime? lastAccessedAt,
  }) async {
    final result = await _inner.upsertWatchHistory(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      positionSeconds: positionSeconds,
      totalDurationSeconds: totalDurationSeconds,
      lastSourcePluginId: lastSourcePluginId,
      lastAccessedAt: lastAccessedAt,
    );
    if (result.isSuccess && _isAuthenticated()) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _syncQueue.enqueue(SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.watchHistory,
        entityKey: jsonEncode({'anilistId': anilistId}),
        payload: jsonEncode({
          'anilist_id': anilistId,
          'last_episode_number': episodeNumber,
          'last_source_plugin_id': lastSourcePluginId,
          'last_position_seconds': positionSeconds,
          'last_total_duration_seconds': totalDurationSeconds,
          'last_accessed_at': now,
        }),
        createdAt: DateTime.now(),
        status: SyncQueueEntryStatus.pending,
      ));
    }
    return result;
  }

  @override
  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference preference,
  ) async {
    final result = await _inner.upsertPlaybackPreference(preference);
    if (result.isSuccess && _isAuthenticated()) {
      await _syncQueue.enqueue(SyncQueueEntry(
        id: 0,
        entityType: SyncEntityType.playbackPreference,
        entityKey: jsonEncode({'anilistId': preference.anilistId}),
        payload: jsonEncode({
          'anilist_id': preference.anilistId,
          'preferred_source_plugin_id': preference.preferredSourcePluginId,
          'preferred_server_name': preference.preferredServerName,
          'preferred_resolver_plugin_id': preference.preferredResolverPluginId,
          'preferred_audio_preference':
              preference.preferredAudioPreference?.name,
          'updated_at': preference.updatedAt.millisecondsSinceEpoch,
        }),
        createdAt: DateTime.now(),
        status: SyncQueueEntryStatus.pending,
      ));
    }
    return result;
  }

  // Pass-through reads (no sync needed).
  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  ) => _inner.getProgress(anilistId, episodeNumber);

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getLatestProgress(
    int anilistId,
  ) => _inner.getLatestProgress(anilistId);

  @override
  Future<Result<List<EpisodeProgress>, KumoriyaError>> getAllProgress(
    int anilistId,
  ) => _inner.getAllProgress(anilistId);

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) => _inner.getRecentHistory(limit: limit);

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getAllHistory() =>
      _inner.getAllHistory();

  @override
  Future<Result<void, KumoriyaError>> deleteHistoryEntry(int anilistId) =>
      _inner.deleteHistoryEntry(anilistId);

  @override
  Future<Result<void, KumoriyaError>> clearAllHistory() =>
      _inner.clearAllHistory();

  @override
  Future<Result<PlaybackPreference?, KumoriyaError>> getPlaybackPreference(
    int anilistId,
  ) => _inner.getPlaybackPreference(anilistId);

  @override
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(int anilistId) =>
      _inner.clearPlaybackPreference(anilistId);

  @override
  Future<Result<void, KumoriyaError>> clearAllPlaybackPreferences() =>
      _inner.clearAllPlaybackPreferences();
}
