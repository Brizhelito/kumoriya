package middleware

import (
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
)

type rateLimitEntry struct {
	timestamps []time.Time
}

func slidingWindowRateLimit(maxRequests int, window time.Duration, keyFn func(fiber.Ctx) (string, bool)) fiber.Handler {
	var mu sync.Mutex
	buckets := make(map[string]*rateLimitEntry)

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
		key, ok := keyFn(c)
		if !ok {
			return c.Next()
		}

		now := time.Now()
		cutoff := now.Add(-window)

		mu.Lock()
		e, exists := buckets[key]
		if !exists {
			e = &rateLimitEntry{}
			buckets[key] = e
		}

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

// PerUserRateLimit creates a simple sliding-window rate limiter keyed by
// the authenticated user ID (from JWT middleware Locals).
func PerUserRateLimit(maxRequests int, window time.Duration) fiber.Handler {
	return slidingWindowRateLimit(maxRequests, window, func(c fiber.Ctx) (string, bool) {
		uid, ok := UserIDFromCtx(c)
		if !ok {
			return "", false
		}
		return uid.String(), true
	})
}

// PerIPRateLimit creates a simple sliding-window rate limiter keyed by client IP.
// This is intended as an app-level fallback behind edge rate limiting.
func PerIPRateLimit(maxRequests int, window time.Duration) fiber.Handler {
	return slidingWindowRateLimit(maxRequests, window, func(c fiber.Ctx) (string, bool) {
		ip := c.IP()
		if ip == "" {
			return "", false
		}
		return ip, true
	})
}
