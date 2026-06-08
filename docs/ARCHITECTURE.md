# Architecture Overview

> **Complete system design, component map, and architectural decisions for the Kumoriya platform.**

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Tier 1: Client (Flutter)](#tier-1-client-flutter)
3. [Tier 2: Server (Go API)](#tier-2-server-go-api)
4. [Tier 3: Edge (Cloudflare Workers)](#tier-3-edge-cloudflare-workers)
5. [Cross-Cutting Concerns](#cross-cutting-concerns)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [Architecture Decision Records](#architecture-decision-records)

---

## High-Level Architecture

Kumoriya follows a **three-tier distributed architecture** with clear separation of concerns:

```
┌──────────────────────────────────────────────────────────────────┐
│                         CLIENT TIER                               │
│                                                                   │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐   │
│  │   Presentation      │  │        Domain Layer              │   │
│  │   (Flutter Widgets) │  │  ┌──────────┐ ┌──────────────┐  │   │
│  │                     │  │  │  Source   │ │   Resolver   │  │   │
│  │  ┌───────────────┐  │  │  │  Plugins  │ │   Plugins    │  │   │
│  │  │  Riverpod     │  │  │  └──────────┘ └──────────────┘  │   │
│  │  │  Providers    │  │  │  ┌──────────┐ ┌──────────────┐  │   │
│  │  └───────────────┘  │  │  │ Matching  │ │   Storage    │  │   │
│  │                     │  │  │  Engine   │ │   (Drift)    │  │   │
│  └─────────────────────┘  │  └──────────┘ └──────────────┘  │   │
│                           └──────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
                              │ HTTPS/REST
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                        SERVER TIER                                │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    Go API (Fiber v3)                        │  │
│  │                                                             │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │  Auth    │ │  Sync    │ │  Party   │ │  Releases    │  │  │
│  │  │  Handler │ │  Handler │ │  Handler │ │  Handler      │  │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘  │  │
│  │       │            │            │               │          │  │
│  │  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌──────┴───────┐  │  │
│  │  │  Auth    │ │  Sync    │ │  Party   │ │  Release     │  │  │
│  │  │  Service │ │  Service │ │  Broker  │ │  Service     │  │  │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘  │  │
│  └───────┼────────────┼────────────┼───────────────┼──────────┘  │
│          │            │            │               │              │
│  ┌───────┴────────────┴────────────┴───────────────┴──────────┐  │
│  │                    Data Layer                               │  │
│  │  ┌──────────────────┐  ┌──────────────────────────────┐    │  │
│  │  │  Neon PostgreSQL │  │  Upstash Redis (Cache/Dedup) │    │  │
│  │  └──────────────────┘  └──────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │ HTTPS
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                         EDGE TIER                                 │
│                                                                   │
│  ┌─────────────────────────┐  ┌──────────────────────────────┐   │
│  │  watch-party-realtime   │  │       join-worker            │   │
│  │  (Cloudflare Worker)    │  │   (Cloudflare Worker)        │   │
│  │                         │  │                              │   │
│  │  ┌───────────────────┐  │  │  ┌────────────────────────┐  │   │
│  │  │  PartyRoomDO      │  │  │  │  Invite Landing Page   │  │   │
│  │  │  (Durable Object) │  │  │  │  + Deep Link Handler   │  │   │
│  │  └───────────────────┘  │  │  └────────────────────────┘  │   │
│  │  ┌───────────────────┐  │  │                              │   │
│  │  │  PartyRegistryDO  │  │  │  Host: join.kumoriya.online │   │
│  │  │  (Durable Object) │  │  │                              │   │
│  │  └───────────────────┘  │  └──────────────────────────────┘   │
│  │                         │                                      │
│  │  Host: party.kumoriya   │                                      │
│  │        .online          │                                      │
│  └─────────────────────────┘                                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Tier 1: Client (Flutter)

### Application Shell

The Flutter app is structured as a **monorepo with Domain-Driven Design (DDD)** principles:

- **`apps/kumoriya_app`**: The main application entry point
- **`packages/`**: 45+ micro-packages enforcing strict boundaries

### Feature Slice Architecture

Each feature is a **vertical slice** containing its own:

```
feature/
├── application/       # Use cases, services, policies
│   ├── services/      # Domain services
│   └── use_cases/     # Orchestration logic
├── domain/            # Feature-specific models (if needed)
├── infrastructure/    # External integrations, clients
└── presentation/      # UI layer
    ├── pages/         # Full-screen views
    ├── widgets/       # Reusable components
    ├── controllers/   # State notifiers
    └── providers/     # Riverpod provider definitions
```

### State Management (Riverpod)

- **Compile-safe:** All dependencies resolved at compile time
- **Override system:** Enables test injection without service locators
- **Auto-dispose:** Resources cleaned up when no longer watched
- **Family providers:** Parameterized providers for dynamic data (e.g., `animeDetailProvider(anilistId)`)

### Local Persistence (Drift/SQLite)

The `kumoriya_storage` package provides:
- Type-safe SQL queries via Dart code generation
- Reactive streams (`.watch()`) for real-time UI updates
- Migration system for schema evolution
- DAO pattern for data access

### Caching Strategy

Multi-tiered cache with TTL-based expiration:

| Cache | TTL | Purpose |
|:---|:---|:---|
| AniList metadata | 30 days | Canonical anime/manga data |
| Source availability | 7 days | Which sources have which anime |
| AniSkip timestamps | 14 days | Intro/outro skip data |
| Translations | 30 days | Dynamic title translations |

Fallback mechanism: When AniList is unreachable, the app serves cached data with a user-visible fallback indicator.

---

## Tier 2: Server (Go API)

### Framework & Routing

Built with **Fiber v3** (Express-inspired Go framework):
- Route grouping with middleware chains
- Per-route rate limiting
- JWT authentication middleware

### Route Structure

```
/auth
  ├── POST   /register/anonymous        # Anonymous account creation
  ├── POST   /register/begin            # Start registration
  ├── POST   /register/finish           # Complete registration
  ├── POST   /oauth/discord             # Discord OAuth
  ├── POST   /oauth/google              # Google OAuth
  ├── POST   /passkeys/register/begin   # WebAuthn registration start
  ├── POST   /passkeys/register/finish  # WebAuthn registration complete
  ├── POST   /passkeys/login/begin      # WebAuthn login start
  ├── POST   /passkeys/login/finish     # WebAuthn login complete
  └── DELETE /passkeys/:id              # Remove passkey

/api/v1 (protected)
  ├── GET    /profile                   # User profile
  ├── PATCH  /profile                   # Update profile
  ├── GET    /sync/pull                 # Pull sync state
  ├── POST   /sync/push                 # Push sync mutations
  ├── DELETE /account                   # Account deletion
  ├── POST   /party                     # Create room
  ├── POST   /party/join                # Join room
  ├── POST   /party/leave               # Leave room
  ├── POST   /party/session/refresh     # Refresh WS token
  ├── GET    /party/me                  # Current room
  ├── GET    /party/invite/:code        # Resolve invite
  ├── PATCH  /party/:id                 # Update room
  ├── GET    /party/:id                 # Get room
  └── GET    /party/:id/signal          # WebSocket upgrade (legacy)

/.well-known
  └── GET    /assetlinks.json           # Android Digital Asset Links
```

### Authentication System

Multi-strategy authentication:

1. **Anonymous:** Device-bound UUID, upgradeable to full account
2. **OAuth 2.0:** Discord and Google social login
3. **WebAuthn/Passkeys:** Passwordless biometric authentication
4. **JWT:** Ed25519-signed tokens for session management

### Sync Engine

**LWW CRDT** (Last-Writer-Wins Conflict-Free Replicated Data Type):

- Each entity has an `updated_at` timestamp (client-generated, monotonic)
- Server maintains **durable cursors** per user — the highest timestamp persisted to Neon
- Push: Client sends mutations with timestamps > cursor
- Pull: Server returns all entities with timestamps > client's last pull
- Conflict resolution: Highest timestamp wins (no merge logic needed)

### Background Workers

**Airing Notification Worker:**
- Periodically queries AniList for currently airing anime
- Cross-references with user library subscriptions
- Deduplicates via Redis (Upstash) to prevent double-notifications
- Sends push notifications via Firebase Cloud Messaging

---

## Tier 3: Edge (Cloudflare Workers)

### watch-party-realtime

**Purpose:** Real-time synchronized viewing rooms with WebSocket signaling.

**Architecture:**
- **Entry Point (`index.ts`):** Routes HTTP requests to health, WebSocket upgrade, or internal API
- **PartyRegistryDO:** Global registry mapping invite codes → room IDs, enforcing user-in-one-room constraint
- **PartyRoomDO:** Per-room Durable Object managing authoritative state

**PartyRoomDO State Machine:**
```
Room Created → Members Join → Ready Check → Playing → Paused → Ended
                    │              │            │         │
                    └── Grace ─────┘            │         │
                    Period on                    │         │
                    Disconnect                   │         │
                                                 │         │
                                          Host Transfer    │
                                          on Host Leave    │
```

**WebSocket Protocol:**
- Typed JSON message envelopes with `type` discriminator
- ACK/error handling with message IDs
- Token-bucket rate limiting per user per message type
- Heartbeat auto-response via DO hibernation bypass (95% cost reduction)

**Session Security:**
- Ed25519-signed JWT tokens issued by Go API
- Claims: `roomId`, `sub` (user ID), `name`, `role` (host/member), `sessionId`
- Worker verifies signature against public key before WebSocket upgrade

### join-worker

**Purpose:** Handles Watch Party invite links (`join.kumoriya.online/{code}`).

**Features:**
- Validates invite code format
- Renders a branded landing page with the invite code
- Attempts deep-link into the Kumoriya app
- Falls back to download page if app not installed
- Android-specific intent:// handling for Chrome compatibility
- Serves Digital Asset Links for passkey association

---

## Cross-Cutting Concerns

### Error Handling

- **Flutter:** `Result<T, KumoriyaError>` pattern — no thrown exceptions for domain logic
- **Go:** Explicit error returns with structured error types
- **Workers:** Typed error envelopes with retryable flags

### Observability

- **Sentry:** Crash reporting, ANR detection (Android), session replay, performance tracing
- **Intelligent filtering:** Known non-actionable errors (media_kit disposal races, resolver failures) are dropped before reaching Sentry
- **Debug logging:** Feature-flagged verbose logging (`KUMORIYA_DOWNLOAD_DEBUG_LOGS`)

### Internationalization

- **Flutter:** ARB-based l10n with Spanish and English support
- **Release notes:** Bilingual (en + es) in `docs/releases/`
- **Dynamic translations:** Runtime title translation service

### Security

- **Secrets:** Ed25519 asymmetric keys for JWT signing
- **Transport:** HTTPS everywhere, WebSocket over WSS
- **Auth:** Passkeys (WebAuthn), OAuth 2.0, JWT sessions
- **Rate limiting:** Per-user, per-endpoint token buckets
- **Input validation:** Whitelist-based invite code validation, SQL parameterization

---

## Data Flow Diagrams

### Content Discovery Flow

```
User opens Home Page
        │
        ▼
Riverpod provider checks AniList cache
        │
        ├── Cache HIT ──► Render from cache
        │
        └── Cache MISS
                │
                ▼
        Call Go API (/anilist/home)
                │
                ├── Success ──► Cache + Render
                │
                └── Failure
                        │
                        ▼
                Check local cache (stale)
                        │
                        ├── Has cache ──► Render with fallback banner
                        │
                        └── No cache ──► Show error state + retry
```

### Episode Playback Flow

```
User taps episode
        │
        ▼
Source Plugin: getEpisodeServerLinks(episode)
        │
        ▼
Resolver Registry: select resolver for each link
        │
        ▼
Resolver Plugin: resolve(link) → playable URL + headers
        │
        ▼
Player Session Orchestrator: configure player
        │
        ▼
Player: play with resolved stream
        │
        ▼
Progress Saver: periodically save position to local DB
        │
        ▼
Sync Coordinator: push to server when online
```

### Watch Party Flow

```
Host creates room (Go API)
        │
        ▼
Go API → Cloudflare Worker: create room (internal API)
        │
        ▼
Worker returns roomId + inviteCode
        │
        ▼
Host shares invite code with friends
        │
        ▼
Friends open join.kumoriya.online/{code}
        │
        ▼
Deep link → Kumoriya app → Join room (Go API)
        │
        ▼
Go API issues Ed25519 session token
        │
        ▼
Client connects WebSocket to party.kumoriya.online
        │
        ▼
PartyRoomDO manages synchronized playback state
```

---

## Architecture Decision Records

### ADR-001: Plugin-First Architecture
**Decision:** All data extraction logic lives in independent plugin packages.
**Rationale:** Third-party websites change DOM structures unpredictably. Isolating scrapers prevents cascading failures.
**Trade-off:** More packages to maintain, but each is small and independently testable.

### ADR-002: Edge Computing for Real-Time
**Decision:** Use Cloudflare Durable Objects instead of traditional WebSocket servers.
**Rationale:** Durable Objects provide strong consistency, implicit routing, and global low-latency without managing pub/sub infrastructure.
**Trade-off:** Vendor lock-in to Cloudflare, but the operational simplicity justifies it.

### ADR-003: LWW CRDT for Sync
**Decision:** Use Last-Writer-Wins conflict resolution instead of operational transforms.
**Rationale:** User data (progress, preferences) is naturally LWW — the latest action is always the intended state. OT would add complexity without benefit.
**Trade-off:** Cannot merge concurrent edits, but concurrent edits are rare for this data model.

### ADR-004: Monorepo with Micro-Packages
**Decision:** Single repository with 45+ Dart packages instead of multiple repos.
**Rationale:** Shared tooling, atomic commits across boundaries, simplified CI. Package boundaries enforced by Dart's import system.
**Trade-off:** Larger clone size, but `flutter pub get` handles dependency resolution.

### ADR-005: Ed25519 for JWT
**Decision:** Use Ed25519 asymmetric keys instead of HMAC or RSA.
**Rationale:** Smaller signatures, faster verification, modern security properties. Enables the Go API to sign tokens that the Cloudflare Worker can verify without sharing a secret.
**Trade-off:** Less widespread than RSA, but all our platforms support it.
