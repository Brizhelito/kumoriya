CREATE TABLE sync_watch_history (
    user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    anilist_id               INTEGER NOT NULL,
    last_episode_number      REAL NOT NULL,
    last_source_plugin_id    TEXT,
    last_position_seconds    INTEGER NOT NULL DEFAULT 0,
    last_total_duration_seconds INTEGER,
    last_accessed_at         BIGINT NOT NULL,
    PRIMARY KEY (user_id, anilist_id)
);
