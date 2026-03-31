# Changelog

All notable changes to Kumoriya will be documented in this file.

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
