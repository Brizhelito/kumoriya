package config

import (
	"crypto/ed25519"
	"encoding/hex"
	"log"
	"os"
	"strings"
	"unicode"
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

	// Android APK SHA-256 fingerprints for Digital Asset Links (passkeys).
	// Release package: dev.kumoriya.app
	AndroidAPKFingerprints []string
	// Debug package: dev.kumoriya.app.debug (separate signing key)
	AndroidAPKDebugFingerprints []string

	// ── Watch Party Realtime v2 (brokered to Cloudflare Worker) ──

	// WatchPartyRealtimeV2 enables the new broker flow (kumoriya-api talks to
	// party.kumoriya.online/internal/* and emits Ed25519 session tickets).
	WatchPartyRealtimeV2 bool
	// PartyRealtimeBaseURL is the HTTPS base used by the API to call
	// `/internal/v1/*` on the Worker.
	PartyRealtimeBaseURL string
	// PartyRealtimeWebsocketBaseURL is the WSS base advertised to clients.
	PartyRealtimeWebsocketBaseURL string
	// PartyInternalToken is the shared bearer for internal endpoints.
	PartyInternalToken string
	// PartyWSAudience is the `aud` claim that session tokens must carry.
	PartyWSAudience string

	// ── Notifications / FCM ──

	// FirebaseServiceAccountJSON is the raw JSON content of the Admin SDK
	// service account key. Preferred over FirebaseServiceAccountFile in
	// container environments (HF Spaces) where secrets are env vars.
	FirebaseServiceAccountJSON string
	// FirebaseServiceAccountFile is a filesystem path to the service
	// account JSON. Used only if FirebaseServiceAccountJSON is empty.
	FirebaseServiceAccountFile string

	// ── Upstash Redis (notification dedup) ──

	UpstashRedisURL   string
	UpstashRedisToken string
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

	// Ed25519 key: 64-byte hex-encoded private key. Copy-paste from secret
	// managers (HF Spaces, shells, UIs) routinely injects stray whitespace —
	// tabs, newlines, zero-width chars — so we strip all whitespace defensively
	// before decoding. Without this, a single stray TAB at the start of the
	// value crashes boot with an opaque hex decode error.
	privHex := stripWhitespace(os.Getenv("JWT_PRIVATE_KEY_HEX"))
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

		AndroidAPKFingerprints:      parseOrigins(os.Getenv("ANDROID_APK_FINGERPRINTS")),
		AndroidAPKDebugFingerprints: parseOrigins(os.Getenv("ANDROID_APK_DEBUG_FINGERPRINTS")),

		// URL env vars are also stripped of whitespace so a stray tab or
		// trailing newline from copy-paste cannot produce opaque "no such
		// host" / "invalid URL escape" errors at request time.
		WatchPartyRealtimeV2:          getEnv("WATCH_PARTY_REALTIME_V2", "") != "",
		PartyRealtimeBaseURL:          stripWhitespace(getEnv("PARTY_REALTIME_BASE_URL", "https://party.kumoriya.online")),
		PartyRealtimeWebsocketBaseURL: stripWhitespace(getEnv("PARTY_REALTIME_WS_BASE_URL", "wss://party.kumoriya.online")),
		PartyInternalToken:            stripWhitespace(os.Getenv("PARTY_INTERNAL_TOKEN")),
		PartyWSAudience:               stripWhitespace(getEnv("PARTY_WS_AUDIENCE", "watch-party")),

		FirebaseServiceAccountJSON: os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON"),
		FirebaseServiceAccountFile: stripWhitespace(os.Getenv("FIREBASE_SERVICE_ACCOUNT_FILE")),

		UpstashRedisURL:   stripWhitespace(os.Getenv("UPSTASH_REDIS_REST_URL")),
		UpstashRedisToken: stripWhitespace(os.Getenv("UPSTASH_REDIS_REST_TOKEN")),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// stripWhitespace removes every Unicode whitespace rune from s. Used for
// secrets that should be a single token but may get tabs/newlines/NBSPs
// injected during copy-paste into dashboards or shell env files.
func stripWhitespace(s string) string {
	if s == "" {
		return s
	}
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		if unicode.IsSpace(r) {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
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
