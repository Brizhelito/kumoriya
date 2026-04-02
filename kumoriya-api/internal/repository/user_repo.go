package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"go-fiber-microservice/internal/model"
)

type UserRepo struct {
	pool *pgxpool.Pool
}

func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool}
}

func (r *UserRepo) CreateUser(ctx context.Context, displayName string, avatarURL *string) (*model.User, error) {
	u := &model.User{
		ID:          uuid.New(),
		DisplayName: displayName,
		AvatarURL:   avatarURL,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	_, err := r.pool.Exec(ctx,
		`INSERT INTO users (id, display_name, avatar_url, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		u.ID, u.DisplayName, u.AvatarURL, u.CreatedAt, u.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) GetUserByID(ctx context.Context, id uuid.UUID) (*model.User, error) {
	u := &model.User{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, display_name, avatar_url, created_at, updated_at FROM users WHERE id = $1`, id,
	).Scan(&u.ID, &u.DisplayName, &u.AvatarURL, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) UpdateAvatar(ctx context.Context, id uuid.UUID, avatarURL string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE users SET avatar_url = $1, updated_at = now() WHERE id = $2`,
		avatarURL, id,
	)
	return err
}

func (r *UserRepo) UpdateDisplayName(ctx context.Context, id uuid.UUID, displayName string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE users SET display_name = $1, updated_at = now() WHERE id = $2`,
		displayName, id,
	)
	return err
}

func (r *UserRepo) DeleteUser(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, id)
	return err
}

// --- OAuth Accounts ---

func (r *UserRepo) UpsertOAuthAccount(ctx context.Context, acct *model.OAuthAccount) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO oauth_accounts (id, user_id, provider, provider_id, email, access_token, refresh_token, token_expiry)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		 ON CONFLICT (provider, provider_id)
		 DO UPDATE SET email = EXCLUDED.email,
		              access_token = EXCLUDED.access_token,
		              refresh_token = EXCLUDED.refresh_token,
		              token_expiry = EXCLUDED.token_expiry`,
		acct.ID, acct.UserID, acct.Provider, acct.ProviderID,
		acct.Email, acct.AccessToken, acct.RefreshToken, acct.TokenExpiry,
	)
	return err
}

func (r *UserRepo) FindOAuthAccount(ctx context.Context, provider, providerID string) (*model.OAuthAccount, error) {
	a := &model.OAuthAccount{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, provider, provider_id, email, created_at
		 FROM oauth_accounts WHERE provider = $1 AND provider_id = $2`,
		provider, providerID,
	).Scan(&a.ID, &a.UserID, &a.Provider, &a.ProviderID, &a.Email, &a.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return a, nil
}

// --- Sessions ---

func (r *UserRepo) CreateSession(ctx context.Context, s *model.Session) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO sessions (id, user_id, refresh_hash, device_name, ip_address, expires_at, created_at)
		 VALUES ($1, $2, $3, $4, $5::inet, $6, $7)`,
		s.ID, s.UserID, s.RefreshHash, s.DeviceName, s.IPAddress, s.ExpiresAt, s.CreatedAt,
	)
	return err
}

func (r *UserRepo) GetActiveSessionsByUser(ctx context.Context, userID uuid.UUID) ([]model.Session, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, refresh_hash, device_name, host(ip_address), expires_at, created_at, revoked
		 FROM sessions
		 WHERE user_id = $1 AND NOT revoked AND expires_at > now()
		 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []model.Session
	for rows.Next() {
		var s model.Session
		if err := rows.Scan(&s.ID, &s.UserID, &s.RefreshHash, &s.DeviceName, &s.IPAddress, &s.ExpiresAt, &s.CreatedAt, &s.Revoked); err != nil {
			return nil, err
		}
		sessions = append(sessions, s)
	}
	return sessions, rows.Err()
}

func (r *UserRepo) UpdateSessionHash(ctx context.Context, sessionID uuid.UUID, newHash string, newExpiry time.Time) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE sessions SET refresh_hash = $1, expires_at = $2 WHERE id = $3`,
		newHash, newExpiry, sessionID,
	)
	return err
}

func (r *UserRepo) RevokeSession(ctx context.Context, sessionID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE sessions SET revoked = TRUE WHERE id = $1`, sessionID,
	)
	return err
}

func (r *UserRepo) RevokeAllSessions(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE sessions SET revoked = TRUE WHERE user_id = $1`, userID,
	)
	return err
}

func (r *UserRepo) CountActiveSessions(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sessions WHERE user_id = $1 AND NOT revoked AND expires_at > now()`,
		userID,
	).Scan(&count)
	return count, err
}

func (r *UserRepo) RevokeOldestSession(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE sessions SET revoked = TRUE
		 WHERE id = (
		   SELECT id FROM sessions
		   WHERE user_id = $1 AND NOT revoked AND expires_at > now()
		   ORDER BY created_at ASC
		   LIMIT 1
		 )`, userID,
	)
	return err
}

// --- Passkey Credentials ---

func (r *UserRepo) CreatePasskeyCredential(ctx context.Context, cred *model.PasskeyCredential) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO passkey_credentials (id, user_id, public_key, attestation_type, transport, sign_count, friendly_name)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		cred.ID, cred.UserID, cred.PublicKey, cred.AttestationType, cred.Transport, cred.SignCount, cred.FriendlyName,
	)
	return err
}

func (r *UserRepo) GetPasskeysByUser(ctx context.Context, userID uuid.UUID) ([]model.PasskeyCredential, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, public_key, attestation_type, transport, sign_count, friendly_name, created_at
		 FROM passkey_credentials WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var creds []model.PasskeyCredential
	for rows.Next() {
		var c model.PasskeyCredential
		if err := rows.Scan(&c.ID, &c.UserID, &c.PublicKey, &c.AttestationType, &c.Transport, &c.SignCount, &c.FriendlyName, &c.CreatedAt); err != nil {
			return nil, err
		}
		creds = append(creds, c)
	}
	return creds, rows.Err()
}

func (r *UserRepo) UpdatePasskeySignCount(ctx context.Context, credID string, signCount uint32) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE passkey_credentials SET sign_count = $1 WHERE id = $2`,
		signCount, credID,
	)
	return err
}

func (r *UserRepo) DeletePasskey(ctx context.Context, credID string, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM passkey_credentials WHERE id = $1 AND user_id = $2`,
		credID, userID,
	)
	return err
}
