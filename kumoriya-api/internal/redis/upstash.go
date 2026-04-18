// Package redis provides a minimal Upstash Redis REST client.
//
// We only need a tiny subset of Redis for notification dedup:
//
//   - SET key value NX EX <ttl>   → returns whether the key was newly set.
//
// Using the REST protocol avoids a new TCP dependency, works identically
// from Cloudflare Workers if we ever need cross-runtime sharing, and
// latency (~100ms per call) is irrelevant for our volume (a handful of
// calls per airing cycle).
package redis

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Client is a minimal Upstash Redis REST client.
type Client struct {
	baseURL string
	token   string
	http    *http.Client
}

// Config holds connection parameters.
type Config struct {
	// URL is the Upstash REST base URL, e.g. https://<name>.upstash.io.
	URL string
	// Token is the Upstash REST token.
	Token string
	// HTTPClient is optional; defaults to a 10s-timeout client.
	HTTPClient *http.Client
}

// New builds a Client.
func New(cfg Config) (*Client, error) {
	url := strings.TrimRight(strings.TrimSpace(cfg.URL), "/")
	token := strings.TrimSpace(cfg.Token)
	if url == "" || token == "" {
		return nil, errors.New("redis: URL and Token are required")
	}
	hc := cfg.HTTPClient
	if hc == nil {
		hc = &http.Client{Timeout: 10 * time.Second}
	}
	return &Client{baseURL: url, token: token, http: hc}, nil
}

// Ping verifies that the configured credentials work.
func (c *Client) Ping(ctx context.Context) error {
	var out struct {
		Result string `json:"result"`
	}
	if err := c.call(ctx, []string{"PING"}, &out); err != nil {
		return err
	}
	if !strings.EqualFold(out.Result, "PONG") {
		return fmt.Errorf("redis ping: unexpected result %q", out.Result)
	}
	return nil
}

// SetNXWithTTL atomically sets key only if it does not already exist,
// with the given TTL. Returns true if the key was newly created.
//
// This is the primitive used by the notifications dedup: the first
// scheduler tick to notify a given (media, episode) wins, subsequent
// restarts within the TTL window skip re-notifying.
func (c *Client) SetNXWithTTL(ctx context.Context, key, value string, ttl time.Duration) (bool, error) {
	if ttl <= 0 {
		return false, errors.New("redis: ttl must be positive")
	}
	seconds := int64(ttl / time.Second)
	if seconds <= 0 {
		seconds = 1
	}
	var out struct {
		// Upstash returns `result: "OK"` on success, `result: null` when
		// NX failed (key already exists). Using *string lets us tell apart.
		Result *string `json:"result"`
	}
	args := []string{"SET", key, value, "EX", fmt.Sprintf("%d", seconds), "NX"}
	if err := c.call(ctx, args, &out); err != nil {
		return false, err
	}
	return out.Result != nil && strings.EqualFold(*out.Result, "OK"), nil
}

// Del removes a key. Returns true if the key existed.
func (c *Client) Del(ctx context.Context, key string) (bool, error) {
	var out struct {
		Result int `json:"result"`
	}
	if err := c.call(ctx, []string{"DEL", key}, &out); err != nil {
		return false, err
	}
	return out.Result > 0, nil
}

// call posts the command to the Upstash pipeline endpoint.
//
// Upstash accepts commands as an array of strings on POST /<cmd>/<arg>...
// but the POST-JSON form below is more robust to special characters in
// values and mirrors the official SDK's wire format.
func (c *Client) call(ctx context.Context, args []string, out interface{}) error {
	body, err := json.Marshal(args)
	if err != nil {
		return fmt.Errorf("redis encode: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("redis request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("redis http: %w", err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("redis read: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("redis http %d: %s", resp.StatusCode, truncate(string(raw), 256))
	}
	// Upstash sometimes returns a top-level `error` field instead of HTTP 4xx.
	var envelope struct {
		Error string `json:"error"`
	}
	_ = json.Unmarshal(raw, &envelope)
	if envelope.Error != "" {
		return fmt.Errorf("redis error: %s", envelope.Error)
	}
	if out == nil {
		return nil
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return fmt.Errorf("redis decode: %w (raw=%s)", err, truncate(string(raw), 256))
	}
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
