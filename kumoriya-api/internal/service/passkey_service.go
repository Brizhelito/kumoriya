package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
)

// ───── ceremony cache (in-memory, TTL-based) ─────

type ceremonyEntry struct {
	session   *webauthn.SessionData
	expiresAt time.Time
}

type ceremonyCache struct {
	mu      sync.Mutex
	entries map[string]ceremonyEntry // keyed by challenge string
}

func newCeremonyCache() *ceremonyCache {
	c := &ceremonyCache{entries: make(map[string]ceremonyEntry)}
	go c.cleanup()
	return c
}

func (c *ceremonyCache) put(key string, s *webauthn.SessionData, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[key] = ceremonyEntry{session: s, expiresAt: time.Now().Add(ttl)}
}

func (c *ceremonyCache) pop(key string) (*webauthn.SessionData, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.entries[key]
	if !ok || time.Now().After(e.expiresAt) {
		delete(c.entries, key)
		return nil, false
	}
	delete(c.entries, key)
	return e.session, true
}

func (c *ceremonyCache) cleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		c.mu.Lock()
		now := time.Now()
		for k, e := range c.entries {
			if now.After(e.expiresAt) {
				delete(c.entries, k)
			}
		}
		c.mu.Unlock()
	}
}

// ───── webauthn user adapter ─────

type webauthnUser struct {
	id          uuid.UUID
	name        string
	displayName string
	credentials []webauthn.Credential
}

func (u *webauthnUser) WebAuthnID() []byte {
	b, _ := u.id.MarshalBinary()
	return b
}
func (u *webauthnUser) WebAuthnName() string        { return u.name }
func (u *webauthnUser) WebAuthnDisplayName() string  { return u.displayName }
func (u *webauthnUser) WebAuthnCredentials() []webauthn.Credential { return u.credentials }

// ───── PasskeyService ─────

const ceremonyCacheTTL = 5 * time.Minute

type PasskeyService struct {
	wan      *webauthn.WebAuthn
	userRepo *repository.UserRepo
	cache    *ceremonyCache
}

func NewPasskeyService(rpID, rpOrigin, rpName string, ur *repository.UserRepo) (*PasskeyService, error) {
	cfg := &webauthn.Config{
		RPID:                  rpID,
		RPDisplayName:         rpName,
		RPOrigins:             []string{rpOrigin},
		AttestationPreference: protocol.PreferNoAttestation,
	}
	wan, err := webauthn.New(cfg)
	if err != nil {
		return nil, fmt.Errorf("webauthn init: %w", err)
	}
	return &PasskeyService{wan: wan, userRepo: ur, cache: newCeremonyCache()}, nil
}

// BeginRegistration starts passkey registration for an authenticated user.
func (s *PasskeyService) BeginRegistration(ctx context.Context, userID uuid.UUID, displayName string) (*protocol.CredentialCreation, error) {
	existingCreds, err := s.userRepo.GetPasskeysByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get passkeys: %w", err)
	}

	u := &webauthnUser{
		id:          userID,
		name:        displayName,
		displayName: displayName,
		credentials: toWebAuthnCreds(existingCreds),
	}

	options, session, err := s.wan.BeginRegistration(u)
	if err != nil {
		return nil, fmt.Errorf("begin registration: %w", err)
	}

	cacheKey := cacheKeyForUser(userID, "register")
	s.cache.put(cacheKey, session, ceremonyCacheTTL)

	return options, nil
}

// FinishRegistration completes passkey registration by parsing + validating the
// attestation response body.
func (s *PasskeyService) FinishRegistration(ctx context.Context, userID uuid.UUID, displayName string, body []byte) error {
	cacheKey := cacheKeyForUser(userID, "register")
	session, ok := s.cache.pop(cacheKey)
	if !ok {
		return fmt.Errorf("no pending registration ceremony")
	}

	existingCreds, err := s.userRepo.GetPasskeysByUser(ctx, userID)
	if err != nil {
		return fmt.Errorf("get passkeys: %w", err)
	}

	u := &webauthnUser{
		id:          userID,
		name:        displayName,
		displayName: displayName,
		credentials: toWebAuthnCreds(existingCreds),
	}

	parsed, err := protocol.ParseCredentialCreationResponseBody(bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("parse attestation: %w", err)
	}

	cred, err := s.wan.CreateCredential(u, *session, parsed)
	if err != nil {
		return fmt.Errorf("create credential: %w", err)
	}

	transports := make([]string, len(cred.Transport))
	for i, t := range cred.Transport {
		transports[i] = string(t)
	}

	dbCred := &model.PasskeyCredential{
		ID:              protocol.URLEncodedBase64(cred.ID).String(),
		UserID:          userID,
		PublicKey:       cred.PublicKey,
		AttestationType: cred.AttestationType,
		Transport:       transports,
		SignCount:       cred.Authenticator.SignCount,
	}

	if err := s.userRepo.CreatePasskeyCredential(ctx, dbCred); err != nil {
		return fmt.Errorf("store credential: %w", err)
	}

	log.Info().Str("user_id", userID.String()).Msg("passkey registered")
	return nil
}

