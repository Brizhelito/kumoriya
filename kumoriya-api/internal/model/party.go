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
