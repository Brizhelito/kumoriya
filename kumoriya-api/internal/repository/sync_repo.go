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

// --- Manga library entries (Slice 10C-2) ---

func (r *SyncRepo) PullMangaLibraryEntries(ctx context.Context, userID uuid.UUID, since int64) ([]model.MangaLibraryEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, manga_anilist_id, added_at, notify_new_chapters,
		        auto_download_new_chapters, preferred_language, preferred_scanlator,
		        last_notified_chapter, updated_at
		 FROM sync_manga_library_entry
		 WHERE user_id = $1 AND updated_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.MangaLibraryEntry
	for rows.Next() {
		var le model.MangaLibraryEntry
		if err := rows.Scan(&le.UserID, &le.MangaAnilistID, &le.AddedAt,
			&le.NotifyNewChapters, &le.AutoDownloadNewChapters,
			&le.PreferredLanguage, &le.PreferredScanlator,
			&le.LastNotifiedChapter, &le.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, le)
	}
	return items, rows.Err()
}

// UpsertMangaLibraryEntry mirrors UpsertLibraryEntry: full-row replacement
// when EXCLUDED.updated_at is strictly newer. Lets unfavorite (added_at=0)
// win over previous favorite states.
func (r *SyncRepo) UpsertMangaLibraryEntry(ctx context.Context, userID uuid.UUID, le model.MangaLibraryEntry) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_manga_library_entry
		   (user_id, manga_anilist_id, added_at, notify_new_chapters,
		    auto_download_new_chapters, preferred_language, preferred_scanlator,
		    last_notified_chapter, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		 ON CONFLICT (user_id, manga_anilist_id)
		 DO UPDATE SET
		   added_at                   = EXCLUDED.added_at,
		   notify_new_chapters        = EXCLUDED.notify_new_chapters,
		   auto_download_new_chapters = EXCLUDED.auto_download_new_chapters,
		   preferred_language         = EXCLUDED.preferred_language,
		   preferred_scanlator        = EXCLUDED.preferred_scanlator,
		   last_notified_chapter      = CASE
		     WHEN sync_manga_library_entry.last_notified_chapter IS NULL THEN EXCLUDED.last_notified_chapter
		     WHEN EXCLUDED.last_notified_chapter IS NULL THEN sync_manga_library_entry.last_notified_chapter
		     ELSE GREATEST(sync_manga_library_entry.last_notified_chapter, EXCLUDED.last_notified_chapter)
		   END,
		   updated_at                 = EXCLUDED.updated_at
		 WHERE EXCLUDED.updated_at > sync_manga_library_entry.updated_at`,
		userID, le.MangaAnilistID, le.AddedAt, le.NotifyNewChapters,
		le.AutoDownloadNewChapters, le.PreferredLanguage, le.PreferredScanlator,
		le.LastNotifiedChapter, le.UpdatedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (r *SyncRepo) DeleteMangaLibraryEntry(ctx context.Context, userID uuid.UUID, mangaAnilistID int, tsMs int64) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM sync_manga_library_entry
		 WHERE user_id = $1 AND manga_anilist_id = $2 AND updated_at <= $3`,
		userID, mangaAnilistID, tsMs,
	)
	return err
}

// --- Manga chapter progress ---

func (r *SyncRepo) PullMangaChapterProgress(ctx context.Context, userID uuid.UUID, since int64) ([]model.MangaChapterProgress, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, manga_anilist_id, source_id, source_chapter_id,
		        chapter_number, page_index, scroll_offset, read_state, updated_at
		 FROM sync_manga_chapter_progress
		 WHERE user_id = $1 AND updated_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.MangaChapterProgress
	for rows.Next() {
		var cp model.MangaChapterProgress
		if err := rows.Scan(&cp.UserID, &cp.MangaAnilistID, &cp.SourceID, &cp.SourceChapterID,
			&cp.ChapterNumber, &cp.PageIndex, &cp.ScrollOffset,
			&cp.ReadState, &cp.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, cp)
	}
	return items, rows.Err()
}

