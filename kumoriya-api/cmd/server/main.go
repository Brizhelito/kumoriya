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
		MaxAge:        3600,
	}))

	// ── Health (no DB) ──
	app.Get("/health", handler.Health)

	// ── Database-dependent routes ──
	if cfg.NeonDSN == "" {
		log.Warn().Msg("NEON_DSN not set; only /health is available")
	} else {
		registerProtectedRoutes(app, cfg)
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
	if err := app.Shutdown(); err != nil {
		log.Error().Err(err).Msg("shutdown error")
	}
}

func registerProtectedRoutes(app *fiber.App, cfg config.Config) {
	pool, err := repository.NewPool(context.Background(), cfg.NeonDSN)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to database")
	}
	// Note: pool.Close() is not deferred here; it lives until process exit.

	userRepo := repository.NewUserRepo(pool)
	syncRepo := repository.NewSyncRepo(pool)

	jwtSvc := service.NewJWTService(cfg.JWTPrivateKey, cfg.JWTPublicKey, cfg.JWTIssuer)
	authSvc := service.NewAuthService(userRepo, jwtSvc)
	oauthSvc := service.NewOAuthService(
		cfg.DiscordClientID, cfg.DiscordClientSecret, cfg.DiscordRedirectURI,
		cfg.GoogleClientID, cfg.GoogleClientSecret, cfg.GoogleRedirectURI,
	)
	syncSvc := service.NewSyncService(syncRepo)

	var passkeySvc *service.PasskeyService
	passkeySvc, err = service.NewPasskeyService(cfg.WebAuthnRPID, cfg.WebAuthnRPOrigin, cfg.WebAuthnRPName, userRepo)
	if err != nil {
		log.Warn().Err(err).Msg("passkey service init failed; passkey endpoints disabled")
	}

	authHandler := handler.NewAuthHandler(authSvc, oauthSvc, passkeySvc)
	syncHandler := handler.NewSyncHandler(syncSvc)
	profileHandler := handler.NewProfileHandler(userRepo)

	// ── Auth Routes (public) ──
	auth := app.Group("/auth")
	auth.Get("/oauth/:provider", authHandler.OAuthStart)
	auth.Get("/oauth/:provider/callback", authHandler.OAuthCallback)
	auth.Post("/refresh", authHandler.Refresh)

	if passkeySvc != nil {
		auth.Post("/passkeys/authenticate/begin", authHandler.PasskeyAuthBegin)
		auth.Post("/passkeys/authenticate/finish", authHandler.PasskeyAuthFinish)
	}

	// ── Auth middleware for protected routes ──
	requireAuth := middleware.RequireAuth(jwtSvc)

	auth.Post("/logout", requireAuth, authHandler.Logout)
	if passkeySvc != nil {
		auth.Post("/passkeys/register/begin", requireAuth, authHandler.PasskeyRegisterBegin)
		auth.Post("/passkeys/register/finish", requireAuth, authHandler.PasskeyRegisterFinish)
	}

	// ── API v1 Routes (all protected) ──
	v1 := app.Group("/api/v1", requireAuth)

	syncRateLimit := middleware.PerUserRateLimit(30, time.Minute)

	v1.Get("/profile", profileHandler.GetProfile)
	v1.Patch("/profile", profileHandler.UpdateProfile)

	v1.Get("/sync/pull", syncHandler.Pull)
	v1.Post("/sync/push", syncRateLimit, syncHandler.Push)

	v1.Delete("/account", authHandler.DeleteAccount)
}
