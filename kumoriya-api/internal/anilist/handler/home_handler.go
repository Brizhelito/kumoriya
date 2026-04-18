// Package handler exposes HTTP endpoints for the AniList Home cache.
package handler

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/anilist/cache"
	"go-fiber-microservice/internal/anilist/service"
)

// HomeHandler serves cached AniList Home surfaces.
type HomeHandler struct {
	svc *service.HomeService
}

// NewHomeHandler builds the handler.
func NewHomeHandler(svc *service.HomeService) *HomeHandler {
	return &HomeHandler{svc: svc}
}

// Register registers the AniList Home routes under the given Fiber app.
// Routes are public (no auth required) since the payloads are public data.
func (h *HomeHandler) Register(app *fiber.App) {
	g := app.Group("/v1/anilist/home")
	g.Get("/trending", h.Trending)
	g.Get("/season-discovery", h.SeasonDiscovery)
	g.Get("/airing-calendar", h.AiringCalendar)
}

// Trending returns the trending / current-season catalog.
func (h *HomeHandler) Trending(c fiber.Ctx) error {
	req := service.TrendingRequest{
		Page:    intQuery(c, "page", 1),
		PerPage: intQuery(c, "perPage", 20),
	}
	res, err := h.svc.Trending(c.Context(), req)
	if err != nil {
		log.Warn().Err(err).Msg("anilist home: trending failed")
		return fiber.NewError(fiber.StatusBadGateway, "anilist upstream failed")
	}
	return writeCached(c, res)
}

// SeasonDiscovery returns the combo season catalog.
func (h *HomeHandler) SeasonDiscovery(c fiber.Ctx) error {
	req := service.SeasonDiscoveryRequest{
		Page:              intQuery(c, "page", 1),
		PerPage:           intQuery(c, "perPage", 30),
		IncludeCarryovers: boolQuery(c, "includeCarryover", true),
	}
	res, err := h.svc.SeasonDiscovery(c.Context(), req)
	if err != nil {
		log.Warn().Err(err).Msg("anilist home: season discovery failed")
		return fiber.NewError(fiber.StatusBadGateway, "anilist upstream failed")
	}
	return writeCached(c, res)
}

// AiringCalendar returns one page of the airing schedule.
func (h *HomeHandler) AiringCalendar(c fiber.Ctx) error {
	req := service.AiringCalendarRequest{
		Days:    intQuery(c, "days", 7),
		Page:    intQuery(c, "page", 1),
		PerPage: intQuery(c, "perPage", 50),
	}
	res, err := h.svc.AiringCalendar(c.Context(), req)
	if err != nil {
		log.Warn().Err(err).Msg("anilist home: airing calendar failed")
		return fiber.NewError(fiber.StatusBadGateway, "anilist upstream failed")
	}
	return writeCached(c, res)
}

func writeCached(c fiber.Ctx, res cache.Result) error {
	c.Set("Content-Type", "application/json")
	// Public because these payloads are identical across users.
	c.Set("Cache-Control", "public, max-age=60, stale-while-revalidate=600")
	c.Set("X-Cache-Stale", boolToStr(res.Stale))
	c.Set("X-Cache-Age", durationMillisStr(res.Age))
	return c.Send(res.Data)
}

func intQuery(c fiber.Ctx, key string, fallback int) int {
	v := c.Query(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}

func boolQuery(c fiber.Ctx, key string, fallback bool) bool {
	v := c.Query(key)
	if v == "" {
		return fallback
	}
	switch v {
	case "1", "true", "TRUE", "True":
		return true
	case "0", "false", "FALSE", "False":
		return false
	}
	return fallback
}

func boolToStr(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func durationMillisStr(d time.Duration) string {
	return strconv.FormatInt(d.Milliseconds(), 10)
}
