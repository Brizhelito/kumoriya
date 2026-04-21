package handler

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"go-fiber-microservice/internal/service"
)

func newTestAuthHandler(t *testing.T) *AuthHandler {
	t.Helper()

	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}

	return NewAuthHandler(
		nil,
		nil,
		nil,
		service.NewJWTService(priv, pub, "kumoriya-test"),
	)
}

func TestOAuthStateTokenRoundTrip(t *testing.T) {
	h := newTestAuthHandler(t)

	token, err := h.newOAuthStateToken(
		"kumoriya://auth/callback",
		"Pixel 8",
		"device-123",
	)
	if err != nil {
		t.Fatalf("newOAuthStateToken: %v", err)
	}

	claims, err := h.parseOAuthStateToken(token)
	if err != nil {
		t.Fatalf("parseOAuthStateToken: %v", err)
	}

	if claims.RedirectURI != "kumoriya://auth/callback" {
		t.Fatalf("unexpected redirect URI: %s", claims.RedirectURI)
	}
	if claims.DeviceName != "Pixel 8" {
		t.Fatalf("unexpected device name: %s", claims.DeviceName)
	}
	if claims.DeviceID != "device-123" {
		t.Fatalf("unexpected device id: %s", claims.DeviceID)
	}
}

func TestOAuthStateTokenRejectsExpiredToken(t *testing.T) {
	h := newTestAuthHandler(t)

	token, err := h.jwtSvc.SignClaims(oauthStateClaims{
		RedirectURI: "kumoriya://auth/callback",
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "kumoriya-oauth-state",
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-15 * time.Minute)),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-5 * time.Minute)),
		},
	})
	if err != nil {
		t.Fatalf("SignClaims: %v", err)
	}

	if _, err := h.parseOAuthStateToken(token); err == nil {
		t.Fatal("expected expired token to fail")
	}
}
