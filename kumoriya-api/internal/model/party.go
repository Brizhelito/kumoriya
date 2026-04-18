package model

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// ── Room (lightweight metadata for REST) ──

type PartyRole string

const (
	PartyRoleHost   PartyRole = "host"
	PartyRoleMember PartyRole = "member"
)

type PartyMember struct {
	UserID      uuid.UUID `json:"userId"`
	DisplayName string    `json:"displayName"`
	AvatarURL   *string   `json:"avatarUrl,omitempty"`
	Role        PartyRole `json:"role"`
	JoinedAt    time.Time `json:"joinedAt"`
}

type PartyRoom struct {
	ID            string        `json:"id"`
	HostID        uuid.UUID     `json:"hostId"`
	Members       []PartyMember `json:"members"`
	AnilistID     int           `json:"anilistId"`
	AnimeTitle    string        `json:"animeTitle"`
	EpisodeNumber float64       `json:"episodeNumber"`
	MaxMembers    int           `json:"maxMembers"`
	InviteCode    string        `json:"inviteCode"`
	CreatedAt     time.Time     `json:"createdAt"`
}

// ── REST Request/Response ──

type CreatePartyRequest struct {
	AnilistID     int     `json:"anilistId"`
	AnimeTitle    string  `json:"animeTitle"`
	EpisodeNumber float64 `json:"episodeNumber"`
	MaxMembers    int     `json:"maxMembers"`
}

type JoinPartyRequest struct {
	InviteCode string `json:"inviteCode"`
}

type UpdatePartyRequest struct {
	AnilistID     *int     `json:"anilistId,omitempty"`
	AnimeTitle    *string  `json:"animeTitle,omitempty"`
	EpisodeNumber *float64 `json:"episodeNumber,omitempty"`
}

type PartyRoomResponse struct {
	Room PartyRoom `json:"room"`
}

// ── Watch Party Realtime v2 DTOs ──
//
// The v2 surface brokers room state to the dedicated realtime Worker
// at `party.kumoriya.online`. The REST API emits a short-lived session
// token (Ed25519 JWT, aud=watch-party) that the client presents to
// `wss://.../ws?token=...`.

type PartyRealtimeSession struct {
	RoomID               string `json:"roomId"`
	WebsocketURL         string `json:"websocketUrl"`
	SessionToken         string `json:"sessionToken"`
	ExpiresAt            int64  `json:"expiresAt"`
	HeartbeatIntervalSec int    `json:"heartbeatIntervalSec"`
}

// PartyRoomResponseV2 is the new shape returned by create/join/me/invite
// when WATCH_PARTY_REALTIME_V2 is enabled. It contains the room metadata
// and the realtime session information in one envelope.
type PartyRoomResponseV2 struct {
	Room            PartyRoom             `json:"room"`
	RealtimeSession *PartyRealtimeSession `json:"realtimeSession,omitempty"`
}

// PartySessionRefreshRequest is the body for POST /api/v1/party/session/refresh.
type PartySessionRefreshRequest struct {
	RoomID string `json:"roomId"`
}

// PartySessionRefreshResponse is the response for a successful session refresh.
type PartySessionRefreshResponse struct {
	Session PartyRealtimeSession `json:"session"`
}

// ── Signaling WebSocket Messages ──
//
// The WS is ephemeral — it only relays WebRTC signaling (SDP + ICE)
// between peers during connection setup. Once the P2P DataChannels
// are established the clients close the WS. All real-time traffic
// (sync, reactions, chat, voice) flows over WebRTC.

type SignalType string

const (
	// Client → Server (relayed to target peer)
	SignalOffer     SignalType = "offer"     // SDP offer
	SignalAnswer    SignalType = "answer"    // SDP answer
	SignalCandidate SignalType = "candidate" // ICE candidate

	// Server → Client (room lifecycle)
	SignalPeerJoined SignalType = "peer_joined"
	SignalPeerLeft   SignalType = "peer_left"
	SignalRoomState  SignalType = "room_state"
	SignalError      SignalType = "error"
)

// SignalMessage is the envelope for all signaling WS messages.
type SignalMessage struct {
	Type    SignalType      `json:"type"`
	From    string          `json:"from,omitempty"`    // sender userId (set by server)
	To      string          `json:"to,omitempty"`      // target userId (for offer/answer/candidate)
	Payload json.RawMessage `json:"payload,omitempty"` // SDP or ICE candidate JSON
}

// SignalPeerPayload identifies a peer in room-lifecycle events.
type SignalPeerPayload struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	AvatarURL   string `json:"avatarUrl,omitempty"`
}

// SignalErrorPayload carries error descriptions.
type SignalErrorPayload struct {
	Message string `json:"message"`
}
