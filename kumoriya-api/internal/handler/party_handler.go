package handler

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/service"
)

// brokerCallTimeout is the per-request timeout used for calls into the
// realtime Worker. It must leave room for one retry (see PartyBrokerClient).
const brokerCallTimeout = 8 * time.Second

// PartyHandler handles REST endpoints for watch-party rooms.
//
// It runs in two modes:
//   - Legacy in-memory (v1): uses PartyService + SignalRelay. The API is
//     authoritative and signaling travels via a separate WebSocket.
//   - Brokered realtime (v2, behind WATCH_PARTY_REALTIME_V2): the Worker at
//     party.kumoriya.online is authoritative. The API simply creates/joins
//     rooms remotely and mints a short-lived Ed25519 session ticket.
//
// Both modes share the same REST paths so the Flutter client can be swapped
// on its own flag and never see mixed behaviour mid-flight.
type PartyHandler struct {
	partySvc   *service.PartyService
	relay      *service.SignalRelay
	broker     *service.PartyBrokerClient
	sessionSvc *service.PartySessionService
	realtimeV2 bool
}

func NewPartyHandler(partySvc *service.PartyService, relay *service.SignalRelay) *PartyHandler {
	return &PartyHandler{partySvc: partySvc, relay: relay}
}

// NewPartyHandlerV2 constructs a handler that prefers the brokered flow when
// `realtimeV2` is true. When false the legacy in-memory service is used.
// `broker` and `sessionSvc` may be nil if the flag is off.
func NewPartyHandlerV2(
	partySvc *service.PartyService,
	relay *service.SignalRelay,
	broker *service.PartyBrokerClient,
	sessionSvc *service.PartySessionService,
	realtimeV2 bool,
) *PartyHandler {
	return &PartyHandler{
		partySvc:   partySvc,
		relay:      relay,
		broker:     broker,
		sessionSvc: sessionSvc,
		realtimeV2: realtimeV2 && broker != nil && sessionSvc != nil,
	}
}

// ── CreateRoom ───────────────────────────────────────────────────────────────

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

	if h.realtimeV2 {
		return h.createRoomV2(c, userID, userName, req)
	}
	return h.createRoomLegacy(c, userID, userName, req)
}

func (h *PartyHandler) createRoomLegacy(
	c fiber.Ctx,
	userID uuid.UUID,
	userName string,
	req model.CreatePartyRequest,
) error {
	room, err := h.partySvc.CreateRoom(userID, userName, nil, req)
	if err != nil {
		log.Warn().Err(err).Str("user", userID.String()).Msg("create party failed")
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(model.PartyRoomResponse{Room: *room})
}

func (h *PartyHandler) createRoomV2(
	c fiber.Ctx,
	userID uuid.UUID,
	userName string,
	req model.CreatePartyRequest,
) error {
	ctx, cancel := context.WithTimeout(c.Context(), brokerCallTimeout)
	defer cancel()

	roomID, inviteCode, err := h.broker.CreateRoom(ctx, userID.String(), userName, service.BrokerMediaState{
		AnilistID:     req.AnilistID,
		AnimeTitle:    req.AnimeTitle,
		EpisodeNumber: req.EpisodeNumber,
	})
	if err != nil {
		return mapBrokerError(c, err, "create party failed")
	}

	session, err := h.sessionSvc.IssueSession(userID, userName, roomID, service.PartySessionRoleHost)
	if err != nil {
		log.Error().Err(err).Str("room", roomID).Msg("issue session token failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to issue session token"})
	}

	return c.Status(fiber.StatusCreated).JSON(model.PartyRoomResponseV2{
		Room:            buildV2Room(roomID, inviteCode, userID, userName, req),
		RealtimeSession: &session,
	})
}

// ── JoinRoom ─────────────────────────────────────────────────────────────────

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

	if h.realtimeV2 {
		return h.joinRoomV2(c, userID, userName, req.InviteCode)
	}
	return h.joinRoomLegacy(c, userID, userName, req.InviteCode)
}

