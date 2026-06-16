# Data Flow & Synchronization

> **How data moves through the Kumoriya system: from scraping to playback, from local to cloud, from device to device.**

---

## Table of Contents

1. [Data Flow Overview](#data-flow-overview)
2. [Content Discovery Pipeline](#content-discovery-pipeline)
3. [Episode Playback Pipeline](#episode-playback-pipeline)
4. [Multi-Device Sync Protocol](#multi-device-sync-protocol)
5. [Offline-First Strategy](#offline-first-strategy)
6. [Download Pipeline](#download-pipeline)
7. [Notification Pipeline](#notification-pipeline)
8. [Watch Party Data Flow](#watch-party-data-flow)

---

## Data Flow Overview

Kumoriya has **six primary data pipelines**:

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA PIPELINES                           │
│                                                              │
│  1. Content Discovery:  AniList API → Cache → UI            │
│  2. Episode Playback:   Source → Resolver → Player          │
│  3. Multi-Device Sync:  Local DB ↔ Go API ↔ Neon            │
│  4. Downloads:          Resolver → HLS/MP4 → Local Storage  │
│  5. Notifications:      AniList → Redis → FCM → Device      │
│  6. Watch Party Voice:  WebRTC P2P mesh via DO signaling    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Content Discovery Pipeline

### Home Feed Loading

```
User opens app
      │
      ▼
HomePage builds → watches homeFeedProvider
      │
      ▼
homeFeedProvider checks AniList cache (Drift)
      │
      ├── Cache HIT (fresh, < 30 days)
      │     │
      │     ▼
      │   Return cached data immediately
      │     │
      │     ▼
      │   Background: refresh from API (SWR pattern)
      │
      └── Cache MISS or STALE
            │
            ▼
        Call Go API: GET /anilist/home
            │
            ├── Success
            │     │
            │     ▼
            │   Store in cache → Return data
            │
            └── Failure (network error, API down)
                  │
                  ▼
              Check cache for stale data
                  │
                  ├── Has stale cache
                  │     │
                  │     ▼
                  │   Return stale data + show fallback banner
                  │
                  └── No cache at all
                        │
                        ▼
                    Show error state with retry button
```

### Search Flow

```
User types query
      │
      ▼
Debounce 300ms
      │
      ▼
Search provider calls AniList GraphQL directly
      │
      ▼
Results cached in memory (session only)
      │
      ▼
UI renders search results with poster, title, format, year
```

### Detail Page Flow

```
User taps anime
      │
      ▼
animeDetailProvider(anilistId) checks cache
      │
      ├── Cache HIT → Return immediately
      │
      └── Cache MISS → Fetch from AniList API
            │
            ▼
        Store in cache → Return data
            │
            ▼
        Parallel: check source availability
          - Query each source plugin for this anime
          - Cache availability results (7-day TTL)
```

---

## Episode Playback Pipeline

### Complete Flow

```
User taps episode
      │
      ▼
1. Source Selection
   ├── Check user playback preferences
   ├── Check source availability cache
   └── Select best available source
      │
      ▼
2. Server Link Extraction
   └── SourcePlugin.getEpisodeServerLinks(episode)
       └── Parse episode page HTML
       └── Extract server links (URL + server name + language)
      │
      ▼
3. Resolver Selection
   └── ResolverRegistry.select(serverLinks)
       ├── For each link: filter resolvers by supports(url)
       ├── Sort by priority
       └── Return best resolver per link (or ambiguity)
      │
      ▼
4. Stream Resolution
   └── ResolverPlugin.resolve(link.url)
       ├── Fetch hosting page
       ├── Extract playable URL from JS/HTML
       ├── Attach required headers (Referer, Origin)
       └── Return ResolvedStream(url, qualityLabel, headers)
      │
      ▼
5. Player Initialization
   └── PlayerSessionOrchestrator
       ├── Configure media_kit / ExoPlayer
       ├── Set source URL + headers
       ├── Restore last position (if resuming)
       └── Start playback
      │
      ▼
6. Progress Tracking
   └── Periodic timer (every 5 seconds)
       ├── Save position to local DB
       └── Queue sync push (debounced)
```

### Error Handling at Each Stage

| Stage | Failure Mode | User Experience |
|:---|:---|:---|
| Source Selection | No source has the anime | Show "unavailable" state |
| Link Extraction | Page structure changed | Try next source, show error if all fail |
| Resolver Selection | No resolver supports link | Skip link, try next |
| Stream Resolution | Extraction failed | Try next resolver, show error if all fail |
| Player Init | Invalid stream URL | Show playback error with retry |
| Progress Save | DB write failed | Queue for retry, non-blocking |

---

## Multi-Device Sync Protocol

### Architecture

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Device A │     │ Device B │     │ Device C │
│ (Phone)  │     │ (Tablet) │     │ (Desktop)│
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                 │                 │
     │  POST /sync/push (mutations)      │
     │  GET  /sync/pull (latest state)   │
     │                 │                 │
     └─────────────────┼─────────────────┘
                       │
                       ▼
              ┌────────────────┐
              │    Go API      │
              │  Sync Engine   │
              └───────┬────────┘
                      │
              ┌───────┴────────┐
              │      Neon      │
              │  (PostgreSQL)  │
              └────────────────┘
```

### Push Protocol

```
Client → Server: POST /sync/push
{
  "mutations": [
    {
      "entity": "episode_progress",
      "anilist_id": 12345,
      "episode_number": 5.0,
      "position_seconds": 342,
      "watch_state": "watching",
      "updated_at": 1715000000123
    },
    {
      "entity": "library_entry",
      "anilist_id": 12345,
      "added_at": 1715000000000,
      "notify_new_episodes": true,
      "updated_at": 1715000000456
    }
  ],
  "cursors": {
    "episode_progress": 1714990000000,
    "library_entries": 1714990000000
  }
}

Server → Client:
{
  "accepted": {
    "episode_progress": 1715000000123,
    "library_entries": 1715000000456
  }
}
```

### Pull Protocol

```
Client → Server: GET /sync/pull
{
  "cursors": {
    "episode_progress": 1714990000000,
    "watch_history": 0,
    "library_entries": 0,
    "playback_preferences": 0,
    "manga_library": 0,
    "manga_progress": 0
  }
}

Server → Client:
{
  "entities": {
    "episode_progress": [
      { "anilist_id": 12345, "episode_number": 5.0, "position_seconds": 342, ... },
      { "anilist_id": 12345, "episode_number": 6.0, "position_seconds": 120, ... }
    ],
    "watch_history": [...],
    "library_entries": [...]
  },
  "cursors": {
    "episode_progress": 1715000000123,
    "watch_history": 1715000000789,
    "library_entries": 1715000000456
  }
}
```

### Conflict Resolution

```
Scenario: Two devices update the same entity while offline

Device A (offline): updates episode_progress position to 342s @ t=1000
Device B (offline): updates episode_progress position to 500s @ t=1005

Device A comes online → pushes @ t=1000
  Server: stores position=342, cursor=1000

Device B comes online → pushes @ t=1005
  Server: t=1005 > cursor=1000 → stores position=500, cursor=1005

Device A pulls → receives position=500 (Device B's update won)
```

---

## Offline-First Strategy

### Local-First Architecture

All user data is **written locally first**, then synced:

```
User action (e.g., mark episode watched)
      │
      ▼
Write to local SQLite (immediate)
      │
      ▼
UI updates reactively (Drift .watch())
      │
      ▼
Queue sync mutation (in-memory queue)
      │
      ▼
Debounce (5 seconds)
      │
      ▼
If online → push to server
If offline → keep in queue
      │
      ▼
On reconnect → drain queue
```

### Sync Coordinator

Located in `apps/kumoriya_app/lib/src/shared/sync/sync_coordinator.dart`:

- **Triggers:** App resume, connectivity change, periodic timer
- **Debounce:** Prevents rapid-fire pushes
- **Queue:** In-memory mutation queue (lost on app kill — acceptable for progress data)
- **Background drain:** Workmanager periodic task (12h) as absolute fallback

### Storage-Aware Stores

Special store wrappers that automatically queue sync mutations:

- `SyncAwareLibraryStore` — wraps library entry writes
- `SyncAwareProgressStore` — wraps episode progress writes
- `SyncAwareMangaLibraryStore` — wraps manga library writes
- `SyncAwareMangaProgressStore` — wraps manga progress writes
- `FcmAwareLibraryStore` — wraps library writes + manages FCM topic subscriptions

---

## Download Pipeline

### Download Flow

```
User requests download
      │
      ▼
1. Source Selection (same as playback)
      │
      ▼
2. Server Link Extraction (same as playback)
      │
      ▼
3. Resolver Selection (same as playback)
      │
      ▼
4. Stream Resolution
   └── ResolverPlugin.resolve(link.url)
       └── Returns ResolvedStream with URL + headers
      │
      ▼
5. Download Strategy Selection
   ├── HLS stream → HLS Segment Downloader
   │   ├── Parse M3U8 playlist
   │   ├── Download segments in parallel (configurable concurrency)
   │   └── Store segments locally
   └── MP4 stream → Direct HTTP download
       └── Stream to file with progress tracking
      │
      ▼
6. Download Manager
   ├── Queue management (FIFO with priorities)
   ├── Progress tracking (bytes/total)
   ├── Pause/Resume support
   ├── Network error retry (exponential backoff)
   └── Foreground service notification (Android)
      │
      ▼
7. Post-Download
   ├── Verify file integrity
   ├── Register in download library index
   └── Mark episode as downloaded
```

### Manga Download Pipeline

```
User requests manga chapter download
      │
      ▼
1. Source Plugin: fetch chapter page list
      │
      ▼
2. Download all page images in parallel
      │
      ▼
3. Pack into CBZ archive
      │
      ▼
4. Register in manga download library
```

---

## Notification Pipeline

### Airing Notification Flow

```
Airing Worker (Go API, periodic)
      │
      ▼
1. Query AniList: currently airing anime
      │
      ▼
2. For each airing anime:
   ├── Check Redis: already notified for this episode?
   │   ├── Yes → Skip
   │   └── No → Continue
   │
   ├── Query Neon: users subscribed to this anime
   │
   ├── For each subscribed user:
   │   └── Send FCM push notification
   │
   └── Mark as notified in Redis (SET NX, TTL 7 days)
      │
      ▼
3. Device receives FCM push
   ├── App in foreground → Show in-app banner
   └── App in background → Show system notification
```

### FCM Topic Management

Users are subscribed to per-anime FCM topics:

- **Topic format:** `anime_{anilist_id}` (e.g., `anime_12345`)
- **Subscribe:** When user adds anime to library with notifications enabled
- **Unsubscribe:** When user removes anime or disables notifications
- **Sync:** Topic subscriptions synced across devices via sync protocol

---

## Watch Party Data Flow

### Room Lifecycle

```
Host creates room
      │
      ▼
Client → Go API: POST /party {anilistId, episodeNumber}
      │
      ▼
Go API → Cloudflare Worker: POST /internal/v1/rooms
      │
      ▼
Worker → PartyRegistryDO: createRoom()
  - Generate invite code
  - Create PartyRoomDO instance
  - Set host as first member
      │
      ▼
Worker → Go API: {roomId, inviteCode}
      │
      ▼
Go API → Client: {roomId, inviteCode, wsToken}
      │
      ▼
Client connects WebSocket to party.kumoriya.online
```

### Playback Synchronization

```
Host seeks to 5:30
      │
      ▼
Client → PartyRoomDO: {type: "playback_intent", payload: {action: "seek", positionMs: 330000}}
      │
      ▼
PartyRoomDO validates:
  - Is sender the host?
  - Is rate limit within bounds?
      │
      ▼
PartyRoomDO updates authoritative state:
  playback.basePositionMs = 330000
  playback.status = 'paused'
  playback.awaitReady = true
  Reset all members' ready states to false
      │
      ▼
PartyRoomDO broadcasts playback_state_changed + member_ready_changed to ALL members
      │
      ▼
All clients seek to 5:30, pause, and re-toggle ready
      │
      ▼
When all connected members are ready → server auto-resumes playback
```

### Auto-Pause on Member Disconnect

```
Member disconnects while status = 'watching'
      │
      ▼
PartyRoomDO detects disconnect (webSocketClose)
      │
      ▼
Server automatically pauses playback:
  playback.status = 'paused'
  (Bypasses host check — server-initiated)
      │
      ▼
PartyRoomDO broadcasts playback_state_changed to all remaining members
      │
      ▼
Member enters grace period (120s for members, 60s for host)
If member reconnects within grace → presence restored, ready state preserved
```

### Member Join Flow

```
Friend opens invite link
      │
      ▼
join-worker landing page → Deep link → Kumoriya app
      │
      ▼
Client → Go API: POST /party/join {inviteCode}
      │
      ▼
Go API → Worker: GET /internal/v1/invite/{code} → roomId
Go API → Worker: POST /internal/v1/rooms/{roomId}/join
      │
      ▼
Go API → Client: {roomId, wsToken}
      │
      ▼
Client connects WebSocket → PartyRoomDO
      │
      ▼
PartyRoomDO broadcasts member_join to all existing members
PartyRoomDO sends full state to new member (playback, media, members)
```

### Voice Chat (WebRTC PTT)

```
Member presses PTT button
      │
      ▼
Client → PartyRoomDO: {type: "voice_state", payload: {speaking: true}}
      │
      ▼
PartyRoomDO broadcasts voice_state_changed to all OTHER members:
  {type: "voice_state_changed", payload: {userId, speaking: true}}
      │
      ▼
Remote clients render audio indicator for the speaking member
      │
      ▼
WebRTC signaling (offer/answer/ICE) relayed through DO:
  Client → PartyRoomDO: {type: "webrtc_signal", payload: {targetUserId, type, signal}}
  PartyRoomDO → Target client: relayed signal
      │
      ▼
P2P mesh established (ExpressTURN relay for NAT traversal)
Audio streams directly between peers (not through DO)
```
