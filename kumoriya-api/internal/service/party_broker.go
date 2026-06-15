package service

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

// PartyBrokerClient is the HTTP client kumoriya-api uses to talk to the
// Party Realtime Worker (party.kumoriya.online) over its `/internal/v1/*`
// surface. The Worker is the authoritative store for room membership and
// playback; the REST API acts purely as a broker.
type PartyBrokerClient struct {
	baseURL       string // e.g. https://party.kumoriya.online
	internalToken string
	httpClient    *http.Client
	// maxRetries is the number of additional attempts (not counting the first
	// call) for idempotent requests. Non-idempotent requests (POST) are
	// retried only for transport errors and 5xx responses.
	maxRetries int
}

// NewPartyBrokerClient constructs a broker client with sensible defaults
// (10 s total timeout, 1 retry with exponential backoff).
func NewPartyBrokerClient(baseURL, internalToken string) *PartyBrokerClient {
	return &PartyBrokerClient{
		baseURL:       strings.TrimRight(baseURL, "/"),
		internalToken: internalToken,
		httpClient:    &http.Client{Timeout: 10 * time.Second},
		maxRetries:    1,
	}
}

// WithHTTPClient swaps out the http client (useful for tests).
func (c *PartyBrokerClient) WithHTTPClient(hc *http.Client) *PartyBrokerClient {
	c.httpClient = hc
	return c
}

// ── Request / response DTOs (internal to the Worker) ─────────────────────────

type BrokerMediaState struct {
	AnilistID     int     `json:"anilistId"`
	AnimeTitle    string  `json:"animeTitle"`
	EpisodeNumber float64 `json:"episodeNumber"`
}

type brokerCreateRoomRequest struct {
	UserID string           `json:"userId"`
	Name   string           `json:"name"`
	Media  BrokerMediaState `json:"media"`
}

type brokerCreateRoomResponse struct {
	RoomID     string `json:"roomId"`
	InviteCode string `json:"inviteCode"`
}

type brokerResolveInviteResponse struct {
	RoomID string `json:"roomId"`
}

type brokerJoinLeaveRequest struct {
	UserID string `json:"userId"`
	Name   string `json:"name,omitempty"`
}

type brokerMemberVerifyRequest struct {
	UserID string `json:"userId"`
}

type brokerMemberVerifyResponse struct {
	IsMember bool `json:"isMember"`
}

// BrokerError is returned by the broker client when the Worker responds
// with a non-2xx status. It preserves the code/message/retryable triple.
type BrokerError struct {
	Status    int    `json:"-"`
	Code      string `json:"code"`
	Message   string `json:"message"`
	Retryable bool   `json:"retryable"`
}

func (e *BrokerError) Error() string {
	return fmt.Sprintf("party broker: %s (%d): %s", e.Code, e.Status, e.Message)
}

// Common sentinel errors for handler-level classification.
var (
	ErrBrokerRoomNotFound      = &BrokerError{Status: 404, Code: "room_not_found", Message: "room not found"}
	ErrBrokerRoomFull          = &BrokerError{Status: 409, Code: "room_full", Message: "room is full"}
	ErrBrokerInvalidInvite     = &BrokerError{Status: 404, Code: "invalid_invite_code", Message: "invalid invite code"}
	ErrBrokerUserInAnotherRoom = &BrokerError{Status: 409, Code: "user_already_in_room", Message: "user is already in another room"}
)

// ── Public methods ───────────────────────────────────────────────────────────

// CreateRoom asks the Worker to create a new room. Returns roomId + inviteCode.
func (c *PartyBrokerClient) CreateRoom(ctx context.Context, userID, name string, media BrokerMediaState) (string, string, error) {
	body := brokerCreateRoomRequest{UserID: userID, Name: name, Media: media}
	var resp brokerCreateRoomResponse
	if err := c.do(ctx, http.MethodPost, "/internal/v1/rooms", body, &resp); err != nil {
		return "", "", err
	}
	return resp.RoomID, resp.InviteCode, nil
}

// ResolveInviteCode maps an invite code to a roomId via the registry.
func (c *PartyBrokerClient) ResolveInviteCode(ctx context.Context, code string) (string, error) {
	var resp brokerResolveInviteResponse
	path := "/internal/v1/invite/" + code
	if err := c.do(ctx, http.MethodGet, path, nil, &resp); err != nil {
		return "", err
	}
	return resp.RoomID, nil
}

// JoinRoom adds a user to a room.
func (c *PartyBrokerClient) JoinRoom(ctx context.Context, roomID, userID, name string) error {
	body := brokerJoinLeaveRequest{UserID: userID, Name: name}
	path := "/internal/v1/rooms/" + roomID + "/join"
	return c.do(ctx, http.MethodPost, path, body, nil)
}

// LeaveRoom removes a user from a room.
func (c *PartyBrokerClient) LeaveRoom(ctx context.Context, roomID, userID string) error {
	body := brokerJoinLeaveRequest{UserID: userID}
	path := "/internal/v1/rooms/" + roomID + "/leave"
	return c.do(ctx, http.MethodPost, path, body, nil)
}

// ForceLeave forces a user out of their current room (recovery mechanism).
func (c *PartyBrokerClient) ForceLeave(ctx context.Context, userID string) error {
	path := "/internal/v1/users/" + userID + "/force-leave"
	return c.do(ctx, http.MethodPost, path, nil, nil)
}

// VerifyMember reports whether a user is still a member (or within grace).
func (c *PartyBrokerClient) VerifyMember(ctx context.Context, roomID, userID string) (bool, error) {
	body := brokerMemberVerifyRequest{UserID: userID}
	var resp brokerMemberVerifyResponse
	path := "/internal/v1/rooms/" + roomID + "/member-verify"
	if err := c.do(ctx, http.MethodPost, path, body, &resp); err != nil {
		return false, err
	}
	return resp.IsMember, nil
}

// ── Internal request plumbing ────────────────────────────────────────────────

func (c *PartyBrokerClient) do(ctx context.Context, method, path string, body, out any) error {
	var lastErr error
	for attempt := 0; attempt <= c.maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff: 250ms, 500ms, 1000ms, ...
			wait := time.Duration(250*(1<<(attempt-1))) * time.Millisecond
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(wait):
			}
		}
		err := c.attempt(ctx, method, path, body, out)
		if err == nil {
			return nil
		}
		lastErr = err

		// Only retry on transient errors: context-less transport failures or 5xx.
		var berr *BrokerError
		if errors.As(err, &berr) {
			if berr.Status < 500 {
				return err
			}
		}
	}
	return lastErr
}

func (c *PartyBrokerClient) attempt(ctx context.Context, method, path string, body, out any) error {
	url := c.baseURL + path

	var reqBody io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("marshal request: %w", err)
		}
		reqBody = bytes.NewReader(buf)
	}

	req, err := http.NewRequestWithContext(ctx, method, url, reqBody)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.internalToken)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("party broker call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		if out == nil {
			return nil
		}
		if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
			return fmt.Errorf("decode response: %w", err)
		}
		return nil
	}

	// Non-2xx — try to parse a structured error.
	raw, _ := io.ReadAll(resp.Body)
	be := &BrokerError{Status: resp.StatusCode}
	if err := json.Unmarshal(raw, be); err != nil || be.Code == "" {
		be.Code = fmt.Sprintf("http_%d", resp.StatusCode)
		be.Message = string(raw)
	}
	return be
}
