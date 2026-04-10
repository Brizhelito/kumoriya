import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../contracts/sync_queue_store.dart';
import '../contracts/sync_service.dart';
import '../models/library_sync_entry.dart';
import '../models/sync_conflict.dart';
import '../models/sync_pull_response.dart';
import '../models/sync_queue_entry.dart';
import '../models/sync_status.dart';

/// Concrete [SyncService] that pushes/pulls sync data to the Kumoriya backend.
final class HttpSyncService implements SyncService {
  HttpSyncService({
    required this.httpClient,
    required this.queueStore,
    required this.progressStore,
    required this.libraryStore,
    required String baseUrl,
  }) : _baseUrl = baseUrl;

  final http.Client httpClient;
  final SyncQueueStore queueStore;
  final AnimeProgressStore progressStore;
  final LibraryStore libraryStore;
  final String _baseUrl;

  DateTime? _lastSyncAt;
  SyncStatus _currentStatus = SyncStatus.idle;

  /// External setter for restoring persisted lastSyncAt.
  set lastSyncAt(DateTime? value) => _lastSyncAt = value;

  @override
  Future<Result<SyncPushResult, KumoriyaError>> pushPending() async {
    _currentStatus = SyncStatus.pushing;
    try {
      final pendingResult = await queueStore.getPendingEntries();
      return pendingResult.fold(
        onFailure: (e) {
          _currentStatus = SyncStatus.failed;
          return Failure(e);
        },
        onSuccess: (entries) async {
          if (entries.isEmpty) {
            _currentStatus = SyncStatus.idle;
            return const Success(SyncPushResult(applied: 0, conflicts: []));
          }

          // Mark all as syncing.
          for (final entry in entries) {
            await queueStore.updateStatus(
              id: entry.id,
              status: SyncQueueEntryStatus.syncing,
            );
          }

          // Group by entity type and build payload.
          final payload = _buildPushPayload(entries);

          try {
            final response = await httpClient.post(
              Uri.parse('$_baseUrl/api/v1/sync/push'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              final applied = (data['applied'] as num?)?.toInt() ?? 0;
              final conflictsList =
                  (data['conflicts'] as List?)
                      ?.map(
                        (c) => SyncConflict(
                          entityType: SyncEntityType.episodeProgress,
                          entityKey: '',
                          reason: c.toString(),
                        ),
                      )
                      .toList() ??
                  [];

              // Mark synced and clean up.
              for (final entry in entries) {
                await queueStore.updateStatus(
                  id: entry.id,
                  status: SyncQueueEntryStatus.synced,
                );
              }
              await queueStore.clearSyncedEntries();

              _currentStatus = SyncStatus.success;
              return Success(
                SyncPushResult(applied: applied, conflicts: conflictsList),
              );
            }

            // Push failed — mark entries as failed.
            for (final entry in entries) {
              await queueStore.updateStatus(
                id: entry.id,
                status: SyncQueueEntryStatus.failed,
                retryCount: entry.retryCount + 1,
                lastError: 'HTTP ${response.statusCode}',
              );
            }

            _currentStatus = SyncStatus.failed;
            return Failure(
              SimpleError(
                code: 'sync.push.http_error',
                message: 'Push failed: ${response.statusCode}',
                kind: KumoriyaErrorKind.transport,
              ),
            );
          } catch (e) {
            for (final entry in entries) {
              await queueStore.updateStatus(
                id: entry.id,
                status: SyncQueueEntryStatus.failed,
                retryCount: entry.retryCount + 1,
                lastError: e.toString(),
              );
            }

            _currentStatus = SyncStatus.failed;
            return Failure(
              SimpleError(
                code: 'sync.push.transport',
                message: 'Network error during push: $e',
                kind: KumoriyaErrorKind.transport,
              ),
            );
          }
        },
      );
    } catch (e) {
      _currentStatus = SyncStatus.failed;
      return Failure(
        SimpleError(
          code: 'sync.push.unexpected',
          message: 'Unexpected error during push: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<SyncPullResponse, KumoriyaError>> pullSince(
    DateTime since,
  ) async {
    _currentStatus = SyncStatus.pulling;
    try {
      final sinceMs = since.millisecondsSinceEpoch;
      final response = await httpClient.get(
        Uri.parse('$_baseUrl/api/v1/sync/pull?since=$sinceMs'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        _currentStatus = SyncStatus.failed;
        return Failure(
          SimpleError(
            code: 'sync.pull.http_error',
            message: 'Pull failed: ${response.statusCode}',
            kind: KumoriyaErrorKind.transport,
          ),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pullResponse = _parsePullResponse(data);

      // Apply to local stores.
      await _applyPullToLocal(pullResponse);

      _lastSyncAt = pullResponse.serverTime;
      _currentStatus = SyncStatus.success;
      return Success(pullResponse);
    } catch (e) {
      _currentStatus = SyncStatus.failed;
      return Failure(
        SimpleError(
          code: 'sync.pull.transport',
          message: 'Network error during pull: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> fullSync() async {
    // Push first, then pull.
    final pushResult = await pushPending();
    if (pushResult.isFailure) {
      return Failure(
        (pushResult as Failure<SyncPushResult, KumoriyaError>).error,
      );
    }

    final since = _lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final pullResult = await pullSince(since);
    if (pullResult.isFailure) {
      return Failure(
        (pullResult as Failure<SyncPullResponse, KumoriyaError>).error,
      );
    }

    return const Success(null);
  }

  @override
  Future<Result<SyncStatus, KumoriyaError>> getStatus() async {
    return Success(_currentStatus);
  }

  Map<String, dynamic> _buildPushPayload(List<SyncQueueEntry> entries) {
    final episodeProgress = <Map<String, dynamic>>[];
    final watchHistory = <Map<String, dynamic>>[];
    final playbackPreferences = <Map<String, dynamic>>[];
    final libraryEntries = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final decoded = jsonDecode(entry.payload) as Map<String, dynamic>;
      switch (entry.entityType) {
        case SyncEntityType.episodeProgress:
          episodeProgress.add(decoded);
        case SyncEntityType.watchHistory:
          watchHistory.add(decoded);
        case SyncEntityType.playbackPreference:
          playbackPreferences.add(decoded);
        case SyncEntityType.libraryEntry:
          libraryEntries.add(decoded);
      }
    }

    return {
      'episode_progress': episodeProgress,
      'watch_history': watchHistory,
      'playback_preferences': playbackPreferences,
      'library_entries': libraryEntries,
    };
  }

  SyncPullResponse _parsePullResponse(Map<String, dynamic> data) {
    final serverTimeMs = (data['server_time'] as num?)?.toInt() ?? 0;

    final episodes = (data['episode_progress'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_parseEpisodeProgress)
        .toList();

    final history = (data['watch_history'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_parseWatchHistory)
        .toList();

    final prefs = (data['playback_preferences'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_parsePlaybackPreference)
        .toList();

    final library = (data['library_entries'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_parseLibraryEntry)
        .toList();

    return SyncPullResponse(
      serverTime: DateTime.fromMillisecondsSinceEpoch(serverTimeMs),
      episodeProgress: episodes,
      watchHistory: history,
      playbackPreferences: prefs,
      libraryEntries: library,
    );
  }

  EpisodeProgress _parseEpisodeProgress(Map<String, dynamic> data) {
    return EpisodeProgress(
      anilistId: (data['anilist_id'] as num).toInt(),
      episodeNumber: (data['episode_number'] as num).toDouble(),
      position: Duration(
        seconds: (data['position_seconds'] as num?)?.toInt() ?? 0,
      ),
      totalDuration: data['total_duration_seconds'] != null
          ? Duration(seconds: (data['total_duration_seconds'] as num).toInt())
          : null,
      watchState: _parseWatchState(data['watch_state'] as String?),
      lastSourcePluginId: data['last_source_plugin_id'] as String?,
      lastServerName: data['last_server_name'] as String?,
      lastResolverPluginId: data['last_resolver_plugin_id'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  AnimeWatchHistory _parseWatchHistory(Map<String, dynamic> data) {
    return AnimeWatchHistory(
      anilistId: (data['anilist_id'] as num).toInt(),
      lastEpisodeNumber: (data['last_episode_number'] as num).toDouble(),
      lastSourcePluginId: data['last_source_plugin_id'] as String?,
      lastPositionSeconds:
          (data['last_position_seconds'] as num?)?.toInt() ?? 0,
      lastTotalDurationSeconds: (data['last_total_duration_seconds'] as num?)
          ?.toInt(),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['last_accessed_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  PlaybackPreference _parsePlaybackPreference(Map<String, dynamic> data) {
    return PlaybackPreference(
      anilistId: (data['anilist_id'] as num).toInt(),
      preferredSourcePluginId: data['preferred_source_plugin_id'] as String?,
      preferredServerName: data['preferred_server_name'] as String?,
      preferredResolverPluginId:
          data['preferred_resolver_plugin_id'] as String?,
      preferredAudioPreference: _parseAudioPref(
        data['preferred_audio_preference'] as String?,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  LibrarySyncEntry _parseLibraryEntry(Map<String, dynamic> data) {
    return LibrarySyncEntry(
      anilistId: (data['anilist_id'] as num).toInt(),
      isFavorite: true, // present on server = favorited
      notify: data['notify_new_episodes'] as bool? ?? false,
      lastNotifiedEpisode: (data['last_notified_episode'] as num?)?.toInt(),
      autoDownloadNewEpisodes:
          data['auto_download_new_episodes'] as bool? ?? false,
      autoDownloadAudioPreference:
          data['auto_download_audio_preference'] as String?,
      addedAt: _tryParseTimestamp(data['added_at']),
    );
  }

  /// Parses a nullable milliseconds-since-epoch value into a [DateTime],
  /// returning `null` when the value is absent or zero.
  DateTime? _tryParseTimestamp(Object? raw) {
    final ms = (raw as num?)?.toInt();
    if (ms == null || ms == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  WatchState _parseWatchState(String? value) {
    return switch (value) {
      'watching' => WatchState.watching,
      'completed' => WatchState.completed,
      _ => WatchState.unwatched,
    };
  }

  PlaybackAudioPreference? _parseAudioPref(String? value) {
    return switch (value) {
      'sub' => PlaybackAudioPreference.sub,
      'dub' => PlaybackAudioPreference.dub,
      _ => null,
    };
  }

  Future<void> _applyPullToLocal(SyncPullResponse pull) async {
    for (final ep in pull.episodeProgress) {
      await progressStore.upsert(ep);
    }
    for (final wh in pull.watchHistory) {
      await progressStore.upsertWatchHistory(
        anilistId: wh.anilistId,
        episodeNumber: wh.lastEpisodeNumber,
        positionSeconds: wh.lastPositionSeconds,
        totalDurationSeconds: wh.lastTotalDurationSeconds,
        lastSourcePluginId: wh.lastSourcePluginId,
        lastAccessedAt: wh.lastAccessedAt,
      );
    }
    for (final pref in pull.playbackPreferences) {
      await progressStore.upsertPlaybackPreference(pref);
    }
    for (final lib in pull.libraryEntries) {
      await libraryStore.setFavorite(
        lib.anilistId,
        isFavorite: lib.isFavorite,
        addedAt: lib.addedAt,
      );
      await libraryStore.setSubscription(lib.anilistId, notify: lib.notify);
      await libraryStore.setAutoDownload(
        lib.anilistId,
        autoDownload: lib.autoDownloadNewEpisodes,
      );
      if (lib.autoDownloadAudioPreference != null) {
        await libraryStore.setAutoDownloadAudioPreference(
          lib.anilistId,
          lib.autoDownloadAudioPreference!,
        );
      }
      if (lib.lastNotifiedEpisode != null) {
        await libraryStore.updateLastNotifiedEpisode(
          lib.anilistId,
          lib.lastNotifiedEpisode!,
        );
      }
    }
  }
}
