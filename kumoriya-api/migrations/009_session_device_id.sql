-- Add a persistent device fingerprint to sessions so logins from the same
-- physical device (even after app reinstall) reuse the session slot instead
-- of creating duplicates.
ALTER TABLE sessions ADD COLUMN device_id TEXT;

-- Partial index for the dedup lookup: find active sessions for a user+device.
CREATE INDEX idx_sessions_device ON sessions(user_id, device_id)
  WHERE device_id IS NOT NULL AND NOT revoked;
