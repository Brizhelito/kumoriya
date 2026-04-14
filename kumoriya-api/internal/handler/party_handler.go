package handler

import (
	"encoding/json"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/service"
)

// PartyHandler handles REST endpoints for watch-party rooms.
// All real-time communication goes over WebRTC P2P — the server
// only manages room metadata and signaling relay.
type PartyHandler struct {
	partySvc *service.PartyService
	relay    *service.SignalRelay
}

func NewPartyHandler(partySvc *service.PartyService, relay *service.SignalRelay) *PartyHandler {
	return &PartyHandler{partySvc: partySvc, relay: relay}
}

// CreateRoom handles POST /api/v1/party
func (h *PartyHandler) CreateRoom(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}
	userName, _ := middleware.UserNameFromCtx(c)

	var req model.CreatePartyRequest
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}
	if req.AnilistID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "anilistId is required"})
	}
	if req.AnimeTitle == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "animeTitle is required"})
	}

	room, err := h.partySvc.CreateRoom(userID, userName, nil, req)
	if err != nil {
		log.Warn().Err(err).Str("user", userID.String()).Msg("create party failed")
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": err.Error()})
	}

	return c.Status(fiber.StatusCreated).JSON(model.PartyRoomResponse{Room: *room})
}

// JoinRoom handles POST /api/v1/party/join
func (h *PartyHandler) JoinRoom(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}
	userName, _ := middleware.UserNameFromCtx(c)

	var req model.JoinPartyRequest
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}
	if req.InviteCode == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "inviteCode is required"})
	}

	room, err := h.partySvc.JoinRoom(req.InviteCode, userID, userName, nil)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	// Notify existing signal-relay peers that a new member joined.
	payload, _ := json.Marshal(model.SignalPeerPayload{
		UserID:      userID.String(),
		DisplayName: userName,
	})
	h.relay.BroadcastExcept(room.ID, userID, model.SignalMessage{
		Type:    model.SignalPeerJoined,
		Payload: payload,
	})

	return c.JSON(model.PartyRoomResponse{Room: *room})
}

// LeaveRoom handles POST /api/v1/party/leave
func (h *PartyHandler) LeaveRoom(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	room, _ := h.partySvc.LeaveRoom(userID)
	if room != nil {
		payload, _ := json.Marshal(model.SignalPeerPayload{UserID: userID.String()})
		h.relay.BroadcastToRoom(room.ID, model.SignalMessage{
			Type:    model.SignalPeerLeft,
			Payload: payload,
		})
	}

	return c.JSON(fiber.Map{"ok": true})
}

// GetRoom handles GET /api/v1/party/:id
func (h *PartyHandler) GetRoom(c fiber.Ctx) error {
	roomID := c.Params("id")
	room, ok := h.partySvc.GetRoom(roomID)
	if !ok {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "room not found"})
	}
	return c.JSON(model.PartyRoomResponse{Room: *room})
}

// GetMyRoom handles GET /api/v1/party/me
func (h *PartyHandler) GetMyRoom(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	room, ok := h.partySvc.GetRoomByUser(userID)
	if !ok {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "not in any room"})
	}
	return c.JSON(model.PartyRoomResponse{Room: *room})
}

// GetRoomByInvite handles GET /api/v1/party/invite/:code
func (h *PartyHandler) GetRoomByInvite(c fiber.Ctx) error {
	code := c.Params("code")
	room, ok := h.partySvc.GetRoomByInvite(code)
	if !ok {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "invalid invite code"})
	}
	return c.JSON(model.PartyRoomResponse{Room: *room})
}

// UpdateRoom handles PATCH /api/v1/party/:id — host changes anime/episode.
func (h *PartyHandler) UpdateRoom(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	roomID := c.Params("id")

	var req model.UpdatePartyRequest
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}

	room, err := h.partySvc.UpdateRoom(roomID, userID, req)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(model.PartyRoomResponse{Room: *room})
}
