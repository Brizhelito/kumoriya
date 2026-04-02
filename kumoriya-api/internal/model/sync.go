package model

import "github.com/google/uuid"

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
