import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../contracts/sync_queue_store.dart';
import '../contracts/sync_service.dart';
import '../models/durable_until.dart';
import '../models/library_sync_entry.dart';
import '../models/sync_conflict.dart';
import '../models/sync_pull_response.dart';
import '../models/sync_queue_entry.dart';
import '../models/sync_status.dart';

/// Max retry attempts per entry before it is parked in `poisoned` state.
/// Poisoned entries are excluded from `getPendingEntries` so one bad payload
/// cannot block the whole queue.
const int _maxRetryCount = 8;

/// Concrete [SyncService] that pushes/pulls sync data to the Kumoriya backend.
///
/// ## Durability contract (client is source of truth)
///
/// The server buffers pushes in RAM and flushes to Neon every ~2h. A `200 OK`
/// on `/sync/push` only means **absorbed in RAM**, not persisted. To avoid
/// data loss on server restarts, this service **never** deletes queue entries
/// on push success. Instead:
///
/// 1. On push success, entries are left in `syncing` status.
/// 2. The server returns `durable_until` (per entity) in the push and pull
///    responses, representing the highest client-assigned timestamp that is
///    already committed to Neon.
/// 3. Any queue entry whose payload timestamp is `<= durable_until[entity]`
///    is deleted from the local queue.
/// 4. Entries that exceed [_maxRetryCount] are marked `poisoned`.
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

  @override
  void restoreLastSyncAt(DateTime? value) {
    _lastSyncAt = value;
  }

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

          // Manga entities are tracked locally but the backend does not
          // accept them yet (Slice 10C-2). They stay in `pending` so the
          // server can drain them once the endpoints land — without a
          // local migration. Anime entities go through the normal path.
          final pushable = entries
              .where((e) => _isBackendPushable(e.entityType))
              .toList(growable: false);
          if (pushable.isEmpty) {
            _currentStatus = SyncStatus.idle;
            return const Success(SyncPushResult(applied: 0, conflicts: []));
          }

          // Mark all as syncing.
          for (final entry in pushable) {
            await queueStore.updateStatus(
              id: entry.id,
              status: SyncQueueEntryStatus.syncing,
            );
          }

          // Group by entity type and build payload.
          final payload = _buildPushPayload(pushable);

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

              // The server may echo back `durable_until` cursors per entity.
              // Any queue entry whose payload timestamp is <= the matching
              // cursor is confirmed persisted to Neon and safe to delete.
              final durable = DurableUntil.fromJson(
                data['durable_until'] as Map<String, dynamic>?,
              );
              await _pruneByDurability(pushable, durable);

              _currentStatus = SyncStatus.success;
              return Success(
                SyncPushResult(applied: applied, conflicts: conflictsList),
              );
            }

            // Permanent 4xx (except 429) → entries are bad and will never
            // succeed. Park them as poisoned immediately.
            final isPermanent4xx =
                response.statusCode >= 400 &&
                response.statusCode < 500 &&
                response.statusCode != 429;

            for (final entry in pushable) {
              final nextRetry = entry.retryCount + 1;
              final exhausted = nextRetry >= _maxRetryCount;
              await queueStore.updateStatus(
                id: entry.id,
                status: (isPermanent4xx || exhausted)
                    ? SyncQueueEntryStatus.poisoned
                    : SyncQueueEntryStatus.failed,
                retryCount: nextRetry,
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
            for (final entry in pushable) {
              final nextRetry = entry.retryCount + 1;
              final exhausted = nextRetry >= _maxRetryCount;
              await queueStore.updateStatus(
                id: entry.id,
                status: exhausted
                    ? SyncQueueEntryStatus.poisoned
                    : SyncQueueEntryStatus.failed,
                retryCount: nextRetry,
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

      // Apply to local stores. If any write fails we keep `_lastSyncAt`
      // unchanged so the next pull will re-fetch the same window — the
      // alternative (advancing the cursor on partial failure) silently
      // drops the rows that never made it to disk.
      final allApplied = await _applyPullToLocal(pullResponse);

      // Prune queue entries already durable on the server. This can happen
      // even on a plain pull (no push in this cycle) because another device
      // may have pushed data that was flushed.
      final pendingResult = await queueStore.getPendingEntries();
      final pendingEntries = pendingResult.fold(
        onSuccess: (v) => v,
        onFailure: (_) => const <SyncQueueEntry>[],
      );
      await _pruneByDurability(pendingEntries, pullResponse.durableUntil);

      if (allApplied) {
        _lastSyncAt = pullResponse.serverTime;
      }
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

  @override
  Future<Result<DateTime?, KumoriyaError>> getLastSyncAt() async {
    return Success(_lastSyncAt);
  }

  /// Deletes queue entries whose payload timestamp is `<= durable[entity]`.
  /// Entries without a timestamp (e.g. malformed payload) are kept.
  Future<void> _pruneByDurability(
    List<SyncQueueEntry> entries,
    DurableUntil durable,
  ) async {
    if (entries.isEmpty) return;
    final toDelete = <int>[];
    for (final entry in entries) {
      final ts = _payloadTimestamp(entry);
      if (ts == null) continue;
      final cursor = _cursorFor(entry.entityType, durable);
      if (cursor > 0 && ts <= cursor) {
        toDelete.add(entry.id);
      }
    }
    if (toDelete.isNotEmpty) {
      await queueStore.deleteEntries(toDelete);
    }
  }

  int _cursorFor(SyncEntityType type, DurableUntil d) {
    switch (type) {
      case SyncEntityType.episodeProgress:
        return d.episodeProgress;
      case SyncEntityType.watchHistory:
      case SyncEntityType.watchHistoryDeletion:
        return d.watchHistory;
      case SyncEntityType.playbackPreference:
        return d.playbackPreference;
      case SyncEntityType.libraryEntry:
      case SyncEntityType.libraryEntryDeletion:
        return d.libraryEntry;
      case SyncEntityType.mangaChapterProgress:
        return d.mangaChapterProgress;
      case SyncEntityType.mangaReadHistory:
      case SyncEntityType.mangaReadHistoryDeletion:
        return d.mangaReadHistory;
      case SyncEntityType.mangaLibraryEntry:
      case SyncEntityType.mangaLibraryEntryDeletion:
        return d.mangaLibraryEntry;
    }
  }

  /// Extracts the LWW timestamp used by the server for this entity. Returns
  /// `null` if the payload is malformed.
  int? _payloadTimestamp(SyncQueueEntry entry) {
    try {
      final decoded = jsonDecode(entry.payload) as Map<String, dynamic>;
      switch (entry.entityType) {
        case SyncEntityType.episodeProgress:
        case SyncEntityType.playbackPreference:
          return (decoded['updated_at'] as num?)?.toInt();
        case SyncEntityType.watchHistory:
          return (decoded['last_accessed_at'] as num?)?.toInt();
        case SyncEntityType.watchHistoryDeletion:
          // Deletions carry `updated_at` (client assigns at enqueue time).
          // Older payloads without it fall back to `createdAt`.
          return (decoded['updated_at'] as num?)?.toInt() ??
              entry.createdAt.millisecondsSinceEpoch;
        case SyncEntityType.libraryEntry:
        case SyncEntityType.libraryEntryDeletion:
          return (decoded['updated_at'] as num?)?.toInt();
        // Manga payloads carry the same `updated_at` shape; reading
        // them keeps `_pruneByDurability` consistent if a future cursor
        // gets wired without touching this method again.
        case SyncEntityType.mangaChapterProgress:
        case SyncEntityType.mangaLibraryEntry:
        case SyncEntityType.mangaLibraryEntryDeletion:
        case SyncEntityType.mangaReadHistoryDeletion:
          return (decoded['updated_at'] as num?)?.toInt();
        case SyncEntityType.mangaReadHistory:
          return (decoded['last_accessed_at'] as num?)?.toInt();
      }
    } catch (_) {
      return null;
    }
  }

  /// Entity types the Kumoriya Go backend accepts.
  ///
  /// As of Slice 10C-2 the backend ships manga endpoints, so all known
  /// types are pushable. The helper is kept (instead of inlined as a
  /// constant `true`) so a future "queue this kind locally only" path
  /// has a single switch-statement seam to flip.
  static bool _isBackendPushable(SyncEntityType type) {
    switch (type) {
      case SyncEntityType.episodeProgress:
      case SyncEntityType.watchHistory:
      case SyncEntityType.watchHistoryDeletion:
      case SyncEntityType.playbackPreference:
      case SyncEntityType.libraryEntry:
      case SyncEntityType.libraryEntryDeletion:
      case SyncEntityType.mangaChapterProgress:
      case SyncEntityType.mangaReadHistory:
      case SyncEntityType.mangaReadHistoryDeletion:
      case SyncEntityType.mangaLibraryEntry:
      case SyncEntityType.mangaLibraryEntryDeletion:
        return true;
    }
  }

  Map<String, dynamic> _buildPushPayload(List<SyncQueueEntry> entries) {
    final episodeProgress = <Map<String, dynamic>>[];
    final watchHistory = <Map<String, dynamic>>[];
    final watchHistoryDeletions = <Map<String, dynamic>>[];
    final playbackPreferences = <Map<String, dynamic>>[];
    final libraryEntries = <Map<String, dynamic>>[];
    final libraryEntryDeletions = <Map<String, dynamic>>[];
    final mangaLibraryEntries = <Map<String, dynamic>>[];
    final mangaLibraryEntryDeletions = <Map<String, dynamic>>[];
    final mangaChapterProgress = <Map<String, dynamic>>[];
    final mangaReadHistory = <Map<String, dynamic>>[];
    final mangaReadHistoryDeletions = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final decoded = jsonDecode(entry.payload) as Map<String, dynamic>;
      switch (entry.entityType) {
        case SyncEntityType.episodeProgress:
          episodeProgress.add(decoded);
        case SyncEntityType.watchHistory:
          watchHistory.add(decoded);
        case SyncEntityType.watchHistoryDeletion:
          watchHistoryDeletions.add(decoded);
        case SyncEntityType.playbackPreference:
          playbackPreferences.add(decoded);
        case SyncEntityType.libraryEntry:
          libraryEntries.add(decoded);
        case SyncEntityType.libraryEntryDeletion:
          libraryEntryDeletions.add(decoded);
        case SyncEntityType.mangaLibraryEntry:
          mangaLibraryEntries.add(decoded);
        case SyncEntityType.mangaLibraryEntryDeletion:
          mangaLibraryEntryDeletions.add(decoded);
        case SyncEntityType.mangaChapterProgress:
          mangaChapterProgress.add(decoded);
        case SyncEntityType.mangaReadHistory:
          mangaReadHistory.add(decoded);
        case SyncEntityType.mangaReadHistoryDeletion:
          mangaReadHistoryDeletions.add(decoded);
      }
    }

    return {
      'episode_progress': episodeProgress,
      'watch_history': watchHistory,
      'watch_history_deletions': watchHistoryDeletions,
      'playback_preferences': playbackPreferences,
      'library_entries': libraryEntries,
      'library_entry_deletions': libraryEntryDeletions,
      'manga_library_entries': mangaLibraryEntries,
      'manga_library_entry_deletions': mangaLibraryEntryDeletions,
      'manga_chapter_progress': mangaChapterProgress,
      'manga_read_history': mangaReadHistory,
      'manga_read_history_deletions': mangaReadHistoryDeletions,
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

    final durable = DurableUntil.fromJson(
      data['durable_until'] as Map<String, dynamic>?,
    );

    return SyncPullResponse(
      serverTime: DateTime.fromMillisecondsSinceEpoch(serverTimeMs),
      episodeProgress: episodes,
      watchHistory: history,
      playbackPreferences: prefs,
      libraryEntries: library,
      durableUntil: durable,
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
    final addedAt = _tryParseTimestamp(data['added_at']);
    final updatedAt = _tryParseTimestamp(data['updated_at']);
    return LibrarySyncEntry(
      anilistId: (data['anilist_id'] as num).toInt(),
      isFavorite: addedAt != null,
      notify: data['notify_new_episodes'] as bool? ?? false,
      lastNotifiedEpisode: (data['last_notified_episode'] as num?)?.toInt(),
      autoDownloadNewEpisodes:
          data['auto_download_new_episodes'] as bool? ?? false,
      autoDownloadAudioPreference:
          data['auto_download_audio_preference'] as String?,
      addedAt: addedAt,
      updatedAt: updatedAt,
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

  /// Applies pulled rows to the local (raw, non-sync-aware) stores.
  /// Returns `true` only when every row was written successfully — a single
  /// failure must keep `_lastSyncAt` from advancing so the next pull re-tries
  /// the same window.
  Future<bool> _applyPullToLocal(SyncPullResponse pull) async {
    var ok = true;
    for (final ep in pull.episodeProgress) {
      final r = await progressStore.upsert(ep);
      if (r.isFailure) ok = false;
    }
    for (final wh in pull.watchHistory) {
      final r = await progressStore.upsertWatchHistory(
        anilistId: wh.anilistId,
        episodeNumber: wh.lastEpisodeNumber,
        positionSeconds: wh.lastPositionSeconds,
        totalDurationSeconds: wh.lastTotalDurationSeconds,
        lastSourcePluginId: wh.lastSourcePluginId,
        lastAccessedAt: wh.lastAccessedAt,
      );
      if (r.isFailure) ok = false;
    }
    for (final pref in pull.playbackPreferences) {
      final r = await progressStore.upsertPlaybackPreference(pref);
      if (r.isFailure) ok = false;
    }
    for (final lib in pull.libraryEntries) {
      final r = await libraryStore.setFavorite(
        lib.anilistId,
        isFavorite: lib.isFavorite,
        addedAt: lib.addedAt,
      );
      if (r.isFailure) ok = false;
      final rSub = await libraryStore.setSubscription(
        lib.anilistId,
        notify: lib.notify,
      );
      if (rSub.isFailure) ok = false;
      final rDl = await libraryStore.setAutoDownload(
        lib.anilistId,
        autoDownload: lib.autoDownloadNewEpisodes,
      );
      if (rDl.isFailure) ok = false;
      if (lib.autoDownloadAudioPreference != null) {
        await libraryStore.setAutoDownloadAudioPreference(
          lib.anilistId,
          lib.autoDownloadAudioPreference!,
        );
      }
      if (lib.lastNotifiedEpisode != null) {
        final r2 = await libraryStore.updateLastNotifiedEpisode(
          lib.anilistId,
          lib.lastNotifiedEpisode!,
        );
        if (r2.isFailure) ok = false;
      }
    }
    return ok;
  }
}
