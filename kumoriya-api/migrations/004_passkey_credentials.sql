CREATE TABLE passkey_credentials (
    id              TEXT PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_key      BYTEA NOT NULL,
    attestation_type TEXT NOT NULL,
    transport       TEXT[],
    sign_count      BIGINT NOT NULL DEFAULT 0,
    friendly_name   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_passkey_user ON passkey_credentials(user_id);
