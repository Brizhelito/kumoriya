# Kumoriya ☁️

> **A real-time cross-platform content aggregation engine that unifies multiple third-party data sources through dynamic indexing, canonical metadata normalization, and a plugin-first architecture.**

[![Flutter](https://img.shields.io/badge/Flutter-3.32-02569B?logo=flutter)](https://flutter.dev)
[![Go](https://img.shields.io/badge/Go-1.25-00ADD8?logo=go)](https://go.dev)
[![Cloudflare Workers](https://img.shields.io/badge/Edge-Cloudflare-F38020?logo=cloudflare)](https://workers.cloudflare.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Kumoriya is a **full-stack distributed system** designed to solve the fragmentation of digital content consumption. It dynamically extracts, normalizes, and unifies metadata from multiple independent web sources into a single, cohesive native experience — available on **Android** and **Windows**.

---

## 🎯 What Problem Does This Solve?

Modern content platforms suffer from **data silos**. Information is scattered across dozens of websites with inconsistent formats, unreliable availability, and no unified access layer. Kumoriya acts as an **aggregation middleware**: it scrapes, indexes, matches, and serves content from disparate sources through a single, polished interface — without the user ever needing to know where the data came from.

---

## 🏗 System Architecture

Kumoriya is a **three-tier distributed system** spanning client, server, and edge:

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT TIER                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │        Flutter App (Android + Windows)            │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │   │
│  │  │  Source   │ │ Resolver │ │   Local Storage  │  │   │
│  │  │  Plugins  │ │ Plugins  │ │   (SQLite/Drift) │  │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│                    SERVER TIER                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Go API (Fiber)                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │   │
│  │  │   Auth   │ │   Sync   │ │  Notifications   │  │   │
│  │  │ (Passkeys│ │ (LWW CRDT│ │  (FCM + Redis    │  │   │
│  │  │  OAuth)  │ │  Cursors)│ │   Dedup)         │  │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│                     EDGE TIER                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │        Cloudflare Workers + Durable Objects       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │   │
│  │  │  Party   │ │   Join   │ │  WebSocket       │  │   │
│  │  │  Rooms   │ │  Landing │ │  Signaling       │  │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

| Decision | Rationale |
|:---|:---|
| **Plugin-First Design** | Third-party web sources change their DOM structures frequently. Isolating scrapers into plugins (`kumoriya_source_*`) ensures the core app never breaks due to external UI updates. |
| **Edge Computing for Real-Time** | Traditional scalable WebSockets require complex pub/sub backplanes. Cloudflare Durable Objects provide strong consistency and implicit routing — users in the same room connect to the exact same edge node globally. |
| **LWW CRDT Sync** | Multi-device state synchronization uses Last-Writer-Wins Conflict-Free Replicated Data Types with durable server-side cursors, ensuring no data loss even during offline periods. |
| **Canonical Metadata Indexing** | Scraped data is inherently dirty. A multi-stage matching pipeline normalizes unstructured web data against a canonical metadata API, acting as a real-time ETL (Extract, Transform, Load) pipeline on the client. |

---

## 📦 Repository Structure

```
Kumoriya/
├── apps/kumoriya_app/          # Flutter application (Android + Windows)
│   ├── lib/
│   │   ├── src/
│   │   │   ├── app/            # App shell, first-launch gate
│   │   │   ├── config/         # Environment configuration
│   │   │   ├── features/       # Vertical feature slices
│   │   │   │   ├── anime_catalog/   # Browse, search, detail, episodes
│   │   │   │   ├── manga_catalog/   # Manga browsing & search
│   │   │   │   ├── player/          # Playback session orchestration
│   │   │   │   ├── downloads/       # Offline download manager
│   │   │   │   ├── watch_party/     # Real-time synchronized viewing
│   │   │   │   ├── auth/            # Authentication UI
│   │   │   │   ├── library/         # Unified library
│   │   │   │   ├── settings/        # App preferences
│   │   │   │   └── app_update/      # OTA update mechanism
│   │   │   └── shared/         # Cross-cutting concerns
│   │   │       ├── auth/       # Passkeys, OAuth, token store
│   │   │       ├── sync/       # Multi-device sync coordinator
│   │   │       ├── notifications/  # FCM push notifications
│   │   │       ├── cache/      # Tiered caching with fallback
│   │   │       ├── navigation/ # App shell navigation
│   │   │       └── theme/      # Design system & theming
│   │   └── l10n/               # Internationalization (es, en)
│   └── test/                   # 65+ test files
│
├── packages/                   # 45+ Dart packages (DDD micro-packages)
│   ├── kumoriya_core/          # Result/Either primitives, error types
│   ├── kumoriya_domain/        # Canonical domain models
│   ├── kumoriya_plugins/       # Plugin contracts & manifest models
│   ├── kumoriya_matching/      # Title normalization & matching engine
│   ├── kumoriya_anilist/       # Metadata gateway contracts
│   ├── kumoriya_storage/       # Local persistence (Drift/SQLite)
│   ├── kumoriya_sync/          # Sync contracts & models
│   ├── kumoriya_auth/          # Authentication contracts
│   ├── kumoriya_exoplayer/     # Android native player bindings
│   ├── kumoriya_reader/        # Manga reader engine
│   ├── kumoriya_source_*/      # 10+ source plugins (scraping)
│   ├── kumoriya_resolver_*/    # 18+ resolver plugins (stream extraction)
│   ├── kumoriya_manga_*/       # Manga domain, plugins, sources
│   └── kumoriya_testing/       # Shared test utilities
│
├── kumoriya-api/               # Go backend service
│   ├── cmd/api/                # Entry point & route wiring
│   ├── internal/
│   │   ├── config/             # Environment configuration
│   │   ├── handler/            # HTTP handlers (auth, sync, party, releases)
│   │   ├── middleware/         # Auth, rate limiting
│   │   ├── model/              # Domain models & validation
│   │   ├── repository/         # Database access (Neon/PostgreSQL)
│   │   ├── service/            # Business logic
│   │   ├── anilist/            # AniList GraphQL client + cache
│   │   ├── notifications/      # FCM push + airing worker
│   │   └── redis/              # Upstash Redis client
│   └── migrations/             # SQL migration files
│
├── infra/                      # Edge infrastructure
│   ├── watch-party-realtime/   # Cloudflare Worker (TypeScript)
│   │   └── src/
│   │       ├── durable-objects/  # PartyRoomDO, PartyRegistryDO
│   │       ├── auth/             # Ed25519 session tokens
│   │       ├── messaging/        # WebSocket protocol + ACK
│   │       ├── types/            # TypeScript type definitions
│   │       └── __tests__/        # Unit + property-based tests
│   └── join-worker/            # Invite landing page Worker
│
├── tools/                      # Developer tooling
│   ├── kumoriya-orch/          # Task orchestration (Python/FastAPI)
│   ├── resolver_cli/           # Resolver benchmarking CLI (Dart)
│   └── anime-nexus-runtime-node/ # Runtime analysis tools (Node.js)
│
├── scripts/                    # Build, release & automation scripts
├── docs/                       # Comprehensive documentation
│   ├── releases/               # Bilingual release notes (en + es)
│   ├── audits/                 # Technical audit reports
│   ├── architecture/           # Architecture decision records
│   └── dev-diary/              # Chronological development log
│
└── .agents/                    # AI-assisted development agents & skills
```

---

## 🛠 Technology Stack

| Layer | Technology | Purpose |
|:---|:---|:---|
| **Mobile/Desktop** | Flutter 3.32 + Dart | Cross-platform UI (Android + Windows) |
| **State Management** | Riverpod 3.x | Reactive, compile-safe dependency injection |
| **Local Database** | Drift (SQLite) | Offline-first persistence with type-safe queries |
| **Backend API** | Go 1.25 + Fiber v3 | High-concurrency REST API |
| **Database** | Neon (Serverless PostgreSQL) | Durable user data, sync state |
| **Cache** | Upstash Redis (REST) | Notification deduplication, rate limiting |
| **Edge Compute** | Cloudflare Workers + Durable Objects | Real-time WebSocket rooms, global low-latency |
| **Push Notifications** | Firebase Cloud Messaging | Cross-platform push delivery |
| **Error Tracking** | Sentry | Crash reporting, ANR detection, session replay |
| **Background Jobs** | Workmanager (Android) | Periodic episode checks, sync drain |
| **Media Playback** | media_kit + ExoPlayer | Multi-format video with HLS support |
| **Authentication** | WebAuthn (Passkeys) + OAuth 2.0 | Passwordless auth + social login |
| **Secrets** | Ed25519 asymmetric keys | JWT signing, session tokens |
| **CI/CD** | GitHub Actions | Format, analyze, test on every push |
| **Release Distribution** | Cloudflare R2 | APK/MSIX hosting with update manifest |

---

## 🔌 Plugin System

Kumoriya's most distinctive architectural feature is its **plugin-first design**. The UI depends on abstract contracts, never on concrete implementations.

### Source Plugins (10+)
Extract structured metadata from third-party websites:
- **Contract:** `SourcePlugin` — search, detail, episode listing, server link extraction
- **Examples:** `kumoriya_source_jkanime`, `kumoriya_source_animeflv`, `kumoriya_source_mangadex`
- **Failure Mode:** Return `Result.failure()` — the app gracefully degrades

### Resolver Plugins (18+)
Transform hosting service URLs into playable media streams:
- **Contract:** `ResolverPlugin` — host gating (`supports()`), stream resolution (`resolve()`)
- **Examples:** `kumoriya_resolver_doodstream`, `kumoriya_resolver_voe`, `kumoriya_resolver_filemoon`
- **Selection:** Priority-based with ambiguity detection — prefers no stream over wrong stream

```
User taps episode
       │
       ▼
Source Plugin extracts server links
       │
       ▼
Resolver Registry selects best resolver
       │
       ▼
Resolver Plugin extracts playable URL + headers
       │
       ▼
Player receives resolved stream (never touches scraping)
```

---

## 🔄 Real-Time Synchronized Viewing (Watch Party)

A distributed system enabling multiple users to watch content in perfect synchronization:

1. **Room Creation:** Go API creates room via Cloudflare Worker internal API
2. **Session Tokens:** Ed25519-signed JWT with room, user, and role claims
3. **WebSocket Upgrade:** Client connects to `wss://party.kumoriya.online/ws`
4. **Durable Object:** Each room is a single-threaded DO instance — authoritative playback state
5. **Protocol:** Typed message envelopes with ACK/error handling, rate limiting, heartbeat auto-response (95% cost reduction via DO hibernation bypass)
6. **Host Authority:** Graceful host transfer on disconnect with grace periods

---

## 📊 Data Synchronization

Multi-device state sync using **LWW CRDT** semantics:

- **Push/Pull:** Client sends local mutations; server merges with durable cursors
- **Entities:** Episode progress, watch history, library entries, playback preferences, manga progress
- **Offline-First:** Local SQLite stores all state; sync drains when connectivity returns
- **Conflict Resolution:** Highest `updated_at` timestamp wins (LWW)
- **Background Drain:** Workmanager periodic task ensures sync even when app is closed

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK ≥ 3.32
- Go ≥ 1.25 (for API)
- Node.js ≥ 20 + Wrangler CLI (for Workers)

### Run the Flutter App
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Run the Go API
```bash
cd kumoriya-api
cp .env.example .env  # configure secrets
go run ./cmd/api
```

### Deploy Edge Workers
```bash
cd infra/watch-party-realtime
npm install
npx wrangler deploy
```

---

## 📚 Documentation

| Document | Description |
|:---|:---|
| [Architecture Overview](docs/ARCHITECTURE.md) | Full system design & component map |
| [Frontend Deep-Dive](docs/FRONTEND.md) | Flutter app structure, state management, UI |
| [Backend Deep-Dive](docs/BACKEND.md) | Go API, database schema, services |
| [Edge Infrastructure](docs/EDGE_INFRASTRUCTURE.md) | Cloudflare Workers & Durable Objects |
| [Plugin System](docs/PLUGIN_SYSTEM.md) | Plugin contracts, registration, resolution |
| [Data Flow & Sync](docs/DATA_FLOW.md) | Synchronization protocol & offline strategy |
| [CI/CD Pipeline](docs/CI_CD.md) | Build, test, release automation |
| [Testing Strategy](docs/TESTING.md) | Unit, integration, property-based tests |

---

## 🧠 Engineering Highlights for Recruiters

- **Distributed Systems:** Designed a three-tier architecture (client/server/edge) with strong consistency guarantees for real-time state synchronization across globally distributed users.
- **Plugin Architecture:** Implemented a SOLID-compliant plugin system with 28+ independent plugins, enabling the core application to remain stable while external data sources change unpredictably.
- **Data Normalization Pipeline:** Built a multi-stage matching engine that takes unstructured web data and cross-references it against canonical APIs — essentially a real-time ETL pipeline running on mobile devices.
- **Edge Computing:** Leveraged Cloudflare Durable Objects for WebSocket management, achieving sub-millisecond coordination between clients without traditional server bottlenecks. Implemented hibernation bypass for 95% cost reduction.
- **Offline-First Design:** Engineered local-first persistence with CRDT-based conflict resolution, enabling seamless multi-device synchronization even after extended offline periods.
- **Modern Security:** Implemented WebAuthn/Passkeys for passwordless authentication, Ed25519 asymmetric cryptography for session tokens, and OAuth 2.0 social login integration.
- **Observability:** Integrated Sentry for crash reporting, ANR detection, session replay, and performance tracing — with intelligent error filtering to reduce noise.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ☁️ by <a href="https://github.com/Brizhelito">Brizhelito</a></sub>
</p>
