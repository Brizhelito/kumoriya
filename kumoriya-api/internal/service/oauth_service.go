package service

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"golang.org/x/oauth2"

	"go-fiber-microservice/internal/model"
)

// httpClient uses public DNS (Google + Cloudflare) so token exchange
// works inside containers whose internal resolver cannot reach
// external domains (common in HF Spaces).
var httpClient = &http.Client{
	Timeout: 15 * time.Second,
	Transport: &http.Transport{
		DialContext: (&net.Dialer{
			Timeout:  5 * time.Second,
			Resolver: &net.Resolver{
				PreferGo: true,
				Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
					d := net.Dialer{Timeout: 3 * time.Second}
					// Try Google DNS first, then Cloudflare
					conn, err := d.DialContext(ctx, "udp", "8.8.8.8:53")
					if err != nil {
						conn, err = d.DialContext(ctx, "udp", "1.1.1.1:53")
					}
					return conn, err
				},
			},
		}).DialContext,
	},
}

type OAuthService struct {
	discordCfg *oauth2.Config
	googleCfg  *oauth2.Config
}

func NewOAuthService(
	discordClientID, discordSecret, discordRedirect string,
	googleClientID, googleSecret, googleRedirect string,
) *OAuthService {
	return &OAuthService{
		discordCfg: &oauth2.Config{
			ClientID:     discordClientID,
			ClientSecret: discordSecret,
			RedirectURL:  discordRedirect,
			Scopes:       []string{"identify", "email"},
			Endpoint: oauth2.Endpoint{
				AuthURL:  "https://discord.com/api/oauth2/authorize",
				TokenURL: "https://discord.com/api/oauth2/token",
			},
		},
		googleCfg: &oauth2.Config{
			ClientID:     googleClientID,
			ClientSecret: googleSecret,
			RedirectURL:  googleRedirect,
			Scopes:       []string{"openid", "profile", "email"},
			Endpoint: oauth2.Endpoint{
				AuthURL:  "https://accounts.google.com/o/oauth2/v2/auth",
				TokenURL: "https://oauth2.googleapis.com/token",
			},
		},
	}
}

func (s *OAuthService) GetAuthURL(provider, state string) (string, error) {
	cfg, err := s.configFor(provider)
	if err != nil {
		return "", err
	}
	return cfg.AuthCodeURL(state, oauth2.AccessTypeOffline), nil
}

func (s *OAuthService) ExchangeCode(ctx context.Context, provider, code string) (*model.OAuthUserInfo, error) {
	cfg, err := s.configFor(provider)
	if err != nil {
		return nil, err
	}

	// Use our custom httpClient with public DNS.
	ctx = context.WithValue(ctx, oauth2.HTTPClient, httpClient)
	token, err := cfg.Exchange(ctx, code)
	if err != nil {
		return nil, fmt.Errorf("oauth exchange: %w", err)
	}

	switch provider {
	case "discord":
		return s.fetchDiscordProfile(ctx, token.AccessToken)
	case "google":
		return s.fetchGoogleProfile(ctx, token.AccessToken)
	default:
		return nil, fmt.Errorf("unsupported provider: %s", provider)
	}
}

func (s *OAuthService) configFor(provider string) (*oauth2.Config, error) {
	switch provider {
	case "discord":
		return s.discordCfg, nil
	case "google":
		return s.googleCfg, nil
	default:
		return nil, fmt.Errorf("unsupported oauth provider: %s", provider)
	}
}

func (s *OAuthService) fetchDiscordProfile(ctx context.Context, accessToken string) (*model.OAuthUserInfo, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://discord.com/api/v10/users/@me", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("discord api: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("discord api status %d: %s", resp.StatusCode, body)
	}

	var data struct {
		ID            string `json:"id"`
		Username      string `json:"username"`
		GlobalName    string `json:"global_name"`
		Email         string `json:"email"`
		Avatar        string `json:"avatar"`
		Discriminator string `json:"discriminator"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, fmt.Errorf("discord json: %w", err)
	}

	displayName := data.GlobalName
	if displayName == "" {
		displayName = data.Username
	}

	var avatarURL string
	if data.Avatar != "" {
		avatarURL = fmt.Sprintf("https://cdn.discordapp.com/avatars/%s/%s.png?size=256", data.ID, data.Avatar)
	}

	return &model.OAuthUserInfo{
		ProviderID:  data.ID,
		Provider:    "discord",
		DisplayName: displayName,
		Email:       data.Email,
		AvatarURL:   avatarURL,
	}, nil
}

func (s *OAuthService) fetchGoogleProfile(ctx context.Context, accessToken string) (*model.OAuthUserInfo, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", "https://www.googleapis.com/oauth2/v2/userinfo", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("google api: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("google api status %d: %s", resp.StatusCode, body)
	}

	var data struct {
		ID      string `json:"id"`
		Name    string `json:"name"`
		Email   string `json:"email"`
		Picture string `json:"picture"`
	}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, fmt.Errorf("google json: %w", err)
	}

	return &model.OAuthUserInfo{
		ProviderID:  data.ID,
		Provider:    "google",
		DisplayName: data.Name,
		Email:       data.Email,
		AvatarURL:   data.Picture,
	}, nil
}
