# Notifications & auto-download pipeline

Status: Active (Slice 6 completed 2026-04-18).

## Responsibilities at a glance

| Concern                          | Who owns it                        |
|----------------------------------|------------------------------------|
| AniList home surfaces (trending, season, airing calendar) | Go backend cache `/v1/anilist/home/*` with SWR fallback on the client |
| Detect airing episode            | Go backend `AiringWorker` polling AniList cache |
| Deduplicate notifications        | Upstash Redis (`SETNX` + TTL)      |
| User-facing push notification    | Firebase Cloud Messaging topic `media_{anilistId}` |
| Topic subscribe/unsubscribe      | Flutter `FcmAwareLibraryStore` decorator |
| Topic reconciliation on login    | `FcmTopicSyncService` after sync pull |
| Topic reconciliation on boot     | `FcmTopicSyncService` in `AuthStateNotifier.build()` |
| Auto-download of new episodes    | Flutter `CheckNewEpisodesWorker` (Workmanager, 4h cadence) |
| Source availability + resolver   | Device-local plugins (unchanged)   |

## Why the worker still exists

FCM gives the user instant notification of a new episode, but **the source
sites (JKAnime, Animeflv, etc.) typically upload episodes 30 min – 24 h
after AniList's airing timestamp**. If auto-download were triggered
directly by the FCM push, the availability check would almost always
fail the first time.

The worker polls on a 4 h cadence and covers that gap naturally: in the
worst case the user sees the FCM notification immediately and the
episode is auto-downloaded 0–4 h after the source publishes.

The worker only processes anime with `auto_download_new_episodes=true`,
so idle users produce zero scraping traffic.

## Known limitations / future slices

### Rate-limit scaling with many users

Every device with auto-download enabled scrapes the source independently.
If 1 000 users subscribe to the same airing anime, the source receives
≈1 000 requests per 4 h window. This is N× what it needs to be.

**Planned mitigations:**

1. **Collaborative availability cache (server-side)**
   First device that resolves availability for `{anilistId, episode}`
   uploads a signed summary to the Go backend with a short TTL. Later
   devices read from the backend and skip the scrape. Collapses N
   requests → 1 request + N reads. Requires:
   - `POST /v1/availability/{anilistId}/{episode}` — content-addressable,
     checksum-signed to resist cache poisoning.
   - `GET  /v1/availability/{anilistId}/{episode}` — public, TTL ~30 min.
   - Clients prefer cache, fall back to scrape on miss or signature fail.

2. **FCM-triggered one-shot + retries (Plan B')**
   On FCM push receipt, schedule an immediate availability check and
   up to 3 retries at 30 min / 2 h / 6 h. Gives near-instant download
   for sources with fast upload windows while tolerating slow ones.
   Replaces or supplements the periodic worker.

3. **Server-side source availability (Plan A, discarded)**
   Porting the scraping plugins to Go would be a massive effort and
   would break the plugin-first architecture that keeps per-device
   flexibility (headers, cookies, geo). Explicitly not on the roadmap.

### Silent push failures

`FcmTopicSyncService.syncTopicsWithLibrary()` is local→FCM only. If the
user unsubscribes on another device while this one is offline, the
stale topic subscription remains on FCM. Messages still arrive, but
`AiringWorker` won't send new ones for that user (server-side `Redis`
dedup + absence of `notify_new_episodes=true` on pulled state), so the
impact is minor. A future slice could add server-side "list my
subscriptions" reconciliation using an authenticated token endpoint.

## Operational notes

- Server env:
  - `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_FILE`
  - `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`
  - Missing either Firebase or Redis credentials → `AiringWorker`
    skips startup, logs a warning, rest of the API continues.
- Client build flags:
  - `KUMORIYA_GO_ANILIST_HOME=false` disables backend-first home.
  - `KUMORIYA_API_BASE_URL=...` overrides the Go backend URL.
- Channel ID: `kumoriya_new_episodes` on both server payload and
  Android client channel; created in `_initNotifications` at app boot.
