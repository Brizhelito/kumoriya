-- Revoke all active sessions across all users.
-- Safe to run multiple times (idempotent).
UPDATE sessions SET revoked = TRUE WHERE NOT revoked;
