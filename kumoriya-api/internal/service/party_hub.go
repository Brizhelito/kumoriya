package service

import (
	"encoding/json"
	"sync"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/model"
)

// Conn abstracts a WebSocket connection.
type Conn interface {
	WriteJSON(v any) error
	Close() error
}

// signalClient is a connected peer in the signaling phase.
type signalClient struct {
	userID uuid.UUID
	name   string
	roomID string
	conn   Conn
	send   chan []byte
}

// SignalRelay is a lightweight hub that only forwards WebRTC
// signaling messages (SDP offers/answers, ICE candidates) between
// peers in the same room. It does NOT carry sync/reaction/chat —
// those go over the P2P DataChannels once established.
//
// Deprecated: the watch-party realtime v2 flow brokers state through
// party.kumoriya.online and does not use this relay. Leave in place
// while WATCH_PARTY_REALTIME_V2 can be flipped off for rollback.
// See docs/80-deferred-work.md for the removal plan.
type SignalRelay struct {
	mu    sync.RWMutex
	rooms map[string]map[uuid.UUID]*signalClient // roomID → userID → client
}

func NewSignalRelay() *SignalRelay {
	return &SignalRelay{rooms: make(map[string]map[uuid.UUID]*signalClient)}
}

// Register adds a peer and starts its write pump.
func (sr *SignalRelay) Register(roomID string, userID uuid.UUID, name string, conn Conn) {
	sr.mu.Lock()
	defer sr.mu.Unlock()

	if _, ok := sr.rooms[roomID]; !ok {
		sr.rooms[roomID] = make(map[uuid.UUID]*signalClient)
	}

	c := &signalClient{
		userID: userID,
		name:   name,
		roomID: roomID,
		conn:   conn,
		send:   make(chan []byte, 32),
	}
	sr.rooms[roomID][userID] = c
	go sr.writePump(c)

	log.Info().Str("room", roomID).Str("user", name).Int("totalPeers", len(sr.rooms[roomID])).Msg("signal peer registered")
}

// Unregister removes a peer.
func (sr *SignalRelay) Unregister(roomID string, userID uuid.UUID) {
	sr.mu.Lock()
	defer sr.mu.Unlock()

	if clients, ok := sr.rooms[roomID]; ok {
		if c, exists := clients[userID]; exists {
			close(c.send)
			delete(clients, userID)
		}
		if len(clients) == 0 {
			delete(sr.rooms, roomID)
		}
	}
}

// BroadcastToRoom sends a SignalMessage to every peer in a room.
func (sr *SignalRelay) BroadcastToRoom(roomID string, msg model.SignalMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	sr.mu.RLock()
	defer sr.mu.RUnlock()

	for _, c := range sr.rooms[roomID] {
		select {
		case c.send <- data:
		default:
		}
	}
}

// BroadcastExcept sends to all peers in a room except one.
func (sr *SignalRelay) BroadcastExcept(roomID string, excludeUID uuid.UUID, msg model.SignalMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	sr.mu.RLock()
	defer sr.mu.RUnlock()

	for uid, c := range sr.rooms[roomID] {
		if uid == excludeUID {
			continue
		}
		select {
		case c.send <- data:
		default:
		}
	}
}

// SendTo sends a message to a specific peer.
func (sr *SignalRelay) SendTo(roomID string, userID uuid.UUID, msg model.SignalMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	sr.mu.RLock()
	defer sr.mu.RUnlock()

	if clients, ok := sr.rooms[roomID]; ok {
		if c, exists := clients[userID]; exists {
			select {
			case c.send <- data:
			default:
			}
		}
	}
}

// RelaySignal routes an incoming signaling message to the target peer
// or broadcasts to room for lifecycle events.
func (sr *SignalRelay) RelaySignal(roomID string, fromUID uuid.UUID, raw []byte) {
	var msg model.SignalMessage
	if err := json.Unmarshal(raw, &msg); err != nil {
		log.Warn().Err(err).Msg("signal: invalid message")
		return
	}

	// Stamp sender.
	msg.From = fromUID.String()

	switch msg.Type {
	case model.SignalOffer, model.SignalAnswer, model.SignalCandidate:
		// P2P signaling — relay to specific target.
		if msg.To == "" {
			log.Warn().Str("type", string(msg.Type)).Msg("signal: missing target")
			return // must have a target
		}
		targetUID, err := uuid.Parse(msg.To)
		if err != nil {
			log.Warn().Str("to", msg.To).Msg("signal: invalid target UUID")
			return
		}
		log.Debug().Str("type", string(msg.Type)).Str("from", fromUID.String()).Str("to", msg.To).Msg("signal: relaying")
		sr.SendTo(roomID, targetUID, msg)

	default:
		log.Warn().Str("type", string(msg.Type)).Msg("signal: unknown client message type")
	}
}

// PeerList returns the list of userIDs currently connected to a room,
// excluding the requesting peer (so the new joiner doesn't see itself).
func (sr *SignalRelay) PeerList(roomID string, excludeUID uuid.UUID) []string {
	sr.mu.RLock()
	defer sr.mu.RUnlock()

	var ids []string
	for uid := range sr.rooms[roomID] {
		if uid == excludeUID {
			continue
		}
		ids = append(ids, uid.String())
	}
	return ids
}

func (sr *SignalRelay) writePump(c *signalClient) {
	for data := range c.send {
		if err := c.conn.WriteJSON(json.RawMessage(data)); err != nil {
			log.Warn().Err(err).Str("user", c.name).Str("room", c.roomID).Msg("signal write error — closing peer connection")
			return
		}
	}
	log.Debug().Str("user", c.name).Str("room", c.roomID).Msg("signal writePump: send channel closed")
}
