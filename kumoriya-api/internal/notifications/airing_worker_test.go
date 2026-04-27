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
	// entries, when non-nil, is filtered against req.AiringAtGreater /
	// AiringAtLesser to mirror AniList's strict-greater / strict-lesser
	// semantics. Use this when a test cares about the upstream window
	// behaviour; legacy tests keep using `payload` and ignore the req.
	entries []buildEntry
	lastReq service.AiringCalendarRequest
	err     error
}

func (f *fakeCalendar) AiringCalendar(ctx context.Context, req service.AiringCalendarRequest) (calendarResult, error) {
	f.lastReq = req
	if f.err != nil {
		return calendarResult{}, f.err
	}
	if f.entries != nil {
		filtered := make([]buildEntry, 0, len(f.entries))
		for _, e := range f.entries {
			// AniList: airingAt_greater is strict (>), airingAt_lesser is strict (<).
			if req.AiringAtGreater > 0 && e.AiringAt <= req.AiringAtGreater {
				continue
			}
			if req.AiringAtLesser > 0 && e.AiringAt >= req.AiringAtLesser {
				continue
			}
			filtered = append(filtered, e)
		}
		return calendarResult{Data: buildPayload(filtered)}, nil
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

// TestAiringWorker_RecoversAcrossBucketBoundary is the regression for the
// "no llegan notificaciones" bug: with the old days-based query the worker
// asked AniList for `airingAt_greater = now.Truncate(5min)`, so any episode
// whose airingAt fell just before the current 5-min cache bucket was
// stripped at the upstream and never dispatched. We reproduce that boundary
// (now lands 30s into a fresh bucket, episode aired 90s ago) and assert the
// worker still sees and dispatches it.
func TestAiringWorker_RecoversAcrossBucketBoundary(t *testing.T) {
	bucket := time.Date(2026, 4, 18, 14, 5, 0, 0, time.UTC) // bucket boundary
	now := bucket.Add(30 * time.Second)
	aired := bucket.Add(-90 * time.Second) // aired in previous bucket

	cal := &fakeCalendar{entries: []buildEntry{
		{MediaID: 42, Episode: 7, AiringAt: aired.Unix(), TitleEN: "Boundary"},
	}}
	send := &fakeSender{}
	w := NewAiringWorker(cal, send, newMemDeduper(), Config{
		Tick: 5 * time.Minute, Window: 10 * time.Minute, DedupTTL: time.Hour,
	})
	w.Clock = fixedClock(now)

	if err := w.Cycle(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := len(send.sent); got != 1 {
		t.Fatalf("expected 1 dispatch across bucket boundary, got %d", got)
	}
	if send.sent[0].topic != "media_42" {
		t.Errorf("expected media_42, got %s", send.sent[0].topic)
	}
	// Sanity: the worker must request an explicit window (not Days-based)
	// so the upstream cache key is stable and the past margin is honoured.
	if cal.lastReq.AiringAtGreater == 0 || cal.lastReq.AiringAtLesser == 0 {
		t.Errorf("worker must use explicit window; got %+v", cal.lastReq)
	}
	if cal.lastReq.AiringAtGreater >= aired.Unix() {
		t.Errorf("airingAtGreater (%d) must be < episode airingAt (%d) so AniList returns it",
			cal.lastReq.AiringAtGreater, aired.Unix())
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
