package cache

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestSWR_ColdMiss_CallsLoaderAndCaches(t *testing.T) {
	c := New(Config{Fresh: 1 * time.Second, Stale: 1 * time.Second})
	var calls int32
	loader := func(ctx context.Context) (json.RawMessage, error) {
		atomic.AddInt32(&calls, 1)
		return json.RawMessage(`{"ok":true}`), nil
	}

	res, err := c.Get(context.Background(), "k", loader)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.FromAge {
		t.Errorf("expected FromAge=false on cold miss, got true")
	}
	if string(res.Data) != `{"ok":true}` {
		t.Errorf("unexpected payload: %s", res.Data)
	}

	// Second call should be a fresh hit — no extra loader invocation.
	if _, err := c.Get(context.Background(), "k", loader); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got := atomic.LoadInt32(&calls); got != 1 {
		t.Errorf("expected loader called once, got %d", got)
	}
}

func TestSWR_StaleHit_ServesImmediatelyAndRefreshesInBackground(t *testing.T) {
	c := New(Config{Fresh: 10 * time.Millisecond, Stale: 1 * time.Second})

	var calls int32
	var mu sync.Mutex
	payloads := []string{`{"v":1}`, `{"v":2}`}
	loader := func(ctx context.Context) (json.RawMessage, error) {
		i := atomic.AddInt32(&calls, 1) - 1
		mu.Lock()
		defer mu.Unlock()
		if int(i) >= len(payloads) {
			return json.RawMessage(payloads[len(payloads)-1]), nil
		}
		return json.RawMessage(payloads[i]), nil
	}

	// Cold miss — get v=1.
	if _, err := c.Get(context.Background(), "k", loader); err != nil {
		t.Fatal(err)
	}
	// Wait past Fresh so the next Get enters the stale branch.
	time.Sleep(30 * time.Millisecond)

	res, err := c.Get(context.Background(), "k", loader)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Stale {
		t.Errorf("expected stale=true, got false")
	}
	if string(res.Data) != `{"v":1}` {
		t.Errorf("expected stale payload v=1, got %s", res.Data)
	}

	// Allow the async refresh to complete.
	deadline := time.Now().Add(500 * time.Millisecond)
	for time.Now().Before(deadline) {
		if atomic.LoadInt32(&calls) >= 2 {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	if got := atomic.LoadInt32(&calls); got < 2 {
		t.Fatalf("expected background refresh to run; loader calls=%d", got)
	}

	// Next Get (still within fresh of the refreshed entry) returns v=2.
	res, err = c.Get(context.Background(), "k", loader)
	if err != nil {
		t.Fatal(err)
	}
	if string(res.Data) != `{"v":2}` {
		t.Errorf("expected refreshed payload v=2, got %s", res.Data)
	}
}

func TestSWR_ExpiredEntry_LoaderFailure_FallsBackToStalePayload(t *testing.T) {
	c := New(Config{Fresh: 1 * time.Millisecond, Stale: 1 * time.Millisecond})

	var calls int32
	loader := func(ctx context.Context) (json.RawMessage, error) {
		n := atomic.AddInt32(&calls, 1)
		if n == 1 {
			return json.RawMessage(`{"v":1}`), nil
		}
		return nil, errors.New("boom")
	}

	if _, err := c.Get(context.Background(), "k", loader); err != nil {
		t.Fatal(err)
	}

	// Age the entry past Fresh+Stale.
	time.Sleep(10 * time.Millisecond)

	res, err := c.Get(context.Background(), "k", loader)
	if err != nil {
		t.Fatalf("expected no error (fallback to stale payload), got %v", err)
	}
	if string(res.Data) != `{"v":1}` {
		t.Errorf("expected fallback to v=1, got %s", res.Data)
	}
	if !res.Stale {
		t.Errorf("expected stale=true on fallback, got false")
	}
}

func TestSWR_ColdMiss_LoaderFailure_PropagatesError(t *testing.T) {
	c := New(Config{Fresh: 1 * time.Second, Stale: 1 * time.Second})
	loader := func(ctx context.Context) (json.RawMessage, error) {
		return nil, errors.New("down")
	}
	_, err := c.Get(context.Background(), "k", loader)
	if err == nil {
		t.Fatalf("expected error on cold miss failure, got nil")
	}
}

func TestSWR_SingleFlight_OnStaleRefresh(t *testing.T) {
	c := New(Config{Fresh: 1 * time.Millisecond, Stale: 1 * time.Second})

	var calls int32
	loader := func(ctx context.Context) (json.RawMessage, error) {
		atomic.AddInt32(&calls, 1)
		time.Sleep(30 * time.Millisecond)
		return json.RawMessage(`{"v":1}`), nil
	}

	// Cold prime.
	if _, err := c.Get(context.Background(), "k", loader); err != nil {
		t.Fatal(err)
	}
	time.Sleep(5 * time.Millisecond) // past Fresh

	// Fire many concurrent stale reads; only one refresh should be in flight.
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, _ = c.Get(context.Background(), "k", loader)
		}()
	}
	wg.Wait()

	// Cold-prime + (exactly one) background refresh.
	time.Sleep(100 * time.Millisecond)
	if got := atomic.LoadInt32(&calls); got != 2 {
		t.Errorf("expected 2 loader calls (cold + 1 refresh), got %d", got)
	}
}
