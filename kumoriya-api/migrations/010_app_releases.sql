CREATE TABLE app_releases (
    tag                    TEXT PRIMARY KEY,
    version                TEXT NOT NULL UNIQUE,
    channel                TEXT NOT NULL DEFAULT 'alpha',
    release_date           DATE NOT NULL,
    manifest_release_notes TEXT NOT NULL,
    summary_es             TEXT NOT NULL,
    summary_en             TEXT NOT NULL,
    notes_es_markdown      TEXT NOT NULL,
    notes_en_markdown      TEXT NOT NULL,
    android_url            TEXT,
    android_file_name      TEXT,
    android_r2_key         TEXT,
    windows_url            TEXT,
    windows_file_name      TEXT,
    windows_r2_key         TEXT,
    is_latest              BOOLEAN NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_app_releases_latest
    ON app_releases(is_latest)
    WHERE is_latest;

CREATE INDEX idx_app_releases_date
    ON app_releases(release_date DESC, created_at DESC);
