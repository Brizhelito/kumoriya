# Kumoriya Storage System — Full Audit Report
**Date:** 2026-03-10
**Scope:** Product + Architecture + Implementation + Reliability
**No code was modified during this audit.**

---

# 1. MCPs Used

| MCP | Purpose |
|-----|---------|
| **dart-mcp-server** | `add_roots`, `run_tests` — ran all 16 storage tests (all pass) |
| **kumoriya-mcp** | Architecture rules reference |
| **filesystem** (code_search, grep, read) | Full codebase traversal of `kumoriya_storage`, `kumoriya_app` wiring, player, detail, providers |

**Code changed during audit:** None.

---

# 2. Current Storage Inventory

## 2.1 Technology
- **Drift 2.32** over **SQLite** (via `sqlite3_flutter_libs`)
- Single `AppDatabase` instance, opened once in `main.dart` via `openAppDatabase()`
- In-memory database helper for tests (`openInMemoryDatabase`)
- Schema version: **1** — no migration strategy defined

## 2.2 Tables (4 total)

| Table | PK | Columns | Purpose |
|-------|-----|---------|---------|
| `episode_progress` | `(anilist_id, episode_number)` | position_seconds, total_duration_seconds, watch_state, last_source_plugin_id, last_server_name, last_resolver_plugin_id, updated_at | Per-episode playback position & state |
| `watch_history` | `(anilist_id)` | last_episode_number, last_source_plugin_id, last_accessed_at | One row per anime — most-recent activity |
| `playback_preference` | `(anilist_id)` | preferred_source_plugin_id, preferred_server_name, preferred_resolver_plugin_id, preferred_audio_preference, updated_at | Per-anime source/server/audio preference |
| `source_availability_cache` | `(anilist_id, source_plugin_id)` | payload_json, updated_at | Cached source availability snapshot (JSON blob per source) |

## 2.3 DAOs (2)

| DAO | Tables accessed |
|-----|-----------------|
| `ProgressDao` | episode_progress, watch_history, playback_preference |
| `SourceAvailabilityCacheDao` | source_availability_cache |

## 2.4 Store Contracts (4 interfaces)

| Contract | Status |
|----------|--------|
| `AnimeProgressStore` | **Fully implemented** — `DriftAnimeProgressStore` |
| `SourceAvailabilityStore` | **Fully implemented** — `DriftSourceAvailabilityStore` |
| `DownloadStore` | **Contract only** — no Drift implementation, no table, no DAO |
| `LibraryStore` | **Contract only** — no Drift implementation, no table, no DAO |

## 2.5 App-Layer Wiring

| Provider/UseCase | Location | Role |
|------------------|----------|------|
| `appDatabaseProvider` | `storage_providers.dart` | Singleton DB, overridden at `ProviderScope` |
| `animeProgressStoreProvider` | `storage_providers.dart` | Creates `DriftAnimeProgressStore` |
| `sourceAvailabilityStoreProvider` | `storage_providers.dart` | Creates `DriftSourceAvailabilityStore` |
| `continueWatchingProvider` | `storage_providers.dart` | `getRecentHistory(limit: 10)` |
| `latestEpisodeProgressProvider` | `storage_providers.dart` | Per-anime latest progress |
| `animeEpisodeProgressListProvider` | `storage_providers.dart` | All episodes' progress for an anime |
| `playbackPreferenceProvider` | `storage_providers.dart` | Per-anime playback preference |
| `episodeProgressProvider` | `storage_providers.dart` | Single episode progress by (anilistId, episodeNumber) |
| `SaveProgressUseCase` | `player/application/` | Saves progress with 90% completion threshold, 5s minimum |
| `SavePlaybackPreferenceUseCase` | `player/application/` | Persists successful source/server selection |
| `ClearPlaybackPreferenceUseCase` | `player/application/` | Clears stale preference row |
| `LoadSourceAvailabilitySummaryUseCase` | `anime_catalog/application/` | Cache-first with TTL + background refresh |
| `SourceAvailabilityCacheCodec` | `anime_catalog/application/services/` | JSON encode/decode with versioned payloads (v2) |
| `PlaybackPreferencePolicy` | `anime_catalog/application/services/` | Reconciles preference vs available options |
| `StartEpisodePlaybackUseCase` | `anime_catalog/application/` | Reads preference + progress, resolves best option |

