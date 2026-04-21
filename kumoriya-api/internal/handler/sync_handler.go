package handler

import (
	"strconv"

	"github.com/gofiber/fiber/v3"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/service"
)

type SyncHandler struct {
	syncSvc  *service.SyncService
	debugLog bool
}

func NewSyncHandler(s *service.SyncService, debugLog bool) *SyncHandler {
	s.DebugLog = debugLog
	return &SyncHandler{syncSvc: s, debugLog: debugLog}
}

// Pull handles GET /api/v1/sync/pull?since={epoch_millis}
func (h *SyncHandler) Pull(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	sinceStr := c.Query("since", "0")
	since, err := strconv.ParseInt(sinceStr, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid since parameter"})
	}

	if h.debugLog {
		log.Debug().Str("user_id", userID.String()).Int64("since", since).Msg("sync pull request")
	}

	resp, err := h.syncSvc.Pull(c.Context(), userID, since)
	if err != nil {
		log.Error().Err(err).Str("user_id", userID.String()).Msg("sync pull failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "sync pull failed"})
	}

	if h.debugLog {
		log.Debug().
			Str("user_id", userID.String()).
			Int("episodes", len(resp.EpisodeProgress)).
			Int("history", len(resp.WatchHistory)).
			Int("prefs", len(resp.PlaybackPreferences)).
			Int("library", len(resp.LibraryEntries)).
			Msg("sync pull success")
	}

	return c.JSON(resp)
}

// Push handles POST /api/v1/sync/push
func (h *SyncHandler) Push(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	var req model.SyncPushRequest
	if err := c.Bind().JSON(&req); err != nil {
		log.Warn().Err(err).Str("user_id", userID.String()).Msg("sync push: invalid request body")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}
	// Clamp client-provided timestamps to the server clock before validation.
	// This is the only line of defence against devices with broken clocks
	// setting LWW cursors far into the future, which would otherwise poison
	// the user's state for every other device until an even newer timestamp
	// arrived to override it.
	req.Normalize(model.NowMillis())
	if err := req.Validate(); err != nil {
		log.Warn().Err(err).Str("user_id", userID.String()).
			Int("episodes", len(req.EpisodeProgress)).
			Int("history", len(req.WatchHistory)).
			Int("prefs", len(req.PlaybackPreferences)).
			Int("library", len(req.LibraryEntries)).
			Msg("sync push: validation failed")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	if h.debugLog {
		log.Debug().
			Str("user_id", userID.String()).
			Int("episodes", len(req.EpisodeProgress)).
			Int("history", len(req.WatchHistory)).
			Int("prefs", len(req.PlaybackPreferences)).
			Int("library", len(req.LibraryEntries)).
			Msg("sync push request")
	}

	resp, err := h.syncSvc.Push(c.Context(), userID, &req)
	if err != nil {
		log.Error().Err(err).Str("user_id", userID.String()).Msg("sync push failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "sync push failed"})
	}

	if h.debugLog {
		log.Debug().
			Str("user_id", userID.String()).
			Int("applied", resp.Applied).
			Int("conflicts", len(resp.Conflicts)).
			Msg("sync push success")
	}

	return c.JSON(resp)
}
