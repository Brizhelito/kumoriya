package model

import "testing"

func TestNormalize_ClampsMangaFutureTimestamps(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	farFuture := nowMs + 10*60*1000

	req := &SyncPushRequest{
		MangaLibraryEntries: []MangaLibraryEntry{{
			MangaAnilistID: 1,
			AddedAt:        farFuture,
			UpdatedAt:      farFuture,
		}},
		MangaChapterProgress: []MangaChapterProgress{{
			MangaAnilistID:  1,
			SourceID:        "mangadex",
			SourceChapterID: "ch-1",
			ChapterNumber:   1,
			UpdatedAt:       farFuture,
			ReadState:       "reading",
		}},
		MangaReadHistory: []MangaReadHistory{{
			MangaAnilistID:    1,
			LastChapterNumber: 1,
			LastAccessedAt:    farFuture,
		}},
		MangaLibraryEntryDeletions: []MangaLibraryEntryDeletion{{
			MangaAnilistID: 1,
			UpdatedAt:      farFuture,
		}},
		MangaReadHistoryDeletions: []MangaReadHistoryDeletion{{
			MangaAnilistID: 1,
			UpdatedAt:      farFuture,
		}},
	}
	req.Normalize(nowMs)

	if req.MangaLibraryEntries[0].UpdatedAt != nowMs ||
		req.MangaLibraryEntries[0].AddedAt != nowMs {
		t.Fatalf("manga_library_entries timestamps not clamped: %+v", req.MangaLibraryEntries[0])
	}
	if req.MangaChapterProgress[0].UpdatedAt != nowMs {
		t.Fatalf("manga_chapter_progress updated_at not clamped")
	}
	if req.MangaReadHistory[0].LastAccessedAt != nowMs {
		t.Fatalf("manga_read_history last_accessed_at not clamped")
	}
	if req.MangaLibraryEntryDeletions[0].UpdatedAt != nowMs {
		t.Fatalf("manga library deletion not clamped")
	}
	if req.MangaReadHistoryDeletions[0].UpdatedAt != nowMs {
		t.Fatalf("manga history deletion not clamped")
	}
}

func TestNormalize_DerivesMangaUpdatedAtFromAddedAt(t *testing.T) {
	const nowMs = int64(1_712_000_000_000)
	const addedAt = int64(1_700_000_000_000)

	req := &SyncPushRequest{
		MangaLibraryEntries: []MangaLibraryEntry{{
			MangaAnilistID: 1,
			AddedAt:        addedAt,
			// UpdatedAt absent — must be derived from AddedAt for
			// backwards-compat with older clients.
		}},
	}
	req.Normalize(nowMs)

	if got := req.MangaLibraryEntries[0].UpdatedAt; got != addedAt {
		t.Fatalf("expected updated_at to fall back to added_at (%d), got %d", addedAt, got)
	}
}

func TestValidate_RejectsInvalidMangaPayloads(t *testing.T) {
	cases := []struct {
		name string
		req  SyncPushRequest
	}{
		{
			name: "manga library entry without anilist id",
			req: SyncPushRequest{
				MangaLibraryEntries: []MangaLibraryEntry{{
					MangaAnilistID: 0,
					UpdatedAt:      1,
				}},
			},
		},
		{
			name: "manga chapter progress without source identity",
			req: SyncPushRequest{
				MangaChapterProgress: []MangaChapterProgress{{
					MangaAnilistID: 1,
					ChapterNumber:  1,
					ReadState:      "reading",
					UpdatedAt:      1,
				}},
			},
		},
		{
			name: "manga chapter progress with bogus read state",
			req: SyncPushRequest{
				MangaChapterProgress: []MangaChapterProgress{{
					MangaAnilistID:  1,
					SourceID:        "mangadex",
					SourceChapterID: "ch-1",
					ChapterNumber:   1,
					UpdatedAt:       1,
					ReadState:       "halfway",
				}},
			},
		},
		{
			name: "manga history without timestamp",
			req: SyncPushRequest{
				MangaReadHistory: []MangaReadHistory{{
					MangaAnilistID:    1,
					LastChapterNumber: 1,
					// LastAccessedAt = 0
				}},
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if err := tc.req.Validate(); err == nil {
				t.Fatalf("expected validation error, got nil")
			}
		})
	}
}

func TestValidate_AcceptsCleanMangaPayload(t *testing.T) {
	req := SyncPushRequest{
		MangaLibraryEntries: []MangaLibraryEntry{{
			MangaAnilistID: 1, AddedAt: 100, UpdatedAt: 100,
		}},
		MangaChapterProgress: []MangaChapterProgress{{
			MangaAnilistID: 1, SourceID: "mangadex", SourceChapterID: "ch-1",
			ChapterNumber: 1, ReadState: "reading", UpdatedAt: 100,
		}},
	}
	if err := req.Validate(); err != nil {
		t.Fatalf("unexpected validation error: %v", err)
	}
}
