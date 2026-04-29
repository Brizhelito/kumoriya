package model

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

type EpisodeProgress struct {
	UserID             uuid.UUID `json:"user_id"`
	AnilistID          int       `json:"anilist_id"`
	EpisodeNumber      float32   `json:"episode_number"`
	PositionSeconds    int       `json:"position_seconds"`
	TotalDuration      *int      `json:"total_duration_seconds,omitempty"`
	WatchState         string    `json:"watch_state"`
	LastSourcePluginID *string   `json:"last_source_plugin_id,omitempty"`
	LastServerName     *string   `json:"last_server_name,omitempty"`
	LastResolverID     *string   `json:"last_resolver_plugin_id,omitempty"`
	UpdatedAt          int64     `json:"updated_at"`
}

type WatchHistory struct {
	UserID             uuid.UUID `json:"user_id"`
	AnilistID          int       `json:"anilist_id"`
	LastEpisodeNumber  float32   `json:"last_episode_number"`
	LastSourcePluginID *string   `json:"last_source_plugin_id,omitempty"`
	LastPositionSecs   int       `json:"last_position_seconds"`
	LastTotalDuration  *int      `json:"last_total_duration_seconds,omitempty"`
	LastAccessedAt     int64     `json:"last_accessed_at"`
}

type PlaybackPreference struct {
	UserID              uuid.UUID `json:"user_id"`
	AnilistID           int       `json:"anilist_id"`
	PreferredSourceID   *string   `json:"preferred_source_plugin_id,omitempty"`
	PreferredServerName *string   `json:"preferred_server_name,omitempty"`
	PreferredResolverID *string   `json:"preferred_resolver_plugin_id,omitempty"`
	PreferredAudioPref  *string   `json:"preferred_audio_preference,omitempty"`
	UpdatedAt           int64     `json:"updated_at"`
}

type LibraryEntry struct {
	UserID                  uuid.UUID `json:"user_id"`
	AnilistID               int       `json:"anilist_id"`
	AddedAt                 int64     `json:"added_at"`
	NotifyNewEpisodes       bool      `json:"notify_new_episodes"`
	LastNotifiedEpisode     *int      `json:"last_notified_episode,omitempty"`
	AutoDownloadNewEpisodes bool      `json:"auto_download_new_episodes"`
	AutoDownloadAudioPref   string    `json:"auto_download_audio_preference"`
	// UpdatedAt is the authoritative LWW cursor for this row. Separating it
	// from AddedAt is what allows "unfavorited" states (AddedAt=0) to win
	// over older "favorited" states (AddedAt>0) without the server having to
	// special-case the transition.
	UpdatedAt int64 `json:"updated_at"`
}

// MangaLibraryEntry mirrors `LibraryEntry` for the manga universe.
// `AddedAt = 0` is the wire signal for "not favorite", same convention
// the anime table uses post-012.
type MangaLibraryEntry struct {
	UserID                  uuid.UUID `json:"user_id"`
	MangaAnilistID          int       `json:"manga_anilist_id"`
	AddedAt                 int64     `json:"added_at"`
	NotifyNewChapters       bool      `json:"notify_new_chapters"`
	AutoDownloadNewChapters bool      `json:"auto_download_new_chapters"`
	PreferredLanguage       *string   `json:"preferred_language,omitempty"`
	PreferredScanlator      *string   `json:"preferred_scanlator,omitempty"`
	LastNotifiedChapter     *float64  `json:"last_notified_chapter,omitempty"`
	UpdatedAt               int64     `json:"updated_at"`
}

// MangaChapterProgress is the per-chapter resume + read-state row.
type MangaChapterProgress struct {
	UserID          uuid.UUID `json:"user_id"`
	MangaAnilistID  int       `json:"manga_anilist_id"`
	SourceID        string    `json:"source_id"`
	SourceChapterID string    `json:"source_chapter_id"`
	ChapterNumber   float64   `json:"chapter_number"`
	PageIndex       int       `json:"page_index"`
	ScrollOffset    *float64  `json:"scroll_offset,omitempty"`
	ReadState       string    `json:"read_state"`
	UpdatedAt       int64     `json:"updated_at"`
}

