package service

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// fakeBrokerServer returns an httptest server that records requests and
// responds according to the route table provided.
func fakeBrokerServer(t *testing.T, wantToken string, handler func(w http.ResponseWriter, r *http.Request)) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer "+wantToken {
			t.Errorf("missing/invalid Authorization header: got %q", got)
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		handler(w, r)
	}))
}

func TestBrokerCreateRoomSuccess(t *testing.T) {
	srv := fakeBrokerServer(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/internal/v1/rooms" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		var body brokerCreateRoomRequest
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode body: %v", err)
		}
		if body.UserID != "user-1" || body.Name != "Alice" || body.Media.AnilistID != 42 {
			t.Errorf("unexpected body: %+v", body)
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(brokerCreateRoomResponse{RoomID: "room-1", InviteCode: "ABCDEF"})
	})
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	roomID, code, err := c.CreateRoom(context.Background(), "user-1", "Alice", BrokerMediaState{
		AnilistID: 42, AnimeTitle: "Test", EpisodeNumber: 1,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if roomID != "room-1" || code != "ABCDEF" {
		t.Fatalf("unexpected response: %s %s", roomID, code)
	}
}

func TestBrokerResolveInviteCode(t *testing.T) {
	srv := fakeBrokerServer(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/internal/v1/invite/ABCDEF" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(brokerResolveInviteResponse{RoomID: "room-9"})
	})
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	id, err := c.ResolveInviteCode(context.Background(), "ABCDEF")
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	if id != "room-9" {
		t.Fatalf("unexpected id: %s", id)
	}
}

func TestBrokerJoinAndLeaveRoom(t *testing.T) {
	var gotJoin, gotLeave bool
	srv := fakeBrokerServer(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/internal/v1/rooms/room-1/join":
			gotJoin = true
			var body brokerJoinLeaveRequest
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Fatalf("decode: %v", err)
			}
			if body.UserID != "user-2" || body.Name != "Bob" {
				t.Errorf("unexpected body: %+v", body)
			}
			_ = json.NewEncoder(w).Encode(map[string]bool{"success": true})
		case r.Method == http.MethodPost && r.URL.Path == "/internal/v1/rooms/room-1/leave":
			gotLeave = true
			_ = json.NewEncoder(w).Encode(map[string]bool{"success": true})
		default:
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
			http.NotFound(w, r)
		}
	})
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	if err := c.JoinRoom(context.Background(), "room-1", "user-2", "Bob"); err != nil {
		t.Fatalf("join err: %v", err)
	}
	if err := c.LeaveRoom(context.Background(), "room-1", "user-2"); err != nil {
		t.Fatalf("leave err: %v", err)
	}
	if !gotJoin || !gotLeave {
		t.Fatalf("missing calls: join=%v leave=%v", gotJoin, gotLeave)
	}
}

func TestBrokerVerifyMember(t *testing.T) {
	srv := fakeBrokerServer(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/internal/v1/rooms/room-1/member-verify" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		_ = json.NewEncoder(w).Encode(brokerMemberVerifyResponse{IsMember: true})
	})
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	ok, err := c.VerifyMember(context.Background(), "room-1", "user-2")
	if err != nil || !ok {
		t.Fatalf("unexpected: ok=%v err=%v", ok, err)
	}
}

func TestBrokerPropagatesStructuredError(t *testing.T) {
	srv := fakeBrokerServer(t, "secret", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict)
		_ = json.NewEncoder(w).Encode(BrokerError{
			Code: "user_already_in_room", Message: "already in another room", Retryable: false,
		})
	})
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	_, _, err := c.CreateRoom(context.Background(), "u", "n", BrokerMediaState{AnilistID: 1, AnimeTitle: "x"})
	if err == nil {
		t.Fatal("expected error")
	}
	var be *BrokerError
	if !errors.As(err, &be) {
		t.Fatalf("expected *BrokerError, got %T", err)
	}
	if be.Status != http.StatusConflict || be.Code != "user_already_in_room" {
		t.Fatalf("unexpected: %+v", be)
	}
}

func TestBrokerRetriesOn5xxThenSucceeds(t *testing.T) {
	var calls int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); !strings.HasPrefix(got, "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		calls++
		if calls == 1 {
			http.Error(w, "boom", http.StatusBadGateway)
			return
		}
		_ = json.NewEncoder(w).Encode(brokerCreateRoomResponse{RoomID: "room-x", InviteCode: "YYYYYY"})
	}))
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	roomID, _, err := c.CreateRoom(context.Background(), "u", "n", BrokerMediaState{AnilistID: 1, AnimeTitle: "x"})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if roomID != "room-x" {
		t.Fatalf("unexpected room: %s", roomID)
	}
	if calls != 2 {
		t.Fatalf("expected 2 calls (retry), got %d", calls)
	}
}

func TestBrokerDoesNotRetryOn4xx(t *testing.T) {
	var calls int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		http.Error(w, `{"code":"invalid_invite_code","message":"bad","retryable":false}`, http.StatusNotFound)
	}))
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "secret")
	_, err := c.ResolveInviteCode(context.Background(), "NOPE")
	if err == nil {
		t.Fatal("expected err")
	}
	if calls != 1 {
		t.Fatalf("expected exactly 1 call, got %d", calls)
	}
}

func TestBrokerFailsWithoutInternalToken(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") == "" {
			http.Error(w, "no auth", http.StatusUnauthorized)
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()

	c := NewPartyBrokerClient(srv.URL, "")
	if _, err := c.ResolveInviteCode(context.Background(), "x"); err == nil {
		t.Fatal("expected auth error")
	}
}