## 2.6 Player ↔ Storage Wiring

- `PlayerPage.initState()` creates `SaveProgressUseCase`, `SavePlaybackPreferenceUseCase`, `ClearPlaybackPreferenceUseCase` directly from `animeProgressStoreProvider`
- Progress saved: on pause, every 15 seconds while playing, on dispose, on exit
- Resume position loaded from `AnimeProgressStore.getProgress()` at playback start
- Successful selection persisted via `SavePlaybackPreferenceUseCase` after first stream opens
- On exit: flushes progress, invalidates `continueWatchingProvider`, `latestEpisodeProgressProvider`, `animeEpisodeProgressListProvider`

---

# 3. Storage vs Product Needs

## 3.1 Progress Persistence

| Requirement | Status | Notes |
|-------------|--------|-------|
| Anime ID | **Implemented** | `anilist_id` in all tables |
| Current episode | **Implemented** | `episode_number` (double, supports .5 episodes) |
| Position | **Implemented** | `position_seconds` (int) |
| Total duration | **Implemented** | `total_duration_seconds` (nullable int) |
| Completed flag | **Implemented** | `watch_state` enum (unwatched/watching/completed) |
| Last access timestamp | **Implemented** | `updated_at` (milliseconds epoch) |
| Last source used | **Implemented** | `last_source_plugin_id` (nullable) |
| Last server used | **Implemented** | `last_server_name` (nullable) |
| Last resolver used | **Implemented** | `last_resolver_plugin_id` (nullable) |

**Verdict: Implemented well.**

## 3.2 Continue Watching / History

| Requirement | Status | Notes |
|-------------|--------|-------|
| Continue watching list | **Implemented** | `watch_history` ordered by `last_accessed_at` DESC |
| Recently watched | **Implemented** | Same table, limit-based query |
| Last episode opened | **Implemented** | `last_episode_number` in `watch_history` |
| Re-entry point | **Partially implemented** | History knows the episode, but lacks `position_seconds` — must join with `episode_progress` |
| Order by activity | **Implemented** | `ORDER BY last_accessed_at DESC` |

**Verdict: Partially implemented** — the continue-watching card must fetch progress separately to show position/percentage. This causes an extra async lookup per card at render time.

## 3.3 Playback Preferences

| Requirement | Status | Notes |
|-------------|--------|-------|
| Preferred source per anime | **Implemented** | `preferred_source_plugin_id` |
| Preferred server per anime | **Implemented** | `preferred_server_name` |
| SUB/DUB preference | **Implemented** | `preferred_audio_preference` (sub/dub enum) |
| Quality preference | **Missing** | No column, no model field |
| Last successful playback | **Partially implemented** | Tracked on `episode_progress` per episode, not aggregated at anime level |
| Preference invalidation | **Implemented** | `PlaybackPreferencePolicy.reconcile()` + `invalidateAfterAutoFailure()` |

**Verdict: Partially implemented** — quality preference is missing; last success is episode-level only.

## 3.4 Source Availability Cache

| Requirement | Status | Notes |
|-------------|--------|-------|
| Cache per anime/source | **Implemented** | PK = `(anilist_id, source_plugin_id)` |
| Serve detail fast | **Implemented** | `LoadSourceAvailabilitySummaryUseCase` reads cache first |
| Avoid aggressive recomputation | **Implemented** | TTL: 6h fresh, 3d max stale, 10min for unavailable |
| Controlled refresh | **Implemented** | Background refresh via `shouldRefreshInBackground` |
| Handle stale cache | **Implemented** | Cache rejected if > `maxStaleAge`, background refresh if > `freshTtl` |
| Invalidate incompatible versions | **Implemented** | `cacheVersion = 2`; decode throws `FormatException` on mismatch |

**Verdict: Implemented well.** This is the strongest part of the storage system.

## 3.5 Detail Fluency Support

| Requirement | Status | Notes |
|-------------|--------|-------|
| Reduce perceived latency | **Implemented** | Cache-first pattern + `keepAlive()` on provider |
| Precache/reuse detail data | **Partially implemented** | Availability is cached; AniList detail is NOT cached to DB (in-memory only via `keepAlive`) |
| Anime → episodes → playback flow | **Implemented** | Storage supports all three stages |
| Source badges without re-scraping | **Implemented** | Served from cache when fresh |

