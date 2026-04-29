-- Manga universe sync tables (Slice 10C-2). Each table mirrors the shape
-- of its anime counterpart so the existing LWW + write-buffer + flush
-- pipeline reuses the same code paths.
--
-- All client-assigned timestamps are millisecond Unix epoch; the server
-- relies on `updated_at` (or `last_accessed_at` for the history table)
-- as the LWW key. Per-row primary keys mirror the manga storage layer
-- on the device:
--
--   library:  one row per (user, manga)
--   progress: one row per (user, manga, source, chapter id)
--   history:  one row per (user, manga)  -- "most-recently-read"
--
-- The Drift wire encoding on the client uses the same column names so a
-- future replication path can stream rows without server-side mapping.

CREATE TABLE IF NOT EXISTS sync_manga_library_entry (
    user_id                      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    manga_anilist_id             INTEGER NOT NULL,
    added_at                     BIGINT NOT NULL,
    notify_new_chapters          BOOLEAN NOT NULL DEFAULT FALSE,
    auto_download_new_chapters   BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_language           TEXT,
    preferred_scanlator          TEXT,
    last_notified_chapter        DOUBLE PRECISION,
    -- Authoritative LWW key. 0 = not yet favorited (mirrors the anime
    -- table's semantics post-012).
    updated_at                   BIGINT NOT NULL,
    PRIMARY KEY (user_id, manga_anilist_id)
);

CREATE TABLE IF NOT EXISTS sync_manga_chapter_progress (
    user_id                      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    manga_anilist_id             INTEGER NOT NULL,
    source_id                    TEXT NOT NULL,
    source_chapter_id            TEXT NOT NULL,
    chapter_number               DOUBLE PRECISION NOT NULL,
    page_index                   INTEGER NOT NULL DEFAULT 0,
    -- Vertical-mode scroll offset (logical pixels). NULL in paginated
    -- mode; explicit so a future client can pick the right resume key
    -- per layout without an extra schema change.
    scroll_offset                DOUBLE PRECISION,
    read_state                   TEXT NOT NULL DEFAULT 'unread',
    updated_at                   BIGINT NOT NULL,
    PRIMARY KEY (user_id, manga_anilist_id, source_id, source_chapter_id)
);

CREATE TABLE IF NOT EXISTS sync_manga_read_history (
    user_id                      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    manga_anilist_id             INTEGER NOT NULL,
    last_chapter_number          DOUBLE PRECISION NOT NULL,
    last_source_id               TEXT,
    last_source_chapter_id       TEXT,
    last_page_index              INTEGER,
    last_accessed_at             BIGINT NOT NULL,
    PRIMARY KEY (user_id, manga_anilist_id)
);

-- Helper indexes that mirror the anime side. Pulls always filter by
-- (user_id, <ts>) so a composite index is the natural shape.
CREATE INDEX IF NOT EXISTS idx_sync_manga_library_entry_user_updated
    ON sync_manga_library_entry (user_id, updated_at);

CREATE INDEX IF NOT EXISTS idx_sync_manga_chapter_progress_user_updated
    ON sync_manga_chapter_progress (user_id, updated_at);

CREATE INDEX IF NOT EXISTS idx_sync_manga_read_history_user_accessed
    ON sync_manga_read_history (user_id, last_accessed_at);
