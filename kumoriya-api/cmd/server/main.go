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
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/config"
	"go-fiber-microservice/internal/handler"
	"go-fiber-microservice/internal/middleware"
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
		WriteTimeout:       30 * time.Second,
		BodyLimit:          1 * 1024 * 1024, // 1 MB
	})

	// ── Global Middleware ──
	app.Use(recover.New())
	app.Use(requestid.New())
	app.Use(helmet.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: []string{"https://api.kumoriya.online"},
		AllowMethods: []string{"GET", "POST", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders: []string{"Authorization", "Content-Type"},
		MaxAge:       3600,
	}))

	// ── Health (no DB) ──
	app.Get("/health", handler.Health)

	// ── Release manifest (no DB needed) ──
	releaseHandler := handler.NewReleaseHandler(cfg.ReleaseManifestURL)
	app.Get("/releases/latest", releaseHandler.GetManifest)

	// ── Digital Asset Links for Android passkeys ──
	if len(cfg.AndroidAPKFingerprints) > 0 {
		assetLinksJSON := buildAssetLinks(cfg.AndroidAPKFingerprints)
		app.Get("/.well-known/assetlinks.json", func(c fiber.Ctx) error {
			c.Set("Content-Type", "application/json")
			c.Set("Cache-Control", "public, max-age=86400")
			return c.SendString(assetLinksJSON)
		})
	}

	// ── Database-dependent routes ──
	var cleanup func()
	if cfg.NeonDSN == "" {
		log.Warn().Msg("NEON_DSN not set; only /health is available")
	} else {
		cleanup = registerProtectedRoutes(app, cfg)
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
	if cleanup != nil {
		cleanup()
	}
	if err := app.Shutdown(); err != nil {
		log.Error().Err(err).Msg("shutdown error")
	}
}

func registerProtectedRoutes(app *fiber.App, cfg config.Config) (cleanup func()) {
	pool, err := repository.NewPool(context.Background(), cfg.NeonDSN)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to database")
	}

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
	passkeySvc, err = service.NewPasskeyService(cfg.WebAuthnRPID, cfg.WebAuthnRPOrigins, cfg.WebAuthnRPName, userRepo)
	if err != nil {
		log.Warn().Err(err).Msg("passkey service init failed; passkey endpoints disabled")
	}

	authHandler := handler.NewAuthHandler(authSvc, oauthSvc, passkeySvc)
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

	return func() {
		log.Info().Msg("flushing write-behind buffer before shutdown...")
		flushCancel()
		<-flushDone
		pool.Close()
		log.Info().Msg("write-behind flush complete, pool closed")
	}
}

// buildAssetLinks returns the Digital Asset Links JSON for Android passkey association.
func buildAssetLinks(fingerprints []string) string {
	var fps string
	for i, fp := range fingerprints {
		if i > 0 {
			fps += ", "
		}
		fps += `"` + fp + `"`
	}
	return `[{
  "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
  "target": {
    "namespace": "android_app",
    "package_name": "dev.kumoriya.app",
    "sha256_cert_fingerprints": [` + fps + `]
  }
}]`
}
