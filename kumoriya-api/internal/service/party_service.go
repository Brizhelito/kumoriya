package service

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/model"
)

const (
	maxRooms          = 200
	roomTTL           = 4 * time.Hour
	defaultMaxMembers = 4
	inviteCodeLen     = 6 // hex chars → 3 random bytes
)

// PartyService manages ephemeral watch-party rooms in memory.
// It does NOT store playback state — that lives on the P2P mesh.
type PartyService struct {
	mu    sync.RWMutex
	rooms map[string]*model.PartyRoom // roomID → room
	codes map[string]string           // inviteCode → roomID
	users map[uuid.UUID]string        // userID → roomID (one room per user)
}

func NewPartyService() *PartyService {
	ps := &PartyService{
		rooms: make(map[string]*model.PartyRoom),
		codes: make(map[string]string),
		users: make(map[uuid.UUID]string),
	}
	go ps.cleanupLoop()
	return ps
}

// ── Room CRUD ──

func (ps *PartyService) CreateRoom(hostID uuid.UUID, hostName string, avatarURL *string, req model.CreatePartyRequest) (*model.PartyRoom, error) {
	ps.mu.Lock()
	defer ps.mu.Unlock()

	if _, ok := ps.users[hostID]; ok {
		return nil, fmt.Errorf("already in a room")
	}
	if len(ps.rooms) >= maxRooms {
		return nil, fmt.Errorf("server room limit reached")
	}

	max := req.MaxMembers
	if max <= 0 || max > 4 {
		max = defaultMaxMembers
	}

	roomID := uuid.New().String()
	code := genInviteCode()

	room := &model.PartyRoom{
		ID:     roomID,
		HostID: hostID,
		Members: []model.PartyMember{{
			UserID:      hostID,
			DisplayName: hostName,
			AvatarURL:   avatarURL,
			Role:        model.PartyRoleHost,
			JoinedAt:    time.Now(),
		}},
		AnilistID:     req.AnilistID,
		AnimeTitle:    req.AnimeTitle,
		EpisodeNumber: req.EpisodeNumber,
		MaxMembers:    max,
		InviteCode:    code,
		CreatedAt:     time.Now(),
	}

	ps.rooms[roomID] = room
	ps.codes[code] = roomID
	ps.users[hostID] = roomID

	log.Info().Str("room", roomID).Str("host", hostName).Msg("party created")
	return room, nil
}

func (ps *PartyService) JoinRoom(inviteCode string, userID uuid.UUID, name string, avatar *string) (*model.PartyRoom, error) {
	ps.mu.Lock()
	defer ps.mu.Unlock()

	roomID, ok := ps.codes[inviteCode]
	if !ok {
		return nil, fmt.Errorf("invalid invite code")
	}
	room, ok := ps.rooms[roomID]
	if !ok {
		return nil, fmt.Errorf("room not found")
	}

	// Already in another room?
	if eid, exists := ps.users[userID]; exists && eid != roomID {
		return nil, fmt.Errorf("already in another room")
	}

	// Already a member (reconnect)?
	for _, m := range room.Members {
		if m.UserID == userID {
			return room, nil
		}
	}

	if len(room.Members) >= room.MaxMembers {
		return nil, fmt.Errorf("room is full")
	}

	room.Members = append(room.Members, model.PartyMember{
		UserID:      userID,
		DisplayName: name,
		AvatarURL:   avatar,
		Role:        model.PartyRoleMember,
		JoinedAt:    time.Now(),
	})
	ps.users[userID] = roomID
	return room, nil
}

