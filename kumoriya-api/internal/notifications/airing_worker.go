package notifications

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/anilist/service"
)

// CalendarSource exposes the AniList airing calendar cache to the worker.
//
// We re-use the same HomeService cache used by the edge-cache endpoints:
// the worker sees exactly what clients see and never makes extra calls
// to AniList.
type CalendarSource interface {
	AiringCalendar(ctx context.Context, req service.AiringCalendarRequest) (calendarResult, error)
}

// calendarResult mirrors cache.Result minimally so CalendarSource can be
// implemented without importing cache. See calendarAdapter below for the
// real adapter.
type calendarResult struct {
	Data json.RawMessage
}

// calendarAdapter adapts *service.HomeService to CalendarSource.
type calendarAdapter struct{ home *service.HomeService }

// NewCalendarSource returns a CalendarSource backed by HomeService.
func NewCalendarSource(home *service.HomeService) CalendarSource {
	return &calendarAdapter{home: home}
}

func (a *calendarAdapter) AiringCalendar(ctx context.Context, req service.AiringCalendarRequest) (calendarResult, error) {
	res, err := a.home.AiringCalendar(ctx, req)
	if err != nil {
		return calendarResult{}, err
	}
	return calendarResult{Data: res.Data}, nil
}

// AiringWorker polls the cached airing calendar on a fixed cadence and
// dispatches one FCM push per freshly-aired episode, deduped via Redis.
type AiringWorker struct {
	calendar CalendarSource
	sender   Sender
	dedup    Deduper

	// Tick is the poll interval.
	Tick time.Duration
	// Window is the backward window in which an episode is considered
	// "just aired" (airingAt ∈ [now-Window, now]). Tune with Tick so
	// transient misses recover on the next cycle.
	Window time.Duration
	// DedupTTL bounds the dedup window in Redis. Must be long enough that
	// a restart + retry cannot re-notify, short enough that the slot is
	// eventually reclaimable.
	DedupTTL time.Duration

	// TopicPrefix is prepended to anilist_id to build the FCM topic.
	// Defaults to "media_".
	TopicPrefix string

	// Clock is injectable for tests.
	Clock func() time.Time
}

// Config tunes worker cadence and bounds.
type Config struct {
	Tick        time.Duration
	Window      time.Duration
	DedupTTL    time.Duration
	TopicPrefix string
}

// DefaultConfig returns production-tuned defaults.
func DefaultConfig() Config {
	return Config{
		Tick:        5 * time.Minute,
		Window:      10 * time.Minute,
		DedupTTL:    7 * 24 * time.Hour,
		TopicPrefix: "media_",
	}
}

// NewAiringWorker builds an AiringWorker.
func NewAiringWorker(cal CalendarSource, sender Sender, dedup Deduper, cfg Config) *AiringWorker {
	if cfg.Tick <= 0 {
		cfg.Tick = 5 * time.Minute
	}
	if cfg.Window <= 0 {
		cfg.Window = 10 * time.Minute
	}
	if cfg.DedupTTL <= 0 {
		cfg.DedupTTL = 7 * 24 * time.Hour
	}
	if cfg.TopicPrefix == "" {
		cfg.TopicPrefix = "media_"
	}
	return &AiringWorker{
		calendar:    cal,
		sender:      sender,
		dedup:       dedup,
		Tick:        cfg.Tick,
		Window:      cfg.Window,
		DedupTTL:    cfg.DedupTTL,
		TopicPrefix: cfg.TopicPrefix,
		Clock:       time.Now,
	}
}

// Run blocks until ctx is cancelled, polling on Tick.
func (w *AiringWorker) Run(ctx context.Context) {
	log.Info().
		Dur("tick", w.Tick).
		Dur("window", w.Window).
		Dur("dedup_ttl", w.DedupTTL).
		Msg("airing worker: started")

	// Run once immediately, then on ticker.
	if err := w.Cycle(ctx); err != nil {
		log.Warn().Err(err).Msg("airing worker: initial cycle failed")
	}
	t := time.NewTicker(w.Tick)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("airing worker: stopped")
			return
		case <-t.C:
			if err := w.Cycle(ctx); err != nil {
				log.Warn().Err(err).Msg("airing worker: cycle failed")
			}
		}
	}
}