// UpsertMangaChapterProgress mirrors UpsertEpisodeProgress: LWW on
// updated_at, with a no-regress guard on page_index when the read_state
// is unchanged. Mirrors anime's `position_seconds` guard.
func (r *SyncRepo) UpsertMangaChapterProgress(ctx context.Context, userID uuid.UUID, cp model.MangaChapterProgress) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_manga_chapter_progress
		   (user_id, manga_anilist_id, source_id, source_chapter_id,
		    chapter_number, page_index, scroll_offset, read_state, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		 ON CONFLICT (user_id, manga_anilist_id, source_id, source_chapter_id)
		 DO UPDATE SET
		   chapter_number = CASE
		     WHEN EXCLUDED.updated_at > sync_manga_chapter_progress.updated_at THEN EXCLUDED.chapter_number
		     ELSE sync_manga_chapter_progress.chapter_number
		   END,
		   page_index = CASE
		     WHEN EXCLUDED.updated_at > sync_manga_chapter_progress.updated_at
		       AND (
		         EXCLUDED.read_state <> sync_manga_chapter_progress.read_state
		         OR EXCLUDED.page_index >= sync_manga_chapter_progress.page_index
		       )
		       THEN EXCLUDED.page_index
		     ELSE sync_manga_chapter_progress.page_index
		   END,
		   scroll_offset = CASE
		     WHEN EXCLUDED.updated_at > sync_manga_chapter_progress.updated_at THEN EXCLUDED.scroll_offset
		     ELSE sync_manga_chapter_progress.scroll_offset
		   END,
		   read_state = CASE
		     WHEN EXCLUDED.updated_at > sync_manga_chapter_progress.updated_at THEN EXCLUDED.read_state
		     ELSE sync_manga_chapter_progress.read_state
		   END,
		   updated_at = GREATEST(EXCLUDED.updated_at, sync_manga_chapter_progress.updated_at)
		 WHERE EXCLUDED.updated_at > sync_manga_chapter_progress.updated_at`,
		userID, cp.MangaAnilistID, cp.SourceID, cp.SourceChapterID,
		cp.ChapterNumber, cp.PageIndex, cp.ScrollOffset, cp.ReadState, cp.UpdatedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// --- Manga read history ---

func (r *SyncRepo) PullMangaReadHistory(ctx context.Context, userID uuid.UUID, since int64) ([]model.MangaReadHistory, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, manga_anilist_id, last_chapter_number, last_source_id,
		        last_source_chapter_id, last_page_index, last_accessed_at
		 FROM sync_manga_read_history
		 WHERE user_id = $1 AND last_accessed_at > $2`,
		userID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.MangaReadHistory
	for rows.Next() {
		var rh model.MangaReadHistory
		if err := rows.Scan(&rh.UserID, &rh.MangaAnilistID, &rh.LastChapterNumber,
			&rh.LastSourceID, &rh.LastSourceChapterID, &rh.LastPageIndex,
			&rh.LastAccessedAt); err != nil {
			return nil, err
		}
		items = append(items, rh)
	}
	return items, rows.Err()
}

func (r *SyncRepo) UpsertMangaReadHistory(ctx context.Context, userID uuid.UUID, rh model.MangaReadHistory) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_manga_read_history
		   (user_id, manga_anilist_id, last_chapter_number, last_source_id,
		    last_source_chapter_id, last_page_index, last_accessed_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (user_id, manga_anilist_id)
		 DO UPDATE SET
		   last_chapter_number    = EXCLUDED.last_chapter_number,
		   last_source_id         = EXCLUDED.last_source_id,
		   last_source_chapter_id = EXCLUDED.last_source_chapter_id,
		   last_page_index        = EXCLUDED.last_page_index,
		   last_accessed_at       = EXCLUDED.last_accessed_at
		 WHERE EXCLUDED.last_accessed_at > sync_manga_read_history.last_accessed_at`,
		userID, rh.MangaAnilistID, rh.LastChapterNumber, rh.LastSourceID,
		rh.LastSourceChapterID, rh.LastPageIndex, rh.LastAccessedAt,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (r *SyncRepo) DeleteMangaReadHistory(ctx context.Context, userID uuid.UUID, mangaAnilistID int, tsMs int64) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM sync_manga_read_history
		 WHERE user_id = $1 AND manga_anilist_id = $2 AND last_accessed_at <= $3`,
		userID, mangaAnilistID, tsMs,
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
	var mle, mcp, mrh sql.NullInt64
	err := r.pool.QueryRow(ctx,
		`SELECT
		   (SELECT MAX(updated_at)      FROM sync_episode_progress       WHERE user_id = $1),
		   (SELECT MAX(last_accessed_at) FROM sync_watch_history          WHERE user_id = $1),
		   (SELECT MAX(updated_at)      FROM sync_playback_preference    WHERE user_id = $1),
		   (SELECT MAX(updated_at)      FROM sync_library_entry          WHERE user_id = $1),
		   (SELECT MAX(updated_at)      FROM sync_manga_library_entry    WHERE user_id = $1),
		   (SELECT MAX(updated_at)      FROM sync_manga_chapter_progress WHERE user_id = $1),
		   (SELECT MAX(last_accessed_at) FROM sync_manga_read_history     WHERE user_id = $1)`,
		userID,
	).Scan(&ep, &wh, &pp, &le, &mle, &mcp, &mrh)
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
	if mle.Valid {
		d.MangaLibraryEntry = mle.Int64
	}
	if mcp.Valid {
		d.MangaChapterProgress = mcp.Int64
	}
	if mrh.Valid {
		d.MangaReadHistory = mrh.Int64
	}
	return d, nil
}
