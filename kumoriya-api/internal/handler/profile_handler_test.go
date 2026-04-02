package handler

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/model"
)

type fakeProfileRepo struct {
	user           *model.User
	linkedAccounts []model.OAuthAccount
	sessions       []model.Session
	passkeys       []model.PasskeyCredential
}

func (f *fakeProfileRepo) GetUserByID(_ context.Context, id uuid.UUID) (*model.User, error) {
	if f.user != nil && f.user.ID == id {
		return f.user, nil
	}
	return nil, nil
}

func (f *fakeProfileRepo) UpdateDisplayName(_ context.Context, id uuid.UUID, displayName string) error {
	if f.user != nil && f.user.ID == id {
		f.user.DisplayName = displayName
	}
	return nil
}

func (f *fakeProfileRepo) ListOAuthAccountsByUser(_ context.Context, userID uuid.UUID) ([]model.OAuthAccount, error) {
	if f.user != nil && f.user.ID == userID {
		return f.linkedAccounts, nil
	}
	return nil, nil
}

func (f *fakeProfileRepo) GetActiveSessionsByUser(_ context.Context, userID uuid.UUID) ([]model.Session, error) {
	if f.user != nil && f.user.ID == userID {
		return f.sessions, nil
	}
	return nil, nil
}

func (f *fakeProfileRepo) GetPasskeysByUser(_ context.Context, userID uuid.UUID) ([]model.PasskeyCredential, error) {
	if f.user != nil && f.user.ID == userID {
		return f.passkeys, nil
	}
	return nil, nil
}

func TestGetProfileIncludesRelatedAuthData(t *testing.T) {
	userID := uuid.New()
	repo := &fakeProfileRepo{
		user: &model.User{
			ID:          userID,
			DisplayName: "Reny",
			CreatedAt:   time.Now().UTC(),
			UpdatedAt:   time.Now().UTC(),
		},
		linkedAccounts: []model.OAuthAccount{{
			ID:         uuid.New(),
			UserID:     userID,
			Provider:   "discord",
			ProviderID: "123",
		}},
		sessions: []model.Session{{
			ID:        uuid.New(),
			UserID:    userID,
			ExpiresAt: time.Now().UTC().Add(24 * time.Hour),
		}},
		passkeys: []model.PasskeyCredential{{
			ID:     "cred-1",
			UserID: userID,
		}},
	}

	app := fiber.New()
	handler := NewProfileHandler(repo)
	app.Get("/profile", func(c fiber.Ctx) error {
		c.Locals(middleware.LocalsUserID, userID)
		return handler.GetProfile(c)
	})

	resp, err := app.Test(httptest.NewRequest("GET", "/profile", nil))
	if err != nil {
		t.Fatalf("profile request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, fiber.StatusOK)
	}

	var body ProfileResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body.User == nil || body.User.ID != userID {
		t.Fatal("expected user payload in profile response")
	}
	if len(body.LinkedAccounts) != 1 {
		t.Fatalf("linked_accounts length = %d, want 1", len(body.LinkedAccounts))
	}
	if len(body.ActiveSessions) != 1 {
		t.Fatalf("active_sessions length = %d, want 1", len(body.ActiveSessions))
	}
	if len(body.RegisteredPasskeys) != 1 {
		t.Fatalf("registered_passkeys length = %d, want 1", len(body.RegisteredPasskeys))
	}
}
