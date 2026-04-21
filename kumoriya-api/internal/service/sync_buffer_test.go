package service

import (
	"testing"

	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
)

// Fresh upsert after a stale deletion must NOT be destroyed by the pending
// deletion — this was the data-loss bug described in the audit.
func TestBufferAbsorb_UpsertWinsOverOlderDeletion(t *testing.T) {
	buf := newWriteBuffer()
	userID := uuid.New()

	// Stale deletion at t=100.
	buf.absorb(userID, &model.SyncPushRequest{
		WatchHistoryDeletions: []model.WatchHistoryDeletion{{AnilistID: 42, UpdatedAt: 100}},
	})
	// Fresh upsert at t=200.
	buf.absorb(userID, &model.SyncPushRequest{
		WatchHistory: []model.WatchHistory{{AnilistID: 42, LastEpisodeNumber: 1, LastAccessedAt: 200}},
	})

	bp := buf.peek(userID)
	if bp == nil {
		t.Fatal("buffer empty after absorb")
	}
	if _, ok := bp.HistoryDel[42]; ok {
		t.Fatalf("stale deletion must be evicted when a newer upsert arrives")
	}
	if _, ok := bp.History[42]; !ok {
		t.Fatalf("fresh upsert must be retained")
	}
}

func TestBufferAbsorb_DeletionWinsOverOlderUpsert(t *testing.T) {
	buf := newWriteBuffer()
	userID := uuid.New()

	buf.absorb(userID, &model.SyncPushRequest{
		WatchHistory: []model.WatchHistory{{AnilistID: 7, LastEpisodeNumber: 1, LastAccessedAt: 100}},
	})
	buf.absorb(userID, &model.SyncPushRequest{
		WatchHistoryDeletions: []model.WatchHistoryDeletion{{AnilistID: 7, UpdatedAt: 200}},
	})

	bp := buf.peek(userID)
	if _, ok := bp.History[7]; ok {
		t.Fatalf("older upsert should be dropped when a newer deletion arrives")
	}
	d, ok := bp.HistoryDel[7]
	if !ok || d.UpdatedAt != 200 {
		t.Fatalf("deletion not retained with correct timestamp")
	}
}

func TestBufferAbsorb_LibraryUpsertWinsOverOlderDeletion(t *testing.T) {
	buf := newWriteBuffer()
	userID := uuid.New()

	buf.absorb(userID, &model.SyncPushRequest{
		LibraryEntryDeletions: []model.LibraryEntryDeletion{{AnilistID: 5, UpdatedAt: 100}},
	})
	buf.absorb(userID, &model.SyncPushRequest{
		LibraryEntries: []model.LibraryEntry{{AnilistID: 5, AddedAt: 200, UpdatedAt: 200}},
	})

	bp := buf.peek(userID)
	if _, ok := bp.LibraryDel[5]; ok {
		t.Fatalf("stale library deletion must be evicted")
	}
	if _, ok := bp.Library[5]; !ok {
		t.Fatalf("fresh library upsert must be retained")
	}
}
