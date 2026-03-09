import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/anime_progress_store.dart';
import 'app_database.dart';
import 'daos/progress_dao.dart';

final class DriftAnimeProgressStore implements AnimeProgressStore {
  DriftAnimeProgressStore(AppDatabase db) : _dao = ProgressDao(db);

  final ProgressDao _dao;

  @override
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress) async {
    try {
      final now = progress.updatedAt.millisecondsSinceEpoch;
      await _dao.upsertProgress(
        EpisodeProgressTableCompanion(
          anilistId: Value(progress.anilistId),
          episodeNumber: Value(progress.episodeNumber),
          positionSeconds: Value(progress.position.inSeconds),
          totalDurationSeconds: progress.totalDuration != null
              ? Value(progress.totalDuration!.inSeconds)
              : const Value.absent(),
          watchState: Value(progress.watchState.name),
          lastSourcePluginId: progress.lastSourcePluginId != null
              ? Value(progress.lastSourcePluginId)
              : const Value.absent(),
          lastServerName: progress.lastServerName != null
              ? Value(progress.lastServerName)
              : const Value.absent(),
          lastResolverPluginId: progress.lastResolverPluginId != null
              ? Value(progress.lastResolverPluginId)
              : const Value.absent(),
          updatedAt: Value(now),
        ),
      );

      await _dao.upsertHistory(
        WatchHistoryTableCompanion(
          anilistId: Value(progress.anilistId),
          lastEpisodeNumber: Value(progress.episodeNumber),
          lastSourcePluginId: progress.lastSourcePluginId != null
              ? Value(progress.lastSourcePluginId)
              : const Value.absent(),
          lastAccessedAt: Value(now),
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
  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  ) async {
    try {
      final row = await _dao.getProgress(anilistId, episodeNumber);
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
      final row = await _dao.getLatestProgress(anilistId);
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
      final rows = await _dao.getAllProgress(anilistId);
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
      final rows = await _dao.getRecentHistory(limit);
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

  @override
  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference preference,
  ) async {
    try {
      await _dao.upsertPlaybackPreference(
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
      final row = await _dao.getPlaybackPreference(anilistId);
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
