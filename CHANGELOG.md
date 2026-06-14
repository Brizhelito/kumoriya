# Changelog

All notable changes to Kumoriya will be documented in this file.

## [Unreleased]

## [v0.5.0] - 2026-06-14

### Added
- **Miruro source plugin** — new anime source with four resolvers (AniDB, Kwik, VibePlayer, VidTube).
- **Watch Party immersive re-entry** — exit confirmation dialog, active party banner, and player HUD integration.
- **System documentation** — comprehensive ARCHITECTURE, BACKEND, CI/CD, DATA_FLOW, EDGE_INFRASTRUCTURE, FRONTEND, PLUGIN_SYSTEM, and TESTING guides.
- **MIT LICENSE** file.

### Changed
- **Watch Party navigation** — migrated from push-based lobby to pop-based navigation with player HUD.
- **Player page redesigned** — improved controls layout and playback flow.
- **Party session architecture** — refactored session guard, realtime state, and providers for reliability.
- **Party lobby page retired** — replaced by the new navigation flow.
- **Localizations** — updated EN and ES strings for new features.

### Fixed
- **Watch Party lobby navigation** — pushReplacement restored after visiting anime detail page.
- **PartyRoomDO** — improved connection state restoration and reconnection handling.

### Infra / Docs
- **PartyRoomDO properties** — added tests for grace period, host authority, media change resets, ready state consistency, and reconnection state restoration.

## [v0.4.2] - 2026-06-06

### Fixed
- **Player stays playing when you need it** — the video no longer pauses when you pull down the notification panel or change device orientation; it only pauses when the app is actually sent to the background.
- **Better orientation control** — locking the orientation now stays exactly where you set it, and unlocking correctly resumes auto-rotation between landscape modes.
- **Found more episodes for split seasons** — fixed an issue where sources combining Season 1 and Season 2 had their extra episodes hidden if AniList hadn't updated yet.
- **Smarter catalog caching** — improved how we refresh available sources to make sure newly released episodes show up promptly without being lost in the cache.
- **Cleaner episode titles** — titles like "Season 2 Episode 10" from sources are now correctly normalized to match the app's style.

### Added
- **Diagnostic logging** — added internal logging to better track source availability and cache performance.

## [v0.4.1] - 2026-05-10

### Added
- **More ways to discover anime** — Browse, Search, and Season Hub now load smoothly as you scroll, with extra filters by status, year, and season.
- **More rows on Discover** — new Top Airing, Top Movies, and Upcoming sections.
- **Choose the app language** — pick English, Spanish, or follow your device setting.
- **Smarter episode titles** — episode names shown in the player and offline downloads adapt to your language when possible.

### Changed
- **Player feels more reliable** — rotation handling is more accurate and the controls are tidier.
- **Settings and Profile cleaned up** — easier to find what you need; destructive actions are less likely to be tapped by accident.
- **Watch Party overlay polished** — matches the new player look.
- **Manga reader is smoother** — pages load before you reach them, so swipes feel less jumpy.

### Fixed
- **Manga sources and scanlators** — picking what to read is more accurate when several options are available.
- **InManga** — better handling of small markup variations from the source.
- **AniList prewarm** — the backend recovers better from transient errors and puts less pressure on AniList rate limits.

### Infra / Docs
- **Windows builds compile cleanly** — Android-only Firebase pieces are filtered out of the Windows build automatically.
- **Historical release notes rewritten** — v0.1.0–v0.3.0 notes now read as user-facing release notes (in English and Spanish).
- **Release publishing tools** — improved `publish-r2-release.sh` and added a `republish-release-history.sh` helper to backfill old releases without touching the current "latest" tag.

## [v0.4.0] - 2026-05-03

### Added
- **Manga mode** — you can now switch between Anime and Manga from the main app, and each universe has its own look and feel.
- **Manga reader** — new reading experience with vertical and paged modes, chapter navigation, and CBZ support.
- **Manga library** — History, Favorites, and Subscribed now live in a dedicated manga library.
- **More places to find manga** — Kumoriya now brings together MangaDex and several Spanish-language sources so discovery is easier.
- **Better filtering and suggestions** — source and scanlator selection is more helpful when picking what to read.
- **Manga downloads and progress sync** — chapters can be downloaded for offline reading, and your reading progress can sync with your account.
- **Better recovery when AniList is unavailable** — the app now has safer fallbacks so it keeps showing useful content instead of a blank screen.
- **Release updates pushed to the app** — Kumoriya can now be notified when a new release is published.

### Changed
- **The app's look follows the selected universe** — Anime and Manga now feel visually distinct when you switch between them.
- **Manga discovery feels smoother** — the manga home screen loads more reliably and with less waiting.

### Fixed
- **Screen turning off while watching** — the player now keeps the screen awake during playback.
- **Brightness not restoring after playback** — leaving the player now returns brightness to its previous level.
- **Missed airing notifications** — the app now catches recently aired episodes more reliably.

## [v0.3.0] - 2026-04-24

### Added
- **Smarter sync** — Kumoriya now keeps checking for changes more often, so it can stay in sync without relying on a single button.
- **Better pull behavior** — when you return to the app, it now checks for remote changes automatically.
- **Android downloads rebuilt** — large files and HLS downloads are handled more reliably.
- **Three downloads at a time** — extra downloads wait their turn instead of overwhelming the device.
- **Resume after restart** — downloads can pick up again if the app closes or the process dies.
- **Downloads that keep going** — closing the app or swiping it away is much less likely to stop active downloads.
- **Clearer error handling** — the app now knows better when to retry, wait, or stop a failed download.
- **APK by architecture** — Android users get a better-sized download for their device instead of always receiving the biggest package.
- **WiFi-only support** — downloads pause and resume automatically when the network changes.
- **Better download notifications** — each download has its own controls, plus a summary for all of them.

