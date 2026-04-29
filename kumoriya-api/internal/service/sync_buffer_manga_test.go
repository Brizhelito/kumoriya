package service

import (
	"testing"

	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
)

// Mirror of TestBufferAbsorb_LibraryUpsertWinsOverOlderDeletion for manga.
func TestBufferAbsorb_MangaLibraryUpsertWinsOverOlderDeletion(t *testing.T) {
	buf := newWriteBuffer()
	userID := uuid.New()

	buf.absorb(userID, &model.SyncPushRequest{
		MangaLibraryEntryDeletions: []model.MangaLibraryEntryDeletion{
			{MangaAnilistID: 5, UpdatedAt: 100},
		},
	})
	buf.absorb(userID, &model.SyncPushRequest{
		MangaLibraryEntries: []model.MangaLibraryEntry{
			{MangaAnilistID: 5, AddedAt: 200, UpdatedAt: 200},
		},
	})

	bp := buf.peek(userID)
	if bp == nil {
		t.Fatal("buffer empty after absorb")
	}
	if _, ok := bp.MangaLibraryDel[5]; ok {
		t.Fatalf("stale manga library deletion must be evicted")
	}
	if _, ok := bp.MangaLibrary[5]; !ok {
		t.Fatalf("fresh manga library upsert must be retained")
	}
}

func TestBufferAbsorb_MangaHistoryDeletionWinsOverOlderUpsert(t *testing.T) {
	buf := newWriteBuffer()
	userID := uuid.New()

	buf.absorb(userID, &model.SyncPushRequest{
		MangaReadHistory: []model.MangaReadHistory{{
			MangaAnilistID: 7, LastChapterNumber: 1, LastAccessedAt: 100,
		}},
	})
	buf.absorb(userID, &model.SyncPushRequest{
		MangaReadHistoryDeletions: []model.MangaReadHistoryDeletion{{
			MangaAnilistID: 7, UpdatedAt: 200,
		}},
	})

	bp := buf.peek(userID)
	if _, ok := bp.MangaHistory[7]; ok {
		t.Fatalf("older manga history upsert should be dropped")
	}
	d, ok := bp.MangaHistoryDel[7]
	if !ok || d.UpdatedAt != 200 {
		t.Fatalf("manga history deletion not retained with correct timestamp")
	}
}

// Per-source key collapsing: two writes for the same chapter from the
// same source merge to the freshest, while writes for the same chapter
// number across different sources stay distinct.
func TestBufferAbsorb_MangaProgressLwwAndPerSourceKey(t *testing.T) {
	buf := newWriteBuffer()
	userID := uuid.New()

	buf.absorb(userID, &model.SyncPushRequest{
		MangaChapterProgress: []model.MangaChapterProgress{
			{
				MangaAnilistID: 1, SourceID: "mangadex", SourceChapterID: "ch-1",
				ChapterNumber: 1, ReadState: "reading", PageIndex: 5, UpdatedAt: 100,
			},
			{
				MangaAnilistID: 1, SourceID: "bato", SourceChapterID: "ch-1",
				ChapterNumber: 1, ReadState: "reading", PageIndex: 10, UpdatedAt: 100,
			},
		},
	})
	// LWW for the mangadex/ch-1 entry — fresher write wins.
	buf.absorb(userID, &model.SyncPushRequest{
		MangaChapterProgress: []model.MangaChapterProgress{{
			MangaAnilistID: 1, SourceID: "mangadex", SourceChapterID: "ch-1",
			ChapterNumber: 1, ReadState: "completed", PageIndex: 20, UpdatedAt: 200,
		}},
	})

	bp := buf.peek(userID)
	if got := len(bp.MangaProgress); got != 2 {
		t.Fatalf("expected 2 distinct (source) entries, got %d", got)
	}
	mdex := bp.MangaProgress[mcpKey{1, "mangadex", "ch-1"}]
	if mdex.UpdatedAt != 200 || mdex.PageIndex != 20 || mdex.ReadState != "completed" {
		t.Fatalf("mangadex entry not LWW-replaced: %+v", mdex)
	}
	bato := bp.MangaProgress[mcpKey{1, "bato", "ch-1"}]
	if bato.UpdatedAt != 100 || bato.PageIndex != 10 {
		t.Fatalf("bato entry should be untouched: %+v", bato)
	}
}
