CREATE TABLE sync_episode_progress (
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    anilist_id           INTEGER NOT NULL,
    episode_number       REAL NOT NULL,
    position_seconds     INTEGER NOT NULL,
    total_duration_seconds INTEGER,
    watch_state          TEXT NOT NULL DEFAULT 'unwatched',
    last_source_plugin_id TEXT,
    last_server_name     TEXT,
    last_resolver_plugin_id TEXT,
    updated_at           BIGINT NOT NULL,
    PRIMARY KEY (user_id, anilist_id, episode_number)
);
