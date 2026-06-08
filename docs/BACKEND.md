# Backend Deep-Dive

> **Go API service architecture, database design, authentication system, and background workers.**

---

## Table of Contents

1. [Service Overview](#service-overview)
2. [Technology Stack](#technology-stack)
3. [Project Structure](#project-structure)
4. [Authentication System](#authentication-system)
5. [Sync Engine](#sync-engine)
6. [Watch Party Broker](#watch-party-broker)
7. [Notification System](#notification-system)
8. [Release Management](#release-management)
9. [Database Schema](#database-schema)
10. [Deployment](#deployment)

---

## Service Overview

The Go API (`kumoriya-api`) serves as the **central coordination layer** between the Flutter client and infrastructure services. It handles:

- **Authentication:** Multi-strategy auth (anonymous, OAuth, Passkeys)
- **Synchronization:** Multi-device state sync with CRDT semantics
- **Watch Party:** Room lifecycle management, session token issuance
- **Notifications:** Airing schedule monitoring, push delivery
- **Releases:** Update manifest serving, publish endpoint

---

## Technology Stack

| Component | Technology | Purpose |
|:---|:---|:---|
| HTTP Framework | Fiber v3 | High-performance routing, middleware |
| Database | Neon (Serverless PostgreSQL) | Durable user/sync data |
| Database Driver | pgx v5 | Native PostgreSQL driver |
| Auth (Passkeys) | go-webauthn/webauthn v0.12 | WebAuthn server-side implementation |
| Auth (JWT) | golang-jwt/jwt v5 | Ed25519 token signing/verification |
| Auth (OAuth) | golang.org/x/oauth2 | Discord + Google OAuth flows |
| Cache | Upstash Redis (REST) | Notification deduplication |
| Push | Firebase Admin SDK | FCM push notification delivery |
| Logging | zerolog | Structured JSON logging |
| UUID | google/uuid | User/session identifiers |

---

## Project Structure

```
kumoriya-api/
├── cmd/api/main.go              # Entry point, route wiring, worker startup
├── internal/
│   ├── config/config.go         # Environment variable loading, validation
│   ├── handler/
│   │   ├── auth_handler.go      # Registration, OAuth, passkey endpoints
│   │   ├── sync_handler.go      # Push/pull sync endpoints
│   │   ├── party_handler.go     # Room CRUD, join/leave
│   │   ├── party_ws_handler.go  # WebSocket upgrade (legacy)
│   │   ├── profile_handler.go   # User profile management
│   │   ├── release_handler.go   # Update manifest, publish
│   │   ├── health.go            # Health check endpoint
│   │   └── notifications_admin_handler.go  # Admin notification test
│   ├── middleware/
│   │   ├── auth.go              # JWT authentication middleware
│   │   └── ratelimit.go         # Per-user rate limiting
│   ├── model/
│   │   ├── auth.go              # Auth request/response types
│   │   ├── user.go              # User profile model
│   │   ├── sync.go              # Sync entity models
│   │   ├── party.go             # Party room models
│   │   └── release.go           # Release manifest models
│   ├── repository/
│   │   ├── pool.go              # pgx connection pool
│   │   ├── user_repo.go         # User CRUD operations
│   │   ├── sync_repo.go         # Sync state persistence
│   │   └── release_repo.go      # Release metadata storage
│   ├── service/
│   │   ├── auth_service.go      # Authentication business logic
│   │   ├── passkey_service.go   # WebAuthn operations
│   │   ├── oauth_service.go     # OAuth flow handling
│   │   ├── jwt_service.go       # Token creation/validation
│   │   ├── sync_service.go      # Sync engine with durable cursors
│   │   ├── sync_buffer.go       # Write-behind buffer
│   │   ├── sync_cache.go        # In-memory sync cache
│   │   ├── party_service.go     # Room lifecycle (legacy)
│   │   ├── party_hub.go         # In-memory room hub (legacy)
│   │   ├── party_broker.go      # Cloudflare Worker HTTP client
│   │   ├── party_session.go     # Ed25519 session token issuance
│   │   └── release_service.go   # Release management
│   ├── anilist/
│   │   ├── client/graphql_client.go    # AniList GraphQL client
│   │   ├── service/home_service.go     # Home feed aggregation
│   │   ├── cache/swr.go                # Stale-While-Revalidate cache
│   │   ├── handler/home_handler.go     # Home API endpoints
│   │   ├── handler/health_handler.go   # AniList health proxy
│   │   └── scheduler/prewarm.go        # Cache prewarming
│   ├── notifications/
│   │   ├── fcm_sender.go        # Firebase Cloud Messaging sender
│   │   ├── airing_worker.go     # Airing schedule monitor
│   │   ├── dedup.go             # Redis-based deduplication
│   │   └── topics.go            # FCM topic management
│   └── redis/
│       └── upstash.go           # Upstash Redis REST client
├── migrations/                  # SQL migration files
├── Dockerfile                   # Container build
└── go.mod                       # Go module definition
```

---

## Authentication System

### Multi-Strategy Architecture

```
                    ┌──────────────────┐
                    │   Auth Handler   │
                    └────────┬─────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  Anonymous   │ │    OAuth     │ │   Passkeys   │
    │  Registration│ │  (Discord,   │ │  (WebAuthn)  │
    │              │ │   Google)    │ │              │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           └────────────────┼────────────────┘
                            │
                            ▼
                   ┌────────────────┐
                   │  JWT Service   │
                   │  (Ed25519)     │
                   └────────┬───────┘
                            │
                            ▼
                   ┌────────────────┐
                   │  Bearer Token  │
                   │  → Client      │
                   └────────────────┘
```

### Anonymous Registration

1. Client generates a device-bound UUID
2. POST `/auth/register/anonymous` with device ID
3. Server creates user record, returns Ed25519-signed JWT
4. Anonymous accounts can later be upgraded to full accounts

### OAuth Flow

1. Client initiates OAuth with provider (Discord/Google)
2. Provider redirects to callback URL
3. Server exchanges authorization code for access token
4. Server fetches user profile from provider
5. Creates or links user account, returns JWT

### Passkeys (WebAuthn)

1. **Registration:** Server generates credential creation options → Client creates credential → Server verifies attestation
2. **Authentication:** Server generates assertion options → Client signs assertion → Server verifies signature
3. Multiple passkeys per account supported (cross-device)
4. Passkey deletion endpoint for key management

### JWT Tokens

- **Algorithm:** Ed25519
- **Claims:** `sub` (user UUID), `iat`, `exp`, `iss`
- **Lifetime:** Configurable (default: 30 days)
- **Middleware:** Validates on every protected route

---

## Sync Engine

### Architecture

```
Client                          Server
  │                               │
  │  POST /sync/push              │
  │  {mutations: [...],           │
  │   cursors: {...}}             │
  │──────────────────────────────►│
  │                               │──► Validate mutations
  │                               │──► Filter by durable cursors
  │                               │──► Write-behind buffer
  │                               │──► Return accepted cursors
  │◄──────────────────────────────│
  │                               │
  │  GET /sync/pull               │
  │  {cursors: {...}}             │
  │──────────────────────────────►│
  │                               │──► Query entities > cursors
  │                               │──► Return entities + new cursors
  │◄──────────────────────────────│
```

### Durable Cursors

The server maintains **per-user, per-entity-type** cursors representing the highest `updated_at` timestamp persisted to Neon:

```
User: uuid-1234
├── episode_progress:    1715000000000
├── watch_history:       1715000000100
├── library_entries:     1715000000200
├── playback_preferences: 1715000000300
├── manga_library:       1715000000400
└── manga_progress:      1715000000500
```

### Write-Behind Buffer

To reduce database write pressure:
1. Incoming mutations are buffered in memory
2. Periodic flush (or on shutdown) writes batch to Neon
3. Durable cursors advance only after successful flush
4. On process restart, cursors are rehydrated from Neon

### Conflict Resolution (LWW)

- Each entity carries a client-generated `updated_at` timestamp
- Server stores the **maximum** timestamp per entity
- If client sends older data, it's silently ignored
- No merge logic — the latest write always wins

### Sync Entities

| Entity | Table | Key |
|:---|:---|:---|
| Episode Progress | `episode_progress` | `(user_id, anilist_id, episode_number)` |
| Watch History | `watch_history` | `(user_id, anilist_id)` |
| Library Entry | `library_entries` | `(user_id, anilist_id)` |
| Playback Preference | `playback_preferences` | `(user_id, anilist_id)` |
| Manga Library | `manga_library_entries` | `(user_id, manga_anilist_id)` |
| Manga Progress | `manga_chapter_progress` | `(user_id, manga_anilist_id, source_id, source_chapter_id)` |

---

## Watch Party Broker

### v2 Architecture (Cloudflare Worker)

The `PartyBrokerClient` is an HTTP client that delegates room management to the Cloudflare Worker:

```
Go API (PartyBrokerClient)
        │
        │  POST /internal/v1/rooms
        │  POST /internal/v1/rooms/:id/join
        │  POST /internal/v1/rooms/:id/leave
        │  GET  /internal/v1/invite/:code
        │  POST /internal/v1/rooms/:id/member-verify
        │
        ▼
Cloudflare Worker (party.kumoriya.online)
        │
        ▼
PartyRegistryDO → PartyRoomDO
```

### Session Token Issuance

The `PartySessionService` creates Ed25519-signed JWT tokens for WebSocket authentication:

- **Claims:** `iss` (API issuer), `aud` (WS audience), `roomId`, `sub` (user ID), `name`, `role` (host/member), `sessionId`
- **Lifetime:** 45 seconds (short-lived for security)
- **Refresh:** Client calls `/party/session/refresh` before expiry

### Retry & Error Handling

- **Retries:** 1 retry with exponential backoff (250ms) for 5xx errors
- **Sentinel errors:** Typed errors for room_not_found, room_full, invalid_invite_code
- **Timeout:** 10-second HTTP client timeout

---

## Notification System

### Airing Worker

Background worker that monitors currently airing anime:

```
Every N minutes:
  1. Query AniList for currently airing anime
  2. For each airing anime:
     a. Check Redis: has this (anime, episode) been notified?
     b. If not: query users subscribed to this anime
     c. Send FCM push to each user's device
     d. Mark as notified in Redis (with TTL)
```

### Redis Deduplication

- **Key format:** `airing:{anilist_id}:{episode_number}`
- **TTL:** 7 days (prevents re-notification for the same episode)
- **Atomic:** SET NX (only set if not exists) for race-condition safety

### FCM Sender

- Initializes from Firebase service account credentials
- Supports both JSON env var and file-based credential loading
- Graceful degradation: if credentials are missing, notifications are silently disabled

---

## Release Management

### Update Manifest

Serves `update.json` from Cloudflare R2:
- **Android:** `version`, `version_code`, `download_url`, `changelog`
- **Windows:** `version`, `download_url`, `changelog`
- **`is_latest` flag:** Controls which release is the current recommended version

### Publish Endpoint

`POST /api/v1/releases/publish` (admin-only):
- Accepts release metadata payload
- Uploads artifacts to R2
- Updates `update.json` manifest
- Requires `RELEASE_PUBLISH_TOKEN` bearer token

---

## Database Schema

### Core Tables

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auth identities (OAuth, Passkeys)
CREATE TABLE auth_identities (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    provider TEXT,        -- 'discord', 'google', 'passkey'
    provider_id TEXT,     -- provider-specific user ID
    credential_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sync: Episode Progress
CREATE TABLE episode_progress (
    user_id UUID REFERENCES users(id),
    anilist_id INTEGER,
    episode_number REAL,
    position_seconds INTEGER,
    total_duration_seconds INTEGER,
    watch_state TEXT,
    last_source_plugin_id TEXT,
    last_server_name TEXT,
    last_resolver_id TEXT,
    updated_at BIGINT,  -- LWW timestamp
    PRIMARY KEY (user_id, anilist_id, episode_number)
);

-- Sync: Watch History
CREATE TABLE watch_history (
    user_id UUID REFERENCES users(id),
    anilist_id INTEGER,
    last_episode_number REAL,
    last_position_seconds INTEGER,
    last_total_duration INTEGER,
    last_source_plugin_id TEXT,
    last_accessed_at BIGINT,
    PRIMARY KEY (user_id, anilist_id)
);

-- Sync: Library Entries
CREATE TABLE library_entries (
    user_id UUID REFERENCES users(id),
    anilist_id INTEGER,
    added_at BIGINT,
    notify_new_episodes BOOLEAN DEFAULT FALSE,
    auto_download_new_episodes BOOLEAN DEFAULT FALSE,
    auto_download_audio_preference TEXT DEFAULT 'sub',
    last_notified_episode INTEGER,
    updated_at BIGINT,
    PRIMARY KEY (user_id, anilist_id)
);

-- Sync: Playback Preferences
CREATE TABLE playback_preferences (
    user_id UUID REFERENCES users(id),
    anilist_id INTEGER,
    preferred_source_plugin_id TEXT,
    preferred_server_name TEXT,
    preferred_resolver_plugin_id TEXT,
    preferred_audio_preference TEXT,
    updated_at BIGINT,
    PRIMARY KEY (user_id, anilist_id)
);

-- Sync: Manga Library
CREATE TABLE manga_library_entries (
    user_id UUID REFERENCES users(id),
    manga_anilist_id INTEGER,
    added_at BIGINT,
    notify_new_chapters BOOLEAN DEFAULT FALSE,
    auto_download_new_chapters BOOLEAN DEFAULT FALSE,
    preferred_language TEXT,
    preferred_scanlator TEXT,
    last_notified_chapter REAL,
    updated_at BIGINT,
    PRIMARY KEY (user_id, manga_anilist_id)
);

-- Sync: Manga Chapter Progress
CREATE TABLE manga_chapter_progress (
    user_id UUID REFERENCES users(id),
    manga_anilist_id INTEGER,
    source_id TEXT,
    source_chapter_id TEXT,
    chapter_number REAL,
    page_index INTEGER,
    read_state TEXT,
    updated_at BIGINT,
    PRIMARY KEY (user_id, manga_anilist_id, source_id, source_chapter_id)
);
```

---

## Deployment

### Docker

```dockerfile
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /api ./cmd/api

FROM alpine:latest
COPY --from=builder /api /api
EXPOSE 7860
CMD ["/api"]
```

### Environment Variables

| Variable | Required | Purpose |
|:---|:---|:---|
| `PORT` | No (7860) | HTTP listen port |
| `NEON_DSN` | Yes | PostgreSQL connection string |
| `JWT_PRIVATE_KEY_HEX` | Yes | Ed25519 private key (64 hex chars) |
| `JWT_ISSUER` | No | JWT issuer claim |
| `BASE_URL` | No | Public API base URL |
| `DISCORD_CLIENT_ID` | No | Discord OAuth client ID |
| `DISCORD_CLIENT_SECRET` | No | Discord OAuth secret |
| `GOOGLE_CLIENT_ID` | No | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | No | Google OAuth secret |
| `WEBAUTHN_RP_ID` | No | WebAuthn Relying Party ID |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | No | Firebase Admin SDK credentials |
| `UPSTASH_REDIS_REST_URL` | No | Redis REST endpoint |
| `UPSTASH_REDIS_REST_TOKEN` | No | Redis auth token |
| `PARTY_REALTIME_BASE_URL` | No | Worker HTTPS base URL |
| `PARTY_REALTIME_WS_BASE_URL` | No | Worker WSS base URL |
| `PARTY_INTERNAL_TOKEN` | No | Worker internal API token |
| `RELEASE_MANIFEST_URL` | No | R2 update.json URL |
| `RELEASE_PUBLISH_TOKEN` | No | Release publish auth token |
