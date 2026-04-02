CREATE TABLE sync_playback_preference (
    user_id                    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    anilist_id                 INTEGER NOT NULL,
    preferred_source_plugin_id TEXT,
    preferred_server_name      TEXT,
    preferred_resolver_plugin_id TEXT,
    preferred_audio_preference TEXT,
    updated_at                 BIGINT NOT NULL,
    PRIMARY KEY (user_id, anilist_id)
);
