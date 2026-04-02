package handler

import (
	"strconv"

	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/service"
)

type SyncHandler struct {
	syncSvc *service.SyncService
}

func NewSyncHandler(s *service.SyncService) *SyncHandler {
	return &SyncHandler{syncSvc: s}
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

	resp, err := h.syncSvc.Pull(c.Context(), userID, since)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "sync pull failed"})
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
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}
	if err := req.Validate(); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	resp, err := h.syncSvc.Push(c.Context(), userID, &req)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "sync push failed"})
	}

	return c.JSON(resp)
}