**Verdict: Partially implemented** — AniList detail/metadata is not persisted to storage; it exists only as in-memory Riverpod cache which is lost on cold restart.

## 3.6 Download Foundations

| Requirement | Status | Notes |
|-------------|--------|-------|
| `DownloadStore` contract | **Defined** | Full interface with `DownloadTask` model, `DownloadStatus` enum |
| `DownloadTask` model | **Well-designed** | id, anilistId, episodeNumber, sourceUrl, status, filePath, totalBytes, downloadedBytes, sourcePluginId, serverName, detectedHost, errorMessage |
| Drift table | **Missing** | No `download_task_table.dart` |
| DAO | **Missing** | No download DAO |
| Implementation | **Missing** | No `DriftDownloadStore` |

**Verdict: Contract only** — the model is solid but there's zero persistence. Foundation is good for future work.

## 3.7 Library / Favorites

| Requirement | Status | Notes |
|-------------|--------|-------|
| `LibraryStore` contract | **Defined** | `setFavorite()`, `getFavoriteAnimeIds()` |
| Drift table | **Missing** | No favorites table |
| Implementation | **Missing** | No `DriftLibraryStore` |

**Verdict: Contract only.**

## 3.8 Scalability

| Requirement | Status |
|-------------|--------|
| Manga/Manhwa/Novels | **Not blocked** — `anilist_id` is generic enough. `episode_number` would need semantic expansion (chapter_number) |
| More sources | **Not blocked** — source_plugin_id is a string key |
| More preferences | **Partially prepared** — preference table would need new columns or a key-value extension |

**Verdict: Reasonable** — no structural blocker, but episode-centric naming will need adaptation for manga.

---

# 4. Architecture Audit

## 4.1 Responsibility Separation

| Layer | Assessment |
|-------|------------|
| **Tables** | Clean. No business logic. Pure schema. |
| **DAOs** | Clean. Raw CRUD only. No domain interpretation. |
| **Store implementations** | Clean. Map between Drift rows and domain models. Return `Result<T, KumoriyaError>`. |
| **Store contracts** | Clean. Interface + domain models. No Drift dependency. |
| **Use cases** | Clean. Business rules (completion threshold, min save, TTL) live here, not in storage. |
| **Providers** | Clean. Thin wiring, no logic leakage. |

**No contamination detected.** The separation between persistence (storage package) and business logic (app use cases) is well-maintained.

## 4.2 Coupling Assessment

| Coupling | Verdict |
|----------|---------|
| Storage ↔ Source plugins | **None.** Storage stores plugin IDs as strings, never imports plugin packages. |
| Storage ↔ Player | **Clean.** Player talks to storage through `AnimeProgressStore` interface. `PlayerSessionOrchestrator` has zero storage references — only the page-level widget saves progress. |
| Storage ↔ UI | **Clean.** UI reads via Riverpod providers backed by store contracts. |
| `ProgressDao` scope | **Slightly broad.** One DAO manages 3 tables (progress, history, preference). Not a bug, but `PlaybackPreferenceDao` could be separated for clarity. |

## 4.3 Structural Issues

1. **`ProgressDao` is a mega-DAO** — it manages `episode_progress`, `watch_history`, AND `playback_preference`. This overloads its responsibility. Preference operations should likely be a separate DAO.

2. **`DriftAnimeProgressStore` is a mega-store** — it implements progress, history, AND preference operations through one interface. The `AnimeProgressStore` contract bundles three distinct concerns:
   - Episode progress CRUD
   - Watch history
   - Playback preferences
   
   This isn't broken, but it's a cohesion smell. If any of these grows in complexity, the contract will become unwieldy.

3. **No `DownloadStore` or `LibraryStore` implementations** — the contracts are exported from the package barrel but have no Drift backing. Any consumer importing them gets a promise with no fulfillment.

---

# 5. Data Model / Schema Audit

## 5.1 Schema Strengths

