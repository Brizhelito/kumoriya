package model

import (
	"fmt"

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
	UserID               uuid.UUID `json:"user_id"`
	AnilistID            int       `json:"anilist_id"`
	PreferredSourceID    *string   `json:"preferred_source_plugin_id,omitempty"`
	PreferredServerName  *string   `json:"preferred_server_name,omitempty"`
	PreferredResolverID  *string   `json:"preferred_resolver_plugin_id,omitempty"`
	PreferredAudioPref   *string   `json:"preferred_audio_preference,omitempty"`
	UpdatedAt            int64     `json:"updated_at"`
}

type LibraryEntry struct {
	UserID                   uuid.UUID `json:"user_id"`
	AnilistID                int       `json:"anilist_id"`
	AddedAt                  int64     `json:"added_at"`
	NotifyNewEpisodes        bool      `json:"notify_new_episodes"`
	LastNotifiedEpisode      *int      `json:"last_notified_episode,omitempty"`
	AutoDownloadNewEpisodes  bool      `json:"auto_download_new_episodes"`
	AutoDownloadAudioPref    string    `json:"auto_download_audio_preference"`
}

// SyncPullResponse is the response for GET /api/v1/sync/pull
type SyncPullResponse struct {
	ServerTime          int64                `json:"server_time"`
	EpisodeProgress     []EpisodeProgress    `json:"episode_progress"`
	WatchHistory        []WatchHistory       `json:"watch_history"`
	PlaybackPreferences []PlaybackPreference `json:"playback_preferences"`
	LibraryEntries      []LibraryEntry       `json:"library_entries"`
}

// SyncPushRequest is the body for POST /api/v1/sync/push
type SyncPushRequest struct {
	EpisodeProgress     []EpisodeProgress    `json:"episode_progress"`
	WatchHistory        []WatchHistory       `json:"watch_history"`
	PlaybackPreferences []PlaybackPreference `json:"playback_preferences"`
	LibraryEntries      []LibraryEntry       `json:"library_entries"`
}

type SyncPushResponse struct {
	Applied   int      `json:"applied"`
	Conflicts []string `json:"conflicts,omitempty"`
}

const (
	maxSyncBatchPerEntity = 1000
	maxSyncBatchTotal     = 5000
)

// Validate performs defensive payload validation for sync push requests.
// It rejects malformed records early to avoid persisting invalid state.
func (r *SyncPushRequest) Validate() error {
	total := len(r.EpisodeProgress) + len(r.WatchHistory) + len(r.PlaybackPreferences) + len(r.LibraryEntries)
	if total == 0 {
		return fmt.Errorf("sync payload is empty")
	}
	if total > maxSyncBatchTotal {
		return fmt.Errorf("sync payload too large")
	}
	if len(r.EpisodeProgress) > maxSyncBatchPerEntity ||
		len(r.WatchHistory) > maxSyncBatchPerEntity ||
		len(r.PlaybackPreferences) > maxSyncBatchPerEntity ||
		len(r.LibraryEntries) > maxSyncBatchPerEntity {
		return fmt.Errorf("sync payload exceeds per-entity limit")
	}

	for _, ep := range r.EpisodeProgress {
		if ep.AnilistID <= 0 || ep.EpisodeNumber <= 0 || ep.UpdatedAt <= 0 {
			return fmt.Errorf("invalid episode_progress identity or timestamp")
		}
		if ep.PositionSeconds < 0 {
			return fmt.Errorf("invalid episode_progress position_seconds")
		}
		if ep.TotalDuration != nil && *ep.TotalDuration <= 0 {
			return fmt.Errorf("invalid episode_progress total_duration_seconds")
		}
		switch ep.WatchState {
		case "unwatched", "watching", "completed":
		default:
			return fmt.Errorf("invalid episode_progress watch_state")
		}
	}

	for _, wh := range r.WatchHistory {
		if wh.AnilistID <= 0 || wh.LastEpisodeNumber <= 0 || wh.LastAccessedAt <= 0 {
			return fmt.Errorf("invalid watch_history identity or timestamp")
		}
		if wh.LastPositionSecs < 0 {
			return fmt.Errorf("invalid watch_history last_position_seconds")
		}
		if wh.LastTotalDuration != nil && *wh.LastTotalDuration <= 0 {
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
		if le.AnilistID <= 0 || le.AddedAt <= 0 {
			return fmt.Errorf("invalid library_entries identity or timestamp")
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

	return nil
}
