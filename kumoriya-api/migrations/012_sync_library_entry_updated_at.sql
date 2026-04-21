-- Add an explicit LWW cursor to the library table. Previously `added_at`
-- doubled as both the favorite-creation timestamp and the LWW key via
-- `LEAST(old, new)`, which made it impossible to represent "user unfavorited
-- at time T" (the added_at would stick at the older value) and was prone to
-- data resurrection on pulls.
--
-- The new `updated_at` column is the authoritative LWW key. `added_at` keeps
-- its semantic meaning ("when this became a favorite"; 0 = not favorite).
ALTER TABLE sync_library_entry
    ADD COLUMN IF NOT EXISTS updated_at BIGINT NOT NULL DEFAULT 0;

-- Backfill: use existing added_at so rows created before this migration are
-- still reachable by the LWW logic.
UPDATE sync_library_entry
SET    updated_at = added_at
WHERE  updated_at = 0;
