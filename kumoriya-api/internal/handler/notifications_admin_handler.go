package handler

import (
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/notifications"
)

// NotificationsAdminHandler exposes ad-hoc FCM sends for diagnostics.
//
// Gated by the same bearer token used for release publishing
// (Authorization: Bearer <RELEASE_PUBLISH_TOKEN>) so we don't introduce
// a new shared secret for what is essentially a deploy-time tool.
//
// Intentionally NOT mounted under a database-protected group: the
// underlying FCM Sender is the only dependency, so the endpoint stays
// available even when Neon is offline.
type NotificationsAdminHandler struct {
	sender    notifications.Sender
	authToken string
}

// NewNotificationsAdminHandler builds the handler. A nil sender is
// allowed (the endpoint will return 503 at request time) so the route
// can still be registered when FCM is not configured.
func NewNotificationsAdminHandler(sender notifications.Sender, authToken string) *NotificationsAdminHandler {
	return &NotificationsAdminHandler{
		sender:    sender,
		authToken: strings.TrimSpace(authToken),
	}
}

// sendTestRequest is the body of POST /internal/notifications/test.
//
// Topic is the raw FCM topic name. For per-anime pushes use
// `media_<anilistId>` (same prefix used by the airing worker); for a
// broadcast to every device that registered for new-episode pushes,
// use a custom topic that the client also subscribes to (out of scope
// for now — clients only subscribe to media_*).
type sendTestRequest struct {
	Topic string            `json:"topic"`
	Title string            `json:"title"`
	Body  string            `json:"body"`
	Data  map[string]string `json:"data,omitempty"`
}

// SendTest dispatches a single FCM topic message with the given
// title/body/data. Returns the FCM-assigned message id on success.
//
// Errors:
//   - 401 invalid / missing bearer token
//   - 400 missing topic / title / body
//   - 502 FCM upstream rejected the send
//   - 503 FCM sender or admin token not configured on this deployment
func (h *NotificationsAdminHandler) SendTest(c fiber.Ctx) error {
	if h.authToken == "" {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"error": "admin notifications disabled: RELEASE_PUBLISH_TOKEN not set",
		})
	}
	if h.sender == nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"error": "admin notifications disabled: fcm sender unavailable",
		})
	}
	if !validBearerToken(c.Get("Authorization"), h.authToken) {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var req sendTestRequest
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}
	req.Topic = strings.TrimSpace(req.Topic)
	req.Title = strings.TrimSpace(req.Title)
	req.Body = strings.TrimSpace(req.Body)
	if req.Topic == "" || req.Title == "" || req.Body == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "topic, title and body are required",
		})
	}

	msg := notifications.TopicMessage{
		Title: req.Title,
		Body:  req.Body,
		Data:  req.Data,
	}
	id, err := h.sender.SendToTopic(c.Context(), req.Topic, msg)
	if err != nil {
		log.Warn().
			Err(err).
			Str("topic", req.Topic).
			Msg("notifications admin: fcm send failed")
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "fcm send failed"})
	}

	log.Info().
		Str("topic", req.Topic).
		Str("message_id", id).
		Msg("notifications admin: test push dispatched")
	return c.JSON(fiber.Map{
		"ok":         true,
		"topic":      req.Topic,
		"message_id": id,
	})
}
