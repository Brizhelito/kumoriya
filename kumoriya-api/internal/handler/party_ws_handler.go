package handler

import (
	"encoding/json"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/valyala/fasthttp"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/service"
)

// PartySignalHandler upgrades to WebSocket for ephemeral WebRTC signaling.
// The WS is only open while peers exchange SDP offers/answers and ICE
// candidates (~2-5 seconds). All real-time traffic then goes P2P.
//
// HF Spaces note: The HF Spaces proxy may close idle WS connections after
// ~30-60s. Clients send keepalive pongs every 30s. The read deadline is
// set to 120s to allow for keepalive while still cleaning up dead peers.
type PartySignalHandler struct {
	relay    *service.SignalRelay
	partySvc *service.PartyService
	upgrader websocket.FastHTTPUpgrader
}

func NewPartySignalHandler(relay *service.SignalRelay, partySvc *service.PartyService) *PartySignalHandler {
	return &PartySignalHandler{
		relay:    relay,
		partySvc: partySvc,
		upgrader: websocket.FastHTTPUpgrader{
			CheckOrigin:     func(_ *fasthttp.RequestCtx) bool { return true },
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
		},
	}
}

// wsConn adapts *websocket.Conn to service.Conn.
type wsConn struct{ c *websocket.Conn }

func (w *wsConn) WriteJSON(v any) error { return w.c.WriteJSON(v) }
func (w *wsConn) Close() error          { return w.c.Close() }

// Upgrade handles GET /api/v1/party/:id/signal
func (h *PartySignalHandler) Upgrade(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}
	userName, _ := middleware.UserNameFromCtx(c)

	roomID := c.Params("id")
	room, ok := h.partySvc.GetRoom(roomID)
	if !ok {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "room not found"})
	}

	isMember := false
	for _, m := range room.Members {
		if m.UserID == userID {
			isMember = true
			break
		}
	}
	if !isMember {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "not a member"})
	}

	return h.upgrader.Upgrade(c.RequestCtx(), func(ws *websocket.Conn) {
		h.signalLoop(ws, roomID, userID, userName)
	})
}

func (h *PartySignalHandler) signalLoop(ws *websocket.Conn, roomID string, userID uuid.UUID, name string) {
	defer ws.Close()

	wc := &wsConn{c: ws}
	h.relay.Register(roomID, userID, name, wc)
	defer func() {
		h.relay.Unregister(roomID, userID)
		// Notify other peers this user disconnected from signaling.
		payload, _ := json.Marshal(model.SignalPeerPayload{UserID: userID.String()})
		h.relay.BroadcastToRoom(roomID, model.SignalMessage{
			Type:    model.SignalPeerLeft,
			Payload: payload,
		})
		log.Debug().Str("room", roomID).Str("user", name).Msg("signal peer left")
	}()

	// Tell new peer about existing peers so it can initiate offers.
	// IMPORTANT: This must be called AFTER Register so the peer sees
	// everyone who was already connected before it joined.
	peers := h.relay.PeerList(roomID)
	log.Debug().Str("room", roomID).Str("user", name).Int("existingPeers", len(peers)).Msg("sending room_state to new peer")
	roomState, _ := json.Marshal(map[string]any{"peers": peers, "roomId": roomID})
	h.relay.SendTo(roomID, userID, model.SignalMessage{
		Type:    model.SignalRoomState,
		Payload: roomState,
	})

	// Notify others a new peer connected — they will create offers to the newcomer.
	joinPayload, _ := json.Marshal(model.SignalPeerPayload{
		UserID:      userID.String(),
		DisplayName: name,
	})
	h.relay.BroadcastExcept(roomID, userID, model.SignalMessage{
		Type:    model.SignalPeerJoined,
		Payload: joinPayload,
	})

	// Read loop — relay signaling messages until disconnect.
	ws.SetReadLimit(4096)
	// 120s deadline — clients send keepalive pongs every 30s.
	// This accommodates HF Spaces proxy idle timeout (~30-60s)
	// while still cleaning up truly dead connections.
	ws.SetReadDeadline(time.Now().Add(120 * time.Second))
	ws.SetPongHandler(func(string) error {
		log.Debug().Str("user", name).Msg("pong received — resetting read deadline")
		ws.SetReadDeadline(time.Now().Add(120 * time.Second))
		return nil
	})

	for {
		_, message, err := ws.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Debug().Err(err).Str("user", name).Msg("signal ws close")
			}
			return
		}
		// Reset read deadline on any message (client is alive).
		ws.SetReadDeadline(time.Now().Add(120 * time.Second))

		// Skip client-side keepalive pongs.
		var probe struct {
			Type string `json:"type"`
		}
		if json.Unmarshal(message, &probe) == nil && probe.Type == "pong" {
			continue
		}

		h.relay.RelaySignal(roomID, userID, message)
	}
}
