package handler

import (
	"crypto/rand"
	"encoding/hex"
	"html/template"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/middleware"
	"go-fiber-microservice/internal/service"
)

// ───── OAuth state cache (CSRF protection) ─────

type oauthStateEntry struct {
	redirectURI string
	deviceName  string
	expiresAt   time.Time
}

type oauthStateCache struct {
	mu      sync.Mutex
	entries map[string]oauthStateEntry
}

func newOAuthStateCache() *oauthStateCache {
	c := &oauthStateCache{entries: make(map[string]oauthStateEntry)}
	go func() {
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
	}()
	return c
}

func (c *oauthStateCache) put(state, redirectURI, deviceName string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[state] = oauthStateEntry{
		redirectURI: redirectURI,
		deviceName:  deviceName,
		expiresAt:   time.Now().Add(10 * time.Minute),
	}
}

func (c *oauthStateCache) pop(state string) (oauthStateEntry, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.entries[state]
	if !ok || time.Now().After(e.expiresAt) {
		delete(c.entries, state)
		return oauthStateEntry{}, false
	}
	delete(c.entries, state)
	return e, true
}

// ───── AuthHandler ─────

// Allowed redirect URI schemes for the OAuth callback.
var allowedRedirectSchemes = []string{"kumoriya://"}

type AuthHandler struct {
	authSvc    *service.AuthService
	oauthSvc   *service.OAuthService
	passkeySvc *service.PasskeyService
	stateCache *oauthStateCache
}

func NewAuthHandler(auth *service.AuthService, oauth *service.OAuthService, passkey *service.PasskeyService) *AuthHandler {
	return &AuthHandler{
		authSvc:    auth,
		oauthSvc:   oauth,
		passkeySvc: passkey,
		stateCache: newOAuthStateCache(),
	}
}

// OAuthStart handles GET /auth/oauth/:provider?redirect_uri=...&device_name=...
// Redirects the user to the OAuth provider.
func (h *AuthHandler) OAuthStart(c fiber.Ctx) error {
	provider := c.Params("provider")
	if provider != "discord" && provider != "google" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "unsupported provider"})
	}

	redirectURI := c.Query("redirect_uri")
	if !isAllowedRedirect(redirectURI) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid redirect_uri"})
	}

	deviceName := c.Query("device_name", "unknown")

	// Generate CSRF state
	stateBuf := make([]byte, 32)
	if _, err := rand.Read(stateBuf); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "internal error"})
	}
	state := hex.EncodeToString(stateBuf)

	h.stateCache.put(state, redirectURI, deviceName)

	authURL, err := h.oauthSvc.GetAuthURL(provider, state)
	if err != nil {
		log.Error().Err(err).Str("provider", provider).Msg("oauth auth url failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "internal error"})
	}

	return c.Redirect().To(authURL)
}

// OAuthCallback handles GET /auth/oauth/:provider/callback?code=...&state=...
func (h *AuthHandler) OAuthCallback(c fiber.Ctx) error {
	provider := c.Params("provider")
	code := c.Query("code")
	state := c.Query("state")

	if code == "" || state == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing code or state"})
	}

	entry, ok := h.stateCache.pop(state)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid or expired state"})
	}

	info, err := h.oauthSvc.ExchangeCode(c.Context(), provider, code)
	if err != nil {
		log.Error().Err(err).Str("provider", provider).Msg("oauth exchange failed")
		return redirectWithError(c, entry.redirectURI, "oauth_exchange_failed")
	}

	user, pair, err := h.authSvc.LoginOrRegisterOAuth(c.Context(), *info, entry.deviceName, c.IP())
	if err != nil {
		log.Error().Err(err).Msg("login or register failed")
		return redirectWithError(c, entry.redirectURI, "auth_failed")
	}

	// Build the callback URL through url.Values so tokens are always safely encoded.
	params := url.Values{}
	params.Set("access_token", pair.AccessToken)
	params.Set("refresh_token", pair.RefreshToken)
	params.Set("expires_in", strconv.Itoa(pair.ExpiresIn))
	params.Set("user_id", user.ID.String())
	redirectURL := entry.redirectURI + "?" + params.Encode()

	// Serve an interstitial HTML page that opens the deep link and tells
	// the user they can close the browser tab. A bare 302 to a custom
	// scheme leaves the browser on a blank/loading page forever.
	return c.Status(fiber.StatusOK).Type("html").SendString(
		buildDeepLinkPage(redirectURL),
	)
}

