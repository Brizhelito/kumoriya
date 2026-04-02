package model

import "testing"

func TestSyncPushRequestValidate_OK(t *testing.T) {
	dur := 1200
	audio := "sub"
	lastEp := 5
	req := &SyncPushRequest{
		EpisodeProgress: []EpisodeProgress{{
			AnilistID:       1,
			EpisodeNumber:   1,
			PositionSeconds: 30,
			TotalDuration:   &dur,
			WatchState:      "watching",
			UpdatedAt:       1712000000000,
		}},
		WatchHistory: []WatchHistory{{
			AnilistID:         1,
			LastEpisodeNumber: 1,
			LastPositionSecs:  30,
			LastTotalDuration: &dur,
			LastAccessedAt:    1712000000001,
		}},
		PlaybackPreferences: []PlaybackPreference{{
			AnilistID:          1,
			PreferredAudioPref: &audio,
			UpdatedAt:          1712000000002,
		}},
		LibraryEntries: []LibraryEntry{{
			AnilistID:               1,
			AddedAt:                 1712000000003,
			LastNotifiedEpisode:     &lastEp,
			AutoDownloadAudioPref:   "none",
			AutoDownloadNewEpisodes: true,
		}},
	}

	if err := req.Validate(); err != nil {
		t.Fatalf("expected request to be valid, got error: %v", err)
	}
}

func TestSyncPushRequestValidate_RejectsInvalidWatchState(t *testing.T) {
	req := &SyncPushRequest{
		EpisodeProgress: []EpisodeProgress{{
			AnilistID:       1,
			EpisodeNumber:   1,
			PositionSeconds: 1,
			WatchState:      "paused",
			UpdatedAt:       1,
		}},
	}

	if err := req.Validate(); err == nil {
		t.Fatal("expected validation error for invalid watch_state")
	}
}

func TestSyncPushRequestValidate_RejectsEmptyPayload(t *testing.T) {
	req := &SyncPushRequest{}
	if err := req.Validate(); err == nil {
		t.Fatal("expected validation error for empty payload")
	}
}

func TestSyncPushRequestValidate_RejectsNegativeValues(t *testing.T) {
	req := &SyncPushRequest{
		WatchHistory: []WatchHistory{{
			AnilistID:         1,
			LastEpisodeNumber: 1,
			LastPositionSecs:  -5,
			LastAccessedAt:    1,
		}},
	}

	if err := req.Validate(); err == nil {
		t.Fatal("expected validation error for negative position")
	}
}
