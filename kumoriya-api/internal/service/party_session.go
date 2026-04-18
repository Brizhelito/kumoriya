package service

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
)

// PartySessionTokenDuration is the lifetime of a short-lived session token
// that the client presents when opening the WebSocket. The token must be
// long enough to survive reconnection bursts but short enough that stolen
// tickets cannot be replayed for long.
const PartySessionTokenDuration = 60 * time.Minute

// PartySessionRole mirrors the Worker's expected role values.
type PartySessionRole string

const (
	PartySessionRoleHost   PartySessionRole = "host"
	PartySessionRoleMember PartySessionRole = "member"
)

// PartySessionClaims describes the Ed25519 JWT signed by the API and
// validated by the Worker before upgrading a WebSocket. The structure
// matches `SessionClaims` on the Worker side.
type PartySessionClaims struct {
	jwt.RegisteredClaims
	Name      string `json:"name"`
	RoomID    string `json:"roomId"`
	Role      string `json:"role"`
	SessionID string `json:"sessionId"`
}

// PartySessionService issues short-lived Ed25519 session tickets for the
// Party Realtime Worker. It re-uses the existing JWT signing key so there
// is a single Ed25519 key pair shared between access tokens and session
// tokens, with separate `aud` claims to distinguish them.
type PartySessionService struct {
	jwt              *JWTService
	audience         string
	websocketBaseURL string // e.g. wss://party.kumoriya.online
	heartbeatSec     int
}

// NewPartySessionService constructs a session token issuer. `websocketBaseURL`
// MUST include the scheme and host but no path; the final URL will be
// `${websocketBaseURL}/ws?token=${token}`.
func NewPartySessionService(
	jwtSvc *JWTService,
	audience string,
	websocketBaseURL string,
	heartbeatSec int,
) *PartySessionService {
	if audience == "" {
		audience = "watch-party"
	}
	if heartbeatSec <= 0 {
		// Kept intentionally high (45s). The Worker uses
		// setWebSocketAutoResponse for heartbeats so these frames are
		// served without waking the Durable Object. A longer interval
		// still halves the residual cost (handshake, legacy clients)
		// without impacting liveness — Cloudflare keeps the underlying
		// TCP connection healthy with its own keepalive.
		heartbeatSec = 45
	}
	return &PartySessionService{
		jwt:              jwtSvc,
		audience:         audience,
		websocketBaseURL: websocketBaseURL,
		heartbeatSec:     heartbeatSec,
	}
}

// IssueSession creates a PartyRealtimeSession DTO ready to be embedded in
// the REST response. The token is signed by the API's Ed25519 key and the
// websocketUrl is built from the configured base URL.
func (s *PartySessionService) IssueSession(
	userID uuid.UUID,
	displayName string,
	roomID string,
	role PartySessionRole,
) (model.PartyRealtimeSession, error) {
	if s.jwt == nil || s.jwt.privateKey == nil {
		return model.PartyRealtimeSession{}, fmt.Errorf("party session service: signing key not configured")
	}
	if roomID == "" {
		return model.PartyRealtimeSession{}, fmt.Errorf("party session service: roomId is required")
	}

	now := time.Now().UTC()
	exp := now.Add(PartySessionTokenDuration)
	sessionID := uuid.NewString()

	claims := PartySessionClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			Issuer:    s.jwt.issuer,
			Audience:  jwt.ClaimStrings{s.audience},
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(exp),
		},
		Name:      displayName,
		RoomID:    roomID,
		Role:      string(role),
		SessionID: sessionID,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	signed, err := token.SignedString(s.jwt.privateKey)
	if err != nil {
		return model.PartyRealtimeSession{}, fmt.Errorf("party session service: sign: %w", err)
	}

	return model.PartyRealtimeSession{
		RoomID:               roomID,
		WebsocketURL:         s.websocketBaseURL + "/ws?token=" + signed,
		SessionToken:         signed,
		ExpiresAt:            exp.Unix(),
		HeartbeatIntervalSec: s.heartbeatSec,
	}, nil
}