- **Composite primary keys** are correct: `(anilist_id, episode_number)` for progress, `(anilist_id, source_plugin_id)` for cache
- **`watch_history` uses `anilist_id` as sole PK** — guarantees one entry per anime, auto-upserts correctly
- **Nullable metadata columns** (source, server, resolver) are appropriate — not all saves include them
- **`watch_state` as text enum** with default `'unwatched'` is safe for forward compatibility
- **`episode_number` as `real` (double)** handles `.5` episodes correctly
- **`updated_at` as integer (epoch ms)** is consistent across all tables
- **Cache payload as JSON blob** — flexible, versioned, allows schema-independent evolution

## 5.2 Schema Weaknesses

1. **No indices beyond primary keys.** The `watch_history` table queries by `ORDER BY last_accessed_at DESC` with no index — will degrade with history growth. The `episode_progress` table queries by `anilist_id` alone (for `getAllProgress`, `getLatestProgress`) without a covering index.

2. **No migration strategy.** `schemaVersion` is `1`, and `AppDatabase` has no `migration` getter override. Adding any column, table, or index in the future will require a migration plan — currently there is nothing to handle this. **This is a time bomb for any schema change.**

3. **`watch_history` lacks position context.** The continue-watching flow must JOIN with `episode_progress` to get position/duration. The `watch_history` table could carry `last_position_seconds` and `last_total_duration_seconds` to avoid the extra query.

4. **No `created_at` on `episode_progress` or `playback_preference`.** Only `updated_at` exists. For future analytics or "first watched" features, the creation timestamp is lost on every upsert.

5. **`preferredAudioPreference` stored as nullable text.** A null value is ambiguous — does it mean "no preference" or "not yet set"? There's no sentinel value to distinguish.

6. **No TTL column on `source_availability_cache`.** TTL logic is computed by the use case at read time using `updated_at` + hardcoded durations. This works but means the DB can't self-clean stale entries. Old cache rows accumulate forever.

7. **Download and Library tables don't exist.** The contracts are exported, creating an expectation that is unmet.

## 5.3 Duplication Risks

- **`last_source_plugin_id` appears in both `episode_progress` and `watch_history`.** Not a true duplication (different semantic scope), but they can diverge if a race condition occurs during upsert.
- **Source/server info lives in both `episode_progress` (per episode) and `playback_preference` (per anime).** This is intentional (episode-level success vs anime-level preference), but reconciliation logic in `PlaybackPreferencePolicy` must keep them coherent.

## 5.4 Migration/Versioning Risks

- **CRITICAL: No migration strategy defined.** Any schema change (new column, new table, new index) will crash existing users unless a migration is added before shipping.
- **Cache version is `2`** — the codec correctly rejects unknown versions via `FormatException`. This is solid.
- **No DB backup/export mechanism.** If the schema migrates badly, user data is lost.

---

# 6. Real Flow Audit

## 6.1 Playback Save/Resume

**Flow:** Play episode → save position → close → reopen → resume

| Step | Works? | Notes |
|------|--------|-------|
| Save on pause | **Yes** | `_onPlayingChanged(false)` triggers `_saveCurrentProgress()` |
| Save periodically | **Yes** | Every 15 seconds via `Timer.periodic` |
| Save on dispose | **Yes** | `unawaited(_saveCurrentProgress())` in `dispose()` |
| Save on back-press | **Yes** | `_handleExitRequested()` → `_flushProgressAndRefresh()` awaits flush |
| Load resume position | **Yes** | `_loadResumePosition()` reads from store, skips if completed or < 5s |
| Completion detection | **Yes** | 90% threshold in `SaveProgressUseCase._resolveWatchState()` |
| History update | **Yes** | Every progress save also upserts `watch_history` |

**Risk:** `dispose()` calls `unawaited(_saveCurrentProgress())`. If the app is killed or the DB closes before the fire-and-forget completes, the last progress save is lost. This is a minor but real data-loss risk on hard kill.

## 6.2 Continue Watching

**Flow:** Open home → show continue watching cards → tap to resume

| Step | Works? | Notes |
|------|--------|-------|
| Fetch history | **Yes** | `continueWatchingProvider` → `getRecentHistory(limit: 10)` |
| Show title + image | **Yes** | Resolves from catalog or fetches AniList detail |
| Show episode number | **Yes** | `entry.lastEpisodeNumber` |
| Show progress % | **Requires extra fetch** | Must read `episode_progress` separately — not in `watch_history` |
| Tap to resume | **Yes** | Loads availability summary, prepares playback decision, opens player |
| Invalidation after playback | **Yes** | `ref.invalidate(continueWatchingProvider)` on player exit |

