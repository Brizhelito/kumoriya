// Package cache implements an in-memory stale-while-revalidate cache for
// AniList Home surfaces.
//
// The cache stores JSON payloads keyed by string, with three time windows:
//
//   - fresh:   served immediately, no refresh.
//   - stale:   served immediately, background refresh triggered.
//   - expired: synchronous refresh (blocks the caller).
//
// All entries live entirely in memory. If the server (Hugging Face Space)
// restarts, cache is empty; the scheduler/boot warmup repopulates it.
// Durability is intentionally not a goal here: the data is public and
// cheap to re-fetch.
package cache

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"github.com/rs/zerolog/log"
)

// Loader fetches a fresh payload for a key. Called synchronously on cold
// miss, or asynchronously for stale refresh.
type Loader func(ctx context.Context) (json.RawMessage, error)

// entry holds one cached payload.
type entry struct {
	data      json.RawMessage
	fetchedAt time.Time
	// refreshing guards the single-flight contract: only one in-flight
	// refresh per key at any time.
	refreshing bool
}

// SWR is a stale-while-revalidate cache.
type SWR struct {
	fresh time.Duration
	stale time.Duration

	mu      sync.Mutex
	entries map[string]*entry

	// refreshTimeout bounds background refreshes so a hanging AniList
	// call does not pin the refresh slot forever.
	refreshTimeout time.Duration
}

// Config configures an SWR cache.
type Config struct {
	// Fresh is how long an entry is served without any refresh attempt.
	Fresh time.Duration
	// Stale is how long past Fresh we keep serving the old payload while
	// a background refresh runs. Total lifetime is Fresh+Stale.
	Stale time.Duration
	// RefreshTimeout bounds background refresh calls. Defaults to 20s.
	RefreshTimeout time.Duration
}

// New builds a new SWR cache.
func New(cfg Config) *SWR {
	if cfg.RefreshTimeout == 0 {
		cfg.RefreshTimeout = 20 * time.Second
	}
	return &SWR{
		fresh:          cfg.Fresh,
		stale:          cfg.Stale,
		refreshTimeout: cfg.RefreshTimeout,
		entries:        make(map[string]*entry),
	}
}

// Result describes what Get returned.
type Result struct {
	Data    json.RawMessage
	Age     time.Duration // time since fetchedAt
	Stale   bool          // true if payload is past Fresh but within Stale
	FromAge bool          // true if payload was served from cache (hit of any kind)
}

// Get returns a cached payload, refreshing according to SWR rules.
//
//   - Fresh hit → returns immediately with stored payload.
//   - Stale hit → returns stored payload immediately AND spawns a
//     background refresh (single-flight per key).
//   - Expired / cold miss → blocks on loader, stores, returns fresh result.
//
// If a background refresh fails, the stored payload remains serveable
// until it expires (Fresh+Stale). If the synchronous load fails and no
// prior payload exists, the error is returned to the caller.
func (c *SWR) Get(ctx context.Context, key string, loader Loader) (Result, error) {
	c.mu.Lock()
	e, ok := c.entries[key]
	now := time.Now()

	if ok {
		age := now.Sub(e.fetchedAt)

		switch {
		case age < c.fresh:
			// Fresh hit.
			res := Result{Data: e.data, Age: age, Stale: false, FromAge: true}
			c.mu.Unlock()
			return res, nil
		case age < c.fresh+c.stale:
			// Stale hit → serve + spawn background refresh.
			res := Result{Data: e.data, Age: age, Stale: true, FromAge: true}
			if !e.refreshing {
				e.refreshing = true
				c.mu.Unlock()
				go c.refreshAsync(key, loader)
				return res, nil
			}
			c.mu.Unlock()
			return res, nil
		}
		// Expired → fall through to synchronous load.
	}
	c.mu.Unlock()

	return c.loadSync(ctx, key, loader)
}

// Set stores a payload for a key, used by the pre-warm scheduler.
func (c *SWR) Set(key string, data json.RawMessage) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.entries[key]
	if !ok {
		e = &entry{}
		c.entries[key] = e
	}
	e.data = data
	e.fetchedAt = time.Now()
	e.refreshing = false
}

// Peek returns a cached payload without triggering refresh; used for
// observability and tests.
func (c *SWR) Peek(key string) (json.RawMessage, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.entries[key]
	if !ok {
		return nil, false
	}
	return e.data, true
}

func (c *SWR) loadSync(ctx context.Context, key string, loader Loader) (Result, error) {
	data, err := loader(ctx)
	if err != nil {
		// If we have any prior payload at all (even expired), surface it as
		// a last-resort stale answer instead of a hard failure. This makes
		// transient AniList outages invisible to users.
		c.mu.Lock()
		defer c.mu.Unlock()
		if e, ok := c.entries[key]; ok && len(e.data) > 0 {
			return Result{
				Data:    e.data,
				Age:     time.Since(e.fetchedAt),
				Stale:   true,
				FromAge: true,
			}, nil
		}
		return Result{}, err
	}
	if len(data) == 0 {
		return Result{}, errors.New("cache loader returned empty payload")
	}
	c.Set(key, data)
	return Result{Data: data, Age: 0, Stale: false, FromAge: false}, nil
}

func (c *SWR) refreshAsync(key string, loader Loader) {
	ctx, cancel := context.WithTimeout(context.Background(), c.refreshTimeout)
	defer cancel()

	defer func() {
		c.mu.Lock()
		if e, ok := c.entries[key]; ok {
			e.refreshing = false
		}
		c.mu.Unlock()
	}()

	data, err := loader(ctx)
	if err != nil {
		log.Warn().Err(err).Str("key", key).Msg("anilist cache: background refresh failed; keeping stale payload")
		return
	}
	if len(data) == 0 {
		log.Warn().Str("key", key).Msg("anilist cache: background refresh returned empty payload; keeping stale")
		return
	}
	c.Set(key, data)
	log.Debug().Str("key", key).Msg("anilist cache: background refresh complete")
}
