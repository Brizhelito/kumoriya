package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/gofiber/fiber/v3/middleware/helmet"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/requestid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/anilist/client"
	anilisthandler "go-fiber-microservice/internal/anilist/handler"
	"go-fiber-microservice/internal/anilist/scheduler"
	anilistservice "go-fiber-microservice/internal/anilist/service"
	"go-fiber-microservice/internal/config"
	"go-fiber-microservice/internal/handler"
	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/notifications"
	kredis "go-fiber-microservice/internal/redis"
	"go-fiber-microservice/internal/repository"
	"go-fiber-microservice/internal/service"
)

func main() {
	// ── Logger ──
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = zerolog.New(os.Stdout).With().Timestamp().Logger()

	// ── Config ──
	cfg := config.Load()

	// ── Fiber ──
	app := fiber.New(fiber.Config{
		TrustProxy: true,
		TrustProxyConfig: fiber.TrustProxyConfig{
			Proxies: cfg.TrustedProxies,
		},
		ProxyHeader:        "CF-Connecting-IP",
		EnableIPValidation: true,
		ReadTimeout:        30 * time.Second,
		// WriteTimeout must be 0 (disabled) for WebSocket connections.
		// A non-zero WriteTimeout causes fasthttp to close long-lived WS
		// connections mid-handshake. WebSocket read deadlines are managed
		// per-connection inside signalLoop instead.
		WriteTimeout: 0,
		BodyLimit:    1 * 1024 * 1024, // 1 MB
	})

	// ── Global Middleware ──
	app.Use(recover.New())
	app.Use(requestid.New())
	app.Use(helmet.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: []string{
			"https://api.kumoriya.online",
			"https://kumoriya.online",
			"https://www.kumoriya.online",
		},
		AllowMethods: []string{"GET", "POST", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders: []string{"Authorization", "Content-Type"},
		MaxAge:       3600,
	}))

	// ── Health (no DB) ──
	app.Get("/health", handler.Health)

	// ── Digital Asset Links for Android passkeys ──
	if len(cfg.AndroidAPKFingerprints) > 0 || len(cfg.AndroidAPKDebugFingerprints) > 0 {
		assetLinksJSON := buildAssetLinks(cfg.AndroidAPKFingerprints, cfg.AndroidAPKDebugFingerprints)
		app.Get("/.well-known/assetlinks.json", func(c fiber.Ctx) error {
			c.Set("Content-Type", "application/json")
			c.Set("Cache-Control", "public, max-age=86400")
			return c.SendString(assetLinksJSON)
		})
	}

	// ── AniList Home edge-cache (no DB, no auth) ──
	anilistCtx, anilistCancel := context.WithCancel(context.Background())
	anilistClient := client.New()
	anilistHome := anilistservice.NewHomeService(anilistClient, anilistservice.DefaultConfig())
	anilisthandler.NewHomeHandler(anilistHome).Register(app)
	anilistPrewarm := scheduler.New(anilistHome, scheduler.DefaultConfig())
	go anilistPrewarm.Run(anilistCtx)

	// ── Airing notifications worker (FCM + Upstash dedup) ──
	// Enabled only when both Firebase credentials and Upstash creds are
	// present. Missing any disables the worker with a warning so dev
	// environments boot without secrets.
	airingCtx, airingCancel := context.WithCancel(context.Background())
	fcmSender := buildFCMSender(airingCtx, cfg)
	airingDone := startAiringWorker(airingCtx, cfg, anilistHome, fcmSender)

	// ── Notifications admin: gated by RELEASE_PUBLISH_TOKEN ──
	// Reuses the deploy bearer token (Authorization: Bearer <RELEASE_PUBLISH_TOKEN>)
	// and the same FCM Sender as the airing worker. Always registered;
	// returns 503 at request time if the sender or token is unavailable.
	notifAdmin := handler.NewNotificationsAdminHandler(fcmSender, cfg.ReleasePublishToken)
	app.Post("/internal/notifications/test", notifAdmin.SendTest)

	// ── Database-dependent routes ──
	var cleanup func()
	if cfg.NeonDSN == "" {
		releaseService := service.NewReleaseService(nil, cfg.ReleaseManifestURL)
		releaseHandler := handler.NewReleaseHandler(
			releaseService,
			cfg.ReleasePublishToken,
		)
		app.Get("/releases/latest", releaseHandler.GetManifest)
		log.Warn().Msg("NEON_DSN not set; release feed publishing is disabled")
	} else {
		pool, err := repository.NewPool(context.Background(), cfg.NeonDSN)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to connect to database")
		}

		releaseRepo := repository.NewReleaseRepo(pool)
		releaseService := service.NewReleaseService(
			releaseRepo,
			cfg.ReleaseManifestURL,
		)
		if err := releaseService.Warm(context.Background()); err != nil {
			log.Warn().
				Err(err).
				Msg("release cache warm failed; latest will fall back to legacy manifest until publish")
		}
		releaseHandler := handler.NewReleaseHandler(
			releaseService,
			cfg.ReleasePublishToken,
		)
		app.Get("/releases/latest", releaseHandler.GetManifest)
		app.Get("/releases/feed", releaseHandler.GetFeed)
		app.Get("/releases/:tag", releaseHandler.GetByTag)
		app.Post("/internal/releases/publish", releaseHandler.Publish)

		cleanup = registerProtectedRoutes(app, cfg, pool)
	}

	// ── Graceful Shutdown ──
	addr := ":" + cfg.Port
	log.Info().Str("addr", addr).Msg("server starting")

	go func() {
		if err := app.Listen(addr); err != nil {
			log.Fatal().Err(err).Msg("server error")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("shutting down...")
	anilistCancel()
	airingCancel()
	if airingDone != nil {
		<-airingDone
	}
	if cleanup != nil {
		cleanup()
	}
	if err := app.Shutdown(); err != nil {
		log.Error().Err(err).Msg("shutdown error")
	}
}

func registerProtectedRoutes(app *fiber.App, cfg config.Config, pool *pgxpool.Pool) (cleanup func()) {
	userRepo := repository.NewUserRepo(pool)
	syncRepo := repository.NewSyncRepo(pool)

	jwtSvc := service.NewJWTService(cfg.JWTPrivateKey, cfg.JWTPublicKey, cfg.JWTIssuer)
	authSvc := service.NewAuthService(userRepo, jwtSvc)
	oauthSvc := service.NewOAuthService(
		cfg.DiscordClientID, cfg.DiscordClientSecret, cfg.DiscordRedirectURI,
		cfg.GoogleClientID, cfg.GoogleClientSecret, cfg.GoogleRedirectURI,
	)
	syncSvc := service.NewSyncService(syncRepo)

	// Start write-behind flush loop (flushes buffered pushes to Neon every 15 min).
	flushCtx, flushCancel := context.WithCancel(context.Background())
	flushDone := make(chan struct{})
	go func() {
		// 2-hour interval keeps Neon awake ~4% of the time (5 min wake / 120 min cycle).
		syncSvc.FlushLoop(flushCtx, 2*time.Hour)
		close(flushDone)
	}()

	var passkeySvc *service.PasskeyService
	passkeySvc, err := service.NewPasskeyService(cfg.WebAuthnRPID, cfg.WebAuthnRPOrigins, cfg.WebAuthnRPName, userRepo)
	if err != nil {
		log.Warn().Err(err).Msg("passkey service init failed; passkey endpoints disabled")
	}

	authHandler := handler.NewAuthHandler(authSvc, oauthSvc, passkeySvc, jwtSvc)
	syncHandler := handler.NewSyncHandler(syncSvc, cfg.SyncDebugLog)
	profileHandler := handler.NewProfileHandler(userRepo)
	authIPRateLimit := middleware.PerIPRateLimit(10, time.Minute)
	oauthCallbackRateLimit := middleware.PerIPRateLimit(5, time.Minute)

	// ── Auth Routes (public) ──
	auth := app.Group("/auth")
	auth.Get("/oauth/:provider", authIPRateLimit, authHandler.OAuthStart)
	auth.Get("/oauth/:provider/callback", oauthCallbackRateLimit, authHandler.OAuthCallback)
	auth.Post("/refresh", authIPRateLimit, authHandler.Refresh)

	if passkeySvc != nil {
		auth.Post("/passkeys/authenticate/begin", authIPRateLimit, authHandler.PasskeyAuthBegin)
		auth.Post("/passkeys/authenticate/finish", authIPRateLimit, authHandler.PasskeyAuthFinish)
	}

	// ── Auth middleware for protected routes ──
	requireAuth := middleware.RequireAuth(jwtSvc)

	auth.Post("/logout", authIPRateLimit, requireAuth, authHandler.Logout)
	if passkeySvc != nil {
		auth.Post("/passkeys/register/begin", authIPRateLimit, requireAuth, authHandler.PasskeyRegisterBegin)
		auth.Post("/passkeys/register/finish", authIPRateLimit, requireAuth, authHandler.PasskeyRegisterFinish)
		auth.Delete("/passkeys/:id", authIPRateLimit, requireAuth, authHandler.PasskeyDelete)
	}

	// ── API v1 Routes (all protected) ──
	v1 := app.Group("/api/v1", requireAuth)

	syncRateLimit := middleware.PerUserRateLimit(30, time.Minute)

	v1.Get("/profile", profileHandler.GetProfile)
	v1.Patch("/profile", profileHandler.UpdateProfile)

	v1.Get("/sync/pull", syncHandler.Pull)
	v1.Post("/sync/push", syncRateLimit, syncHandler.Push)

	v1.Delete("/account", authHandler.DeleteAccount)

	// ── Watch Party (ephemeral rooms + signaling relay) ──
	partySvc := service.NewPartyService()
	signalRelay := service.NewSignalRelay()

	// v2 wiring: talk to the Cloudflare Worker when WATCH_PARTY_REALTIME_V2
	// is set. Both legacy and v2 routes share the same REST paths — the flag
	// selects which backend the handler uses at request time.
	var (
		partyBroker  *service.PartyBrokerClient
		partySession *service.PartySessionService
	)
	if cfg.WatchPartyRealtimeV2 {
		if cfg.PartyInternalToken == "" {
			log.Warn().Msg("WATCH_PARTY_REALTIME_V2 requested but PARTY_INTERNAL_TOKEN is empty; falling back to legacy")
		} else {
			partyBroker = service.NewPartyBrokerClient(cfg.PartyRealtimeBaseURL, cfg.PartyInternalToken)
			partySession = service.NewPartySessionService(
				jwtSvc,
				cfg.PartyWSAudience,
				cfg.PartyRealtimeWebsocketBaseURL,
				0, // use service default (45s) — see NewPartySessionService
			)
			log.Info().
				Str("broker", cfg.PartyRealtimeBaseURL).
				Str("ws", cfg.PartyRealtimeWebsocketBaseURL).
				Msg("watch-party realtime v2 enabled")
		}
	}

	partyHandler := handler.NewPartyHandlerV2(
		partySvc, signalRelay, partyBroker, partySession, cfg.WatchPartyRealtimeV2,
	)
	signalHandler := handler.NewPartySignalHandler(signalRelay, partySvc)

	partyRateLimit := middleware.PerUserRateLimit(10, time.Minute)

	party := v1.Group("/party")
	party.Post("/", partyRateLimit, partyHandler.CreateRoom)
	party.Post("/join", partyRateLimit, partyHandler.JoinRoom)
	party.Post("/leave", partyHandler.LeaveRoom)
	party.Post("/session/refresh", partyRateLimit, partyHandler.RefreshSession)
	party.Get("/me", partyHandler.GetMyRoom)
	party.Get("/invite/:code", partyHandler.GetRoomByInvite)
	party.Patch("/:id", partyHandler.UpdateRoom)
	party.Get("/:id", partyHandler.GetRoom)
	party.Get("/:id/signal", signalHandler.Upgrade)

	return func() {
		log.Info().Msg("flushing write-behind buffer before shutdown...")
		flushCancel()
		<-flushDone
		pool.Close()
		log.Info().Msg("write-behind flush complete, pool closed")
	}
}

// buildFCMSender builds an FCM Sender from configured Firebase credentials,
// or returns nil (with a warn log) when credentials are missing or invalid.
//
// Extracted from startAiringWorker so the same Sender can also back the
// admin "send test notification" endpoint without duplicating credential
// parsing or risking divergence between the worker and ad-hoc senders.
func buildFCMSender(ctx context.Context, cfg config.Config) notifications.Sender {
	credsJSON := cfg.FirebaseServiceAccountJSON
	if credsJSON == "" && cfg.FirebaseServiceAccountFile != "" {
		raw, err := os.ReadFile(cfg.FirebaseServiceAccountFile)
		if err != nil {
			log.Warn().Err(err).Str("path", cfg.FirebaseServiceAccountFile).Msg("fcm sender disabled: cannot read service account file")
			return nil
		}
		credsJSON = string(raw)
	}
	if credsJSON == "" {
		log.Warn().Msg("fcm sender disabled: FIREBASE_SERVICE_ACCOUNT_JSON / _FILE not set")
		return nil
	}
	sender, err := notifications.NewFCMSenderFromCredentialsJSON(ctx, []byte(credsJSON))
	if err != nil {
		log.Warn().Err(err).Msg("fcm sender disabled: FCM init failed")
		return nil
	}
	return sender
}

// startAiringWorker wires up the FCM airing-notifications pipeline if all
// required credentials are present. Returns a done channel that is closed
// when the worker exits (or nil if the worker was not started).
func startAiringWorker(ctx context.Context, cfg config.Config, home *anilistservice.HomeService, sender notifications.Sender) <-chan struct{} {
	if sender == nil {
		log.Warn().Msg("airing worker disabled: fcm sender unavailable")
		return nil
	}
	if cfg.UpstashRedisURL == "" || cfg.UpstashRedisToken == "" {
		log.Warn().Msg("airing worker disabled: UPSTASH_REDIS_REST_URL / _TOKEN not set")
		return nil
	}

	rdb, err := kredis.New(kredis.Config{URL: cfg.UpstashRedisURL, Token: cfg.UpstashRedisToken})
	if err != nil {
		log.Warn().Err(err).Msg("airing worker disabled: Redis init failed")
		return nil
	}
	// Fail fast if the Redis credentials are bad — otherwise we'd only
	// discover it at the first airing window.
	pingCtx, pingCancel := context.WithTimeout(ctx, 5*time.Second)
	defer pingCancel()
	if err := rdb.Ping(pingCtx); err != nil {
		log.Warn().Err(err).Msg("airing worker disabled: Redis ping failed")
		return nil
	}

	worker := notifications.NewAiringWorker(
		notifications.NewCalendarSource(home),
		sender,
		notifications.NewRedisDeduper(rdb),
		notifications.DefaultConfig(),
	)
	done := make(chan struct{})
	go func() {
		defer close(done)
		worker.Run(ctx)
	}()
	log.Info().Msg("airing worker: enabled")
	return done
}

// buildAssetLinks returns the Digital Asset Links JSON for Android passkey association.
// Emits separate entries for release (dev.kumoriya.app) and debug (dev.kumoriya.app.debug)
// package names, each with their own signing fingerprints.
func buildAssetLinks(releaseFingerprints, debugFingerprints []string) string {
	fmtFps := func(fps []string) string {
		var s string
		for i, fp := range fps {
			if i > 0 {
				s += ", "
			}
			s += `"` + fp + `"`
		}
		return s
	}
	entry := func(pkg string, fps []string) string {
		return `{
  "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
  "target": {
    "namespace": "android_app",
    "package_name": "` + pkg + `",
    "sha256_cert_fingerprints": [` + fmtFps(fps) + `]
  }
}`
	}
	var entries []string
	if len(releaseFingerprints) > 0 {
		entries = append(entries, entry("dev.kumoriya.app", releaseFingerprints))
	}
	if len(debugFingerprints) > 0 {
		entries = append(entries, entry("dev.kumoriya.app.debug", debugFingerprints))
	}
	result := "["
	for i, e := range entries {
		if i > 0 {
			result += ","
		}
		result += e
	}
	result += "]"
	return result
}