// Cycle runs a single scan → claim → dispatch pass. Exported for tests.
func (w *AiringWorker) Cycle(ctx context.Context) error {
	cal, err := w.calendar.AiringCalendar(ctx, service.AiringCalendarRequest{
		Days: 1, Page: 1, PerPage: 50,
	})
	if err != nil {
		return fmt.Errorf("fetch calendar: %w", err)
	}
	entries, err := parseAiringEntries(cal.Data)
	if err != nil {
		return fmt.Errorf("parse calendar: %w", err)
	}

	now := w.Clock()
	windowStart := now.Add(-w.Window)

	dispatched, skipped, failed := 0, 0, 0
	for _, e := range entries {
		if e.AiringAt < windowStart.Unix() || e.AiringAt > now.Unix() {
			continue
		}
		ok, err := w.dedup.Claim(ctx, e.MediaID, e.Episode, w.DedupTTL)
		if err != nil {
			log.Warn().
				Err(err).
				Int("media_id", e.MediaID).
				Int("episode", e.Episode).
				Msg("airing worker: dedup error")
			failed++
			continue
		}
		if !ok {
			skipped++
			continue
		}
		topic := w.TopicPrefix + fmt.Sprintf("%d", e.MediaID)
		msg := TopicMessage{
			Title: e.topicTitle(),
			Body:  fmt.Sprintf("Episode %d is available now.", e.Episode),
			Data: map[string]string{
				"anilist_id": fmt.Sprintf("%d", e.MediaID),
				"episode":    fmt.Sprintf("%d", e.Episode),
				"deep_link":  fmt.Sprintf("kumoriya://anime/%d/ep/%d", e.MediaID, e.Episode),
				"airing_at":  fmt.Sprintf("%d", e.AiringAt),
			},
		}
		if _, err := w.sender.SendToTopic(ctx, topic, msg); err != nil {
			log.Warn().
				Err(err).
				Int("media_id", e.MediaID).
				Int("episode", e.Episode).
				Str("topic", topic).
				Msg("airing worker: fcm send failed")
			failed++
			continue
		}
		dispatched++
		log.Info().
			Int("media_id", e.MediaID).
			Int("episode", e.Episode).
			Str("topic", topic).
			Msg("airing worker: dispatched")
	}

	log.Info().
		Int("dispatched", dispatched).
		Int("skipped_dedup", skipped).
		Int("failed", failed).
		Int("candidates", len(entries)).
		Msg("airing worker: cycle complete")
	return nil
}

// airingEntry is one flattened airing row from the AniList payload.
type airingEntry struct {
	MediaID  int
	Episode  int
	AiringAt int64
	TitleEN  string
	TitleROM string
	IsAdult  bool
}

func (e airingEntry) topicTitle() string {
	if strings.TrimSpace(e.TitleEN) != "" {
		return e.TitleEN
	}
	if strings.TrimSpace(e.TitleROM) != "" {
		return e.TitleROM
	}
	return "New episode available"
}

// parseAiringEntries flattens the AniList airing calendar payload into a
// convenient slice. The payload shape is:
//
//	{ "Page": { "airingSchedules": [ { "episode": 5, "airingAt": 1234,
//	  "media": { "id": 123, "isAdult": false, "title": {...} } } ] } }
func parseAiringEntries(raw json.RawMessage) ([]airingEntry, error) {
	if len(raw) == 0 {
		return nil, errors.New("empty payload")
	}
	var envelope struct {
		Page struct {
			AiringSchedules []struct {
				Episode  int   `json:"episode"`
				AiringAt int64 `json:"airingAt"`
				Media    struct {
					ID      int  `json:"id"`
					IsAdult bool `json:"isAdult"`
					Title   struct {
						English string `json:"english"`
						Romaji  string `json:"romaji"`
					} `json:"title"`
				} `json:"media"`
			} `json:"airingSchedules"`
		} `json:"Page"`
	}
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return nil, err
	}
	out := make([]airingEntry, 0, len(envelope.Page.AiringSchedules))
	for _, s := range envelope.Page.AiringSchedules {
		if s.Media.ID <= 0 || s.Episode <= 0 || s.AiringAt <= 0 {
			continue
		}
		if s.Media.IsAdult {
			continue
		}
		out = append(out, airingEntry{
			MediaID:  s.Media.ID,
			Episode:  s.Episode,
			AiringAt: s.AiringAt,
			TitleEN:  s.Media.Title.English,
			TitleROM: s.Media.Title.Romaji,
		})
	}
	return out, nil
}
