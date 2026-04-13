package repository

import (
	"context"

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

// DeleteWatchHistory removes a watch history entry for a given user and anilist ID.
func (r *SyncRepo) DeleteWatchHistory(ctx context.Context, userID uuid.UUID, anilistID int) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM sync_watch_history WHERE user_id = $1 AND anilist_id = $2`,
		userID, anilistID,
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
	// Library entries use added_at = LEAST(old, new) in the upsert, so added_at
	// can go backward.  Pull all entries for the user to avoid missed updates.
	// Library set is small/bounded per user.
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, anilist_id, added_at, notify_new_episodes, last_notified_episode,
		        auto_download_new_episodes, auto_download_audio_preference
		 FROM sync_library_entry
		 WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.LibraryEntry
	for rows.Next() {
		var le model.LibraryEntry
		if err := rows.Scan(&le.UserID, &le.AnilistID, &le.AddedAt, &le.NotifyNewEpisodes, &le.LastNotifiedEpisode,
			&le.AutoDownloadNewEpisodes, &le.AutoDownloadAudioPref); err != nil {
			return nil, err
		}
		items = append(items, le)
	}
	return items, rows.Err()
}

func (r *SyncRepo) UpsertLibraryEntry(ctx context.Context, userID uuid.UUID, le model.LibraryEntry) (bool, error) {
	// LWW by added_at; merge booleans (if either side is true, keep true)
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_library_entry
		   (user_id, anilist_id, added_at, notify_new_episodes, last_notified_episode,
		    auto_download_new_episodes, auto_download_audio_preference)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (user_id, anilist_id)
		 DO UPDATE SET
		   added_at = LEAST(sync_library_entry.added_at, EXCLUDED.added_at),
		   notify_new_episodes = sync_library_entry.notify_new_episodes OR EXCLUDED.notify_new_episodes,
		   last_notified_episode = CASE
		     WHEN sync_library_entry.last_notified_episode IS NULL THEN EXCLUDED.last_notified_episode
		     WHEN EXCLUDED.last_notified_episode IS NULL THEN sync_library_entry.last_notified_episode
		     ELSE GREATEST(sync_library_entry.last_notified_episode, EXCLUDED.last_notified_episode)
		   END,
		   auto_download_new_episodes = sync_library_entry.auto_download_new_episodes OR EXCLUDED.auto_download_new_episodes,
		   auto_download_audio_preference = CASE
		     WHEN EXCLUDED.added_at > sync_library_entry.added_at THEN EXCLUDED.auto_download_audio_preference
		     ELSE sync_library_entry.auto_download_audio_preference
		   END`,
		userID, le.AnilistID, le.AddedAt, le.NotifyNewEpisodes, le.LastNotifiedEpisode,
		le.AutoDownloadNewEpisodes, le.AutoDownloadAudioPref,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}
