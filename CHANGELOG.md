# Changelog

All notable changes to Kumoriya will be documented in this file.

## [Unreleased]

## [v0.3.0] - 2026-04-24

### Added
- **Event-driven sync coordinator** — sync-to-server ya no depende solo del botón "Sync Now". `SyncCoordinator` orquesta seis triggers: escrituras locales con debounce de 500 ms, `AppLifecycleState.resumed` (fullSync si la última sincronización es > 6 h), reconexión de red vía `connectivity_plus`, `paused` con programación de una `OneTimeWorkRequest` en Android, flush bloqueante antes de logout (timeout 5 s), y tarea periódica de Workmanager cada 12 h como fallback absoluto. Incluye lock de push único en vuelo, backoff exponencial en fallo y skip automático cuando el dispositivo está offline para no envenenar las entradas con reintentos reales.
- **Pull independiente del push** — nuevo `SyncCoordinator.triggerPull()` que llama solo `pullSince(lastSyncAt)` sin encolar un push, con lock `_pulling` separado. Al volver a foreground ahora siempre se hace pull (debounceado a 30 s entre resumes), y se programa un timer periódico de 30 min mientras la app está abierta para ver cambios de otros dispositivos del mismo usuario sin esperar al próximo cierre/apertura. Base lista para la integración futura con FCM silent push.
- **Native downloader rebuilt from scratch (Android)** — `kumoriya_exoplayer` ships a standalone OkHttp + coroutines download engine that replaces the legacy Media3 `DownloadManager` path. Direct MP4/WebM/MKV via a range-aware `ParallelDownloader`, HLS via segment fetch + optional Media3 `Transformer` remux to MP4 (with `.ts` concat fallback on failure or low disk). Target files land in the user-chosen directory (`DownloadDirectoryService`).
- **Download queue with concurrency cap** — at most three downloads run in parallel; the rest wait as `PENDING` in a FIFO queue and are promoted automatically as slots free up. Each active download still chunks internally via `ParallelDownloader` Range requests when the server supports them.
- **Auto-resume on cold start** — tasks that were `downloading`, `pending`, `remuxing`, or `disconnected` when the process died are re-enqueued to the native engine on next app launch. Downloaders resume from `.state.json` + `.partial` bytes without re-downloading completed segments. Paused tasks stay paused.
- **Downloads survive app close / swipe-away** — engine, notification center, and event sink are now process-scope; Flutter attach/detach only wires channels. `FOREGROUND_SERVICE_DATA_SYNC` keeps downloads running after the user swipes the app from recents, with `android:stopWithTask="false"` and an explicit `onTaskRemoved` override.
- **Retry + error taxonomy** — `DownloadErrorClassifier` maps failures into `FailFast` / `RetryOnce` / `RetryBackoff` / `StorageFull` / `Disconnected`. 5xx and timeouts retry 1/2/4/8/16s (cap 5); 404 retries once; 401/403/410 fail fast. Terminal failures now carry a stable `errorCode` (e.g. `download.storage_full`, `download.server_error_503`) alongside the message.
- **Android APK split per ABI** — release pipeline now builds `arm64-v8a`, `armeabi-v7a`, `x86_64`, and `universal` APKs. The in-app updater auto-detects the device ABI via `device_info_plus` and downloads the matching split (~35-45 MB each) instead of the ~90 MB universal APK. The API (`/releases/latest`) and update manifest expose both `universal` and per-ABI slots (`abis.arm64_v8a`, etc.) with SHA-256 and size for integrity checks.
- **WiFi-only + auto-resume on reconnect** — toggling "WiFi only" or losing connectivity auto-pauses active + queued tasks with `DISCONNECTED`; tasks resume automatically when an acceptable network returns.
- **Per-task + summary download notifications** — each active download has its own notification with Pause/Resume/Cancel actions; a grouped summary exposes Pause all / Resume all.

### Changed
- **`media_kit_libs_video` replaced with desktop-only libs** — `media_kit_libs_linux`, `media_kit_libs_windows_video`, `media_kit_libs_macos_video` are pulled explicitly so the Android APK no longer ships libmpv / libavcodec / libdav1d (~30-50 MB of `.so` saved). Android playback runs exclusively through `kumoriya_exoplayer` (Media3); `MediaKit.ensureInitialized()` is gated with `!Platform.isAndroid`.
- **`DownloadBackend` contract** — a single abstraction routes Android to `NativeDownloadBackend` and desktop to `DartDownloadBackend` (wraps the existing `DownloadManagerService`). Use cases and UI depend on the contract, not on concrete backends.
- **Unified HTTP stack** — player and downloader now share `KumoriyaHttpClient` (single OkHttp `OkHttpClient` singleton with pool, redirects, timeouts, and UA extraction). Media3 playback uses `OkHttpDataSource.Factory` instead of `DefaultHttpDataSource`.

### Fixed
- **UI de descargas no se actualizaba** — el flujo nativo ahora emite eventos de `state` explícitos (pending → downloading → completed/failed) y el servicio Dart los refleja inmediatamente en Drift y en los streams de Riverpod, así la tab Active muestra progreso en vivo.
- **Descargas quedaban atascadas** — Media3 trataba todos los streams como progressive, bajando solo el `.m3u8`; ahora las URLs HLS van por un `HlsDownloadPreparer` con el MIME correcto.
- **Eventos tempranos perdidos** — el sink del `EventChannel` es mutable y con buffer: eventos que ocurren antes de que Flutter suscriba se drenan al adjuntarse.
- **Cancelar dejaba la descarga marcada como `failed`** — cancelar ahora borra el task de Drift y limpia segmentos/caché temporales (cancel = delete).
- **Headers custom duplicados en la URL** al entregar una descarga al plugin nativo.
- **Queue stuck after cold start** — before the reconciliation pass, tasks in `pending`/`downloading` in Drift had no matching native job; pause/resume were no-ops.
- **Swipe-away killed downloads** — Flutter detach used to destroy the engine and stop the FGS, taking every in-flight download with it. Engine ownership moved to a process-scope singleton (`DownloadCore`).
- **`.ts` and `.mp4` artifacts orphaned on cancel** — the cancel path now sweeps both HLS remux variants plus their `.partial` siblings.
- **Auto-pause lost task on enqueue race** — the waiting queue is locked so concurrent enqueues cannot over-count active jobs; duplicate resume/retry clicks dedupe on `taskId`.

### Infra / Docs
- **APK release baseline documented** — `docs/apk-size-analysis.md` captures per-ABI sizes (35.4 MB armv7 / 42.3 MB arm64 / 45.1 MB x86_64), component breakdown, and a prioritised list of follow-up optimisations (AAB migration, `flutter_webrtc` removal, media_kit web-only assets).

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
