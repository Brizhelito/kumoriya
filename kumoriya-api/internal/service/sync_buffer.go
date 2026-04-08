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

// bufferedPush holds merged push data for a single user.
type bufferedPush struct {
	Episodes  map[epKey]model.EpisodeProgress
	History   map[int]model.WatchHistory
	Prefs     map[int]model.PlaybackPreference
	Library   map[int]model.LibraryEntry
	Deletions map[int]struct{} // anilist_ids for watch history deletions
}

func newBufferedPush() *bufferedPush {
	return &bufferedPush{
		Episodes:  make(map[epKey]model.EpisodeProgress),
		History:   make(map[int]model.WatchHistory),
		Prefs:     make(map[int]model.PlaybackPreference),
		Library:   make(map[int]model.LibraryEntry),
		Deletions: make(map[int]struct{}),
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
		bp.Library[le.AnilistID] = le // Library merge semantics handled by DB upsert
		absorbed++
	}

	for _, d := range req.WatchHistoryDeletions {
		bp.Deletions[d.AnilistID] = struct{}{}
		delete(bp.History, d.AnilistID) // Also remove from buffered history
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
