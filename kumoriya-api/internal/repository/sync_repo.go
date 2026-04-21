package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"go-fiber-microservice/internal/model"
)

type SyncRepo struct {
	pool *pgxpool.Pool
}

func NewSyncRepo(pool *pgxpool.Pool) *SyncRepo {
	return &SyncRepo{pool: pool}
}

// --- Episode Progress ---

func (r *SyncRepo) PullEpisodeProgress(ctx context.Context, userID uuid.UUID, since int64) ([]model.EpisodeProgress, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, anilist_id, episode_number, position_seconds,
		        total_duration_seconds, watch_state,
		        last_source_plugin_id, last_server_name, last_resolver_plugin_id, updated_at
		 FROM sync_episode_progress
		 WHERE user_id = $1 AND updated_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.EpisodeProgress
	for rows.Next() {
		var ep model.EpisodeProgress
		if err := rows.Scan(&ep.UserID, &ep.AnilistID, &ep.EpisodeNumber, &ep.PositionSeconds,
			&ep.TotalDuration, &ep.WatchState,
			&ep.LastSourcePluginID, &ep.LastServerName, &ep.LastResolverID, &ep.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, ep)
	}
	return items, rows.Err()
}

func (r *SyncRepo) UpsertEpisodeProgress(ctx context.Context, userID uuid.UUID, ep model.EpisodeProgress) (bool, error) {
	// LWW by updated_at with a no-regress guard for position_seconds when the watch state is unchanged.
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_episode_progress
		   (user_id, anilist_id, episode_number, position_seconds, total_duration_seconds,
		    watch_state, last_source_plugin_id, last_server_name, last_resolver_plugin_id, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 ON CONFLICT (user_id, anilist_id, episode_number)
		 DO UPDATE SET
		   position_seconds = CASE
		     WHEN EXCLUDED.updated_at > sync_episode_progress.updated_at
		       AND (
		         EXCLUDED.watch_state <> sync_episode_progress.watch_state
		         OR EXCLUDED.position_seconds >= sync_episode_progress.position_seconds
		       )
		       THEN EXCLUDED.position_seconds
		     ELSE sync_episode_progress.position_seconds
		   END,
		   total_duration_seconds = CASE
		     WHEN EXCLUDED.updated_at > sync_episode_progress.updated_at THEN EXCLUDED.total_duration_seconds
		     ELSE sync_episode_progress.total_duration_seconds
		   END,
		   watch_state = CASE
		     WHEN EXCLUDED.updated_at > sync_episode_progress.updated_at THEN EXCLUDED.watch_state
		     ELSE sync_episode_progress.watch_state
		   END,
		   last_source_plugin_id = CASE
		     WHEN EXCLUDED.updated_at > sync_episode_progress.updated_at THEN EXCLUDED.last_source_plugin_id
		     ELSE sync_episode_progress.last_source_plugin_id
		   END,
		   last_server_name = CASE
		     WHEN EXCLUDED.updated_at > sync_episode_progress.updated_at THEN EXCLUDED.last_server_name
		     ELSE sync_episode_progress.last_server_name
		   END,
		   last_resolver_plugin_id = CASE
		     WHEN EXCLUDED.updated_at > sync_episode_progress.updated_at THEN EXCLUDED.last_resolver_plugin_id
		     ELSE sync_episode_progress.last_resolver_plugin_id
		   END,
		   updated_at = GREATEST(EXCLUDED.updated_at, sync_episode_progress.updated_at)
		 WHERE EXCLUDED.updated_at > sync_episode_progress.updated_at`,
		userID, ep.AnilistID, ep.EpisodeNumber, ep.PositionSeconds,
		ep.TotalDuration, ep.WatchState,
		ep.LastSourcePluginID, ep.LastServerName, ep.LastResolverID, ep.UpdatedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// --- Watch History ---

func (r *SyncRepo) PullWatchHistory(ctx context.Context, userID uuid.UUID, since int64) ([]model.WatchHistory, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, anilist_id, last_episode_number, last_source_plugin_id,
		        last_position_seconds, last_total_duration_seconds, last_accessed_at
		 FROM sync_watch_history
		 WHERE user_id = $1 AND last_accessed_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.WatchHistory
	for rows.Next() {
		var wh model.WatchHistory
		if err := rows.Scan(&wh.UserID, &wh.AnilistID, &wh.LastEpisodeNumber, &wh.LastSourcePluginID,
			&wh.LastPositionSecs, &wh.LastTotalDuration, &wh.LastAccessedAt); err != nil {
			return nil, err
		}
		items = append(items, wh)
	}
	return items, rows.Err()
}

func (r *SyncRepo) UpsertWatchHistory(ctx context.Context, userID uuid.UUID, wh model.WatchHistory) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_watch_history
		   (user_id, anilist_id, last_episode_number, last_source_plugin_id,
		    last_position_seconds, last_total_duration_seconds, last_accessed_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (user_id, anilist_id)
		 DO UPDATE SET
		   last_episode_number = EXCLUDED.last_episode_number,
		   last_source_plugin_id = EXCLUDED.last_source_plugin_id,
		   last_position_seconds = EXCLUDED.last_position_seconds,
		   last_total_duration_seconds = EXCLUDED.last_total_duration_seconds,
		   last_accessed_at = EXCLUDED.last_accessed_at
		 WHERE EXCLUDED.last_accessed_at > sync_watch_history.last_accessed_at`,
		userID, wh.AnilistID, wh.LastEpisodeNumber, wh.LastSourcePluginID,
		wh.LastPositionSecs, wh.LastTotalDuration, wh.LastAccessedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// DeleteWatchHistory removes a watch-history row only when the deletion
// timestamp is at least as recent as the existing row's last_accessed_at.
// Without this LWW guard a stale deletion replayed by the client queue would
// erase a freshly-written entry.
func (r *SyncRepo) DeleteWatchHistory(ctx context.Context, userID uuid.UUID, anilistID int, tsMs int64) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM sync_watch_history
		 WHERE user_id = $1 AND anilist_id = $2 AND last_accessed_at <= $3`,
		userID, anilistID, tsMs,
	)
	return err
}

// --- Playback Preferences ---

func (r *SyncRepo) PullPlaybackPreferences(ctx context.Context, userID uuid.UUID, since int64) ([]model.PlaybackPreference, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, anilist_id, preferred_source_plugin_id, preferred_server_name,
		        preferred_resolver_plugin_id, preferred_audio_preference, updated_at
		 FROM sync_playback_preference
		 WHERE user_id = $1 AND updated_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.PlaybackPreference
	for rows.Next() {
		var pp model.PlaybackPreference
		if err := rows.Scan(&pp.UserID, &pp.AnilistID, &pp.PreferredSourceID, &pp.PreferredServerName,
			&pp.PreferredResolverID, &pp.PreferredAudioPref, &pp.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, pp)
	}
	return items, rows.Err()
}

func (r *SyncRepo) UpsertPlaybackPreference(ctx context.Context, userID uuid.UUID, pp model.PlaybackPreference) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_playback_preference
		   (user_id, anilist_id, preferred_source_plugin_id, preferred_server_name,
		    preferred_resolver_plugin_id, preferred_audio_preference, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (user_id, anilist_id)
		 DO UPDATE SET
		   preferred_source_plugin_id = EXCLUDED.preferred_source_plugin_id,
		   preferred_server_name = EXCLUDED.preferred_server_name,
		   preferred_resolver_plugin_id = EXCLUDED.preferred_resolver_plugin_id,
		   preferred_audio_preference = EXCLUDED.preferred_audio_preference,
		   updated_at = EXCLUDED.updated_at
		 WHERE EXCLUDED.updated_at > sync_playback_preference.updated_at`,
		userID, pp.AnilistID, pp.PreferredSourceID, pp.PreferredServerName,
		pp.PreferredResolverID, pp.PreferredAudioPref, pp.UpdatedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// --- Library Entries ---

func (r *SyncRepo) PullLibraryEntries(ctx context.Context, userID uuid.UUID, since int64) ([]model.LibraryEntry, error) {
	// Library state uses LWW on updated_at. Pulling with `updated_at > since`
	// is correct now that added_at is no longer the ordering key.
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, anilist_id, added_at, notify_new_episodes, last_notified_episode,
		        auto_download_new_episodes, auto_download_audio_preference, updated_at
		 FROM sync_library_entry
		 WHERE user_id = $1 AND updated_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.LibraryEntry
	for rows.Next() {
		var le model.LibraryEntry
		if err := rows.Scan(&le.UserID, &le.AnilistID, &le.AddedAt, &le.NotifyNewEpisodes, &le.LastNotifiedEpisode,
			&le.AutoDownloadNewEpisodes, &le.AutoDownloadAudioPref, &le.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, le)
	}
	return items, rows.Err()
}

// UpsertLibraryEntry replaces the whole row when the incoming updated_at is
// strictly newer. This lets unfavorite (added_at = 0) correctly win over a
// previous favorite (added_at > 0), which the previous `LEAST(added_at)`
// semantics made impossible.
func (r *SyncRepo) UpsertLibraryEntry(ctx context.Context, userID uuid.UUID, le model.LibraryEntry) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_library_entry
		   (user_id, anilist_id, added_at, notify_new_episodes, last_notified_episode,
		    auto_download_new_episodes, auto_download_audio_preference, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		 ON CONFLICT (user_id, anilist_id)
		 DO UPDATE SET
		   added_at                      = EXCLUDED.added_at,
		   notify_new_episodes           = EXCLUDED.notify_new_episodes,
		   last_notified_episode         = CASE
		     WHEN sync_library_entry.last_notified_episode IS NULL THEN EXCLUDED.last_notified_episode
		     WHEN EXCLUDED.last_notified_episode IS NULL THEN sync_library_entry.last_notified_episode
		     ELSE GREATEST(sync_library_entry.last_notified_episode, EXCLUDED.last_notified_episode)
		   END,
		   auto_download_new_episodes    = EXCLUDED.auto_download_new_episodes,
		   auto_download_audio_preference = EXCLUDED.auto_download_audio_preference,
		   updated_at                    = EXCLUDED.updated_at
		 WHERE EXCLUDED.updated_at > sync_library_entry.updated_at`,
		userID, le.AnilistID, le.AddedAt, le.NotifyNewEpisodes, le.LastNotifiedEpisode,
		le.AutoDownloadNewEpisodes, le.AutoDownloadAudioPref, le.UpdatedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// DeleteLibraryEntry removes the row only when the incoming deletion is at
// least as recent as the current updated_at. Mirrors DeleteWatchHistory's
// LWW guard.
func (r *SyncRepo) DeleteLibraryEntry(ctx context.Context, userID uuid.UUID, anilistID int, tsMs int64) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM sync_library_entry
		 WHERE user_id = $1 AND anilist_id = $2 AND updated_at <= $3`,
		userID, anilistID, tsMs,
	)
	return err
}

// --- Durability cursors ---

// MaxDurableTimestamps reads the current max client-assigned timestamp per
// entity for a user. Used to rehydrate in-memory `durable_until` cursors
// after a server restart, so clients can resume pruning their queues without
// losing data.
func (r *SyncRepo) MaxDurableTimestamps(ctx context.Context, userID uuid.UUID) (model.DurableUntil, error) {
	var d model.DurableUntil
	var ep, wh, pp, le sql.NullInt64
	err := r.pool.QueryRow(ctx,
		`SELECT
		   (SELECT MAX(updated_at)      FROM sync_episode_progress    WHERE user_id = $1),
		   (SELECT MAX(last_accessed_at) FROM sync_watch_history       WHERE user_id = $1),
		   (SELECT MAX(updated_at)      FROM sync_playback_preference WHERE user_id = $1),
		   (SELECT MAX(updated_at)      FROM sync_library_entry       WHERE user_id = $1)`,
		userID,
	).Scan(&ep, &wh, &pp, &le)
	if err != nil {
		return d, err
	}
	if ep.Valid {
		d.EpisodeProgress = ep.Int64
	}
	if wh.Valid {
		d.WatchHistory = wh.Int64
	}
	if pp.Valid {
		d.PlaybackPreference = pp.Int64
	}
	if le.Valid {
		d.LibraryEntry = le.Int64
	}
	return d, nil
}
