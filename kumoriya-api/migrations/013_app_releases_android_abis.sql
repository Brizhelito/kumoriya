-- Android APK split-per-ABI support.
--
-- We keep the legacy `android_url / android_file_name / android_r2_key`
-- columns and interpret them as the universal (fat) APK for backward
-- compatibility. New per-ABI splits (arm64-v8a, armeabi-v7a, x86_64) live
-- in a child table so clients can pick the smallest matching artifact.

CREATE TABLE IF NOT EXISTS app_release_android_artifacts (
    tag        TEXT NOT NULL REFERENCES app_releases(tag) ON DELETE CASCADE,
    abi        TEXT NOT NULL CHECK (abi IN ('universal', 'arm64_v8a', 'armeabi_v7a', 'x86_64')),
    url        TEXT NOT NULL,
    file_name  TEXT NOT NULL DEFAULT '',
    r2_key     TEXT NOT NULL DEFAULT '',
    size_bytes BIGINT NOT NULL DEFAULT 0,
    sha256     TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tag, abi)
);

CREATE INDEX IF NOT EXISTS idx_app_release_android_artifacts_tag
    ON app_release_android_artifacts(tag);

-- Backfill: every existing android_url becomes the 'universal' artifact.
INSERT INTO app_release_android_artifacts (tag, abi, url, file_name, r2_key)
SELECT
    tag,
    'universal',
    android_url,
    COALESCE(android_file_name, ''),
    COALESCE(android_r2_key, '')
FROM app_releases
WHERE android_url IS NOT NULL AND android_url <> ''
ON CONFLICT (tag, abi) DO NOTHING;