// Refresh handles POST /auth/refresh { "refresh_token": "...", "user_id": "..." }
func (h *AuthHandler) Refresh(c fiber.Ctx) error {
	type refreshReq struct {
		RefreshToken string `json:"refresh_token"`
		UserID       string `json:"user_id"`
	}

	var req refreshReq
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}

	if req.RefreshToken == "" || req.UserID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing refresh_token or user_id"})
	}

	userID, err := uuid.Parse(req.UserID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid user_id"})
	}

	pair, err := h.authSvc.RefreshTokens(c.Context(), userID, req.RefreshToken)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "invalid refresh token"})
	}

	return c.JSON(pair)
}

// Logout handles POST /auth/logout (authenticated)
func (h *AuthHandler) Logout(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	type logoutReq struct {
		RefreshToken string `json:"refresh_token"`
	}
	var req logoutReq
	if err := c.Bind().JSON(&req); err != nil || req.RefreshToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing refresh_token"})
	}

	if err := h.authSvc.Logout(c.Context(), userID, req.RefreshToken); err != nil {
		log.Error().Err(err).Msg("logout failed")
	}

	return c.JSON(fiber.Map{"ok": true})
}

// DeleteAccount handles DELETE /api/v1/account (authenticated)
func (h *AuthHandler) DeleteAccount(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	if err := h.authSvc.DeleteAccount(c.Context(), userID); err != nil {
		log.Error().Err(err).Msg("delete account failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to delete account"})
	}

	return c.JSON(fiber.Map{"ok": true})
}

// ───── Passkey endpoints ─────

// PasskeyRegisterBegin handles POST /auth/passkeys/register/begin (authenticated)
func (h *AuthHandler) PasskeyRegisterBegin(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}
	userName, _ := c.Locals(middleware.LocalsUserName).(string)

	type beginReq struct {
		FriendlyName string `json:"friendly_name"`
	}
	var req beginReq
	// Body is optional — ignore parse errors so callers without a body still work.
	_ = c.Bind().JSON(&req)

	options, err := h.passkeySvc.BeginRegistration(c.Context(), userID, userName, req.FriendlyName)
	if err != nil {
		log.Error().Err(err).Msg("passkey register begin failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "registration failed"})
	}

	return c.JSON(options)
}

// PasskeyRegisterFinish handles POST /auth/passkeys/register/finish (authenticated)
func (h *AuthHandler) PasskeyRegisterFinish(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}
	userName, _ := c.Locals(middleware.LocalsUserName).(string)

	body := c.Body()
	if len(body) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "empty body"})
	}

	if err := h.passkeySvc.FinishRegistration(c.Context(), userID, userName, body); err != nil {
		log.Error().Err(err).Msg("passkey register finish failed")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"ok": true})
}

// PasskeyAuthBegin handles POST /auth/passkeys/authenticate/begin
func (h *AuthHandler) PasskeyAuthBegin(c fiber.Ctx) error {
	type passkeyAuthReq struct {
		UserID string `json:"user_id"`
	}
	var req passkeyAuthReq
	if err := c.Bind().JSON(&req); err != nil || req.UserID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing user_id"})
	}

	userID, err := uuid.Parse(req.UserID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid user_id"})
	}

	options, err := h.passkeySvc.BeginLogin(c.Context(), userID, "")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(options)
}

