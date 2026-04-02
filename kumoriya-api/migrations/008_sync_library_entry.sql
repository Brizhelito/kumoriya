CREATE TABLE sync_library_entry (
    user_id                      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    anilist_id                   INTEGER NOT NULL,
    added_at                     BIGINT NOT NULL,
    notify_new_episodes          BOOLEAN NOT NULL DEFAULT FALSE,
    last_notified_episode        INTEGER,
    auto_download_new_episodes   BOOLEAN NOT NULL DEFAULT FALSE,
    auto_download_audio_preference TEXT DEFAULT 'none',
    PRIMARY KEY (user_id, anilist_id)
);
