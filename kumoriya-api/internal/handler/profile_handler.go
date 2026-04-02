package handler

import (
	"context"

	"github.com/google/uuid"
	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/middleware"
)

type profileUserRepository interface {
	GetUserByID(ctx context.Context, id uuid.UUID) (*model.User, error)
	UpdateDisplayName(ctx context.Context, id uuid.UUID, displayName string) error
	ListOAuthAccountsByUser(ctx context.Context, userID uuid.UUID) ([]model.OAuthAccount, error)
	GetActiveSessionsByUser(ctx context.Context, userID uuid.UUID) ([]model.Session, error)
	GetPasskeysByUser(ctx context.Context, userID uuid.UUID) ([]model.PasskeyCredential, error)
}

type ProfileResponse struct {
	User          *model.User               `json:"user"`
	LinkedAccounts []model.OAuthAccount     `json:"linked_accounts"`
	ActiveSessions []model.Session          `json:"active_sessions"`
	RegisteredPasskeys []model.PasskeyCredential `json:"registered_passkeys"`
}

type ProfileHandler struct {
	userRepo profileUserRepository
}

func NewProfileHandler(ur profileUserRepository) *ProfileHandler {
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
	linkedAccounts, err := h.userRepo.ListOAuthAccountsByUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch linked accounts"})
	}
	activeSessions, err := h.userRepo.GetActiveSessionsByUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch active sessions"})
	}
	registeredPasskeys, err := h.userRepo.GetPasskeysByUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch registered passkeys"})
	}

	return c.JSON(ProfileResponse{
		User:               user,
		LinkedAccounts:     linkedAccounts,
		ActiveSessions:     activeSessions,
		RegisteredPasskeys: registeredPasskeys,
	})
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

	linkedAccounts, err := h.userRepo.ListOAuthAccountsByUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch linked accounts"})
	}
	activeSessions, err := h.userRepo.GetActiveSessionsByUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch active sessions"})
	}
	registeredPasskeys, err := h.userRepo.GetPasskeysByUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to fetch registered passkeys"})
	}

	return c.JSON(ProfileResponse{
		User:               user,
		LinkedAccounts:     linkedAccounts,
		ActiveSessions:     activeSessions,
		RegisteredPasskeys: registeredPasskeys,
	})
}
