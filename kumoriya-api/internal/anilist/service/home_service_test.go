package service

import (
	"context"
	"encoding/json"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

type fakeClient struct {
	calls     int32
	lastQuery string
	lastVars  map[string]interface{}
	response  json.RawMessage
	err       error
}

func (f *fakeClient) Execute(ctx context.Context, query string, vars map[string]interface{}) (json.RawMessage, error) {
	atomic.AddInt32(&f.calls, 1)
	f.lastQuery = query
	f.lastVars = vars
	if f.err != nil {
		return nil, f.err
	}
	return f.response, nil
}

func TestHomeService_Trending_CachesAcrossCalls(t *testing.T) {
	fake := &fakeClient{response: json.RawMessage(`{"Page":{"media":[]}}`)}
	svc := NewHomeService(fake, Config{
		TrendingFresh: time.Minute, TrendingStale: time.Minute,
		SeasonFresh: time.Minute, SeasonStale: time.Minute,
		CalendarFresh: time.Minute, CalendarStale: time.Minute,
		MangaHomeFresh: time.Minute, MangaHomeStale: time.Minute,
	})

	for i := 0; i < 3; i++ {
		if _, err := svc.Trending(context.Background(), TrendingRequest{}); err != nil {
			t.Fatal(err)
		}
	}
	if got := atomic.LoadInt32(&fake.calls); got != 1 {
		t.Errorf("expected 1 upstream call, got %d", got)
	}
}

func TestHomeService_Trending_PassesExpectedVariables(t *testing.T) {
	fake := &fakeClient{response: json.RawMessage(`{"Page":{"media":[]}}`)}
	svc := NewHomeService(fake, DefaultConfig())

	if _, err := svc.Trending(context.Background(), TrendingRequest{Page: 2, PerPage: 10}); err != nil {
		t.Fatal(err)
	}
	if fake.lastVars["page"].(int) != 2 {
		t.Errorf("expected page=2, got %v", fake.lastVars["page"])
	}
	if fake.lastVars["perPage"].(int) != 10 {
		t.Errorf("expected perPage=10, got %v", fake.lastVars["perPage"])
	}
	if _, ok := fake.lastVars["season"].(string); !ok {
		t.Errorf("expected season string var, got %T", fake.lastVars["season"])
	}
}

func TestHomeService_SeasonDiscovery_IncludesCarryoverFlag(t *testing.T) {
	fake := &fakeClient{response: json.RawMessage(`{"current":{"media":[]}}`)}
	svc := NewHomeService(fake, DefaultConfig())

	if _, err := svc.SeasonDiscovery(context.Background(), SeasonDiscoveryRequest{IncludeCarryovers: true}); err != nil {
		t.Fatal(err)
	}
	if got, _ := fake.lastVars["includeCarryover"].(bool); !got {
		t.Errorf("expected includeCarryover=true to be forwarded to AniList vars")
	}
}

func TestHomeService_AiringCalendar_WindowIsUnixSeconds(t *testing.T) {
	fake := &fakeClient{response: json.RawMessage(`{"Page":{"airingSchedules":[]}}`)}
	svc := NewHomeService(fake, DefaultConfig())

	if _, err := svc.AiringCalendar(context.Background(), AiringCalendarRequest{Days: 7}); err != nil {
		t.Fatal(err)
	}
	greater, ok := fake.lastVars["airingAtGreater"].(int64)
	if !ok {
		t.Fatalf("airingAtGreater should be int64, got %T", fake.lastVars["airingAtGreater"])
	}
	lesser, ok := fake.lastVars["airingAtLesser"].(int64)
	if !ok {
		t.Fatalf("airingAtLesser should be int64, got %T", fake.lastVars["airingAtLesser"])
	}
	if lesser-greater != int64(7*24*3600) {
		t.Errorf("expected 7-day window in seconds, got %d", lesser-greater)
	}
}

func TestHomeService_MangaHome_CachesAcrossCallsAndForwardsPaging(t *testing.T) {
	fake := &fakeClient{response: json.RawMessage(`{"trending":{"media":[]},"popular":{"media":[]},"latest":{"media":[]},"topRated":{"media":[]}}`)}
	svc := NewHomeService(fake, DefaultConfig())

	for i := 0; i < 3; i++ {
		if _, err := svc.MangaHome(context.Background(), MangaHomeRequest{Page: 1, PerPage: 20}); err != nil {
			t.Fatal(err)
		}
	}
	if got := atomic.LoadInt32(&fake.calls); got != 1 {
		t.Errorf("expected 1 upstream call (cached), got %d", got)
	}
	if fake.lastVars["page"].(int) != 1 {
		t.Errorf("expected page=1, got %v", fake.lastVars["page"])
	}
	if fake.lastVars["perPage"].(int) != 20 {
		t.Errorf("expected perPage=20, got %v", fake.lastVars["perPage"])
	}
}

func TestHomeService_MangaHome_NormalizesInvalidPaging(t *testing.T) {
	fake := &fakeClient{response: json.RawMessage(`{"trending":{"media":[]}}`)}
	svc := NewHomeService(fake, DefaultConfig())

	if _, err := svc.MangaHome(context.Background(), MangaHomeRequest{Page: 0, PerPage: 999}); err != nil {
		t.Fatal(err)
	}
	if fake.lastVars["page"].(int) != 1 {
		t.Errorf("expected normalized page=1, got %v", fake.lastVars["page"])
	}
	if fake.lastVars["perPage"].(int) != 20 {
		t.Errorf("expected normalized perPage=20, got %v", fake.lastVars["perPage"])
	}
}

func TestHomeService_UpstreamError_SurfacesOnColdMiss(t *testing.T) {
	fake := &fakeClient{err: errors.New("anilist down")}
	svc := NewHomeService(fake, DefaultConfig())

	if _, err := svc.Trending(context.Background(), TrendingRequest{}); err == nil {
		t.Fatalf("expected error on cold miss, got nil")
	}
}

func TestCurrentSeasonWindow(t *testing.T) {
	cases := []struct {
		in     time.Time
		season string
		year   int
	}{
		{time.Date(2026, time.January, 15, 0, 0, 0, 0, time.UTC), "WINTER", 2026},
		{time.Date(2026, time.April, 15, 0, 0, 0, 0, time.UTC), "SPRING", 2026},
		{time.Date(2026, time.July, 15, 0, 0, 0, 0, time.UTC), "SUMMER", 2026},
		{time.Date(2026, time.October, 15, 0, 0, 0, 0, time.UTC), "FALL", 2026},
		{time.Date(2026, time.December, 31, 0, 0, 0, 0, time.UTC), "WINTER", 2026},
	}
	for _, tc := range cases {
		s, y := currentSeasonWindow(tc.in)
		if s != tc.season || y != tc.year {
			t.Errorf("currentSeasonWindow(%s) = (%s, %d), want (%s, %d)", tc.in, s, y, tc.season, tc.year)
		}
	}
}

func TestPreviousSeasonWindow(t *testing.T) {
	cases := []struct {
		s  string
		y  int
		ws string
		wy int
	}{
		{"WINTER", 2026, "FALL", 2025},
		{"SPRING", 2026, "WINTER", 2026},
		{"SUMMER", 2026, "SPRING", 2026},
		{"FALL", 2026, "SUMMER", 2026},
	}
	for _, tc := range cases {
		s, y := previousSeasonWindow(tc.s, tc.y)
		if s != tc.ws || y != tc.wy {
			t.Errorf("previousSeasonWindow(%s, %d) = (%s, %d), want (%s, %d)", tc.s, tc.y, s, y, tc.ws, tc.wy)
		}
	}
}
