package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
)

type AuthService struct {
	userRepo *repository.UserRepo
	jwt      *JWTService
}

func NewAuthService(ur *repository.UserRepo, jwt *JWTService) *AuthService {
	return &AuthService{userRepo: ur, jwt: jwt}
}

// PasskeyLoginInfo creates a minimal OAuthUserInfo for passkey-based re-auth.
// The user already exists so the login flow will find them by their existing OAuth account or user ID.
func PasskeyLoginInfo(userID uuid.UUID) model.OAuthUserInfo {
	return model.OAuthUserInfo{
		ProviderID:  userID.String(),
		Provider:    "passkey",
		DisplayName: "",
	}
}

// LoginOrRegisterPasskey issues a token pair for an existing user after passkey verification.
func (s *AuthService) LoginOrRegisterPasskey(ctx context.Context, userID uuid.UUID, deviceName, ipAddress string) (*model.User, *model.TokenPair, error) {
	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, nil, fmt.Errorf("get user: %w", err)
	}
	if user == nil {
		return nil, nil, fmt.Errorf("user not found")
	}

	pair, err := s.issueTokenPair(ctx, user, deviceName, ipAddress)
	if err != nil {
		return nil, nil, err
	}
	return user, pair, nil
}

// LoginOrRegisterOAuth handles the OAuth callback: find or create user, issue tokens.
func (s *AuthService) LoginOrRegisterOAuth(
	ctx context.Context,
	info model.OAuthUserInfo,
	deviceName string,
	ipAddress string,
) (*model.User, *model.TokenPair, error) {
	// 1. Check if this OAuth account already exists
	existing, err := s.userRepo.FindOAuthAccount(ctx, info.Provider, info.ProviderID)
	if err != nil {
		return nil, nil, fmt.Errorf("find oauth account: %w", err)
	}

	var user *model.User

	if existing != nil {
		// Existing user — fetch and update avatar
		user, err = s.userRepo.GetUserByID(ctx, existing.UserID)
		if err != nil {
			return nil, nil, fmt.Errorf("get user: %w", err)
		}
		if user == nil {
			return nil, nil, fmt.Errorf("orphaned oauth account for provider_id %s", info.ProviderID)
		}
		if info.AvatarURL != "" {
			if err := s.userRepo.UpdateAvatar(ctx, user.ID, info.AvatarURL); err != nil {
				log.Warn().Err(err).Msg("failed to update avatar")
			}
			user.AvatarURL = &info.AvatarURL
		}
	} else {
		// New user
		var avatar *string
		if info.AvatarURL != "" {
			avatar = &info.AvatarURL
		}
		user, err = s.userRepo.CreateUser(ctx, info.DisplayName, avatar)
		if err != nil {
			return nil, nil, fmt.Errorf("create user: %w", err)
		}
	}

	// Upsert the OAuth account with up-to-date tokens
	var email *string
	if info.Email != "" {
		email = &info.Email
	}
	oauthAcct := &model.OAuthAccount{
		ID:         uuid.New(),
		UserID:     user.ID,
		Provider:   info.Provider,
		ProviderID: info.ProviderID,
		Email:      email,
	}
	if err := s.userRepo.UpsertOAuthAccount(ctx, oauthAcct); err != nil {
		return nil, nil, fmt.Errorf("upsert oauth: %w", err)
	}

	// Issue tokens
	pair, err := s.issueTokenPair(ctx, user, deviceName, ipAddress)
	if err != nil {
		return nil, nil, err
	}

	return user, pair, nil
}

// RefreshTokens validates a refresh token and issues a new pair (rotation).
func (s *AuthService) RefreshTokens(ctx context.Context, userID uuid.UUID, rawRefresh string) (*model.TokenPair, error) {
	sessions, err := s.userRepo.GetActiveSessionsByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get sessions: %w", err)
	}

	// Find matching session
	var matched *model.Session
	for i := range sessions {
		if CompareRefreshToken(rawRefresh, sessions[i].RefreshHash) {
			matched = &sessions[i]
			break
		}
	}

	if matched == nil {
		// Possible token reuse — revoke ALL sessions as compromise signal
		log.Warn().Str("user_id", userID.String()).Msg("refresh token reuse detected, revoking all sessions")
		if err := s.userRepo.RevokeAllSessions(ctx, userID); err != nil {
			log.Error().Err(err).Msg("failed to revoke all sessions")
		}
		return nil, fmt.Errorf("invalid refresh token")
	}

	// Generate new refresh token (rotation)
	newRaw, newHash, err := GenerateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("generate refresh: %w", err)
	}

	newExpiry := time.Now().UTC().Add(RefreshTokenDuration)
	if err := s.userRepo.UpdateSessionHash(ctx, matched.ID, newHash, newExpiry); err != nil {
		return nil, fmt.Errorf("update session: %w", err)
	}

	user, err := s.userRepo.GetUserByID(ctx, userID)
	if err != nil || user == nil {
		return nil, fmt.Errorf("get user for refresh: %w", err)
	}

	accessToken, err := s.jwt.GenerateAccessToken(user.ID, user.DisplayName)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

	return &model.TokenPair{
		AccessToken:  accessToken,
		RefreshToken: newRaw,
		ExpiresIn:    int(AccessTokenDuration.Seconds()),
	}, nil
}

// Logout revokes a specific session.
func (s *AuthService) Logout(ctx context.Context, userID uuid.UUID, rawRefresh string) error {
	sessions, err := s.userRepo.GetActiveSessionsByUser(ctx, userID)
	if err != nil {
		return fmt.Errorf("get sessions: %w", err)
	}
	for _, sess := range sessions {
		if CompareRefreshToken(rawRefresh, sess.RefreshHash) {
			return s.userRepo.RevokeSession(ctx, sess.ID)
		}
	}
	return nil // token not found, treat as already logged out
}

// DeleteAccount removes the user and all related data (CASCADE).
func (s *AuthService) DeleteAccount(ctx context.Context, userID uuid.UUID) error {
	return s.userRepo.DeleteUser(ctx, userID)
}

func (s *AuthService) issueTokenPair(ctx context.Context, user *model.User, deviceName, ipAddress string) (*model.TokenPair, error) {
	// Enforce max sessions
	count, err := s.userRepo.CountActiveSessions(ctx, user.ID)
	if err != nil {
		return nil, fmt.Errorf("count sessions: %w", err)
	}
	if count >= MaxSessionsPerUser {
		if err := s.userRepo.RevokeOldestSession(ctx, user.ID); err != nil {
			return nil, fmt.Errorf("revoke oldest: %w", err)
		}
	}

	accessToken, err := s.jwt.GenerateAccessToken(user.ID, user.DisplayName)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

	rawRefresh, hashRefresh, err := GenerateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	var devName *string
	if deviceName != "" {
		devName = &deviceName
	}
	var ip *string
	if ipAddress != "" {
		ip = &ipAddress
	}

	session := &model.Session{
		ID:          uuid.New(),
		UserID:      user.ID,
		RefreshHash: hashRefresh,
		DeviceName:  devName,
		IPAddress:   ip,
		ExpiresAt:   time.Now().UTC().Add(RefreshTokenDuration),
		CreatedAt:   time.Now().UTC(),
	}

	if err := s.userRepo.CreateSession(ctx, session); err != nil {
		return nil, fmt.Errorf("create session: %w", err)
	}

	return &model.TokenPair{
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
		ExpiresIn:    int(AccessTokenDuration.Seconds()),
	}, nil
}
