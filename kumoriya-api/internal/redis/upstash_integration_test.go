//go:build integration

// This suite hits the real Upstash instance. Run with:
//
//	UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=... \
//	  go test -tags=integration ./internal/redis/... -count=1 -v
package redis

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"
)

func newIntegrationClient(t *testing.T) *Client {
	t.Helper()
	url := os.Getenv("UPSTASH_REDIS_REST_URL")
	token := os.Getenv("UPSTASH_REDIS_REST_TOKEN")
	if url == "" || token == "" {
		t.Skip("UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN not set")
	}
	c, err := New(Config{URL: url, Token: token})
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestIntegration_Ping(t *testing.T) {
	c := newIntegrationClient(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := c.Ping(ctx); err != nil {
		t.Fatal(err)
	}
}

func TestIntegration_SetNXWithTTL_FirstCallWinsSecondSkips(t *testing.T) {
	c := newIntegrationClient(t)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	key := fmt.Sprintf("kumoriya:test:dedup:%d", time.Now().UnixNano())
	defer func() { _, _ = c.Del(context.Background(), key) }()

	ok, err := c.SetNXWithTTL(ctx, key, "1", 30*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatalf("first SETNX should have won")
	}

	ok, err = c.SetNXWithTTL(ctx, key, "2", 30*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatalf("second SETNX should have been skipped (key exists)")
	}
}
