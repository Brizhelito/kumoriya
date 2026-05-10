// Package scheduler keeps the AniList Home cache warm so no user request
// ever blocks on a cold miss against graphql.anilist.co.
package scheduler

import (
	"context"
	"time"

	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/anilist/service"
)

// Prewarmer refreshes the Home cache on a fixed cadence.
type Prewarmer struct {
	home *service.HomeService

	trendingEvery  time.Duration
	seasonEvery    time.Duration
	calendarEvery  time.Duration
	mangaHomeEvery time.Duration
}

// Config configures Prewarmer cadence.
type Config struct {
	TrendingEvery  time.Duration
	SeasonEvery    time.Duration
	CalendarEvery  time.Duration
	MangaHomeEvery time.Duration
}

// DefaultConfig is tuned conservatively below AniList's 85 req/min limit.
// Four cron jobs fire, each ~1 req per cycle — well under budget.
func DefaultConfig() Config {
	return Config{
		TrendingEvery: 10 * time.Minute,
		SeasonEvery:   30 * time.Minute,
		CalendarEvery: 5 * time.Minute,
		// Manga shelves change slower than anime trending. 15 min keeps
		// the entry comfortably inside MangaHomeFresh=30min so cold tabs
		// always hit a fresh payload.
		MangaHomeEvery: 15 * time.Minute,
	}
}

// New builds a Prewarmer.
func New(home *service.HomeService, cfg Config) *Prewarmer {
	return &Prewarmer{
		home:           home,
		trendingEvery:  cfg.TrendingEvery,
		seasonEvery:    cfg.SeasonEvery,
		calendarEvery:  cfg.CalendarEvery,
		mangaHomeEvery: cfg.MangaHomeEvery,
	}
}

// Run warms the cache immediately, then refreshes on schedule until ctx is
// cancelled. It should be launched in its own goroutine from main.
func (p *Prewarmer) Run(ctx context.Context) {
	log.Info().Msg("anilist prewarm: initial warmup")
	p.warmAll(ctx)

	trendingT := time.NewTicker(p.trendingEvery)
	seasonT := time.NewTicker(p.seasonEvery)
	calendarT := time.NewTicker(p.calendarEvery)
	mangaHomeT := time.NewTicker(p.mangaHomeEvery)
	defer trendingT.Stop()
	defer seasonT.Stop()
	defer calendarT.Stop()
	defer mangaHomeT.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("anilist prewarm: stopping")
			return
		case <-trendingT.C:
			p.warmTrending(ctx)
		case <-seasonT.C:
			p.warmSeason(ctx)
		case <-calendarT.C:
			p.warmCalendar(ctx)
		case <-mangaHomeT.C:
			p.warmMangaHome(ctx)
		}
	}
}

func (p *Prewarmer) warmAll(ctx context.Context) {
	p.warmTrending(ctx)
	p.warmSeason(ctx)
	p.warmCalendar(ctx)
	p.warmMangaHome(ctx)
}

func (p *Prewarmer) warmTrending(ctx context.Context) {
	c, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	if _, err := p.home.Trending(c, service.TrendingRequest{Page: 1, PerPage: 20}); err != nil {
		log.Warn().Err(err).Msg("anilist prewarm: trending failed")
		return
	}
	log.Debug().Msg("anilist prewarm: trending refreshed")
}

func (p *Prewarmer) warmSeason(ctx context.Context) {
	c, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	if _, err := p.home.SeasonDiscovery(c, service.SeasonDiscoveryRequest{
		Page: 1, PerPage: 30, IncludeCarryovers: true,
	}); err != nil {
		log.Warn().Err(err).Msg("anilist prewarm: season discovery failed")
		return
	}
	log.Debug().Msg("anilist prewarm: season discovery refreshed")
}

func (p *Prewarmer) warmCalendar(ctx context.Context) {
	c, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	if _, err := p.home.AiringCalendar(c, service.AiringCalendarRequest{Days: 7, Page: 1, PerPage: 50}); err != nil {
		log.Warn().Err(err).Msg("anilist prewarm: airing calendar failed")
		return
	}
	log.Debug().Msg("anilist prewarm: airing calendar refreshed")
}

func (p *Prewarmer) warmMangaHome(ctx context.Context) {
	c, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	if _, err := p.home.MangaHome(c, service.MangaHomeRequest{Page: 1, PerPage: 20}); err != nil {
		log.Warn().Err(err).Msg("anilist prewarm: manga home failed")
		return
	}
	log.Debug().Msg("anilist prewarm: manga home refreshed")
}
