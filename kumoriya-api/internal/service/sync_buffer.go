package service

import (
	"sync"

	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
)

// epKey uniquely identifies an episode progress entry.
type epKey struct {
	AnilistID     int
	EpisodeNumber float32
}

// mcpKey uniquely identifies a manga-chapter progress entry. The
// per-source key matches the `sync_manga_chapter_progress` PRIMARY KEY
// so the buffer collapses LWW per (user, manga, source, chapter) the
// same way the database does.
type mcpKey struct {
	MangaAnilistID  int
	SourceID        string
	SourceChapterID string
}

// whDeletion carries an LWW-tagged deletion for a watch-history row.
type whDeletion struct {
	AnilistID int
	UpdatedAt int64
}

// libDeletion carries an LWW-tagged deletion for a library row.
type libDeletion struct {
	AnilistID int
	UpdatedAt int64
}

// mangaLibDeletion carries an LWW-tagged deletion for a manga library row.
type mangaLibDeletion struct {
	MangaAnilistID int
	UpdatedAt      int64
}

// mangaHistDeletion carries an LWW-tagged deletion for a manga history row.
type mangaHistDeletion struct {
	MangaAnilistID int
	UpdatedAt      int64
}

// bufferedPush holds merged push data for a single user.
type bufferedPush struct {
	Episodes   map[epKey]model.EpisodeProgress
	History    map[int]model.WatchHistory
	Prefs      map[int]model.PlaybackPreference
	Library    map[int]model.LibraryEntry
	HistoryDel map[int]whDeletion
	LibraryDel map[int]libDeletion

	// Manga universe (Slice 10C-2). Keyed by manga AniList id (or by
	// composite key for chapter progress) so LWW collapse mirrors the
	// database PRIMARY KEY shape.
	MangaLibrary    map[int]model.MangaLibraryEntry
	MangaProgress   map[mcpKey]model.MangaChapterProgress
	MangaHistory    map[int]model.MangaReadHistory
	MangaLibraryDel map[int]mangaLibDeletion
	MangaHistoryDel map[int]mangaHistDeletion
}

func newBufferedPush() *bufferedPush {
	return &bufferedPush{
		Episodes:        make(map[epKey]model.EpisodeProgress),
		History:         make(map[int]model.WatchHistory),
		Prefs:           make(map[int]model.PlaybackPreference),
		Library:         make(map[int]model.LibraryEntry),
		HistoryDel:      make(map[int]whDeletion),
		LibraryDel:      make(map[int]libDeletion),
		MangaLibrary:    make(map[int]model.MangaLibraryEntry),
		MangaProgress:   make(map[mcpKey]model.MangaChapterProgress),
		MangaHistory:    make(map[int]model.MangaReadHistory),
		MangaLibraryDel: make(map[int]mangaLibDeletion),
		MangaHistoryDel: make(map[int]mangaHistDeletion),
	}
}

// writeBuffer accumulates push data in memory per user. Data stays here
// until flushed to Neon by the background goroutine.
type writeBuffer struct {
	mu    sync.Mutex
	dirty map[uuid.UUID]*bufferedPush
}

func newWriteBuffer() *writeBuffer {
	return &writeBuffer{dirty: make(map[uuid.UUID]*bufferedPush)}
}

