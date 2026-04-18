# Changelog

All notable changes to Kumoriya will be documented in this file.

## [Unreleased]

### Added
- **Server-side AniList home cache (Go backend)** — trending, seasonal discovery, and airing calendar are now served from `api.kumoriya.online/v1/anilist/home/*` with in-memory SWR caching, prewarm scheduler, and conservative TTLs (trending 10m, season 30m, calendar 5m). Clients hit the backend first and transparently fall back to direct AniList on any backend failure. Reduces AniList rate-limit pressure across the fleet.
- **Firebase Cloud Messaging push notifications for airing episodes** — `media_{anilistId}` topic subscriptions mirror the `notify_new_episodes` library toggle; topics are reconciled after login (post-migration) and on every app boot with an active session. Server-side `AiringWorker` polls the cached airing calendar, dedupes via Upstash Redis `SETNX`, and fans out via Firebase topics.
- **Backend-first AniList metadata gateway decorator** — `BackendFirstAnilistMetadataGateway` intercepts `fetchHomeCatalog` and `fetchSeasonDiscovery`; feature-flag `KUMORIYA_GO_ANILIST_HOME` (default on) allows rollback without redeploy.

### Changed
- **Legacy new-episodes background worker reduced to auto-download only** — local-notification path removed (redundant with FCM push). Worker cadence dropped from 1h to 4h to reduce scraping traffic. Only anime with `auto_download_new_episodes=true` produce network activity.
- **FCM notification channel aligned** between Go server (`AiringWorker`) and Android client: both use `kumoriya_new_episodes`.

### Removed
- Debug-only "Test notificacion" button in Settings (targeted the removed local-notification path).

## [v0.1.4] - 2026-04-02

### Added
- **Clear download queue button** — queue tab now shows a "Clear queue" action with confirmation dialog that removes all pending and failed tasks.

### Changed
- Download cancel/clear operations now remove tasks from UI/store first, then perform artifact cleanup in background for immediate UI feedback.

### Fixed
- **Windows cancel delay in Downloads UI** — cancelled tasks now disappear immediately instead of waiting on large HLS segment folder deletion.
- **Orphan HLS segment folders after app restart** — startup cleanup now removes stale `*_segments` directories not linked to active tasks (Windows/Android).
- **FormatException on resolver responses** — resolver plugins now use malformed-safe UTF-8 decoding for non-UTF-8 embed responses.
- **StateError: Using "ref" after widget unmount** — downloads refresh now guards `ref.invalidate()` after async gaps.

## [v0.1.3] - 2026-04-01

### Added
- **Browse Anime Page** — advanced genre/format/sort filtering with multi-genre selection and persistent filter state.
- **Tag-Guided Anime Finder** — discover anime by AniList tags organized by category, with inline step-by-step guide.
- **Bug Report Button** — in-app feedback widget in Settings that captures user reports directly to Sentry with tagging and categorization.
- **Sentry crash monitoring** — full error tracking and user feedback integration via `sentry_flutter`.
- **Consolidated Seasonal Discovery** — single AniList request combining current-season, upcoming, and recommended anime.
- **AniList genre/tag collection queries** — fetch all valid genres and tags in one request each.
- **Batch anime metadata fetch** — load full catalog data for a list of AniList IDs in one request.
- **Watch history management** — `getAllHistory`, `deleteHistoryEntry`, and `clearAllHistory` methods in storage.
- **AniList cache batch lookup** — `getByIds` for prefetching cache by ID list.

### Changed
- **Player seek accumulation** — double-tap seek zones now accumulate ±10s with visual Delta indicator (e.g. "+30s"), commits after 800ms idle. Keyboard arrows support accumulation.
- **Safer auto-next episode** — prevents position listeners from re-triggering auto-next during page transition.
- **StreamWish mirror fallback** — added 3 new mirror hosts (`sfastwish.com`, `awish.pro`, `wishfast.top`); primary failures try mirrors before giving up.
- **Honorific-hyphen normalization** — titles like "Hime-sama" now correctly match "Himesama" in AniList matching.
- **Consolidated AniList GraphQL queries** — fewer network round-trips for browsing and discovery.
- Download resolution failures now log detailed Sentry breadcrumbs.

### Fixed
- Disposed engine crashes — race where media_kit teardown triggered operations on already-disposed native player.
- Player seek indicator now shows dynamic accumulated Delta instead of fixed ±10s.
- Better playback teardown — stop before dispose reduces race windows.

## [v0.1.2] - 2026-03-31

### Added
- Settings now shows the installed app version in the App section.

### Changed
- App version bumped to `0.1.2+3`.

### Fixed
- Update availability check now runs automatically at startup on Android and Windows, so release builds can detect remote updates without relying on debug-only actions.

## [v0.1.1] - 2026-03-31

### Added
- Parallel 4-connection range-based APK download accelerator (falls back to single-stream if server does not support range requests).
- Native Android HTTP client via Cronet engine — same network stack used by Chrome and Android WebView, significantly faster than Dart's built-in client for large downloads.
- `REQUEST_INSTALL_PACKAGES` permission in Android manifest.
- Android storage access permission request on first launch (before download path dialog).
- Debug forced-update dialog in Settings — opens the update install flow without requiring a newer remote version, for testing.
- Storage: five new AniList cache columns — `synonyms`, `season`, `popularity`, `nextAiringEpisode`, `nextAiringAt`.
- Storage: four new DAO query methods — `getRecent`, `getByStatus`, `getByYearAndStatus`, `searchByTitle`.

### Changed
- Android application ID changed from `com.example.kumoriya_app` to `dev.kumoriya.app`.
- Android app display name changed from `kumoriya_app` to `Kumoriya`.
- Android app category set to `video`.
- Debug builds use `applicationIdSuffix = ".debug"` and display label `Kumoriya (DEBUG)` so debug and release can coexist on the same device.
- Download path first-launch dialog is now fully localized (ES + EN).
- All update download requests include `Accept-Encoding: identity` to prevent CDN compression on binary payloads.

### Fixed
- Update installer failing silently when `REQUEST_INSTALL_PACKAGES` was denied — now prompts the user to the system settings to grant the permission.
- First-launch download folder dialog showing English text regardless of device locale.

## [v0.1.0] - 2026-03-30

### Added / Agregado
- Initial public alpha app release for Android and Windows.
- App update check flow via remote `update.json` manifest hosted on Cloudflare R2.
- In-app update dialog with version comparison and release notes display.
- Android update download and APK installer handoff.
- Windows update installer handoff with app close-before-install behavior.

### Changed / Cambios
- Release process now supports centralized version metadata in R2.
- Release publishing path now targets platform-specific versioned artifacts.

### Fixed / Corregido
- N/A for baseline release.
