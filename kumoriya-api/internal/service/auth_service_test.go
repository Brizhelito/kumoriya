package service

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
)

type fakeAuthUserRepo struct {
	user               *model.User
	oauthAccount       *model.OAuthAccount
	sessions           []model.Session
	countActive        int
	createdSession     *model.Session
	updatedSessionID   uuid.UUID
	updatedSessionHash string
	updatedSessionExp  time.Time
	revokedSessionID   uuid.UUID
	revokedAllUserID   uuid.UUID
	revokedOldestUser  uuid.UUID
}

func (f *fakeAuthUserRepo) GetUserByID(_ context.Context, id uuid.UUID) (*model.User, error) {
	if f.user != nil && f.user.ID == id {
		return f.user, nil
	}
	return nil, nil
}

func (f *fakeAuthUserRepo) FindOAuthAccount(_ context.Context, provider, providerID string) (*model.OAuthAccount, error) {
	if f.oauthAccount != nil && f.oauthAccount.Provider == provider && f.oauthAccount.ProviderID == providerID {
		return f.oauthAccount, nil
	}
	return nil, nil
}

func (f *fakeAuthUserRepo) UpdateAvatar(_ context.Context, _ uuid.UUID, avatarURL string) error {
	if f.user != nil {
		f.user.AvatarURL = &avatarURL
	}
	return nil
}

func (f *fakeAuthUserRepo) CreateUser(_ context.Context, displayName string, avatarURL *string) (*model.User, error) {
	f.user = &model.User{
		ID:          uuid.New(),
		DisplayName: displayName,
		AvatarURL:   avatarURL,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	return f.user, nil
}

func (f *fakeAuthUserRepo) UpsertOAuthAccount(_ context.Context, acct *model.OAuthAccount) error {
	f.oauthAccount = acct
	return nil
}

func (f *fakeAuthUserRepo) GetActiveSessionsByUser(_ context.Context, userID uuid.UUID) ([]model.Session, error) {
	if f.user != nil && f.user.ID != userID {
		return nil, nil
	}
	return append([]model.Session(nil), f.sessions...), nil
}

func (f *fakeAuthUserRepo) RevokeAllSessions(_ context.Context, userID uuid.UUID) error {
	f.revokedAllUserID = userID
	return nil
}

func (f *fakeAuthUserRepo) UpdateSessionHash(_ context.Context, sessionID uuid.UUID, newHash string, newExpiry time.Time) error {
	f.updatedSessionID = sessionID
	f.updatedSessionHash = newHash
	f.updatedSessionExp = newExpiry
	for i := range f.sessions {
		if f.sessions[i].ID == sessionID {
			f.sessions[i].RefreshHash = newHash
			f.sessions[i].ExpiresAt = newExpiry
			return nil
		}
	}
	return errors.New("session not found")
}

func (f *fakeAuthUserRepo) RevokeSession(_ context.Context, sessionID uuid.UUID) error {
	f.revokedSessionID = sessionID
	return nil
}

func (f *fakeAuthUserRepo) DeleteUser(_ context.Context, _ uuid.UUID) error {
	return nil
}

func (f *fakeAuthUserRepo) CountActiveSessions(_ context.Context, _ uuid.UUID) (int, error) {
	return f.countActive, nil
}

func (f *fakeAuthUserRepo) RevokeOldestSession(_ context.Context, userID uuid.UUID) error {
	f.revokedOldestUser = userID
	return nil
}

func (f *fakeAuthUserRepo) RevokeSessionsByDeviceID(_ context.Context, _ uuid.UUID, _ string) error {
	return nil
}

func (f *fakeAuthUserRepo) CreateSession(_ context.Context, s *model.Session) error {
	clone := *s
	f.createdSession = &clone
	f.sessions = append(f.sessions, clone)
	return nil
}

func newTestJWTService(t *testing.T) *JWTService {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("generate ed25519 keypair: %v", err)
	}
	return NewJWTService(priv, pub, "kumoriya-api")
}

func TestAuthServiceRefreshTokensRotatesSession(t *testing.T) {
	userID := uuid.New()
	rawRefresh, hashRefresh, err := GenerateRefreshToken()
	if err != nil {
		t.Fatalf("generate refresh token: %v", err)
	}

	repo := &fakeAuthUserRepo{
		user: &model.User{ID: userID, DisplayName: "Reny"},
		sessions: []model.Session{{
			ID:          uuid.New(),
			UserID:      userID,
			RefreshHash: hashRefresh,
			ExpiresAt:   time.Now().UTC().Add(24 * time.Hour),
		}},
	}
	svc := NewAuthService(repo, newTestJWTService(t))

	pair, err := svc.RefreshTokens(context.Background(), userID, rawRefresh)
	if err != nil {
		t.Fatalf("RefreshTokens returned error: %v", err)
	}
	if pair.AccessToken == "" || pair.RefreshToken == "" {
		t.Fatal("expected new access and refresh tokens")
	}
	if pair.RefreshToken == rawRefresh {
		t.Fatal("expected refresh token to rotate")
	}
	if repo.updatedSessionID == uuid.Nil {
		t.Fatal("expected session hash to be updated")
	}
	if repo.updatedSessionHash == "" {
		t.Fatal("expected updated session hash to be persisted")
	}
	if !CompareRefreshToken(pair.RefreshToken, repo.updatedSessionHash) {
		t.Fatal("expected returned refresh token to match persisted rotated hash")
	}
	if repo.revokedAllUserID != uuid.Nil {
		t.Fatal("did not expect all sessions to be revoked during normal rotation")
	}
}

func TestAuthServiceRefreshTokensDetectsReuseAndRevokesAllSessions(t *testing.T) {
	userID := uuid.New()
	repo := &fakeAuthUserRepo{
		user: &model.User{ID: userID, DisplayName: "Reny"},
		sessions: []model.Session{{
			ID:          uuid.New(),
			UserID:      userID,
			RefreshHash: "$2a$10$abcdefghijklmnopqrstuv",
			ExpiresAt:   time.Now().UTC().Add(24 * time.Hour),
		}},
	}
	svc := NewAuthService(repo, newTestJWTService(t))

	_, err := svc.RefreshTokens(context.Background(), userID, "reused-or-invalid-token")
	if err == nil {
		t.Fatal("expected invalid refresh token error")
	}
	if repo.revokedAllUserID != userID {
		t.Fatal("expected all sessions to be revoked on reuse detection")
	}
}

func TestAuthServiceIssueTokenPairRevokesOldestWhenAtSessionLimit(t *testing.T) {
	userID := uuid.New()
	repo := &fakeAuthUserRepo{
		user:        &model.User{ID: userID, DisplayName: "Reny"},
		countActive: MaxSessionsPerUser,
	}
	svc := NewAuthService(repo, newTestJWTService(t))

	_, pair, err := svc.LoginOrRegisterPasskey(context.Background(), userID, "Desktop", "", "127.0.0.1")
	if err != nil {
		t.Fatalf("LoginOrRegisterPasskey returned error: %v", err)
	}
	if pair == nil || pair.AccessToken == "" || pair.RefreshToken == "" {
		t.Fatal("expected issued token pair")
	}
	if repo.revokedOldestUser != userID {
		t.Fatal("expected oldest session to be revoked when session limit is reached")
	}
	if repo.createdSession == nil {
		t.Fatal("expected a new session to be created")
	}
}
