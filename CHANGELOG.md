# Changelog

All notable changes to Kumoriya will be documented in this file.

## [Unreleased]

## [v0.2.0] - 2026-04-18

### Added
- **Dedicated Watch Party surfaces** — party anime and episode pages now have their own room-first layouts, making it much easier to understand members, readiness, room state, and the collaborative launch flow.
- **Server-side AniList home cache (Go backend)** — trending, seasonal discovery, and airing calendar are now served from `api.kumoriya.online/v1/anilist/home/*` with in-memory SWR caching and conservative TTLs to reduce AniList rate-limit pressure.
- **Firebase Cloud Messaging push notifications for airing episodes** — `media_{anilistId}` topic subscriptions now mirror the `notify_new_episodes` toggle and are reconciled after login and on app boot.
- **Backend-first AniList metadata gateway** — clients now prefer backend-powered home/discovery fetches with transparent fallback to direct AniList on backend failure.
- **API-driven release feed** — release metadata now lives in Neon and is served through `api.kumoriya.online/releases/*`, enabling the app and website to read a shared source of truth.

### Changed
- **Watch Party navigation flow** — party browse and playback routes now preserve room context correctly and return users to the lobby instead of unwinding the global navigation stack.
- **Profile hierarchy** — Watch Party is now a prominent CTA, logout is more visible, and destructive/account metadata actions are much more discreet to reduce accidental taps.
- **Legacy new-episodes worker reduced to auto-download only** — local notifications were removed in favor of FCM push, and worker cadence was reduced to lower scraping traffic.
- **Website release data source** — homepage downloads and changelog entries now consume the API-backed release feed instead of hand-maintained JSON as the primary source.

### Fixed
- **Release publish staleness** — release metadata no longer depends on a one-time manifest fetch; publishing a new version now refreshes the API cache immediately.
- **Airing notification channel drift** — Android and backend now use the same `kumoriya_new_episodes` channel.
- **Accidental account deletion risk in Profile** — destructive actions and the account UUID are now visually de-emphasized compared with the main session actions.

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