func (h *PartyHandler) joinRoomLegacy(
	c fiber.Ctx,
	userID uuid.UUID,
	userName string,
	inviteCode string,
) error {
	room, err := h.partySvc.JoinRoom(inviteCode, userID, userName, nil)
	if err != nil {
		log.Warn().Err(err).Str("user", userID.String()).Str("code", inviteCode).Msg("join party failed")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}
	log.Info().Str("room", room.ID).Str("user", userName).Int("members", len(room.Members)).Msg("user joined party")
	return c.JSON(model.PartyRoomResponse{Room: *room})
}

func (h *PartyHandler) joinRoomV2(
	c fiber.Ctx,
	userID uuid.UUID,
	userName string,
	inviteCode string,
) error {
	ctx, cancel := context.WithTimeout(c.Context(), brokerCallTimeout)
	defer cancel()

	roomID, err := h.broker.ResolveInviteCode(ctx, inviteCode)
	if err != nil {
		return mapBrokerError(c, err, "invite lookup failed")
	}

	if err := h.broker.JoinRoom(ctx, roomID, userID.String(), userName); err != nil {
		return mapBrokerError(c, err, "join party failed")
	}

	session, err := h.sessionSvc.IssueSession(userID, userName, roomID, service.PartySessionRoleMember)
	if err != nil {
		log.Error().Err(err).Str("room", roomID).Msg("issue session token failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to issue session token"})
	}

	return c.JSON(model.PartyRoomResponseV2{
		Room:            buildV2Room(roomID, inviteCode, userID, userName, model.CreatePartyRequest{}),
		RealtimeSession: &session,
	})
}

// ── LeaveRoom ────────────────────────────────────────────────────────────────

// LeaveRoom handles POST /api/v1/party/leave
func (h *PartyHandler) LeaveRoom(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	if h.realtimeV2 {
		// Best-effort: we do not know the roomId from here. The Flutter client
		// is expected to send the roomId explicitly via a query param; fall
		// back to "nothing to do" otherwise.
		roomID := c.Query("roomId")
		if roomID == "" {
			return c.JSON(fiber.Map{"ok": true})
		}
		ctx, cancel := context.WithTimeout(c.Context(), brokerCallTimeout)
		defer cancel()
		if err := h.broker.LeaveRoom(ctx, roomID, userID.String()); err != nil {
			log.Warn().Err(err).Str("room", roomID).Msg("broker leave failed")
		}
		return c.JSON(fiber.Map{"ok": true})
	}

	room, _ := h.partySvc.LeaveRoom(userID)
	if room != nil && h.relay != nil {
		payload, _ := json.Marshal(model.SignalPeerPayload{UserID: userID.String()})
		h.relay.BroadcastToRoom(room.ID, model.SignalMessage{
			Type:    model.SignalPeerLeft,
			Payload: payload,
		})
	}
	return c.JSON(fiber.Map{"ok": true})
}

// ── Read-only helpers (legacy only) ──────────────────────────────────────────

// GetRoom handles GET /api/v1/party/:id (legacy only).
func (h *PartyHandler) GetRoom(c fiber.Ctx) error {
	if h.realtimeV2 {
		return c.Status(fiber.StatusGone).JSON(fiber.Map{"error": "not supported in v2; open the WebSocket and wait for room_snapshot"})
	}
	roomID := c.Params("id")
	room, ok := h.partySvc.GetRoom(roomID)
	if !ok {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "room not found"})
	}
	return c.JSON(model.PartyRoomResponse{Room: *room})
}

