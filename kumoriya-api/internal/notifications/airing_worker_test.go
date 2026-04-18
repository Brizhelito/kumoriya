package notifications

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"go-fiber-microservice/internal/anilist/service"
)

// ----------------------------------------------------------------------------
// Fakes
// ----------------------------------------------------------------------------

type fakeCalendar struct {
	payload json.RawMessage
	err     error
}

func (f *fakeCalendar) AiringCalendar(ctx context.Context, req service.AiringCalendarRequest) (calendarResult, error) {
	if f.err != nil {
		return calendarResult{}, f.err
	}
	return calendarResult{Data: f.payload}, nil
}

type fakeSender struct {
	mu        sync.Mutex
	sent      []sentArgs
	failTopic string
}

type sentArgs struct {
	topic string
	msg   TopicMessage
}

func (f *fakeSender) SendToTopic(ctx context.Context, topic string, msg TopicMessage) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.failTopic != "" && f.failTopic == topic {
		return "", errors.New("fcm down")
	}
	f.sent = append(f.sent, sentArgs{topic: topic, msg: msg})
	return fmt.Sprintf("msg-%d", len(f.sent)), nil
}

// memDeduper is a local in-memory Deduper for tests. Not suitable for
// production (no durability across restart).
type memDeduper struct {
	mu      sync.Mutex
	claimed map[string]time.Time
	err     error
}

func newMemDeduper() *memDeduper {
	return &memDeduper{claimed: map[string]time.Time{}}
}

