package model

// TokenPair holds the JWT access token and opaque refresh token.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"` // seconds until access token expires
}

// OAuthUserInfo represents the profile returned by an OAuth provider.
type OAuthUserInfo struct {
	ProviderID  string
	Provider    string
	DisplayName string
	Email       string
	AvatarURL   string
}
