// Package service implements the AniList Home surface services.
//
// Each method returns the raw `data` payload from AniList so handlers can
// pass it through to clients and Flutter mappers work unchanged.
package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"go-fiber-microservice/internal/anilist"
	"go-fiber-microservice/internal/anilist/cache"
)

// GraphQLClient is the minimum surface HomeService needs from the AniList
// client. Defined here so tests can supply a fake.
type GraphQLClient interface {
	Execute(ctx context.Context, query string, variables map[string]interface{}) (json.RawMessage, error)
}

// HomeService serves cached AniList Home surfaces.
type HomeService struct {
	client   GraphQLClient
	trending *cache.SWR
	season   *cache.SWR
	calendar *cache.SWR
}

// Config configures HomeService cache TTLs.
type Config struct {
	TrendingFresh time.Duration
	TrendingStale time.Duration
	SeasonFresh   time.Duration
	SeasonStale   time.Duration
	CalendarFresh time.Duration
	CalendarStale time.Duration
}

// DefaultConfig returns production-tuned TTLs. These are conservative:
// Home surfaces change slowly and AniList rate limits are tight.
func DefaultConfig() Config {
	return Config{
		TrendingFresh: 10 * time.Minute,
		TrendingStale: 50 * time.Minute,
		SeasonFresh:   30 * time.Minute,
		SeasonStale:   90 * time.Minute,
		CalendarFresh: 5 * time.Minute,
		CalendarStale: 25 * time.Minute,
	}
}

// NewHomeService builds a HomeService.
func NewHomeService(gc GraphQLClient, cfg Config) *HomeService {
	return &HomeService{
		client:   gc,
		trending: cache.New(cache.Config{Fresh: cfg.TrendingFresh, Stale: cfg.TrendingStale}),
		season:   cache.New(cache.Config{Fresh: cfg.SeasonFresh, Stale: cfg.SeasonStale}),
		calendar: cache.New(cache.Config{Fresh: cfg.CalendarFresh, Stale: cfg.CalendarStale}),
	}
}

// TrendingRequest parameters for trending/current-season Home catalog.
type TrendingRequest struct {
	Page    int
	PerPage int
}

func (r TrendingRequest) normalized() TrendingRequest {
	if r.Page <= 0 {
		r.Page = 1
	}
	if r.PerPage <= 0 || r.PerPage > 50 {
		r.PerPage = 20
	}
	return r
}

func (r TrendingRequest) cacheKey() string {
	return fmt.Sprintf("trending:p%d:n%d", r.Page, r.PerPage)
}

// Trending returns the trending + current-season anime payload.
func (s *HomeService) Trending(ctx context.Context, req TrendingRequest) (cache.Result, error) {
	req = req.normalized()
	season, year := currentSeasonWindow(time.Now().UTC())

	loader := func(ctx context.Context) (json.RawMessage, error) {
		return s.client.Execute(ctx, anilist.TrendingQuery, map[string]interface{}{
			"page":       req.Page,
			"perPage":    req.PerPage,
			"season":     season,
			"seasonYear": year,
			"statusIn":   []string{"RELEASING", "NOT_YET_RELEASED"},
		})
	}
	return s.trending.Get(ctx, req.cacheKey(), loader)
}

// SeasonDiscoveryRequest parameters for the season-discovery combo.
type SeasonDiscoveryRequest struct {
	Page              int
	PerPage           int
	IncludeCarryovers bool
}

func (r SeasonDiscoveryRequest) normalized() SeasonDiscoveryRequest {
	if r.Page <= 0 {
		r.Page = 1
	}
	if r.PerPage <= 0 || r.PerPage > 50 {
		r.PerPage = 30
	}
	return r
}

func (r SeasonDiscoveryRequest) cacheKey() string {
	return fmt.Sprintf("season:p%d:n%d:co%t", r.Page, r.PerPage, r.IncludeCarryovers)
}

// SeasonDiscovery returns the aliased current/upcoming/recommended/
// (carryover) payload.
func (s *HomeService) SeasonDiscovery(ctx context.Context, req SeasonDiscoveryRequest) (cache.Result, error) {
	req = req.normalized()
	now := time.Now().UTC()
	season, year := currentSeasonWindow(now)
	prevSeason, prevYear := previousSeasonWindow(season, year)

	loader := func(ctx context.Context) (json.RawMessage, error) {
		return s.client.Execute(ctx, anilist.SeasonDiscoveryQuery, map[string]interface{}{
			"page":             req.Page,
			"perPage":          req.PerPage,
			"season":           season,
			"seasonYear":       year,
			"prevSeason":       prevSeason,
			"prevSeasonYear":   prevYear,
			"includeCarryover": req.IncludeCarryovers,
		})
	}
	return s.season.Get(ctx, req.cacheKey(), loader)
}