**Risk:** Continue watching cards for anime not in the home catalog must fetch AniList detail individually. If AniList is slow, the card shows "AniList #12345" temporarily.

## 6.3 Anime Detail Cache-First

**Flow:** Open detail → show availability badges → tap episode → play

| Step | Works? | Notes |
|------|--------|-------|
| Read cache | **Yes** | `LoadSourceAvailabilitySummaryUseCase._readCached()` |
| Serve stale-but-valid cache | **Yes** | Up to `maxStaleAge` (3 days) |
| Background refresh | **Yes** | If age > `freshTtl` (6h) or missing sources, `shouldRefreshInBackground` triggers async refresh |
| Persist refreshed data | **Yes** | `_refresh()` calls `_store.replaceAvailability()` |
| Provider stays alive | **Yes** | `ref.keepAlive()` on `sourceAvailabilitySummaryProvider` |

**Solid flow.** This is the most polished storage-backed flow.

## 6.4 Source Preference Reuse

**Flow:** Play with source X/server Y → next time auto-select same combo

| Step | Works? | Notes |
|------|--------|-------|
| Save preference on success | **Yes** | `_persistSuccessfulSelection()` after stream opens |
| Load preference at start | **Yes** | `StartEpisodePlaybackUseCase._loadPreference()` |
| Reconcile with available options | **Yes** | `PlaybackPreferencePolicy.reconcile()` checks if preferred source/server/resolver still available |
| Invalidate on failure | **Yes** | `invalidateAfterAutoFailure()` clears broken preference fields |
| Clear preference explicitly | **Yes** | `ClearPlaybackPreferenceUseCase` called when `persistSelection` is false |

**Solid flow.**

## 6.5 Stale/Unavailable Cache Recovery

| Step | Works? | Notes |
|------|--------|-------|
| Reject cache older than `maxStaleAge` | **Yes** | Falls through to fresh compute |
| Unavailable sources refresh faster | **Yes** | `unavailableFreshTtl` = 10 minutes |
| New source plugins trigger refresh | **Yes** | `missingCoverage` check in use case |
| Versioned cache decode | **Yes** | `cacheVersion` mismatch throws `FormatException`, treated as cache miss |
| No cleanup of old cache rows | **Issue** | Rows for anime you'll never visit again accumulate forever |

## 6.6 Download Foundations

| Step | Works? |
|------|--------|
| Persist download task | **No** — contract only |
| Track download progress | **No** — contract only |
| Resume download | **No** — contract only |

---

# 7. Reliability and Performance Audit

## 7.1 Stale Cache Risks

- **Source availability cache rows never expire at the DB level.** Old entries for rarely-visited anime accumulate. Over months of use this is wasteful but not catastrophic — the table only stores one JSON blob per anime × source.
- **In-memory `keepAlive()` caches (animeDetail, sourceAvailabilitySummary) are lost on cold restart.** This means every app launch pays a full AniList + scrape cost for the first few navigations.

## 7.2 Recomputation Risks

- **Continue watching cards** may trigger up to 10 individual `episode_progress` lookups to show position bars. This is N+1 but acceptable at N ≤ 10.
- **`sourceAvailabilitySummaryProvider` triggers a full scrape** if cache is stale, even if the user just wanted to browse. The background-refresh pattern mitigates this well, but the initial compute on cache miss can be 5-15 seconds.

## 7.3 Excessive Writes

- **Progress is saved every 15 seconds during playback.** This is reasonable. The write is a single upsert (INSERT ON CONFLICT UPDATE) — efficient.
- **Watch history is updated on every progress save.** This means the `watch_history` row for the current anime is overwritten every 15 seconds. Harmless but unnecessary — updating `watch_history` only on episode change or session boundaries would be more efficient.

## 7.4 Weak Invalidation

- **No mechanism to purge old source availability cache entries.** A future cleanup job or LRU eviction would help.
- **Playback preference is never cleaned up when a source plugin is removed.** If a user had `preferred_source_plugin_id = 'kumoriya.source.foo'` and that plugin is removed, the preference row persists. The `PlaybackPreferencePolicy.reconcile()` handles this at read time, but the stale row stays forever.