// absorb merges a push request into the buffer using LWW semantics.
// Returns the number of entries absorbed.
//
// Critical invariant: upserts and deletions for the same (entity, anilistID)
// cannot coexist with older timestamps. When an upsert wins over an existing
// deletion (or vice versa) the loser is dropped — otherwise the Flush phase
// would apply both and data could be silently destroyed.
func (b *writeBuffer) absorb(userID uuid.UUID, req *model.SyncPushRequest) int {
	b.mu.Lock()
	defer b.mu.Unlock()

	bp, ok := b.dirty[userID]
	if !ok {
		bp = newBufferedPush()
		b.dirty[userID] = bp
	}

	absorbed := 0

	for _, ep := range req.EpisodeProgress {
		key := epKey{ep.AnilistID, ep.EpisodeNumber}
		if existing, exists := bp.Episodes[key]; !exists || ep.UpdatedAt > existing.UpdatedAt {
			bp.Episodes[key] = ep
			absorbed++
		}
	}

	for _, wh := range req.WatchHistory {
		// A pending deletion older than this upsert is obsolete.
		if d, ok := bp.HistoryDel[wh.AnilistID]; ok && d.UpdatedAt < wh.LastAccessedAt {
			delete(bp.HistoryDel, wh.AnilistID)
		}
		// If a deletion is newer, the upsert must be ignored.
		if d, ok := bp.HistoryDel[wh.AnilistID]; ok && d.UpdatedAt >= wh.LastAccessedAt {
			continue
		}
		if existing, exists := bp.History[wh.AnilistID]; !exists || wh.LastAccessedAt > existing.LastAccessedAt {
			bp.History[wh.AnilistID] = wh
			absorbed++
		}
	}

	for _, pp := range req.PlaybackPreferences {
		if existing, exists := bp.Prefs[pp.AnilistID]; !exists || pp.UpdatedAt > existing.UpdatedAt {
			bp.Prefs[pp.AnilistID] = pp
			absorbed++
		}
	}

	for _, le := range req.LibraryEntries {
		// Symmetric handling vs library deletions.
		if d, ok := bp.LibraryDel[le.AnilistID]; ok && d.UpdatedAt < le.UpdatedAt {
			delete(bp.LibraryDel, le.AnilistID)
		}
		if d, ok := bp.LibraryDel[le.AnilistID]; ok && d.UpdatedAt >= le.UpdatedAt {
			continue
		}
		if existing, exists := bp.Library[le.AnilistID]; !exists || le.UpdatedAt > existing.UpdatedAt {
			bp.Library[le.AnilistID] = le
			absorbed++
		}
	}

	for _, d := range req.WatchHistoryDeletions {
		// LWW: keep the newest deletion timestamp.
		if existing, exists := bp.HistoryDel[d.AnilistID]; exists && d.UpdatedAt <= existing.UpdatedAt {
			continue
		}
		// If a newer upsert already sits in the buffer, the deletion is stale.
		if wh, ok := bp.History[d.AnilistID]; ok && wh.LastAccessedAt > d.UpdatedAt {
			continue
		}
		bp.HistoryDel[d.AnilistID] = whDeletion{AnilistID: d.AnilistID, UpdatedAt: d.UpdatedAt}
		// Drop any buffered upsert that is now superseded.
		if wh, ok := bp.History[d.AnilistID]; ok && wh.LastAccessedAt <= d.UpdatedAt {
			delete(bp.History, d.AnilistID)
		}
		absorbed++
	}

	for _, d := range req.LibraryEntryDeletions {
		if existing, exists := bp.LibraryDel[d.AnilistID]; exists && d.UpdatedAt <= existing.UpdatedAt {
			continue
		}
		if le, ok := bp.Library[d.AnilistID]; ok && le.UpdatedAt > d.UpdatedAt {
			continue
		}
		bp.LibraryDel[d.AnilistID] = libDeletion{AnilistID: d.AnilistID, UpdatedAt: d.UpdatedAt}
		if le, ok := bp.Library[d.AnilistID]; ok && le.UpdatedAt <= d.UpdatedAt {
			delete(bp.Library, d.AnilistID)
		}
		absorbed++
	}

	// --- Manga universe (Slice 10C-2) ---

	for _, le := range req.MangaLibraryEntries {
		if d, ok := bp.MangaLibraryDel[le.MangaAnilistID]; ok && d.UpdatedAt < le.UpdatedAt {
			delete(bp.MangaLibraryDel, le.MangaAnilistID)
		}
		if d, ok := bp.MangaLibraryDel[le.MangaAnilistID]; ok && d.UpdatedAt >= le.UpdatedAt {
			continue
		}
		if existing, exists := bp.MangaLibrary[le.MangaAnilistID]; !exists || le.UpdatedAt > existing.UpdatedAt {
			bp.MangaLibrary[le.MangaAnilistID] = le
			absorbed++
		}
	}

	for _, cp := range req.MangaChapterProgress {
		key := mcpKey{cp.MangaAnilistID, cp.SourceID, cp.SourceChapterID}
		if existing, exists := bp.MangaProgress[key]; !exists || cp.UpdatedAt > existing.UpdatedAt {
			bp.MangaProgress[key] = cp
			absorbed++
		}
	}

	for _, rh := range req.MangaReadHistory {
		if d, ok := bp.MangaHistoryDel[rh.MangaAnilistID]; ok && d.UpdatedAt < rh.LastAccessedAt {
			delete(bp.MangaHistoryDel, rh.MangaAnilistID)
		}
		if d, ok := bp.MangaHistoryDel[rh.MangaAnilistID]; ok && d.UpdatedAt >= rh.LastAccessedAt {
			continue
		}
		if existing, exists := bp.MangaHistory[rh.MangaAnilistID]; !exists || rh.LastAccessedAt > existing.LastAccessedAt {
			bp.MangaHistory[rh.MangaAnilistID] = rh
			absorbed++
		}
	}

	for _, d := range req.MangaLibraryEntryDeletions {
		if existing, exists := bp.MangaLibraryDel[d.MangaAnilistID]; exists && d.UpdatedAt <= existing.UpdatedAt {
			continue
		}
		if le, ok := bp.MangaLibrary[d.MangaAnilistID]; ok && le.UpdatedAt > d.UpdatedAt {
			continue
		}
		bp.MangaLibraryDel[d.MangaAnilistID] = mangaLibDeletion{
			MangaAnilistID: d.MangaAnilistID, UpdatedAt: d.UpdatedAt,
		}
		if le, ok := bp.MangaLibrary[d.MangaAnilistID]; ok && le.UpdatedAt <= d.UpdatedAt {
			delete(bp.MangaLibrary, d.MangaAnilistID)
		}
		absorbed++
	}

	for _, d := range req.MangaReadHistoryDeletions {
		if existing, exists := bp.MangaHistoryDel[d.MangaAnilistID]; exists && d.UpdatedAt <= existing.UpdatedAt {
			continue
		}
		if rh, ok := bp.MangaHistory[d.MangaAnilistID]; ok && rh.LastAccessedAt > d.UpdatedAt {
			continue
		}
		bp.MangaHistoryDel[d.MangaAnilistID] = mangaHistDeletion{
			MangaAnilistID: d.MangaAnilistID, UpdatedAt: d.UpdatedAt,
		}
		if rh, ok := bp.MangaHistory[d.MangaAnilistID]; ok && rh.LastAccessedAt <= d.UpdatedAt {
			delete(bp.MangaHistory, d.MangaAnilistID)
		}
		absorbed++
	}

	return absorbed
}

// peek returns the buffered push for a user without draining. May be nil.
func (b *writeBuffer) peek(userID uuid.UUID) *bufferedPush {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.dirty[userID]
}

// drainAll atomically takes all dirty entries and clears the buffer.
func (b *writeBuffer) drainAll() map[uuid.UUID]*bufferedPush {
	b.mu.Lock()
	defer b.mu.Unlock()

	if len(b.dirty) == 0 {
		return nil
	}

	taken := b.dirty
	b.dirty = make(map[uuid.UUID]*bufferedPush)
	return taken
}
