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
	WebAuthnRPID      string
	WebAuthnRPOrigins []string
	WebAuthnRPName    string

	// Public base URL (for building redirect URLs)
	BaseURL string

	// Debug flags
	SyncDebugLog bool

	// Release manifest URL (R2 or similar)
	ReleaseManifestURL string

	// Android APK SHA-256 fingerprint for Digital Asset Links (passkeys)
	AndroidAPKFingerprint string
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

		WebAuthnRPID:      getEnv("WEBAUTHN_RP_ID", "kumoriya.online"),
		WebAuthnRPOrigins: parseOrigins(getEnv("WEBAUTHN_RP_ORIGINS", baseURL)),
		WebAuthnRPName:    getEnv("WEBAUTHN_RP_NAME", "Kumoriya"),

		BaseURL: baseURL,

		SyncDebugLog: getEnv("SYNC_DEBUG_LOG", "") != "",

		ReleaseManifestURL: getEnv("RELEASE_MANIFEST_URL", "https://pub-8159019abe1741a097538b976c19722c.r2.dev/update.json"),

		AndroidAPKFingerprint: os.Getenv("ANDROID_APK_FINGERPRINT"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// parseOrigins splits a comma-separated string into a list of origins.
func parseOrigins(raw string) []string {
	var origins []string
	for _, v := range strings.Split(raw, ",") {
		item := strings.TrimSpace(v)
		if item != "" {
			origins = append(origins, item)
		}
	}
	return origins
}