## 7.5 Dead Paths

- **`LibraryStore` and `DownloadStore`** contracts are exported but never imported by the app. They are dead code.
- **`kumoriya_storage_base.dart`** contains only a `@Deprecated` typedef to `Never` — legacy artifact, should be removed.

## 7.6 Data Consistency Risks

- **`watch_history.last_source_plugin_id` can become null** if the next progress save omits it. The history entry then loses track of which source was used. This is the expected behavior per the upsert logic, but it means the continue-watching card can't always show the source badge.
- **Double as PK component (`episode_number`)**: Floating-point equality in SQLite comparisons for PKs is technically safe (SQLite stores exact representations for values like `1.0`, `2.5`), but unconventional. No current bug, but any arithmetic on the key before lookup could introduce subtle mismatches.
- **`dispose()` fire-and-forget save**: On hard app kill, the last 15 seconds of progress may be lost.

---

# 8. Test Coverage Audit

## 8.1 Storage Package Tests (16 tests, all pass)

| File | Tests | Coverage |
|------|-------|----------|
| `drift_anime_progress_store_test.dart` | 11 | upsert, overwrite, history write, latest progress, all progress ordering, recent history, playback preference CRUD, preference partial update, preference clearing |
| `drift_source_availability_store_test.dart` | 4 | replace + read, clear |
| `kumoriya_storage_test.dart` | 1 | Model constructibility smoke test |

### What's well-covered
- Basic CRUD for all implemented stores
- Upsert-overwrite semantics
- History update on progress save
- Preference save/read/clear including partial field updates

### What's weakly covered
- No test for concurrent writes / race conditions
- No test for large datasets (performance regression)
- No test for edge cases: `episodeNumber = 0.0`, `positionSeconds = 0`, `updatedAt = 0`
- No test for `SourceAvailabilityCacheCodec` decode with malformed/legacy JSON
- No schema migration tests (there are none to test)

### What's missing entirely
- **No integration tests** that exercise the full flow (save progress → read continue watching → load resume position)
- **No tests for `DownloadStore` or `LibraryStore`** (no implementation exists)
- **No tests for `watch_history` being updated atomically with `episode_progress`** (transactional guarantee)
- **No tests for TTL-based cache freshness logic** (lives in use case, not storage, but the interaction is untested at the storage level)

## 8.2 App-Level Tests Touching Storage

| File | What it tests |
|------|---------------|
| `save_progress_use_case_test.dart` | Completion threshold, min position, watchState resolution |
| `load_source_availability_summary_use_case_test.dart` | Cache-first, TTL, background refresh, version mismatch |
| `start_episode_playback_use_case_test.dart` | Preference reconciliation, option ranking, fallback |
| `home_continue_watching_desktop_test.dart` | Widget rendering of continue watching section |

These use mocks for storage, so they test business logic but not real DB round-trips.

---

# 9. Top Issues (Priority Order)

| # | Issue | Severity | User Impact | Technical Impact | Fix Direction |
|---|-------|----------|-------------|------------------|---------------|
| 1 | **No migration strategy** | **CRITICAL** | Any schema change crashes existing users | Blocks all future schema evolution | Add `migration` getter to `AppDatabase` with stepwise migration plan; add schema migration tests |
| 2 | **No DB indices beyond PKs** | **HIGH** | Continue watching and history queries slow down over time | O(n) scans on `watch_history.last_accessed_at`, `episode_progress.anilist_id` | Add indices on `watch_history(last_accessed_at)` and `episode_progress(anilist_id, updated_at)` |
| 3 | **`AnimeProgressStore` bundles 3 concerns** | **MEDIUM** | None directly | Makes the interface harder to evolve, test, and reason about | Consider splitting into `EpisodeProgressStore`, `WatchHistoryStore`, `PlaybackPreferenceStore` or at minimum separate the contracts |
| 4 | **`watch_history` lacks position context** | **MEDIUM** | Continue watching cards can't show progress % without extra query | N+1 reads for home page | Add `last_position_seconds`, `last_total_duration_seconds` to `watch_history` table |
| 5 | **`watch_history` upserted every 15s** | **LOW** | None | Unnecessary writes during normal playback | Update history only on session start, episode change, or session end |
| 6 | **No cache cleanup** | **LOW** | Old data accumulates over months | Slight DB size growth | Add periodic cleanup or LRU eviction for source availability cache |
| 7 | **`dispose()` fire-and-forget progress save** | **LOW** | Last 15s of progress can be lost on hard kill | Minor data loss | Already mitigated by 15s periodic saves; could add `AppLifecycleListener` for `onDetach` |
| 8 | **Dead code: `LibraryStore`, `DownloadStore` exports, `kumoriya_storage_base.dart`** | **LOW** | None | Noise in the codebase | Remove dead legacy file; keep contracts if they're on the roadmap, otherwise remove exports |
| 9 | **No `created_at` timestamps** | **LOW** | No "first watched" analytics possible | Limits future features | Add `created_at` column alongside `updated_at` when next schema change occurs |
| 10 | **`preferredAudioPreference` null ambiguity** | **TRIVIAL** | None visible | Minor code clarity issue | Document that null means "no preference set" |