// LeaveRoom removes a user. Returns updated room (nil if destroyed) and
// the new host ID if it changed.
func (ps *PartyService) LeaveRoom(userID uuid.UUID) (room *model.PartyRoom, newHost *uuid.UUID) {
	ps.mu.Lock()
	defer ps.mu.Unlock()

	roomID, ok := ps.users[userID]
	if !ok {
		return nil, nil
	}
	room, ok = ps.rooms[roomID]
	if !ok {
		delete(ps.users, userID)
		return nil, nil
	}

	var remaining []model.PartyMember
	for _, m := range room.Members {
		if m.UserID != userID {
			remaining = append(remaining, m)
		}
	}
	delete(ps.users, userID)

	if len(remaining) == 0 {
		delete(ps.rooms, roomID)
		delete(ps.codes, room.InviteCode)
		log.Info().Str("room", roomID).Msg("party destroyed (empty)")
		return nil, nil
	}

	room.Members = remaining

	// Host transfer.
	if room.HostID == userID {
		room.HostID = remaining[0].UserID
		remaining[0].Role = model.PartyRoleHost
		room.Members = remaining
		nh := remaining[0].UserID
		newHost = &nh
	}

	return room, newHost
}

func (ps *PartyService) GetRoom(roomID string) (*model.PartyRoom, bool) {
	ps.mu.RLock()
	defer ps.mu.RUnlock()
	r, ok := ps.rooms[roomID]
	return r, ok
}

func (ps *PartyService) GetRoomByUser(userID uuid.UUID) (*model.PartyRoom, bool) {
	ps.mu.RLock()
	defer ps.mu.RUnlock()
	rid, ok := ps.users[userID]
	if !ok {
		return nil, false
	}
	r, ok := ps.rooms[rid]
	return r, ok
}

func (ps *PartyService) GetRoomByInvite(code string) (*model.PartyRoom, bool) {
	ps.mu.RLock()
	defer ps.mu.RUnlock()
	rid, ok := ps.codes[code]
	if !ok {
		return nil, false
	}
	r, ok := ps.rooms[rid]
	return r, ok
}

func (ps *PartyService) KickMember(roomID string, hostID, targetID uuid.UUID) error {
	ps.mu.Lock()
	defer ps.mu.Unlock()

	room, ok := ps.rooms[roomID]
	if !ok {
		return fmt.Errorf("room not found")
	}
	if room.HostID != hostID {
		return fmt.Errorf("only host can kick")
	}
	if hostID == targetID {
		return fmt.Errorf("cannot kick yourself")
	}

	var remaining []model.PartyMember
	found := false
	for _, m := range room.Members {
		if m.UserID == targetID {
			found = true
			continue
		}
		remaining = append(remaining, m)
	}
	if !found {
		return fmt.Errorf("target not in room")
	}
	room.Members = remaining
	delete(ps.users, targetID)
	return nil
}

// UpdateRoom lets the host change the current anime/episode.
func (ps *PartyService) UpdateRoom(roomID string, hostID uuid.UUID, req model.UpdatePartyRequest) (*model.PartyRoom, error) {
	ps.mu.Lock()
	defer ps.mu.Unlock()

	room, ok := ps.rooms[roomID]
	if !ok {
		return nil, fmt.Errorf("room not found")
	}
	if room.HostID != hostID {
		return nil, fmt.Errorf("only host can update room")
	}

	if req.AnilistID != nil {
		room.AnilistID = *req.AnilistID
	}
	if req.AnimeTitle != nil {
		room.AnimeTitle = *req.AnimeTitle
	}
	if req.EpisodeNumber != nil {
		room.EpisodeNumber = *req.EpisodeNumber
	}
	return room, nil
}

// ── Cleanup ──

func (ps *PartyService) cleanupLoop() {
	t := time.NewTicker(10 * time.Minute)
	defer t.Stop()
	for range t.C {
		ps.mu.Lock()
		now := time.Now()
		for id, room := range ps.rooms {
			if now.Sub(room.CreatedAt) > roomTTL {
				for _, m := range room.Members {
					delete(ps.users, m.UserID)
				}
				delete(ps.codes, room.InviteCode)
				delete(ps.rooms, id)
				log.Info().Str("room", id).Msg("stale party cleaned")
			}
		}
		ps.mu.Unlock()
	}
}

func genInviteCode() string {
	b := make([]byte, inviteCodeLen)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%X", time.Now().UnixNano())[:inviteCodeLen*2]
	}
	return hex.EncodeToString(b)[:inviteCodeLen*2]
}
