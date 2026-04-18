package service

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// newTestJWT returns a JWT service backed by a fresh Ed25519 key pair.
func newTestJWT(t *testing.T) (*JWTService, ed25519.PublicKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("generate ed25519: %v", err)
	}
	return NewJWTService(priv, pub, "https://api.kumoriya.online"), pub
}

func TestIssueSessionProducesVerifiableToken(t *testing.T) {
	jwtSvc, pub := newTestJWT(t)
	sessionSvc := NewPartySessionService(jwtSvc, "watch-party", "wss://party.kumoriya.online", 25)

	userID := uuid.New()
	session, err := sessionSvc.IssueSession(userID, "Alice", "room-abc", PartySessionRoleHost)
	if err != nil {
		t.Fatalf("issue: %v", err)
	}

	if session.RoomID != "room-abc" {
		t.Errorf("roomId mismatch: %s", session.RoomID)
	}
	if session.HeartbeatIntervalSec != 25 {
		t.Errorf("heartbeat mismatch: %d", session.HeartbeatIntervalSec)
	}
	if session.WebsocketURL == "" || session.SessionToken == "" {
		t.Errorf("empty session fields: %+v", session)
	}
	if session.ExpiresAt <= time.Now().Unix() {
		t.Errorf("expiresAt not in the future: %d", session.ExpiresAt)
	}

	// Parse + verify the token.
	parsed, err := jwt.ParseWithClaims(session.SessionToken, &PartySessionClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodEd25519); !ok {
			return nil, jwt.ErrTokenSignatureInvalid
		}
		return pub, nil
	})
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	claims, ok := parsed.Claims.(*PartySessionClaims)
	if !ok || !parsed.Valid {
		t.Fatalf("invalid parsed claims: %+v", parsed)
	}

	if claims.Subject != userID.String() {
		t.Errorf("sub mismatch: %s", claims.Subject)
	}
	if claims.Name != "Alice" {
		t.Errorf("name mismatch: %s", claims.Name)
	}
	if claims.RoomID != "room-abc" {
		t.Errorf("roomId mismatch: %s", claims.RoomID)
	}
	if claims.Role != "host" {
		t.Errorf("role mismatch: %s", claims.Role)
	}
	if claims.SessionID == "" {
		t.Errorf("sessionId empty")
	}
	if len(claims.Audience) != 1 || claims.Audience[0] != "watch-party" {
		t.Errorf("aud mismatch: %+v", claims.Audience)
	}
	if claims.Issuer != "https://api.kumoriya.online" {
		t.Errorf("iss mismatch: %s", claims.Issuer)
	}
}

func TestIssueSessionEmbedsWebsocketURL(t *testing.T) {
	jwtSvc, _ := newTestJWT(t)
	sessionSvc := NewPartySessionService(jwtSvc, "watch-party", "wss://party.example.com", 25)
	session, err := sessionSvc.IssueSession(uuid.New(), "Bob", "room-1", PartySessionRoleMember)
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	want := "wss://party.example.com/ws?token=" + session.SessionToken
	if session.WebsocketURL != want {
		t.Errorf("websocketUrl mismatch:\n got  %q\n want %q", session.WebsocketURL, want)
	}
}

func TestIssueSessionRejectsEmptyRoom(t *testing.T) {
	jwtSvc, _ := newTestJWT(t)
	sessionSvc := NewPartySessionService(jwtSvc, "watch-party", "wss://p.x", 25)
	if _, err := sessionSvc.IssueSession(uuid.New(), "x", "", PartySessionRoleMember); err == nil {
		t.Fatal("expected error for empty roomId")
	}
}

func TestIssueSessionRejectsMissingKey(t *testing.T) {
	unsignedJWT := NewJWTService(nil, nil, "")
	sessionSvc := NewPartySessionService(unsignedJWT, "watch-party", "wss://p.x", 25)
	if _, err := sessionSvc.IssueSession(uuid.New(), "x", "room", PartySessionRoleMember); err == nil {
		t.Fatal("expected error when signing key is missing")
	}
}

func TestIssueSessionDefaultsAudienceAndHeartbeat(t *testing.T) {
	jwtSvc, _ := newTestJWT(t)
	sessionSvc := NewPartySessionService(jwtSvc, "", "wss://p.x", 0)
	session, err := sessionSvc.IssueSession(uuid.New(), "x", "r", PartySessionRoleMember)
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	if session.HeartbeatIntervalSec != 45 {
		t.Errorf("expected default heartbeat 45, got %d", session.HeartbeatIntervalSec)
	}
}
