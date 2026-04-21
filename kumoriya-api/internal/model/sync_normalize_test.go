package model

import "testing"

func TestNormalize_ClampsFutureTimestamps(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	// Ten minutes in the future — beyond the 5-minute tolerance.
	farFuture := nowMs + 10*60*1000

	req := &SyncPushRequest{
		EpisodeProgress: []EpisodeProgress{{
			AnilistID:     1,
			EpisodeNumber: 1,
			UpdatedAt:     farFuture,
			WatchState:    "watching",
		}},
		WatchHistory: []WatchHistory{{
			AnilistID:         1,
			LastEpisodeNumber: 1,
			LastAccessedAt:    farFuture,
		}},
		PlaybackPreferences: []PlaybackPreference{{
			AnilistID: 1,
			UpdatedAt: farFuture,
		}},
		LibraryEntries: []LibraryEntry{{
			AnilistID: 1,
			AddedAt:   farFuture,
			UpdatedAt: farFuture,
		}},
		WatchHistoryDeletions: []WatchHistoryDeletion{{
			AnilistID: 1,
			UpdatedAt: farFuture,
		}},
		LibraryEntryDeletions: []LibraryEntryDeletion{{
			AnilistID: 1,
			UpdatedAt: farFuture,
		}},
	}
	req.Normalize(nowMs)

	if req.EpisodeProgress[0].UpdatedAt != nowMs {
		t.Fatalf("episode_progress updated_at not clamped: got %d", req.EpisodeProgress[0].UpdatedAt)
	}
	if req.WatchHistory[0].LastAccessedAt != nowMs {
		t.Fatalf("watch_history last_accessed_at not clamped")
	}
	if req.PlaybackPreferences[0].UpdatedAt != nowMs {
		t.Fatalf("playback_preferences updated_at not clamped")
	}
	if req.LibraryEntries[0].AddedAt != nowMs || req.LibraryEntries[0].UpdatedAt != nowMs {
		t.Fatalf("library_entries timestamps not clamped")
	}
	if req.WatchHistoryDeletions[0].UpdatedAt != nowMs {
		t.Fatalf("watch_history deletion updated_at not clamped")
	}
	if req.LibraryEntryDeletions[0].UpdatedAt != nowMs {
		t.Fatalf("library_entry deletion updated_at not clamped")
	}
}

func TestNormalize_FillsMissingDeletionTimestamp(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	req := &SyncPushRequest{
		WatchHistoryDeletions: []WatchHistoryDeletion{{AnilistID: 1}},
	}
	req.Normalize(nowMs)
	if req.WatchHistoryDeletions[0].UpdatedAt != nowMs {
		t.Fatalf("expected missing deletion timestamp to be filled with now")
	}
}

// Old clients send library_entry with added_at but no updated_at. Normalize
// must backfill so the payload passes Validate() and LWW still works.
func TestNormalize_BackwardsCompat_LibraryEntryWithoutUpdatedAt(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	added := nowMs - 1_000
	req := &SyncPushRequest{
		LibraryEntries: []LibraryEntry{{
			AnilistID: 1,
			AddedAt:   added,
			// UpdatedAt intentionally unset — simulates an old client.
		}},
	}
	req.Normalize(nowMs)
	if req.LibraryEntries[0].UpdatedAt != added {
		t.Fatalf("expected UpdatedAt to be backfilled from AddedAt, got %d", req.LibraryEntries[0].UpdatedAt)
	}
	if err := req.Validate(); err != nil {
		t.Fatalf("old-client payload must survive validation after normalize: %v", err)
	}
}

func TestNormalize_BackwardsCompat_EmptyLibraryTimestamps(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	req := &SyncPushRequest{
		LibraryEntries: []LibraryEntry{{AnilistID: 1}}, // both 0
	}
	req.Normalize(nowMs)
	if req.LibraryEntries[0].UpdatedAt != nowMs {
		t.Fatalf("expected empty timestamps to be filled with nowMs")
	}
	if req.LibraryEntries[0].AddedAt != 0 {
		t.Fatalf("AddedAt=0 (not favorite) must stay 0")
	}
}

func TestNormalize_PreservesReasonableTimestamps(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	ts := nowMs - 60_000 // one minute in the past
	req := &SyncPushRequest{
		EpisodeProgress: []EpisodeProgress{{
			AnilistID: 1, EpisodeNumber: 1, UpdatedAt: ts, WatchState: "watching",
		}},
	}
	req.Normalize(nowMs)
	if req.EpisodeProgress[0].UpdatedAt != ts {
		t.Fatalf("past timestamp was unexpectedly rewritten")
	}
}
