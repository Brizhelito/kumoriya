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

// DurableUntil is the per-entity cursor signalling which client-assigned
// timestamps are already persisted to Neon for the current user. Clients use
// it to prune their local sync queue. Any value of 0 means "not yet known",
// so nothing is safe to prune for that entity.
type DurableUntil struct {
	EpisodeProgress    int64 `json:"episode_progress"`
	WatchHistory       int64 `json:"watch_history"`
	PlaybackPreference int64 `json:"playback_preference"`
	LibraryEntry       int64 `json:"library_entry"`
}

// SyncPullResponse is the response for GET /api/v1/sync/pull
type SyncPullResponse struct {
	ServerTime          int64                `json:"server_time"`
	EpisodeProgress     []EpisodeProgress    `json:"episode_progress"`
	WatchHistory        []WatchHistory       `json:"watch_history"`
	PlaybackPreferences []PlaybackPreference `json:"playback_preferences"`
	LibraryEntries      []LibraryEntry       `json:"library_entries"`
	DurableUntil        DurableUntil         `json:"durable_until"`
}

// SyncPushRequest is the body for POST /api/v1/sync/push
type SyncPushRequest struct {
	EpisodeProgress       []EpisodeProgress      `json:"episode_progress"`
	WatchHistory          []WatchHistory         `json:"watch_history"`
	PlaybackPreferences   []PlaybackPreference   `json:"playback_preferences"`
	LibraryEntries        []LibraryEntry         `json:"library_entries"`
	WatchHistoryDeletions []WatchHistoryDeletion `json:"watch_history_deletions"`
	LibraryEntryDeletions []LibraryEntryDeletion `json:"library_entry_deletions"`
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
}

// NowMillis returns the current wall-clock time in Unix milliseconds.
func NowMillis() int64 { return time.Now().UnixMilli() }

// Validate performs defensive payload validation for sync push requests.
// It rejects malformed records early to avoid persisting invalid state.
func (r *SyncPushRequest) Validate() error {
	total := len(r.EpisodeProgress) + len(r.WatchHistory) + len(r.PlaybackPreferences) +
		len(r.LibraryEntries) + len(r.WatchHistoryDeletions) + len(r.LibraryEntryDeletions)
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
		len(r.LibraryEntryDeletions) > maxSyncBatchPerEntity {
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

	return nil
}
