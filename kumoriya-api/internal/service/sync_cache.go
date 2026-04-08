package service

import (
	"sync"
	"time"

	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
)

const (
	// cacheTTL is how long a snapshot stays valid before being re-fetched.
	// Kept intentionally long to minimise Neon compute wake-ups.
	cacheTTL = 2 * time.Hour
	// cacheMaxEntries caps the number of user snapshots kept in memory.
	// When exceeded, the oldest entry is evicted.
	cacheMaxEntries = 500
)

// pullSnapshot holds a full-dataset pull response cached in memory.
type pullSnapshot struct {
	resp      *model.SyncPullResponse
	fetchedAt time.Time
}

// pullCache keeps one full snapshot per user in memory. It is invalidated
// whenever a push (mutation) happens for that user, so subsequent pulls can
// be served without touching Neon.
//
// Multi-user: each user gets their own entry keyed by UUID.
// TTL: entries older than cacheTTL are treated as misses.
// LRU-ish eviction: when cacheMaxEntries is reached, the oldest entry is dropped.
type pullCache struct {
	mu        sync.Mutex
	snapshots map[uuid.UUID]*pullSnapshot
}

func newPullCache() *pullCache {
	return &pullCache{
		snapshots: make(map[uuid.UUID]*pullSnapshot),
	}
}

// get returns the cached full snapshot for userID, or nil if absent / expired.
func (c *pullCache) get(userID uuid.UUID) (*pullSnapshot, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	snap, ok := c.snapshots[userID]
	if !ok {
		return nil, false
	}
	// TTL check.
	if time.Since(snap.fetchedAt) > cacheTTL {
		delete(c.snapshots, userID)
		return nil, false
	}
	return snap, true
}

// set stores a full snapshot for userID, evicting the oldest entry if at capacity.
func (c *pullCache) set(userID uuid.UUID, resp *model.SyncPullResponse) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Evict oldest if at capacity (and not just updating an existing key).
	if _, exists := c.snapshots[userID]; !exists && len(c.snapshots) >= cacheMaxEntries {
		c.evictOldestLocked()
	}

	c.snapshots[userID] = &pullSnapshot{
		resp:      resp,
		fetchedAt: time.Now(),
	}
}

// evictOldestLocked removes the entry with the oldest fetchedAt. Caller must hold mu.
func (c *pullCache) evictOldestLocked() {
	var oldestID uuid.UUID
	var oldestTime time.Time
	first := true
	for id, snap := range c.snapshots {
		if first || snap.fetchedAt.Before(oldestTime) {
			oldestID = id
			oldestTime = snap.fetchedAt
			first = false
		}
	}
	if !first {
		delete(c.snapshots, oldestID)
	}
}

// invalidate removes the cached snapshot for userID (called after push/delete).
func (c *pullCache) invalidate(userID uuid.UUID) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.snapshots, userID)
}

// merge applies push data into the cached snapshot for userID using LWW.
// If no snapshot exists, creates one from the push data alone.
func (c *pullCache) merge(userID uuid.UUID, req *model.SyncPushRequest) {
	c.mu.Lock()
	defer c.mu.Unlock()

	snap, exists := c.snapshots[userID]
	if !exists {
		// No cached snapshot — seed one from push data.
		resp := &model.SyncPullResponse{
			ServerTime:          time.Now().UnixMilli(),
			EpisodeProgress:     append([]model.EpisodeProgress{}, req.EpisodeProgress...),
			WatchHistory:        append([]model.WatchHistory{}, req.WatchHistory...),
			PlaybackPreferences: append([]model.PlaybackPreference{}, req.PlaybackPreferences...),
			LibraryEntries:      append([]model.LibraryEntry{}, req.LibraryEntries...),
		}
		if len(c.snapshots) >= cacheMaxEntries {
			c.evictOldestLocked()
		}
		c.snapshots[userID] = &pullSnapshot{resp: resp, fetchedAt: time.Now()}
		return
	}

	resp := snap.resp

	// Merge episode progress (LWW by updated_at).
	for _, ep := range req.EpisodeProgress {
		found := false
		for i, ex := range resp.EpisodeProgress {
			if ex.AnilistID == ep.AnilistID && ex.EpisodeNumber == ep.EpisodeNumber {
				if ep.UpdatedAt > ex.UpdatedAt {
					resp.EpisodeProgress[i] = ep
				}
				found = true
				break
			}
		}
		if !found {
			resp.EpisodeProgress = append(resp.EpisodeProgress, ep)
		}
	}

	// Merge watch history (LWW by last_accessed_at).
	for _, wh := range req.WatchHistory {
		found := false
		for i, ex := range resp.WatchHistory {
			if ex.AnilistID == wh.AnilistID {
				if wh.LastAccessedAt > ex.LastAccessedAt {
					resp.WatchHistory[i] = wh
				}
				found = true
				break
			}
		}
		if !found {
			resp.WatchHistory = append(resp.WatchHistory, wh)
		}
	}

	// Merge playback preferences (LWW by updated_at).
	for _, pp := range req.PlaybackPreferences {
		found := false
		for i, ex := range resp.PlaybackPreferences {
			if ex.AnilistID == pp.AnilistID {
				if pp.UpdatedAt > ex.UpdatedAt {
					resp.PlaybackPreferences[i] = pp
				}
				found = true
				break
			}
		}
		if !found {
			resp.PlaybackPreferences = append(resp.PlaybackPreferences, pp)
		}
	}

	// Merge library entries.
	for _, le := range req.LibraryEntries {
		found := false
		for i, ex := range resp.LibraryEntries {
			if ex.AnilistID == le.AnilistID {
				resp.LibraryEntries[i] = le
				found = true
				break
			}
		}
		if !found {
			resp.LibraryEntries = append(resp.LibraryEntries, le)
		}
	}

	// Apply watch history deletions.
	for _, d := range req.WatchHistoryDeletions {
		for i, ex := range resp.WatchHistory {
			if ex.AnilistID == d.AnilistID {
				resp.WatchHistory = append(resp.WatchHistory[:i], resp.WatchHistory[i+1:]...)
				break
			}
		}
	}

	snap.fetchedAt = time.Now()
}

// filterBySince creates a new SyncPullResponse containing only entries that
// are newer than `since` (unix millis). LibraryEntries are always included
// (the DB query already pulls all of them for correctness).
func filterBySince(full *model.SyncPullResponse, since int64) *model.SyncPullResponse {
	out := &model.SyncPullResponse{
		ServerTime:          time.Now().UnixMilli(),
		EpisodeProgress:     make([]model.EpisodeProgress, 0),
		WatchHistory:        make([]model.WatchHistory, 0),
		PlaybackPreferences: make([]model.PlaybackPreference, 0),
		LibraryEntries:      full.LibraryEntries, // always full set
	}
	if out.LibraryEntries == nil {
		out.LibraryEntries = []model.LibraryEntry{}
	}
	for _, ep := range full.EpisodeProgress {
		if ep.UpdatedAt > since {
			out.EpisodeProgress = append(out.EpisodeProgress, ep)
		}
	}
	for _, wh := range full.WatchHistory {
		if wh.LastAccessedAt > since {
			out.WatchHistory = append(out.WatchHistory, wh)
		}
	}
	for _, pp := range full.PlaybackPreferences {
		if pp.UpdatedAt > since {
			out.PlaybackPreferences = append(out.PlaybackPreferences, pp)
		}
	}
	return out
}