// PasskeyAuthFinish handles POST /auth/passkeys/authenticate/finish
func (h *AuthHandler) PasskeyAuthFinish(c fiber.Ctx) error {
	type passkeyFinishReq struct {
		UserID     string `json:"user_id"`
		DeviceName string `json:"device_name"`
	}

	// Read user_id from query or separate header since body is the attestation
	userIDStr := c.Query("user_id")
	deviceName := c.Query("device_name", "unknown")
	if userIDStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing user_id query param"})
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid user_id"})
	}

	body := c.Body()
	if len(body) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "empty body"})
	}

	if err := h.passkeySvc.FinishLogin(c.Context(), userID, "", body); err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": err.Error()})
	}

	// Issue new token pair after passkey auth
	_, pair, err := h.authSvc.LoginOrRegisterPasskey(c.Context(), userID, deviceName, c.IP())
	if err != nil {
		log.Error().Err(err).Msg("token issuance after passkey failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "token issuance failed"})
	}

	return c.JSON(fiber.Map{
		"access_token":  pair.AccessToken,
		"refresh_token": pair.RefreshToken,
		"expires_in":    pair.ExpiresIn,
		"user_id":       userID.String(),
	})
}

// PasskeyDelete handles DELETE /auth/passkeys/:id (authenticated)
func (h *AuthHandler) PasskeyDelete(c fiber.Ctx) error {
	userID, ok := middleware.UserIDFromCtx(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "not authenticated"})
	}

	credID := c.Params("id")
	if credID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing passkey id"})
	}

	if err := h.passkeySvc.DeletePasskey(c.Context(), userID, credID); err != nil {
		log.Error().Err(err).Str("cred_id", credID).Msg("passkey delete failed")
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to delete passkey"})
	}

	return c.JSON(fiber.Map{"ok": true})
}

// ───── helpers ─────

func isAllowedRedirect(uri string) bool {
	if uri == "" {
		return false
	}
	for _, scheme := range allowedRedirectSchemes {
		if strings.HasPrefix(uri, scheme) {
			return true
		}
	}
	return false
}

func redirectWithError(c fiber.Ctx, baseRedirect, errCode string) error {
	parsed, err := url.Parse(baseRedirect)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid redirect_uri"})
	}
	query := parsed.Query()
	query.Set("error", errCode)
	parsed.RawQuery = query.Encode()
	return c.Status(fiber.StatusOK).Type("html").SendString(
		buildDeepLinkPage(parsed.String()),
	)
}

// deepLinkPageTpl is the pre-parsed HTML template for the OAuth callback landing page.
var deepLinkPageTpl = template.Must(template.New("deeplink").Parse(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kumoriya</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
       background:#0f0f13;color:#e1e1e6;display:flex;align-items:center;
       justify-content:center;min-height:100vh;text-align:center}
  .card{max-width:380px;padding:40px 32px;border-radius:16px;
        background:#1a1a24;box-shadow:0 8px 32px rgba(0,0,0,.4)}
  .icon{font-size:48px;margin-bottom:16px}
  h1{font-size:20px;font-weight:600;margin-bottom:8px;color:#a78bfa}
  p{font-size:14px;color:#9ca3af;line-height:1.5;margin-bottom:16px}
  .btn{display:inline-block;padding:10px 24px;border-radius:8px;
       background:#a78bfa;color:#0f0f13;font-weight:600;text-decoration:none;
       font-size:14px;transition:background .2s}
  .btn:hover{background:#8b5cf6}
</style>
</head>
<body>
<div class="card">
  <div class="icon">✅</div>
  <h1>Login exitoso</h1>
  <p>Regresando a Kumoriya...<br>Si no se abre automáticamente:</p>
  <a class="btn" id="open" href="{{.URL}}">Abrir Kumoriya</a>
  <p style="margin-top:16px;font-size:12px;color:#6b7280">
    Ya puedes cerrar esta pestaña.
  </p>
</div>
<script>window.location.href={{.URL}};</script>
</body>
</html>`))

// buildDeepLinkPage returns an HTML page that opens the custom-scheme deep link
// and shows a user-friendly message to close the browser tab.
func buildDeepLinkPage(deepLinkURL string) string {
	var buf strings.Builder
	_ = deepLinkPageTpl.Execute(&buf, struct{ URL string }{deepLinkURL})
	return buf.String()
}