// AiringCalendarRequest parameters for the airing calendar.
//
// Two ways to specify the window:
//  1. Days-based (default): set Days to how many days forward from
//     "now" (truncated to a 5-minute bucket so repeated requests
//     within the bucket share a cache entry).
//  2. Explicit timestamps: set both AiringAtGreater and AiringAtLesser
//     (unix seconds). Overrides Days. Useful when callers need a
//     custom window — e.g. Flutter's gateway which paginates through
//     the same window across multiple requests.
type AiringCalendarRequest struct {
	Days            int   // ignored if AiringAtGreater + AiringAtLesser are both non-zero
	AiringAtGreater int64 // unix seconds, optional
	AiringAtLesser  int64 // unix seconds, optional
	Page            int
	PerPage         int
}

func (r AiringCalendarRequest) normalized() AiringCalendarRequest {
	if r.Days <= 0 || r.Days > 14 {
		r.Days = 7
	}
	if r.Page <= 0 {
		r.Page = 1
	}
	if r.PerPage <= 0 || r.PerPage > 50 {
		r.PerPage = 50
	}
	// Explicit timestamps require both sides and lesser > greater.
	if r.AiringAtGreater <= 0 || r.AiringAtLesser <= 0 || r.AiringAtLesser <= r.AiringAtGreater {
		r.AiringAtGreater = 0
		r.AiringAtLesser = 0
	}
	return r
}

// hasExplicitWindow reports whether the request carries a valid
// caller-provided window. Must be called after normalized().
func (r AiringCalendarRequest) hasExplicitWindow() bool {
	return r.AiringAtGreater > 0 && r.AiringAtLesser > 0
}

func (r AiringCalendarRequest) cacheKey() string {
	if r.hasExplicitWindow() {
		return fmt.Sprintf(
			"calendar:g%d:l%d:p%d:n%d",
			r.AiringAtGreater, r.AiringAtLesser, r.Page, r.PerPage,
		)
	}
	windowStart := time.Now().UTC().Truncate(5 * time.Minute)
	return fmt.Sprintf(
		"calendar:d%d:p%d:n%d:w%d",
		r.Days, r.Page, r.PerPage, windowStart.Unix()/300,
	)
}

// AiringCalendar returns a single page of the airing schedule in the
// requested window. The response is the raw AniList payload; callers
// handle pagination client-side.
//
// For days-based requests we cache per (days, page, perPage, 5-minute
// window bucket) so slight clock drift between requests still hits the
// cache. The bucket changes every 5 min → matches our pre-warm cadence.
//
// For explicit-timestamp requests the cache key uses the timestamps
// directly — two callers with the same window share a cache entry.
func (s *HomeService) AiringCalendar(ctx context.Context, req AiringCalendarRequest) (cache.Result, error) {
	req = req.normalized()

	var greater, lesser int64
	if req.hasExplicitWindow() {
		greater = req.AiringAtGreater
		lesser = req.AiringAtLesser
	} else {
		windowStart := time.Now().UTC().Truncate(5 * time.Minute)
		windowEnd := windowStart.Add(time.Duration(req.Days) * 24 * time.Hour)
		greater = windowStart.Unix()
		lesser = windowEnd.Unix()
	}

	loader := func(ctx context.Context) (json.RawMessage, error) {
		return s.client.Execute(ctx, anilist.AiringCalendarQuery, map[string]interface{}{
			"page":            req.Page,
			"perPage":         req.PerPage,
			"airingAtGreater": greater,
			"airingAtLesser":  lesser,
		})
	}
	return s.calendar.Get(ctx, req.cacheKey(), loader)
}

// currentSeasonWindow mirrors the Dart gateway logic so clients and server
// always agree on which season "now" falls into.
func currentSeasonWindow(now time.Time) (season string, year int) {
	switch now.Month() {
	case time.December:
		// Dec belongs to WINTER of the *current* year (year-rolls over in Jan).
		return "WINTER", now.Year()
	case time.January, time.February:
		return "WINTER", now.Year()
	case time.March, time.April, time.May:
		return "SPRING", now.Year()
	case time.June, time.July, time.August:
		return "SUMMER", now.Year()
	default:
		return "FALL", now.Year()
	}
}

// previousSeasonWindow returns the season preceding the given one.
func previousSeasonWindow(season string, year int) (string, int) {
	switch season {
	case "WINTER":
		return "FALL", year - 1
	case "SPRING":
		return "WINTER", year
	case "SUMMER":
		return "SPRING", year
	case "FALL":
		return "SUMMER", year
	}
	return season, year
}
