// Package client implements a minimal GraphQL client for AniList.
//
// It is used by the edge-cache subsystem only: the client is single-purpose,
// intentionally simple, and **must not** be called from hot paths. Every
// call should go through the cache/SWR layer so we respect AniList's
// rate-limit from a single server IP.
package client

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"
)

// DefaultEndpoint is the AniList GraphQL endpoint.
const DefaultEndpoint = "https://graphql.anilist.co"

// DefaultUserAgent identifies Kumoriya server-side traffic so AniList can
// reach us if they need to flag misbehaviour.
const DefaultUserAgent = "KumoriyaEdgeCache/1.0 (+https://kumoriya.online)"

// Client talks to AniList GraphQL.
type Client struct {
	endpoint   string
	userAgent  string
	httpClient *http.Client
}

// Option configures a Client.
type Option func(*Client)

// WithEndpoint overrides the AniList endpoint (tests).
func WithEndpoint(endpoint string) Option {
	return func(c *Client) { c.endpoint = endpoint }
}

// WithHTTPClient overrides the underlying http.Client (tests, custom timeouts).
func WithHTTPClient(h *http.Client) Option {
	return func(c *Client) { c.httpClient = h }
}

// WithUserAgent overrides the User-Agent header.
func WithUserAgent(ua string) Option {
	return func(c *Client) { c.userAgent = ua }
}

// New creates a Client with sensible defaults.
func New(opts ...Option) *Client {
	c := &Client{
		endpoint:  DefaultEndpoint,
		userAgent: DefaultUserAgent,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// ErrRateLimited is returned when AniList responds with HTTP 429.
var ErrRateLimited = errors.New("anilist rate limited")

// GraphQLError mirrors the "errors" entries AniList may return alongside
// a 200 response with a partial/empty data object.
type GraphQLError struct {
	Message string                 `json:"message"`
	Status  int                    `json:"status,omitempty"`
	Extra   map[string]interface{} `json:"-"`
}

func (e GraphQLError) Error() string {
	if e.Status != 0 {
		return fmt.Sprintf("anilist graphql: %s (status %d)", e.Message, e.Status)
	}
	return "anilist graphql: " + e.Message
}

// Response is the envelope AniList returns.
type Response struct {
	Data   json.RawMessage `json:"data"`
	Errors []GraphQLError  `json:"errors,omitempty"`
}

// Execute performs a GraphQL query and returns the raw `data` payload so
// the handler layer can stream it back to clients as-is.
//
// It returns:
//   - ErrRateLimited when AniList responds with 429.
//   - A *GraphQLError wrapper when `errors` is non-empty in a 200 response.
//   - A generic error for transport/decoding issues.
func (c *Client) Execute(ctx context.Context, query string, variables map[string]interface{}) (json.RawMessage, error) {
	body := map[string]interface{}{
		"query":     query,
		"variables": variables,
	}
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("encode graphql body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.endpoint, bytes.NewReader(buf))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", c.userAgent)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("anilist http: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read anilist body: %w", err)
	}

	if resp.StatusCode == http.StatusTooManyRequests {
		return nil, ErrRateLimited
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("anilist http status %d: %s", resp.StatusCode, truncate(string(raw), 256))
	}

	var env Response
	if err := json.Unmarshal(raw, &env); err != nil {
		return nil, fmt.Errorf("decode anilist response: %w", err)
	}
	if len(env.Errors) > 0 {
		// Surface the first error; callers rarely need the full list for
		// our cache use case.
		return env.Data, env.Errors[0]
	}
	if len(env.Data) == 0 {
		return nil, errors.New("anilist returned empty data")
	}
	return env.Data, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
