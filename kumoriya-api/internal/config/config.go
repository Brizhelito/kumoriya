package config

import (
	"crypto/ed25519"
	"encoding/hex"
	"log"
	"os"
	"strings"
)

type Config struct {
	Port           string
	TrustedProxies []string

	// Database
	NeonDSN string

	// JWT (Ed25519)
	JWTPrivateKey ed25519.PrivateKey
	JWTPublicKey  ed25519.PublicKey
	JWTIssuer     string

	// OAuth — Discord
	DiscordClientID     string
	DiscordClientSecret string
	DiscordRedirectURI  string

	// OAuth — Google
	GoogleClientID     string
	GoogleClientSecret string
	GoogleRedirectURI  string

	// WebAuthn
	WebAuthnRPID     string
	WebAuthnRPOrigin string
	WebAuthnRPName   string

	// Public base URL (for building redirect URLs)
	BaseURL string
}

func Load() Config {
	port := getEnv("PORT", "7860")
	trusted := getEnv("TRUSTED_PROXIES", "0.0.0.0/0")

	var proxies []string
	for _, v := range strings.Split(trusted, ",") {
		item := strings.TrimSpace(v)
		if item != "" {
			proxies = append(proxies, item)
		}
	}
	if len(proxies) == 0 {
		proxies = []string{"0.0.0.0/0"}
	}

	baseURL := getEnv("BASE_URL", "https://api.kumoriya.online")
	jwtIssuer := getEnv("JWT_ISSUER", baseURL)

	// Ed25519 key: 64-byte hex-encoded private key
	privHex := os.Getenv("JWT_PRIVATE_KEY_HEX")
	var privKey ed25519.PrivateKey
	var pubKey ed25519.PublicKey
	if privHex != "" {
		raw, err := hex.DecodeString(privHex)
		if err != nil {
			log.Fatalf("invalid JWT_PRIVATE_KEY_HEX: %v", err)
		}
		if len(raw) != ed25519.PrivateKeySize {
			log.Fatalf("JWT_PRIVATE_KEY_HEX must be %d bytes, got %d", ed25519.PrivateKeySize, len(raw))
		}
		privKey = ed25519.PrivateKey(raw)
		pubKey = privKey.Public().(ed25519.PublicKey)
	}

	return Config{
		Port:           port,
		TrustedProxies: proxies,

		NeonDSN: os.Getenv("NEON_DSN"),

		JWTPrivateKey: privKey,
		JWTPublicKey:  pubKey,
		JWTIssuer:     jwtIssuer,

		DiscordClientID:     os.Getenv("DISCORD_CLIENT_ID"),
		DiscordClientSecret: os.Getenv("DISCORD_CLIENT_SECRET"),
		DiscordRedirectURI:  baseURL + "/auth/oauth/discord/callback",

		GoogleClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		GoogleRedirectURI:  baseURL + "/auth/oauth/google/callback",

		WebAuthnRPID:     getEnv("WEBAUTHN_RP_ID", "kumoriya.online"),
		WebAuthnRPOrigin: getEnv("WEBAUTHN_RP_ORIGIN", baseURL),
		WebAuthnRPName:   getEnv("WEBAUTHN_RP_NAME", "Kumoriya"),

		BaseURL: baseURL,
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