// GetMyRoom handles GET /api/v1/party/me (legacy only).
func (h *PartyHandler) GetMyRoom(c fiber.Ctx) error {
	if h.realtimeV2 {
		// In v2 the Worker is the authority; we do not keep a reverse index
		// here. Client uses its persisted room ID + session refresh.
		return c.Status(fiber.StatusGone).JSON(fiber.Map{"error": "not supported in v2; use persisted session and /session/refresh"})
	}
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

// GetRoomByInvite handles GET /api/v1/party/invite/:code (legacy only).
func (h *PartyHandler) GetRoomByInvite(c fiber.Ctx) error {
	if h.realtimeV2 {
		return c.Status(fiber.StatusGone).JSON(fiber.Map{"error": "not supported in v2; call POST /party/join"})
	}
	code := c.Params("code")
	room, ok := h.partySvc.GetRoomByInvite(code)
	if !ok {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "invalid invite code"})
	}
	return c.JSON(model.PartyRoomResponse{Room: *room})
}

// UpdateRoom handles PATCH /api/v1/party/:id — host changes anime/episode
// (legacy only). In v2, host sends playback_intent:media_change over WS.
func (h *PartyHandler) UpdateRoom(c fiber.Ctx) error {
	if h.realtimeV2 {
		return c.Status(fiber.StatusGone).JSON(fiber.Map{"error": "not supported in v2; send playback_intent:media_change via WebSocket"})
	}
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

// ── Session refresh (v2 only) ────────────────────────────────────────────────

// RefreshSession handles POST /api/v1/party/session/refresh.
// It mints a new Ed25519 session token for an already-joined user so the
// client can reconnect after the previous token expired, without going
// through create/join again.
func (h *PartyHandler) RefreshSession(c fiber.Ctx) error {
	if !h.realtimeV2 {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "not available"})
	}
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}
	userName, _ := middleware.UserNameFromCtx(c)

	var req model.PartySessionRefreshRequest
	if err := c.Bind().JSON(&req); err != nil || req.RoomID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "roomId is required"})
	}

	ctx, cancel := context.WithTimeout(c.Context(), brokerCallTimeout)
	defer cancel()

	isMember, err := h.broker.VerifyMember(ctx, req.RoomID, userID.String())
	if err != nil {
		return mapBrokerError(c, err, "member verify failed")
	}
	if !isMember {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "not a member of this room"})
	}

	// Role is re-derived by the Worker from room state; the session token
	// declaration is advisory. Default to member; host-transfer decisions
	// are the Worker's responsibility.
	session, err := h.sessionSvc.IssueSession(userID, userName, req.RoomID, service.PartySessionRoleMember)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to issue session token"})
	}
	return c.JSON(model.PartySessionRefreshResponse{Session: session})
}

// ── helpers ──────────────────────────────────────────────────────────────────

// buildV2Room constructs a minimal PartyRoom placeholder for the v2 response.
// The authoritative state lives in the Worker; we only echo enough metadata
// here for the client to bootstrap before the WebSocket is open.
func buildV2Room(
	roomID string,
	inviteCode string,
	userID uuid.UUID,
	userName string,
	req model.CreatePartyRequest,
) model.PartyRoom {
	return model.PartyRoom{
		ID:            roomID,
		HostID:        userID,
		Members:       []model.PartyMember{}, // filled by Worker snapshot
		AnilistID:     req.AnilistID,
		AnimeTitle:    req.AnimeTitle,
		EpisodeNumber: req.EpisodeNumber,
		MaxMembers:    4,
		InviteCode:    inviteCode,
	}
}

func mapBrokerError(c fiber.Ctx, err error, failMsg string) error {
	var berr *service.BrokerError
	if errors.As(err, &berr) {
		status := berr.Status
		if status < 400 || status >= 600 {
			status = fiber.StatusBadGateway
		}
		log.Warn().Err(err).Str("code", berr.Code).Int("status", berr.Status).Msg(failMsg)
		return c.Status(status).JSON(fiber.Map{
			"error":     berr.Message,
			"code":      berr.Code,
			"retryable": berr.Retryable,
		})
	}
	log.Error().Err(err).Msg(failMsg)
	return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": failMsg})
}