---

# 10. Recommended Roadmap

## Phase 1: Stabilize Foundations (Before Any New Feature)

1. **Add migration strategy to `AppDatabase`** — implement `migration` getter with at least a no-op v1→v2 pattern and test scaffolding. This unblocks everything else.
2. **Add DB indices** — index `watch_history(last_accessed_at DESC)` and `episode_progress(anilist_id, updated_at DESC)` as part of v2 migration.

## Phase 2: Refine Core Storage

3. **Enrich `watch_history`** — add `last_position_seconds` and `last_total_duration_seconds` to eliminate N+1 on continue-watching.
4. **Throttle `watch_history` upserts** — only write on session start/end and episode transitions, not every 15s.
5. **Add `created_at` columns** to `episode_progress` and `playback_preference`.

## Phase 3: Strengthen Availability Cache

6. **Add cache cleanup** — periodic purge of entries older than `maxStaleAge` for anime not in recent history.
7. **Consider adding TTL/expiry column** to `source_availability_cache` for DB-level queries.

## Phase 4: Prepare Download & Library

8. **Implement `DriftDownloadStore`** — add `download_task` table, DAO, implementation. The contract is already solid.
9. **Implement `DriftLibraryStore`** — add `favorites` table, DAO, implementation.

## Phase 5: Clean Up

10. **Remove `kumoriya_storage_base.dart`** — dead code.
11. **Consider splitting `AnimeProgressStore`** — evaluate if the single interface is becoming unwieldy.
12. **Add integration tests** — end-to-end flow tests (save → resume, cache → refresh, preference → reconcile).

---

# 11. Final Truth Summary

## Overall Verdict: **Usable but fragile**

The storage layer of Kumoriya is **architecturally clean and functionally correct for its current scope**. The separation between persistence contracts and business logic is exemplary. The source availability cache system is genuinely well-designed with proper TTL, versioning, and background refresh patterns.

**However, the system has critical fragility:**

- **No migration strategy** means the first schema change will break existing users. This is the single biggest risk.
- **No DB indices** means performance will silently degrade as history and progress grow.
- **Two of four store contracts have no implementation** — the download and library foundations are promises only.
- **Continue watching requires extra queries** due to `watch_history` lacking position context.

**What's solid:**
- Episode progress persistence (save, resume, completion detection)
- Source availability caching (TTL, versioning, background refresh, stale handling)
- Playback preference lifecycle (save, reconcile, invalidate, clear)
- Architecture boundaries (storage never touches plugins, player, or UI directly)
- Test coverage of core CRUD operations

**What's broken or risky:**
- Migration strategy (non-existent — **must fix before any schema change**)
- Missing indices (performance time bomb)
- Dead code and unimplemented contracts

**What's missing:**
- Download persistence
- Library/favorites persistence
- AniList metadata caching to DB (detail is in-memory only)
- Quality preference
- Analytics timestamps (`created_at`)

**Bottom line:** The storage layer is well-architected but incomplete. It supports the current product MVP correctly, but it is **not yet sufficient for product growth** without the migration foundation and the missing implementations. The recommended fix order is: migrations → indices → history enrichment → downloads → library.