// MangaReadHistory is the most-recently-read chapter, one row per manga.
type MangaReadHistory struct {
	UserID              uuid.UUID `json:"user_id"`
	MangaAnilistID      int       `json:"manga_anilist_id"`
	LastChapterNumber   float64   `json:"last_chapter_number"`
	LastSourceID        *string   `json:"last_source_id,omitempty"`
	LastSourceChapterID *string   `json:"last_source_chapter_id,omitempty"`
	LastPageIndex       *int      `json:"last_page_index,omitempty"`
	LastAccessedAt      int64     `json:"last_accessed_at"`
}

// MangaLibraryEntryDeletion mirrors `LibraryEntryDeletion` for manga.
type MangaLibraryEntryDeletion struct {
	MangaAnilistID int   `json:"manga_anilist_id"`
	UpdatedAt      int64 `json:"updated_at"`
}

// MangaReadHistoryDeletion mirrors `WatchHistoryDeletion` for manga.
type MangaReadHistoryDeletion struct {
	MangaAnilistID int   `json:"manga_anilist_id"`
	UpdatedAt      int64 `json:"updated_at,omitempty"`
}

// DurableUntil is the per-entity cursor signalling which client-assigned
// timestamps are already persisted to Neon for the current user. Clients use
// it to prune their local sync queue. Any value of 0 means "not yet known",
// so nothing is safe to prune for that entity.
type DurableUntil struct {
	EpisodeProgress    int64 `json:"episode_progress"`
	WatchHistory       int64 `json:"watch_history"`
	PlaybackPreference int64 `json:"playback_preference"`
	LibraryEntry       int64 `json:"library_entry"`

	// Manga universe (Slice 10C-2). Zero on clients that have not yet
	// observed a successful manga push, which keeps the
	// safe-to-prune semantics the anime side already relies on.
	MangaLibraryEntry    int64 `json:"manga_library_entry"`
	MangaChapterProgress int64 `json:"manga_chapter_progress"`
	MangaReadHistory     int64 `json:"manga_read_history"`
}

// SyncPullResponse is the response for GET /api/v1/sync/pull
type SyncPullResponse struct {
	ServerTime          int64                `json:"server_time"`
	EpisodeProgress     []EpisodeProgress    `json:"episode_progress"`
	WatchHistory        []WatchHistory       `json:"watch_history"`
	PlaybackPreferences []PlaybackPreference `json:"playback_preferences"`
	LibraryEntries      []LibraryEntry       `json:"library_entries"`

	// Manga universe (Slice 10C-2).
	MangaLibraryEntries  []MangaLibraryEntry    `json:"manga_library_entries"`
	MangaChapterProgress []MangaChapterProgress `json:"manga_chapter_progress"`
	MangaReadHistory     []MangaReadHistory     `json:"manga_read_history"`

	DurableUntil DurableUntil `json:"durable_until"`
}

// SyncPushRequest is the body for POST /api/v1/sync/push
type SyncPushRequest struct {
	EpisodeProgress       []EpisodeProgress      `json:"episode_progress"`
	WatchHistory          []WatchHistory         `json:"watch_history"`
	PlaybackPreferences   []PlaybackPreference   `json:"playback_preferences"`
	LibraryEntries        []LibraryEntry         `json:"library_entries"`
	WatchHistoryDeletions []WatchHistoryDeletion `json:"watch_history_deletions"`
	LibraryEntryDeletions []LibraryEntryDeletion `json:"library_entry_deletions"`

	// Manga universe (Slice 10C-2). Older clients will not send these
	// keys; Go's json decoder leaves the slices nil, which the
	// validate/normalize pipeline treats as zero-length and lets
	// existing tests pass unchanged.
	MangaLibraryEntries        []MangaLibraryEntry         `json:"manga_library_entries"`
	MangaChapterProgress       []MangaChapterProgress      `json:"manga_chapter_progress"`
	MangaReadHistory           []MangaReadHistory          `json:"manga_read_history"`
	MangaLibraryEntryDeletions []MangaLibraryEntryDeletion `json:"manga_library_entry_deletions"`
	MangaReadHistoryDeletions  []MangaReadHistoryDeletion  `json:"manga_read_history_deletions"`
}

