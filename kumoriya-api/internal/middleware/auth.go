package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"go-fiber-microservice/internal/service"
)

// Context keys for user claims.
const (
	LocalsUserID   = "userID"
	LocalsUserName = "userName"
)

// RequireAuth returns middleware that validates the JWT access token
// from the Authorization: Bearer <token> header, and sets userID + userName
// on fiber.Ctx.Locals for downstream handlers.
func RequireAuth(jwt *service.JWTService) fiber.Handler {
	return func(c fiber.Ctx) error {
		auth := c.Get("Authorization")
		if auth == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "missing authorization header"})
		}

		parts := strings.SplitN(auth, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid authorization format"})
		}

		claims, err := jwt.ValidateAccessToken(parts[1])
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid or expired token"})
		}

		userID, err := uuid.Parse(claims.Subject)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid token subject"})
		}

		c.Locals(LocalsUserID, userID)
		c.Locals(LocalsUserName, claims.Name)
		return c.Next()
	}
}

// UserIDFromCtx extracts the authenticated user's UUID from Locals.
func UserIDFromCtx(c fiber.Ctx) (uuid.UUID, bool) {
	v := c.Locals(LocalsUserID)
	if v == nil {
		return uuid.Nil, false
	}
	id, ok := v.(uuid.UUID)
	return id, ok
}
