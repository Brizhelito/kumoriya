import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/anime_progress_store.dart';
import 'app_database.dart';
import 'daos/playback_preference_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/watch_history_dao.dart';

final class DriftAnimeProgressStore implements AnimeProgressStore {
  DriftAnimeProgressStore(AppDatabase db)
    : _progressDao = ProgressDao(db),
      _historyDao = WatchHistoryDao(db),
      _preferenceDao = PlaybackPreferenceDao(db);

  final ProgressDao _progressDao;
  final WatchHistoryDao _historyDao;
  final PlaybackPreferenceDao _preferenceDao;

  @override
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress) async {
    try {
      final now = progress.updatedAt.millisecondsSinceEpoch;
      await _progressDao.upsertProgress(
        EpisodeProgressTableCompanion(
          anilistId: Value(progress.anilistId),
          episodeNumber: Value(progress.episodeNumber),
          positionSeconds: Value(progress.position.inSeconds),
          totalDurationSeconds: progress.totalDuration != null
              ? Value(progress.totalDuration!.inSeconds)
              : const Value.absent(),
          watchState: Value(progress.watchState.name),
          lastSourcePluginId: Value(progress.lastSourcePluginId),
          lastServerName: Value(progress.lastServerName),
          lastResolverPluginId: Value(progress.lastResolverPluginId),
          updatedAt: Value(now),
        ),
      );

      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.upsert_failed',
          message: 'Failed to save episode progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
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
    try {
      final ts = (lastAccessedAt ?? DateTime.now()).millisecondsSinceEpoch;
      await _historyDao.upsertHistory(
        WatchHistoryTableCompanion(
          anilistId: Value(anilistId),
          lastEpisodeNumber: Value(episodeNumber),
          lastSourcePluginId: Value(lastSourcePluginId),
          lastPositionSeconds: Value(positionSeconds),
          lastTotalDurationSeconds: totalDurationSeconds != null
              ? Value(totalDurationSeconds)
              : const Value.absent(),
          lastAccessedAt: Value(ts),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.history_upsert_failed',
          message: 'Failed to save watch history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  ) async {
    try {
      final row = await _progressDao.getProgress(anilistId, episodeNumber);
      return Success(row != null ? _rowToProgress(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.read_failed',
          message: 'Failed to read episode progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getLatestProgress(
    int anilistId,
  ) async {
    try {
      final row = await _progressDao.getLatestProgress(anilistId);
      return Success(row != null ? _rowToProgress(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.read_failed',
          message: 'Failed to read latest episode progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<EpisodeProgress>, KumoriyaError>> getAllProgress(
    int anilistId,
  ) async {
    try {
      final rows = await _progressDao.getAllProgress(anilistId);
      return Success(rows.map(_rowToProgress).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.read_failed',
          message: 'Failed to read all progress: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) async {
    try {
      final rows = await _historyDao.getRecentHistory(limit);
      return Success(
        rows
            .map(
              (r) => AnimeWatchHistory(
                anilistId: r.anilistId,
                lastEpisodeNumber: r.lastEpisodeNumber,
                lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(
                  r.lastAccessedAt,
                ),
                lastSourcePluginId: r.lastSourcePluginId,
                lastPositionSeconds: r.lastPositionSeconds,
                lastTotalDurationSeconds: r.lastTotalDurationSeconds,
              ),
            )
            .toList(),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.read_failed',
          message: 'Failed to read watch history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  AnimeWatchHistory _mapHistoryRow(WatchHistoryTableData r) =>
      AnimeWatchHistory(
        anilistId: r.anilistId,
        lastEpisodeNumber: r.lastEpisodeNumber,
        lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(r.lastAccessedAt),
        lastSourcePluginId: r.lastSourcePluginId,
        lastPositionSeconds: r.lastPositionSeconds,
        lastTotalDurationSeconds: r.lastTotalDurationSeconds,
      );

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getAllHistory() async {
    try {
      final rows = await _historyDao.getAllHistory();
      return Success(rows.map(_mapHistoryRow).toList());
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.read_failed',
          message: 'Failed to read all watch history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> deleteHistoryEntry(int anilistId) async {
    try {
      await _historyDao.deleteHistoryEntry(anilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.delete_failed',
          message: 'Failed to delete history entry: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllHistory() async {
    try {
      await _historyDao.clearAllHistory();
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.delete_failed',
          message: 'Failed to clear watch history: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference preference,
  ) async {
    try {
      await _preferenceDao.upsertPlaybackPreference(
        PlaybackPreferenceTableCompanion(
          anilistId: Value(preference.anilistId),
          preferredSourcePluginId: Value(preference.preferredSourcePluginId),
          preferredServerName: Value(preference.preferredServerName),
          preferredResolverPluginId: Value(
            preference.preferredResolverPluginId,
          ),
          preferredAudioPreference: Value(
            preference.preferredAudioPreference?.name,
          ),
          updatedAt: Value(preference.updatedAt.millisecondsSinceEpoch),
        ),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.preference_upsert_failed',
          message: 'Failed to save playback preference: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<PlaybackPreference?, KumoriyaError>> getPlaybackPreference(
    int anilistId,
  ) async {
    try {
      final row = await _preferenceDao.getPlaybackPreference(anilistId);
      return Success(row != null ? _rowToPlaybackPreference(row) : null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.preference_read_failed',
          message: 'Failed to read playback preference: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(
    int anilistId,
  ) async {
    try {
      await _preferenceDao.deletePlaybackPreference(anilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.preference_clear_failed',
          message: 'Failed to clear playback preference: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllPlaybackPreferences() async {
    try {
      await _preferenceDao.deleteAllPlaybackPreferences();
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.preference_clear_all_failed',
          message: 'Failed to clear playback preferences: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  EpisodeProgress _rowToProgress(EpisodeProgressTableData row) {
    return EpisodeProgress(
      anilistId: row.anilistId,
      episodeNumber: row.episodeNumber,
      position: Duration(seconds: row.positionSeconds),
      totalDuration: row.totalDurationSeconds != null
          ? Duration(seconds: row.totalDurationSeconds!)
          : null,
      watchState: WatchState.values.firstWhere(
        (s) => s.name == row.watchState,
        orElse: () => WatchState.unwatched,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      lastSourcePluginId: row.lastSourcePluginId,
      lastServerName: row.lastServerName,
      lastResolverPluginId: row.lastResolverPluginId,
    );
  }

  PlaybackPreference _rowToPlaybackPreference(PlaybackPreferenceTableData row) {
    return PlaybackPreference(
      anilistId: row.anilistId,
      preferredSourcePluginId: row.preferredSourcePluginId,
      preferredServerName: row.preferredServerName,
      preferredResolverPluginId: row.preferredResolverPluginId,
      preferredAudioPreference: row.preferredAudioPreference == null
          ? null
          : PlaybackAudioPreference.values.firstWhere(
              (value) => value.name == row.preferredAudioPreference,
              orElse: () => PlaybackAudioPreference.sub,
            ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
