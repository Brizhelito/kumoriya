package model

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID          uuid.UUID `json:"id"`
	DisplayName string    `json:"display_name"`
	AvatarURL   *string   `json:"avatar_url,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type OAuthAccount struct {
	ID           uuid.UUID  `json:"id"`
	UserID       uuid.UUID  `json:"user_id"`
	Provider     string     `json:"provider"`
	ProviderID   string     `json:"provider_id"`
	Email        *string    `json:"email,omitempty"`
	AccessToken  *string    `json:"-"`
	RefreshToken *string    `json:"-"`
	TokenExpiry  *time.Time `json:"-"`
	CreatedAt    time.Time  `json:"created_at"`
}

type Session struct {
	ID          uuid.UUID `json:"id"`
	UserID      uuid.UUID `json:"user_id"`
	RefreshHash string    `json:"-"`
	DeviceName  *string   `json:"device_name,omitempty"`
	IPAddress   *string   `json:"ip_address,omitempty"`
	ExpiresAt   time.Time `json:"expires_at"`
	CreatedAt   time.Time `json:"created_at"`
	Revoked     bool      `json:"revoked"`
}

type PasskeyCredential struct {
	ID              string    `json:"id"`
	UserID          uuid.UUID `json:"user_id"`
	PublicKey       []byte    `json:"-"`
	AttestationType string    `json:"attestation_type"`
	Transport       []string  `json:"transport"`
	SignCount       uint32    `json:"sign_count"`
	FriendlyName    *string   `json:"friendly_name,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}
