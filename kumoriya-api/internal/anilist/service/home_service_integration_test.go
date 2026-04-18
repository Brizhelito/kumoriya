//go:build integration

// These tests hit the real AniList GraphQL endpoint. They are skipped by
// default (`go test ./...`) and only run with:
//
//	go test -tags=integration ./internal/anilist/...
//
// They verify that the pass-through cache returns payloads Flutter's
// existing mappers can consume (Page.media for trending, aliased Pages for
// season-discovery, Page.airingSchedules for the airing calendar).
package service

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"go-fiber-microservice/internal/anilist/client"
)

func newIntegrationService(t *testing.T) *HomeService {
	t.Helper()
	return NewHomeService(client.New(), DefaultConfig())
}

func decode(t *testing.T, raw json.RawMessage) map[string]interface{} {
	t.Helper()
	var m map[string]interface{}
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatalf("invalid json payload: %v\n%s", err, string(raw))
	}
	return m
}

func TestIntegration_Trending_ReturnsPageMediaList(t *testing.T) {
	svc := newIntegrationService(t)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	res, err := svc.Trending(ctx, TrendingRequest{Page: 1, PerPage: 5})
	if err != nil {
		t.Fatalf("Trending failed: %v", err)
	}
	if res.FromAge {
		t.Errorf("expected cold miss on first call, got FromAge=true")
	}

	m := decode(t, res.Data)
	page, ok := m["Page"].(map[string]interface{})
	if !ok {
		t.Fatalf("payload missing Page object; got keys: %v", mapKeys(m))
	}
	media, ok := page["media"].([]interface{})
	if !ok {
		t.Fatalf("Page.media missing or wrong type; got keys: %v", mapKeys(page))
	}
	if len(media) == 0 {
		t.Fatalf("Page.media empty; expected at least 1 entry")
	}

	// Sanity: first item has an id and a title.
	first, ok := media[0].(map[string]interface{})
	if !ok {
		t.Fatalf("first media entry is not a JSON object")
	}
	if _, ok := first["id"].(float64); !ok {
		t.Errorf("first.id missing or not numeric")
	}
	if _, ok := first["title"].(map[string]interface{}); !ok {
		t.Errorf("first.title missing or wrong type")
	}
}

func TestIntegration_SeasonDiscovery_HasAliasedPages(t *testing.T) {
	svc := newIntegrationService(t)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	res, err := svc.SeasonDiscovery(ctx, SeasonDiscoveryRequest{
		Page: 1, PerPage: 5, IncludeCarryovers: true,
	})
	if err != nil {
		t.Fatalf("SeasonDiscovery failed: %v", err)
	}

	m := decode(t, res.Data)
	for _, alias := range []string{"current", "upcoming", "recommended", "carryover"} {
		page, ok := m[alias].(map[string]interface{})
		if !ok {
			t.Errorf("alias %q missing from payload; keys: %v", alias, mapKeys(m))
			continue
		}
		media, ok := page["media"].([]interface{})
		if !ok {
			t.Errorf("alias %q has no media list", alias)
			continue
		}
		// current and recommended should always have entries; upcoming and
		// carryover may be empty depending on season.
		if (alias == "current" || alias == "recommended") && len(media) == 0 {
			t.Errorf("alias %q unexpectedly empty", alias)
		}
	}
}

func TestIntegration_AiringCalendar_HasAiringSchedules(t *testing.T) {
	svc := newIntegrationService(t)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	res, err := svc.AiringCalendar(ctx, AiringCalendarRequest{Days: 7, Page: 1, PerPage: 10})
	if err != nil {
		t.Fatalf("AiringCalendar failed: %v", err)
	}

	m := decode(t, res.Data)
	page, ok := m["Page"].(map[string]interface{})
	if !ok {
		t.Fatalf("payload missing Page; keys: %v", mapKeys(m))
	}
	schedules, ok := page["airingSchedules"].([]interface{})
	if !ok {
		t.Fatalf("Page.airingSchedules missing or wrong type; keys: %v", mapKeys(page))
	}
	if len(schedules) == 0 {
		// 7-day forward window should normally contain episodes. If empty
		// we log rather than fail (AniList could be in a weird state).
		t.Logf("warning: airingSchedules empty (window was 7 days)")
	}
	info, ok := page["pageInfo"].(map[string]interface{})
	if !ok {
		t.Errorf("pageInfo missing")
	} else if _, ok := info["hasNextPage"].(bool); !ok {
		t.Errorf("pageInfo.hasNextPage missing or not bool")
	}
}

func TestIntegration_Trending_SecondCallIsCached(t *testing.T) {
	svc := newIntegrationService(t)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	if _, err := svc.Trending(ctx, TrendingRequest{Page: 1, PerPage: 5}); err != nil {
		t.Fatalf("first Trending failed: %v", err)
	}
	start := time.Now()
	res, err := svc.Trending(ctx, TrendingRequest{Page: 1, PerPage: 5})
	if err != nil {
		t.Fatalf("second Trending failed: %v", err)
	}
	elapsed := time.Since(start)
	if !res.FromAge {
		t.Errorf("expected FromAge=true on second call (cache hit)")
	}
	if elapsed > 50*time.Millisecond {
		t.Errorf("cache hit took %v, expected <50ms", elapsed)
	}
}

func mapKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}