// WatchHistoryDeletion requests deletion of a watch history entry.
// UpdatedAt is the client's timestamp at the moment the user deleted the
// entry; the repository uses LWW so a stale deletion cannot erase fresher
// writes. Zero or missing is treated as "now" for backwards compatibility.
type WatchHistoryDeletion struct {
	AnilistID int   `json:"anilist_id"`
	UpdatedAt int64 `json:"updated_at,omitempty"`
}

// LibraryEntryDeletion requests full removal of a library row.
type LibraryEntryDeletion struct {
	AnilistID int   `json:"anilist_id"`
	UpdatedAt int64 `json:"updated_at"`
}

type SyncPushResponse struct {
	Applied      int          `json:"applied"`
	Conflicts    []string     `json:"conflicts,omitempty"`
	DurableUntil DurableUntil `json:"durable_until"`
}

const (
	maxSyncBatchPerEntity = 1000
	maxSyncBatchTotal     = 5000
	// Maximum tolerated client-clock skew. Timestamps further in the future
	// than this are clamped to `now` in Normalize().
	maxClockSkewMs = 5 * 60 * 1000 // 5 minutes
)

// Normalize clamps any client-provided timestamp that is implausibly far in
// the future to `nowMs`, protecting LWW cursors from clients with broken
// clocks that would otherwise poison state permanently.
func (r *SyncPushRequest) Normalize(nowMs int64) {
	limit := nowMs + maxClockSkewMs
	clamp := func(ts int64) int64 {
		if ts > limit {
			return nowMs
		}
		return ts
	}
	for i := range r.EpisodeProgress {
		r.EpisodeProgress[i].UpdatedAt = clamp(r.EpisodeProgress[i].UpdatedAt)
	}
	for i := range r.WatchHistory {
		r.WatchHistory[i].LastAccessedAt = clamp(r.WatchHistory[i].LastAccessedAt)
	}
	for i := range r.PlaybackPreferences {
		r.PlaybackPreferences[i].UpdatedAt = clamp(r.PlaybackPreferences[i].UpdatedAt)
	}
	for i := range r.LibraryEntries {
		// Backwards-compat: old clients only set AddedAt. Derive UpdatedAt
		// from it so LWW still works; absent both, default to now.
		if r.LibraryEntries[i].UpdatedAt == 0 {
			if r.LibraryEntries[i].AddedAt > 0 {
				r.LibraryEntries[i].UpdatedAt = r.LibraryEntries[i].AddedAt
			} else {
				r.LibraryEntries[i].UpdatedAt = nowMs
			}
		}
		r.LibraryEntries[i].UpdatedAt = clamp(r.LibraryEntries[i].UpdatedAt)
		// AddedAt=0 means "not favorite"; keep it. Otherwise clamp.
		if r.LibraryEntries[i].AddedAt > 0 {
			r.LibraryEntries[i].AddedAt = clamp(r.LibraryEntries[i].AddedAt)
		}
	}
	for i := range r.WatchHistoryDeletions {
		if r.WatchHistoryDeletions[i].UpdatedAt == 0 {
			r.WatchHistoryDeletions[i].UpdatedAt = nowMs
		} else {
			r.WatchHistoryDeletions[i].UpdatedAt = clamp(r.WatchHistoryDeletions[i].UpdatedAt)
		}
	}
	for i := range r.LibraryEntryDeletions {
		if r.LibraryEntryDeletions[i].UpdatedAt == 0 {
			r.LibraryEntryDeletions[i].UpdatedAt = nowMs
		} else {
			r.LibraryEntryDeletions[i].UpdatedAt = clamp(r.LibraryEntryDeletions[i].UpdatedAt)
		}
	}

	// Manga (Slice 10C-2).
	for i := range r.MangaLibraryEntries {
		if r.MangaLibraryEntries[i].UpdatedAt == 0 {
			if r.MangaLibraryEntries[i].AddedAt > 0 {
				r.MangaLibraryEntries[i].UpdatedAt = r.MangaLibraryEntries[i].AddedAt
			} else {
				r.MangaLibraryEntries[i].UpdatedAt = nowMs
			}
		}
		r.MangaLibraryEntries[i].UpdatedAt = clamp(r.MangaLibraryEntries[i].UpdatedAt)
		if r.MangaLibraryEntries[i].AddedAt > 0 {
			r.MangaLibraryEntries[i].AddedAt = clamp(r.MangaLibraryEntries[i].AddedAt)
		}
	}
	for i := range r.MangaChapterProgress {
		r.MangaChapterProgress[i].UpdatedAt = clamp(r.MangaChapterProgress[i].UpdatedAt)
	}
	for i := range r.MangaReadHistory {
		r.MangaReadHistory[i].LastAccessedAt = clamp(r.MangaReadHistory[i].LastAccessedAt)
	}
	for i := range r.MangaLibraryEntryDeletions {
		if r.MangaLibraryEntryDeletions[i].UpdatedAt == 0 {
			r.MangaLibraryEntryDeletions[i].UpdatedAt = nowMs
		} else {
			r.MangaLibraryEntryDeletions[i].UpdatedAt = clamp(r.MangaLibraryEntryDeletions[i].UpdatedAt)
		}
	}
	for i := range r.MangaReadHistoryDeletions {
		if r.MangaReadHistoryDeletions[i].UpdatedAt == 0 {
			r.MangaReadHistoryDeletions[i].UpdatedAt = nowMs
		} else {
			r.MangaReadHistoryDeletions[i].UpdatedAt = clamp(r.MangaReadHistoryDeletions[i].UpdatedAt)
		}
	}
}

