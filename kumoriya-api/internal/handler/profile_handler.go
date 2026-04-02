package handler

import (
	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/repository"
)

type ProfileHandler struct {
	userRepo *repository.UserRepo
}

func NewProfileHandler(ur *repository.UserRepo) *ProfileHandler {
	return &ProfileHandler{userRepo: ur}
}

// GetProfile handles GET /api/v1/profile
func (h *ProfileHandler) GetProfile(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	user, err := h.userRepo.GetUserByID(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch profile"})
	}
	if user == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "user not found"})
	}

	return c.JSON(user)
}

// UpdateProfile handles PATCH /api/v1/profile { "display_name": "..." }
func (h *ProfileHandler) UpdateProfile(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	type updateReq struct {
		DisplayName string `json:"display_name"`
	}
	var req updateReq
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}

	if req.DisplayName == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "display_name is required"})
	}

	if len(req.DisplayName) > 64 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "display_name too long"})
	}

	if err := h.userRepo.UpdateDisplayName(c.Context(), userID, req.DisplayName); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to update profile"})
	}

	user, err := h.userRepo.GetUserByID(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch profile"})
	}

	return c.JSON(user)
}