func (d *memDeduper) Claim(ctx context.Context, mediaID, episode int, ttl time.Duration) (bool, error) {
	if d.err != nil {
		return false, d.err
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	key := fmt.Sprintf("%d:%d", mediaID, episode)
	if exp, ok := d.claimed[key]; ok && time.Now().Before(exp) {
		return false, nil
	}
	d.claimed[key] = time.Now().Add(ttl)
	return true, nil
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

func buildPayload(entries []buildEntry) json.RawMessage {
	type sched struct {
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
	}
	var schedules []sched
	for _, e := range entries {
		s := sched{Episode: e.Episode, AiringAt: e.AiringAt}
		s.Media.ID = e.MediaID
		s.Media.IsAdult = e.IsAdult
		s.Media.Title.English = e.TitleEN
		s.Media.Title.Romaji = e.TitleROM
		schedules = append(schedules, s)
	}
	env := map[string]interface{}{
		"Page": map[string]interface{}{
			"airingSchedules": schedules,
		},
	}
	b, _ := json.Marshal(env)
	return b
}

type buildEntry struct {
	MediaID  int
	Episode  int
	AiringAt int64
	TitleEN  string
	TitleROM string
	IsAdult  bool
}

func fixedClock(t time.Time) func() time.Time {
	return func() time.Time { return t }
}

// ----------------------------------------------------------------------------
// Tests
// ----------------------------------------------------------------------------

func TestAiringWorker_DispatchesOnlyWithinWindow(t *testing.T) {
	now := time.Date(2026, 4, 18, 14, 0, 0, 0, time.UTC)

	cal := &fakeCalendar{payload: buildPayload([]buildEntry{
		{MediaID: 1, Episode: 5, AiringAt: now.Add(-3 * time.Minute).Unix(), TitleEN: "Foo"},    // in window
		{MediaID: 2, Episode: 10, AiringAt: now.Add(-1 * time.Hour).Unix(), TitleEN: "Too old"}, // out
		{MediaID: 3, Episode: 1, AiringAt: now.Add(+5 * time.Minute).Unix(), TitleEN: "Future"}, // out
	})}
	send := &fakeSender{}
	dedup := newMemDeduper()
	w := NewAiringWorker(cal, send, dedup, Config{
		Tick: time.Minute, Window: 10 * time.Minute, DedupTTL: time.Hour,
	})
	w.Clock = fixedClock(now)

	if err := w.Cycle(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := len(send.sent); got != 1 {
		t.Fatalf("expected 1 dispatch, got %d", got)
	}
	if send.sent[0].topic != "media_1" {
		t.Errorf("expected topic media_1, got %s", send.sent[0].topic)
	}
	if send.sent[0].msg.Title != "Foo" {
		t.Errorf("expected title Foo, got %s", send.sent[0].msg.Title)
	}
	if send.sent[0].msg.Data["deep_link"] != "kumoriya://anime/1/ep/5" {
		t.Errorf("unexpected deep link: %s", send.sent[0].msg.Data["deep_link"])
	}
}

func TestAiringWorker_DedupSkipsOnRestart(t *testing.T) {
	now := time.Date(2026, 4, 18, 14, 0, 0, 0, time.UTC)

	cal := &fakeCalendar{payload: buildPayload([]buildEntry{
		{MediaID: 1, Episode: 5, AiringAt: now.Add(-1 * time.Minute).Unix(), TitleEN: "Foo"},
	})}
	send := &fakeSender{}
	dedup := newMemDeduper()
	w := NewAiringWorker(cal, send, dedup, Config{
		Tick: time.Minute, Window: 10 * time.Minute, DedupTTL: time.Hour,
	})
	w.Clock = fixedClock(now)

	for i := 0; i < 5; i++ {
		if err := w.Cycle(context.Background()); err != nil {
			t.Fatal(err)
		}
	}
	if got := len(send.sent); got != 1 {
		t.Fatalf("expected dedup to collapse 5 cycles to 1 dispatch, got %d", got)
	}
}

func TestAiringWorker_SkipsAdultMedia(t *testing.T) {
	now := time.Date(2026, 4, 18, 14, 0, 0, 0, time.UTC)

	cal := &fakeCalendar{payload: buildPayload([]buildEntry{
		{MediaID: 1, Episode: 5, AiringAt: now.Add(-1 * time.Minute).Unix(), TitleEN: "Adult", IsAdult: true},
		{MediaID: 2, Episode: 5, AiringAt: now.Add(-1 * time.Minute).Unix(), TitleEN: "Safe"},
	})}
	send := &fakeSender{}
	w := NewAiringWorker(cal, send, newMemDeduper(), DefaultConfig())
	w.Clock = fixedClock(now)

	if err := w.Cycle(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := len(send.sent); got != 1 {
		t.Fatalf("expected 1 dispatch (adult skipped), got %d", got)
	}
	if send.sent[0].msg.Title != "Safe" {
		t.Errorf("wrong dispatch: %+v", send.sent[0])
	}
}

func TestAiringWorker_FCMFailure_DoesNotBlockOthers(t *testing.T) {
	now := time.Date(2026, 4, 18, 14, 0, 0, 0, time.UTC)

	cal := &fakeCalendar{payload: buildPayload([]buildEntry{
		{MediaID: 1, Episode: 5, AiringAt: now.Add(-1 * time.Minute).Unix(), TitleEN: "Foo"},
		{MediaID: 2, Episode: 5, AiringAt: now.Add(-1 * time.Minute).Unix(), TitleEN: "Bar"},
	})}
	send := &fakeSender{failTopic: "media_1"}
	w := NewAiringWorker(cal, send, newMemDeduper(), DefaultConfig())
	w.Clock = fixedClock(now)

	if err := w.Cycle(context.Background()); err != nil {
		t.Fatal(err)
	}
	// media_2 should have been dispatched despite media_1 failing.
	if got := len(send.sent); got != 1 {
		t.Fatalf("expected 1 successful dispatch, got %d", got)
	}
	if send.sent[0].topic != "media_2" {
		t.Errorf("expected media_2, got %s", send.sent[0].topic)
	}
}

func TestAiringWorker_TitleFallbacksToRomaji(t *testing.T) {
	now := time.Date(2026, 4, 18, 14, 0, 0, 0, time.UTC)
	cal := &fakeCalendar{payload: buildPayload([]buildEntry{
		{MediaID: 1, Episode: 5, AiringAt: now.Add(-1 * time.Minute).Unix(), TitleROM: "Kimetsu"},
	})}
	send := &fakeSender{}
	w := NewAiringWorker(cal, send, newMemDeduper(), DefaultConfig())
	w.Clock = fixedClock(now)

	if err := w.Cycle(context.Background()); err != nil {
		t.Fatal(err)
	}
	if send.sent[0].msg.Title != "Kimetsu" {
		t.Errorf("expected romaji fallback, got %q", send.sent[0].msg.Title)
	}
}

func TestAiringWorker_EmptyPayloadIsError(t *testing.T) {
	cal := &fakeCalendar{payload: json.RawMessage{}}
	w := NewAiringWorker(cal, &fakeSender{}, newMemDeduper(), DefaultConfig())
	if err := w.Cycle(context.Background()); err == nil {
		t.Fatalf("expected error on empty payload")
	}
}

func TestLooksLikeServiceAccountJSON(t *testing.T) {
	ok := looksLikeServiceAccountJSON([]byte(`{
		"type": "service_account",
		"project_id": "p",
		"client_email": "e",
		"private_key": "k"
	}`))
	if !ok {
		t.Error("expected valid service account to pass")
	}
	if looksLikeServiceAccountJSON([]byte(`{"type":"authorized_user"}`)) {
		t.Error("expected non-service_account to fail")
	}
	if looksLikeServiceAccountJSON([]byte(`not json`)) {
		t.Error("expected invalid JSON to fail")
	}
}
