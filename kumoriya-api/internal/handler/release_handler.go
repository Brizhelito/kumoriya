package handler

import (
	"context"
	"crypto/subtle"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/notifications"
	"go-fiber-microservice/internal/repository"
	"go-fiber-microservice/internal/service"
)

type ReleaseHandler struct {
	service      *service.ReleaseService
	publishToken string
	// fcmSender, when non-nil, receives a fan-out push on every successful
	// publish. Optional: a missing sender simply skips the broadcast.
	fcmSender notifications.Sender
}

// NewReleaseHandler builds a handler. `fcmSender` is optional; pass nil
// to disable the post-publish broadcast (useful for tests and for
// deployments without Firebase credentials).
func NewReleaseHandler(svc *service.ReleaseService, publishToken string, fcmSender notifications.Sender) *ReleaseHandler {
	return &ReleaseHandler{
		service:      svc,
		publishToken: strings.TrimSpace(publishToken),
		fcmSender:    fcmSender,
	}
}

func (h *ReleaseHandler) GetManifest(c fiber.Ctx) error {
	data, err := h.service.GetLatestManifest(c.Context())
	if err != nil {
		if err == repository.ErrReleaseNotFound {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "release not found"})
		}
		log.Error().Err(err).Msg("release manifest fetch failed")
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "release unavailable"})
	}

	c.Set("Cache-Control", "public, max-age=300")
	return c.JSON(data)
}

func (h *ReleaseHandler) GetFeed(c fiber.Ctx) error {
	data, err := h.service.GetFeed()
	if err != nil {
		if err == repository.ErrReleaseNotFound {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "release feed not found"})
		}
		log.Error().Err(err).Msg("release feed fetch failed")
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "release feed unavailable"})
	}

	c.Set("Cache-Control", "public, max-age=300")
	return c.JSON(data)
}

func (h *ReleaseHandler) GetByTag(c fiber.Ctx) error {
	tag := strings.TrimSpace(c.Params("tag"))
	if tag == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing tag"})
	}
	data, err := h.service.GetRelease(tag)
	if err != nil {
		if err == repository.ErrReleaseNotFound {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "release not found"})
		}
		log.Error().Err(err).Str("tag", tag).Msg("release by tag fetch failed")
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "release unavailable"})
	}

	c.Set("Cache-Control", "public, max-age=300")
	return c.JSON(data)
}

func (h *ReleaseHandler) Publish(c fiber.Ctx) error {
	if h.publishToken == "" {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{"error": "release publishing disabled"})
	}
	if !validBearerToken(c.Get("Authorization"), h.publishToken) {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
	}

	var input service.PublishReleaseInput
	if err := c.Bind().JSON(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}
	if err := h.service.Publish(c.Context(), input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	// Broadcast a single FCM push so installed clients learn about the
	// release without waiting for the next periodic manifest poll.
	// Best-effort: an FCM failure must NOT roll back a successful
	// publish (the manifest is the source of truth; the push is just
	// a hint).
	h.broadcastReleasePush(c.Context(), input)

	return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
}

// broadcastReleasePush fires a single FCM topic message to AppUpdatesTopic.
// All errors are logged at warn level and swallowed.
func (h *ReleaseHandler) broadcastReleasePush(ctx context.Context, input service.PublishReleaseInput) {
	if h.fcmSender == nil {
		return
	}
	version := strings.TrimSpace(input.Version)
	if version == "" {
		return
	}
	tag := strings.TrimSpace(input.Tag)

	// Body prefers the short Spanish summary, then English, then the
	// manifest blurb; trimmed to one sensible line so the notification
	// banner stays compact.
	body := firstNonEmpty(
		input.Summary.ES,
		input.Summary.EN,
		input.ManifestReleaseNotes,
		"Toca para actualizar Kumoriya",
	)
	body = firstLine(body)

	msg := notifications.TopicMessage{
		Title: "Nueva versión " + version,
		Body:  body,
		Data: map[string]string{
			"type":      "app_update",
			"version":   version,
			"tag":       tag,
			"deep_link": "kumoriya://app-update",
		},
	}
	id, err := h.fcmSender.SendToTopic(ctx, notifications.AppUpdatesTopic, msg)
	if err != nil {
		log.Warn().
			Err(err).
			Str("version", version).
			Str("tag", tag).
			Msg("release publish: fcm broadcast failed")
		return
	}
	log.Info().
		Str("version", version).
		Str("tag", tag).
		Str("message_id", id).
		Msg("release publish: fcm broadcast dispatched")
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if s := strings.TrimSpace(v); s != "" {
			return s
		}
	}
	return ""
}

func firstLine(s string) string {
	if i := strings.IndexAny(s, "\r\n"); i >= 0 {
		s = s[:i]
	}
	return strings.TrimSpace(s)
}

func validBearerToken(header, expected string) bool {
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return false
	}
	token := strings.TrimSpace(strings.TrimPrefix(header, prefix))
	if token == "" || expected == "" {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(token), []byte(expected)) == 1
}
