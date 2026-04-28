package handler

import (
	"time"

	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/anilist/service"
)

// HealthHandler exposes a lightweight AniList reachability probe so
// clients can detect when upstream recovers and refresh their UIs
// without needing to retry every individual request.
//
// The probe is computed entirely from the local SWR cache state — no
// fan-out call to AniList — so it is cheap to poll (single mutex
// acquire per bucket).
type HealthHandler struct {
	svc *service.HomeService
}

// NewHealthHandler builds the handler.
func NewHealthHandler(svc *service.HomeService) *HealthHandler {
	return &HealthHandler{svc: svc}
}

// Register mounts the health probe under /v1/anilist/health.
func (h *HealthHandler) Register(app *fiber.App) {
	app.Get("/v1/anilist/health", h.Get)
}

// HealthResponse is the wire shape of GET /v1/anilist/health.
type HealthResponse struct {
	// AnilistReachable is `true` when at least one cache bucket has a
	// recent successful refresh (i.e. its entries are not all in
	// outage). When the cache is completely empty (cold start) we
	// optimistically report `true` so clients don't show an offline
	// banner before they've even tried a request.
	AnilistReachable bool `json:"anilist_reachable"`
	// CheckedAt is the wall-clock time the snapshot was taken (RFC3339).
	CheckedAt string `json:"checked_at"`
	// Buckets reports per-bucket stats so operators can debug which
	// surface is degraded. Clients should not rely on the exact shape;
	// only AnilistReachable is part of the stable contract.
	Buckets map[string]BucketHealth `json:"buckets"`
}

// BucketHealth reports the state of a single SWR bucket.
type BucketHealth struct {
	TotalEntries     int    `json:"total_entries"`
	OutageEntries    int    `json:"outage_entries"`
	OldestAgeSeconds int64  `json:"oldest_age_seconds,omitempty"`
	OldestFetchedAt  string `json:"oldest_fetched_at,omitempty"`
}

// Get serves the health probe.
func (h *HealthHandler) Get(c fiber.Ctx) error {
	now := time.Now()
	snap := h.svc.Snapshot()

	// Cache aggressively short — clients poll this frequently when in
	// degraded mode, so 1s of caching avoids hammering the handler
	// while still surfacing recoveries within the polling interval.
	c.Set("Cache-Control", "public, max-age=1")

	totalEntries := 0
	totalOutage := 0
	buckets := make(map[string]BucketHealth, len(snap))
	for name, s := range snap {
		bh := BucketHealth{
			TotalEntries:  s.TotalEntries,
			OutageEntries: s.OutageEntries,
		}
		if !s.OldestFetchedAt.IsZero() {
			bh.OldestAgeSeconds = int64(now.Sub(s.OldestFetchedAt) / time.Second)
			bh.OldestFetchedAt = s.OldestFetchedAt.UTC().Format(time.RFC3339)
		}
		buckets[name] = bh
		totalEntries += s.TotalEntries
		totalOutage += s.OutageEntries
	}

	reachable := isReachable(totalEntries, totalOutage)
	return c.JSON(HealthResponse{
		AnilistReachable: reachable,
		CheckedAt:        now.UTC().Format(time.RFC3339),
		Buckets:          buckets,
	})
}

// isReachable applies the heuristic that decides whether AniList is
// considered reachable based on the aggregate cache state.
//
// Rules (in order):
//
//  1. Empty cache (cold start, no warmup yet) → reachable=true. We
//     don't know yet, and a false-positive here would cause clients
//     to show an offline banner before any request was even tried.
//  2. ≥50% of entries are in outage → reachable=false. The cache has
//     been trying to refresh and most refreshes are failing.
//  3. Otherwise → reachable=true.
//
// The 50% threshold is chosen so that a single bucket failing
// (e.g. only manga-home is degraded because of an alias-specific
// AniList bug) does not flip the global health signal — the user can
// still browse the working surfaces.
func isReachable(total, outage int) bool {
	if total == 0 {
		return true
	}
	return outage*2 < total
}