// BeginLogin starts passkey authentication for a known user.
func (s *PasskeyService) BeginLogin(ctx context.Context, userID uuid.UUID, displayName string) (*protocol.CredentialAssertion, error) {
	creds, err := s.userRepo.GetPasskeysByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get passkeys: %w", err)
	}
	if len(creds) == 0 {
		return nil, fmt.Errorf("no registered passkeys")
	}

	u := &webauthnUser{
		id:          userID,
		name:        displayName,
		displayName: displayName,
		credentials: toWebAuthnCreds(creds),
	}

	options, session, err := s.wan.BeginLogin(u)
	if err != nil {
		return nil, fmt.Errorf("begin login: %w", err)
	}

	cacheKey := cacheKeyForUser(userID, "login")
	s.cache.put(cacheKey, session, ceremonyCacheTTL)

	return options, nil
}

// FinishLogin completes passkey authentication, validates the assertion,
// and updates the sign count.
func (s *PasskeyService) FinishLogin(ctx context.Context, userID uuid.UUID, displayName string, body []byte) error {
	cacheKey := cacheKeyForUser(userID, "login")
	session, ok := s.cache.pop(cacheKey)
	if !ok {
		return fmt.Errorf("no pending login ceremony")
	}

	creds, err := s.userRepo.GetPasskeysByUser(ctx, userID)
	if err != nil {
		return fmt.Errorf("get passkeys: %w", err)
	}

	u := &webauthnUser{
		id:          userID,
		name:        displayName,
		displayName: displayName,
		credentials: toWebAuthnCreds(creds),
	}

	parsed, err := protocol.ParseCredentialRequestResponseBody(bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("parse assertion: %w", err)
	}

	updatedCred, err := s.wan.ValidateLogin(u, *session, parsed)
	if err != nil {
		return fmt.Errorf("validate login: %w", err)
	}

	credID := protocol.URLEncodedBase64(updatedCred.ID).String()
	if err := s.userRepo.UpdatePasskeySignCount(ctx, credID, updatedCred.Authenticator.SignCount); err != nil {
		log.Warn().Err(err).Str("cred_id", credID).Msg("failed to update sign count")
	}

	return nil
}

// ───── helpers ─────

func toWebAuthnCreds(dbCreds []model.PasskeyCredential) []webauthn.Credential {
	out := make([]webauthn.Credential, 0, len(dbCreds))
	for _, c := range dbCreds {
		credID, err := decodeCredentialID(c.ID)
		if err != nil {
			log.Warn().Err(err).Str("credential_id", c.ID).Msg("skipping invalid stored passkey credential id")
			continue
		}
		transports := make([]protocol.AuthenticatorTransport, len(c.Transport))
		for j, t := range c.Transport {
			transports[j] = protocol.AuthenticatorTransport(t)
		}
		out = append(out, webauthn.Credential{
			ID:              credID,
			PublicKey:       c.PublicKey,
			AttestationType: c.AttestationType,
			Transport:       transports,
			Authenticator: webauthn.Authenticator{
				SignCount: c.SignCount,
			},
		})
	}
	return out
}

func cacheKeyForUser(userID uuid.UUID, ceremony string) string {
	return userID.String() + ":" + ceremony
}

func decodeCredentialID(value string) ([]byte, error) {
	var decoded protocol.URLEncodedBase64
	if err := json.Unmarshal([]byte("\""+value+"\""), &decoded); err != nil {
		return nil, err
	}
	return []byte(decoded), nil
}