// NowMillis returns the current wall-clock time in Unix milliseconds.
func NowMillis() int64 { return time.Now().UnixMilli() }

// Validate performs defensive payload validation for sync push requests.
// It rejects malformed records early to avoid persisting invalid state.
func (r *SyncPushRequest) Validate() error {
	total := len(r.EpisodeProgress) + len(r.WatchHistory) + len(r.PlaybackPreferences) +
		len(r.LibraryEntries) + len(r.WatchHistoryDeletions) + len(r.LibraryEntryDeletions) +
		len(r.MangaLibraryEntries) + len(r.MangaChapterProgress) + len(r.MangaReadHistory) +
		len(r.MangaLibraryEntryDeletions) + len(r.MangaReadHistoryDeletions)
	if total == 0 {
		return fmt.Errorf("sync payload is empty")
	}
	if total > maxSyncBatchTotal {
		return fmt.Errorf("sync payload too large")
	}
	if len(r.EpisodeProgress) > maxSyncBatchPerEntity ||
		len(r.WatchHistory) > maxSyncBatchPerEntity ||
		len(r.PlaybackPreferences) > maxSyncBatchPerEntity ||
		len(r.LibraryEntries) > maxSyncBatchPerEntity ||
		len(r.WatchHistoryDeletions) > maxSyncBatchPerEntity ||
		len(r.LibraryEntryDeletions) > maxSyncBatchPerEntity ||
		len(r.MangaLibraryEntries) > maxSyncBatchPerEntity ||
		len(r.MangaChapterProgress) > maxSyncBatchPerEntity ||
		len(r.MangaReadHistory) > maxSyncBatchPerEntity ||
		len(r.MangaLibraryEntryDeletions) > maxSyncBatchPerEntity ||
		len(r.MangaReadHistoryDeletions) > maxSyncBatchPerEntity {
		return fmt.Errorf("sync payload exceeds per-entity limit")
	}

	for _, ep := range r.EpisodeProgress {
		if ep.AnilistID <= 0 || ep.EpisodeNumber < 0 || ep.UpdatedAt <= 0 {
			return fmt.Errorf("invalid episode_progress identity or timestamp")
		}
		if ep.PositionSeconds < 0 {
			return fmt.Errorf("invalid episode_progress position_seconds")
		}
		if ep.TotalDuration != nil && *ep.TotalDuration < 0 {
			return fmt.Errorf("invalid episode_progress total_duration_seconds")
		}
		switch ep.WatchState {
		case "unwatched", "watching", "completed":
		default:
			return fmt.Errorf("invalid episode_progress watch_state")
		}
	}

	for _, wh := range r.WatchHistory {
		if wh.AnilistID <= 0 || wh.LastEpisodeNumber < 0 || wh.LastAccessedAt <= 0 {
			return fmt.Errorf("invalid watch_history identity or timestamp")
		}
		if wh.LastPositionSecs < 0 {
			return fmt.Errorf("invalid watch_history last_position_seconds")
		}
		if wh.LastTotalDuration != nil && *wh.LastTotalDuration < 0 {
			return fmt.Errorf("invalid watch_history last_total_duration_seconds")
		}
	}

	for _, pp := range r.PlaybackPreferences {
		if pp.AnilistID <= 0 || pp.UpdatedAt <= 0 {
			return fmt.Errorf("invalid playback_preferences identity or timestamp")
		}
		if pp.PreferredAudioPref != nil {
			switch *pp.PreferredAudioPref {
			case "none", "sub", "dub":
			default:
				return fmt.Errorf("invalid playback_preferences preferred_audio_preference")
			}
		}
	}

	for _, le := range r.LibraryEntries {
		if le.AnilistID <= 0 || le.UpdatedAt <= 0 {
			return fmt.Errorf("invalid library_entries identity or updated_at")
		}
		if le.AddedAt < 0 {
			return fmt.Errorf("invalid library_entries added_at")
		}
		if le.LastNotifiedEpisode != nil && *le.LastNotifiedEpisode < 0 {
			return fmt.Errorf("invalid library_entries last_notified_episode")
		}
		switch le.AutoDownloadAudioPref {
		case "", "none", "sub", "dub":
		default:
			return fmt.Errorf("invalid library_entries auto_download_audio_preference")
		}
	}

	for _, d := range r.WatchHistoryDeletions {
		if d.AnilistID <= 0 {
			return fmt.Errorf("invalid watch_history_deletions anilist_id")
		}
	}

	for _, d := range r.LibraryEntryDeletions {
		if d.AnilistID <= 0 {
			return fmt.Errorf("invalid library_entry_deletions anilist_id")
		}
		if d.UpdatedAt <= 0 {
			return fmt.Errorf("invalid library_entry_deletions updated_at")
		}
	}

	// --- Manga (Slice 10C-2) ---

	for _, le := range r.MangaLibraryEntries {
		if le.MangaAnilistID <= 0 || le.UpdatedAt <= 0 {
			return fmt.Errorf("invalid manga_library_entries identity or updated_at")
		}
		if le.AddedAt < 0 {
			return fmt.Errorf("invalid manga_library_entries added_at")
		}
		if le.LastNotifiedChapter != nil && *le.LastNotifiedChapter < 0 {
			return fmt.Errorf("invalid manga_library_entries last_notified_chapter")
		}
	}

	for _, cp := range r.MangaChapterProgress {
		if cp.MangaAnilistID <= 0 || cp.UpdatedAt <= 0 {
			return fmt.Errorf("invalid manga_chapter_progress identity or timestamp")
		}
		if cp.SourceID == "" || cp.SourceChapterID == "" {
			return fmt.Errorf("invalid manga_chapter_progress source identity")
		}
		if cp.ChapterNumber < 0 {
			return fmt.Errorf("invalid manga_chapter_progress chapter_number")
		}
		if cp.PageIndex < 0 {
			return fmt.Errorf("invalid manga_chapter_progress page_index")
		}
		switch cp.ReadState {
		case "unread", "reading", "completed":
		default:
			return fmt.Errorf("invalid manga_chapter_progress read_state")
		}
	}

	for _, rh := range r.MangaReadHistory {
		if rh.MangaAnilistID <= 0 || rh.LastAccessedAt <= 0 {
			return fmt.Errorf("invalid manga_read_history identity or timestamp")
		}
		if rh.LastChapterNumber < 0 {
			return fmt.Errorf("invalid manga_read_history last_chapter_number")
		}
		if rh.LastPageIndex != nil && *rh.LastPageIndex < 0 {
			return fmt.Errorf("invalid manga_read_history last_page_index")
		}
	}

	for _, d := range r.MangaLibraryEntryDeletions {
		if d.MangaAnilistID <= 0 {
			return fmt.Errorf("invalid manga_library_entry_deletions manga_anilist_id")
		}
		if d.UpdatedAt <= 0 {
			return fmt.Errorf("invalid manga_library_entry_deletions updated_at")
		}
	}

	for _, d := range r.MangaReadHistoryDeletions {
		if d.MangaAnilistID <= 0 {
			return fmt.Errorf("invalid manga_read_history_deletions manga_anilist_id")
		}
	}

	return nil
}
