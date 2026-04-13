package handler

import (
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"
)

// ReleaseHandler serves the release update manifest, fetching it from the
// upstream once on first request and caching it for the lifetime of the
// process. A restart picks up the latest version.
type ReleaseHandler struct {
	upstreamURL string
	once        sync.Once
	cached      []byte
	fetchErr    error
}

func NewReleaseHandler(upstreamURL string) *ReleaseHandler {
	return &ReleaseHandler{upstreamURL: upstreamURL}
}

// GetManifest returns the cached release manifest JSON.
func (h *ReleaseHandler) GetManifest(c fiber.Ctx) error {
	data, err := h.load()
	if err != nil {
		log.Error().Err(err).Msg("release manifest fetch failed")
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "upstream unavailable"})
	}

	c.Set("Content-Type", "application/json")
	c.Set("Cache-Control", "public, max-age=3600")
	return c.Send(data)
}

func (h *ReleaseHandler) load() ([]byte, error) {
	h.once.Do(func() {
		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Get(h.upstreamURL)
		if err != nil {
			h.fetchErr = fmt.Errorf("fetch manifest: %w", err)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			h.fetchErr = fmt.Errorf("upstream returned %s", resp.Status)
			return
		}

		body, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
		if err != nil {
			h.fetchErr = fmt.Errorf("read manifest body: %w", err)
			return
		}

		h.cached = body
	})

	return h.cached, h.fetchErr
}
