package service

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"

	"github.com/google/uuid"
)

func TestJWTServiceGenerateAndValidateAccessToken(t *testing.T) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("generate keypair: %v", err)
	}

	svc := NewJWTService(priv, pub, "kumoriya-api")
	userID := uuid.New()
	token, err := svc.GenerateAccessToken(userID, "Reny")
	if err != nil {
		t.Fatalf("generate token: %v", err)
	}

	claims, err := svc.ValidateAccessToken(token)
	if err != nil {
		t.Fatalf("validate token: %v", err)
	}
	if claims.Subject != userID.String() {
		t.Fatalf("subject = %s, want %s", claims.Subject, userID.String())
	}
	if claims.Name != "Reny" {
		t.Fatalf("name = %s, want Reny", claims.Name)
	}
}

func TestGenerateRefreshTokenAndCompare(t *testing.T) {
	raw, hash, err := GenerateRefreshToken()
	if err != nil {
		t.Fatalf("generate refresh token: %v", err)
	}
	if raw == "" || hash == "" {
		t.Fatal("expected non-empty raw token and hash")
	}
	if !CompareRefreshToken(raw, hash) {
		t.Fatal("expected refresh token hash comparison to succeed")
	}
	if CompareRefreshToken("wrong-token", hash) {
		t.Fatal("expected refresh token hash comparison to fail")
	}
}
