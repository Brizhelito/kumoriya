package handler

import (
	"crypto/subtle"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/repository"
	"go-fiber-microservice/internal/service"
)

type ReleaseHandler struct {
	service      *service.ReleaseService
	publishToken string
}

func NewReleaseHandler(svc *service.ReleaseService, publishToken string) *ReleaseHandler {
	return &ReleaseHandler{
		service:      svc,
		publishToken: strings.TrimSpace(publishToken),
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

	return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
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