### Changed
- **Lighter Android app** — the app no longer ships desktop-only video pieces on Android.
- **Shared network foundation** — playback and downloads now use the same HTTP base so they behave more consistently.

### Fixed
- **Downloads UI now updates right away** — progress and state changes show up immediately.
- **HLS downloads now start correctly** — HLS content is handled the right way instead of getting stuck.
- **Early events no longer vanish** — startup events are buffered until Flutter is ready.
- **Cancel now cleans up properly** — cancelled downloads are removed instead of being left in a bad state.
- **Less confusion with custom headers** — download headers are no longer duplicated in the URL.
- **Cold start recovery works again** — queued tasks reconnect correctly after app restart.
- **Swiping away the app no longer kills everything** — downloads are kept alive more reliably.
- **Cancel cleanup is more complete** — temporary HLS leftovers are removed more thoroughly.
- **Retry spam is better handled** — repeated taps no longer over-count active work.

### Infra / Docs
- **APK size baseline documented** — a size breakdown was added so future release work can focus on the biggest wins.

## [v0.2.0] - 2026-04-18

### Added
- **Watch Party screens** — anime and episode pages were redesigned around room context and group playback.
- **Faster AniList home** — trending, seasonal, and airing content now load from the backend with caching.
- **Airing episode alerts** — anime subscriptions now sync better with your notification settings.
- **Shared release feed** — the app and website now read release info from the API.

### Changed
- **Watch Party navigation** — browsing, playback, and returning to the lobby now feels more consistent.
- **Profile layout** — Watch Party is easier to notice, while sensitive actions are less prominent.
- **Simpler notifications flow** — local episode notifications were replaced with push notifications.
- **Website release source** — the website now uses the API feed instead of hand-maintained JSON.

### Fixed
- **Release publishing stayed fresh** — new releases now refresh the API right away.
- **Notification channel mismatch** — Android and backend now use the same episode alert channel.
- **Safer profile actions** — destructive actions are now less likely to be tapped by mistake.

## [v0.1.4] - 2026-04-02

### Added
- **Clear queue button** — you can now clear pending and failed downloads with confirmation.

### Changed
- Cancelling or clearing now removes items from the list first, while cleanup continues in the background.

### Fixed
- **Windows cancel delay** — cancelled downloads disappear immediately.
- **Leftover HLS folders** — old segment folders are cleaned up on startup.
- **Safer resolver responses** — odd text responses are handled more safely.
- **Refresh after leaving the screen** — downloads refresh avoids errors if the screen is already gone.

## [v0.1.3] - 2026-04-01

### Added
- **Browse Anime page** — filter anime by genre, format, and sort order, including multiple genres.
- **Tag-guided discovery** — browse AniList tags by category to find anime more easily.
- **Bug report button** — send feedback and issues directly from the app.
- **Error monitoring** — helps the team spot problems and fix them faster.
- **Seasonal discovery** — current, upcoming, and recommended anime are now grouped together.
- **More AniList data in one go** — the app can request more genre, tag, and metadata info at once.
- **Watch history tools** — history can be viewed, deleted, or cleared.
- **Faster cache lookup** — multiple IDs can be prefetched at once.

### Changed
- **Seek accumulation** — quick taps now build up jumps so skipping is more precise.
- **Safer auto-next** — the next episode is less likely to trigger by mistake.
- **More playback fallbacks** — extra mirrors were added to improve availability.
- **Better title matching** — some hyphenated titles now match more naturally.
- **Fewer network calls** — browsing and discovery now use fewer round-trips.
- Download failures now leave better breadcrumbs for debugging.

### Fixed
- **Player teardown crashes** — closing playback is now safer.
- **Seek indicator** — the skip indicator now reflects the accumulated jump.
- **Playback shutdown** — stopping before closing reduces race conditions.

## [v0.1.2] - 2026-03-31

### Added
- Settings now shows the installed app version.

### Changed
- App version bumped to `0.1.2+3`.

### Fixed
- Update checks now run at startup on Android and Windows.

## [v0.1.1] - 2026-03-31

### Added
- Faster update downloads using multiple connections.
- Better Android network handling for big files.
- Permission support for installing updates.
- Storage access requested earlier during setup.
- A debug-only forced update screen for testing.
- More AniList data saved locally.
- Better storage queries for browsing and search.

### Changed
- Android app identity changed to `dev.kumoriya.app` and `Kumoriya`.
- Debug and release builds can now coexist on the same device.
- Download path dialogs are now localized.
- Update downloads avoid extra compression so the file arrives correctly.

### Fixed
- Update installs now tell you what to do if permission is denied.
- The first-launch download folder dialog now respects your language.

## [v0.1.0] - 2026-03-30

### Added / Agregado
- First public alpha release for Android and Windows.
- In-app update checks using a remote release file.
- Update dialog with release notes.
- Android update download and install handoff.
- Windows installer handoff with safe app closing.

### Changed / Cambios
- Release metadata is now centralized.
- Release publishing now uses versioned artifacts per platform.

### Fixed / Corregido
- None for the baseline release.
