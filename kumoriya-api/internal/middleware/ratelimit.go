package middleware

import (
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
)

// PerUserRateLimit creates a simple sliding-window rate limiter keyed by
// the authenticated user ID (from JWT middleware Locals).
// maxRequests is the cap per window; window is the sliding-window duration.
func PerUserRateLimit(maxRequests int, window time.Duration) fiber.Handler {
	type entry struct {
		timestamps []time.Time
	}

	var mu sync.Mutex
	buckets := make(map[uuid.UUID]*entry)

	// Periodic cleanup of stale buckets (every 2× window).
	go func() {
		ticker := time.NewTicker(window * 2)
		defer ticker.Stop()
		for range ticker.C {
			cutoff := time.Now().Add(-window)
			mu.Lock()
			for k, e := range buckets {
				fresh := e.timestamps[:0]
				for _, ts := range e.timestamps {
					if ts.After(cutoff) {
						fresh = append(fresh, ts)
					}
				}
				if len(fresh) == 0 {
					delete(buckets, k)
				} else {
					e.timestamps = fresh
				}
			}
			mu.Unlock()
		}
	}()

	return func(c fiber.Ctx) error {
		uid, ok := UserIDFromCtx(c)
		if !ok {
			// No user context — should not happen on authed routes; pass through.
			return c.Next()
		}

		now := time.Now()
		cutoff := now.Add(-window)

		mu.Lock()
		e, exists := buckets[uid]
		if !exists {
			e = &entry{}
			buckets[uid] = e
		}

		// Prune old timestamps.
		fresh := e.timestamps[:0]
		for _, ts := range e.timestamps {
			if ts.After(cutoff) {
				fresh = append(fresh, ts)
			}
		}
		e.timestamps = fresh

		if len(e.timestamps) >= maxRequests {
			mu.Unlock()
			c.Set("Retry-After", "60")
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error": "rate limit exceeded",
			})
		}

		e.timestamps = append(e.timestamps, now)
		mu.Unlock()

		return c.Next()
	}
}
