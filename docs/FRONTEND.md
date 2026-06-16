# Frontend Deep-Dive

> **Flutter application architecture, state management, UI design, and feature implementation details.**

---

## Table of Contents

1. [Application Entry Point](#application-entry-point)
2. [Feature Slice Architecture](#feature-slice-architecture)
3. [State Management (Riverpod)](#state-management-riverpod)
4. [Navigation & Routing](#navigation--routing)
5. [UI Design System](#ui-design-system)
6. [Feature Catalog](#feature-catalog)
7. [Offline & Caching](#offline--caching)
8. [Platform Integration](#platform-integration)

---

## Application Entry Point

### `main.dart` — Startup Sequence

The app follows a **cold-start-optimized** boot sequence:

```
1. Sentry initialization (error tracking from frame 0)
2. WidgetsFlutterBinding.ensureInitialized()
3. Platform-specific init (WindowManager on Windows)
4. WebRTC engine init (flutter_webrtc native — required before voice chat)
5. Database open (blocking — required before UI)
6. ProviderContainer creation with DB override
7. runApp() — first frame renders immediately
8. Post-frame async init (non-blocking):
   ├── Restore download queue
   ├── Auto-delete watched downloads
   ├── Purge expired caches
   ├── Firebase + FCM init (Android only)
   ├── Local notifications init (Android only)
   ├── Workmanager registration (Android only)
   └── Download foreground service init (Android only)
```

**Key optimization:** Only the database (and WebRTC engine) block the first frame. All platform services (Firebase, FCM, notifications, Workmanager) initialize asynchronously after `runApp()`.

### `KumoriyaApp` — App Shell

The root widget manages:
- **Universe switching:** Anime vs Manga mode with animated theme transitions
- **Deep link handling:** `kumoriya://` custom scheme for Watch Party invites
- **Lifecycle hooks:** Sync coordinator push on resume/pause
- **First-launch gate:** Sequential onboarding flows

---

## Feature Slice Architecture

Each feature follows a consistent **Clean Architecture** pattern:

```
feature/
├── application/
│   ├── services/       # Domain services (stateless, injectable)
│   └── use_cases/      # Orchestration logic (single responsibility)
├── domain/             # Feature-specific models (rare — prefer shared domain)
├── infrastructure/     # External clients, platform channels
└── presentation/
    ├── pages/          # Full-screen Scaffold widgets
    ├── widgets/        # Reusable UI components
    ├── controllers/    # StateNotifier / AsyncNotifier classes
    └── providers/      # Riverpod provider definitions
```

### Example: `anime_catalog` Feature

```
anime_catalog/
├── application/
│   ├── services/
│   │   ├── plugin_runtime_catalog.dart      # Plugin registration & lookup
│   │   ├── resolver_registry.dart           # Resolver selection algorithm
│   │   ├── source_selection_policy.dart     # Which source to use
│   │   └── playback_preference_policy.dart  # User preference resolution
│   └── use_cases/
│       ├── check_source_availability_use_case.dart
│       ├── get_source_episode_server_links_use_case.dart
│       ├── resolve_source_server_link_use_case.dart
│       └── start_episode_playback_use_case.dart
├── presentation/
│   ├── pages/
│   │   ├── home_page.dart                   # Main discovery feed
│   │   ├── search_page.dart                 # Search interface
│   │   ├── anime_detail_page.dart           # Detail view
│   │   ├── episode_list_page.dart           # Episode listing
│   │   ├── calendar_page.dart               # Airing calendar
│   │   ├── library_page.dart                # User library
│   │   ├── downloads_page.dart              # Offline content
│   │   ├── trending_page.dart               # Trending rankings
│   │   ├── season_hub_page.dart             # Seasonal browser
│   │   └── tag_guided_find_page.dart        # Tag-based discovery
│   ├── widgets/
│   │   ├── anime_card.dart                  # Grid/list item
│   │   ├── anime_list_tile.dart             # List item variant
│   │   └── anime_ranked_tile.dart           # Ranked list item
│   ├── controllers/
│   │   └── paginated_anime_feed_notifier.dart
│   └── providers/
│       ├── anime_catalog_providers.dart     # Core providers
│       └── storage_providers.dart           # Storage-related providers
```

---

## State Management (Riverpod)

### Provider Categories

| Provider Type | Use Case | Example |
|:---|:---|:---|
| `Provider` | Computed/derived values | `universeAccentProvider` |
| `StateProvider` | Simple mutable state | `selectedTabProvider` |
| `FutureProvider` | Async data fetching | `homeFeedProvider` |
| `StreamProvider` | Reactive data streams | `downloadProgressProvider` |
| `NotifierProvider` | Complex state logic | `syncCoordinatorProvider` |
| `AsyncNotifierProvider` | Async state with mutations | `authStateProvider` |

### Dependency Injection

Riverpod's override system enables clean test injection:

```dart
// Production
final container = ProviderContainer(
  overrides: [appDatabaseProvider.overrideWithValue(db)],
);

// Test
final container = ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(inMemoryDb),
    anilistGatewayProvider.overrideWith(mockGateway),
  ],
);
```

### Provider Lifecycle

- **Auto-dispose:** Providers are garbage-collected when no longer watched
- **Keep-alive:** Critical providers (auth, DB) are kept alive
- **Family:** Parameterized providers for dynamic data (e.g., `animeDetailProvider(anilistId)`)

---

## Navigation & Routing

### AppNavigationShell

The app uses a **custom navigation shell** with:
- **Bottom navigation bar** with 5 tabs (Anime) or 4 tabs (Manga)
- **Tab state preservation:** Each tab maintains its own navigation stack
- **Universe switching:** Animated transition between Anime and Manga modes
- **Fallback banner:** Global error state with retry action

### Deep Link Handling

The `DeepLinkHandler` processes `kumoriya://` custom scheme URLs:
- `kumoriya://party/join?code=XXXX` → Navigate to Watch Party join flow
- Handles cold-start (app not running) and warm-start (app in background) scenarios

---

## UI Design System

### Theme Architecture

The `KumoriyaTheme` provides:
- **Universe-specific accents:** Purple for Anime, Blue for Manga
- **Dark theme only:** Designed for media consumption
- **Animated transitions:** `AnimatedTheme` cross-fades on universe switch
- **Consistent color tokens:** `KumoriyaColors.primary`, `.surface`, `.textPrimary`, etc.

### Shared Widgets

| Widget | Purpose |
|:---|:---|
| `AnimeCard` | Grid item with poster, title, status pill |
| `ContinueWatchingCard` | Horizontal scroll item with progress bar |
| `EpisodeRow` | Episode list item with number, title, watched state |
| `KumoriyaCachedImage` | Image with loading shimmer, error fallback, cache |
| `MetaChip` | Genre/tag chip with consistent styling |
| `SectionHeader` | Section title with optional "See all" action |
| `StatusPill` | Airing/Completed status indicator |
| `StateViews` | Loading, error, empty state widgets |
| `BugReportButton` | Floating action button for user feedback |
| `ActivePartyBanner` | Persistent banner on home when user is in an active watch party |
| `PartyExitDialog` | Confirmation dialog when leaving a watch party |

### Responsive Design

- **Grid layout:** Adaptive columns based on screen width
- **Desktop optimization:** Wider layouts, hover states on Windows
- **Tablet support:** Intermediate column counts

---

## Feature Catalog

### Anime Catalog (`anime_catalog/`)

**Pages:** Home, Search, Detail, Episodes, Calendar, Library, Downloads, Trending, Season Hub, Tag Find

**Key capabilities:**
- Paginated infinite scroll feeds
- Multi-source availability checking
- Source-specific episode listing (JKAnime, AnimeFLV, etc.)
- Server link extraction with resolver selection
- Playback launch orchestration

### Manga Catalog (`manga_catalog/`)

**Pages:** Home, Search, Library, Downloads

**Key capabilities:**
- Manga-specific discovery feed
- Chapter listing with scanlator info
- Manga reader with page navigation
- CBZ download packing

### Player (`player/`)

**Key capabilities:**
- Session orchestration (initialize, play, pause, seek, dispose)
- Multi-quality stream selection
- HLS stream handling
- Progress tracking with periodic saves
- AniSkip integration (intro/outro detection)
- Performance benchmark mode
- **Watch Party integration:** buffering state reporting, synchronized seek barrier, auto-pause on member disconnect

### Downloads (`downloads/`)

**Key capabilities:**
- Background download manager with queue
- HLS segment downloader
- Download scoring/prioritization
- Auto-delete after watching
- Download directory management
- Foreground service (Android notification)

### Watch Party (`watch_party/`)

**Key capabilities:**
- Room creation and joining via Cloudflare Worker (v2 architecture)
- WebSocket real-time client with Ed25519 session tokens
- Playback state synchronization with server-authoritative clock
- Host authority management (transfer, kick, grace period)
- **Ready barrier system:** synchronized seek, media change, and episode change reset all ready states; playback auto-resumes when all members re-toggle ready
- **Buffering state tracking:** members report `buffering` status during video load
- **Auto-pause on disconnect:** server pauses playback when a watching member disconnects
- **Source selection broadcast:** host's source/server choice is broadcast so members can auto-resolve the same provider locally
- **Immersive re-entry:** persistent party banner on home, exit confirmation dialog, pop-based navigation
- **Voice Chat (WebRTC PTT):** Push-to-Talk voice communication via `flutter_webrtc` 1.5.1, ExpressTURN relay, P2P mesh topology
- Debug logging for diagnostics

### Authentication (`auth/`)

**Key capabilities:**
- Anonymous account creation
- OAuth login (Discord, Google)
- Passkey registration and login
- Token storage (secure storage)
- Account migration (anonymous → authenticated)
- Account deletion

### App Update (`app_update/`)

**Key capabilities:**
- OTA update checking against R2 manifest
- Version comparison
- Update available dialog
- Post-update release notes
- Platform-specific download (APK/MSIX)

### Library (`library/`)

**Key capabilities:**
- Unified anime + manga library view
- Filtering and sorting
- Notification preferences per title
- Auto-download preferences

### Settings (`settings/`)

**Key capabilities:**
- Language preference (es/en)
- Auto-delete delay configuration
- Download path management

---

## Offline & Caching

### Cache Architecture

```
┌─────────────────────────────────────────────┐
│              Cache Layer                     │
│                                              │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐  │
│  │ AniList  │ │ Source   │ │ Translation │  │
│  │ Cache    │ │ Avail.   │ │ Cache       │  │
│  │ (30d TTL)│ │ (7d TTL) │ │ (30d TTL)   │  │
│  └──────────┘ └──────────┘ └─────────────┘  │
│  ┌──────────┐                               │
│  │ AniSkip  │                               │
│  │ Cache    │                               │
│  │ (14d TTL)│                               │
│  └──────────┘                               │
│                                              │
│  All caches backed by Drift (SQLite)         │
└─────────────────────────────────────────────┘
```

### Fallback Strategy

When the AniList API is unreachable:
1. Serve from local cache (even if stale)
2. Show a **fallback banner** indicating degraded mode
3. Periodically probe AniList health
4. Auto-recover when connectivity returns

### Offline Queue

- **Sync mutations:** Queued locally, drained when online
- **Download queue:** Persisted across app restarts
- **Progress saves:** Written locally first, synced later

---

## Platform Integration

### Android-Specific

- **ExoPlayer:** Native video playback via `kumoriya_exoplayer`
- **Workmanager:** Background periodic tasks
- **Foreground Service:** Download progress notification
- **Local Notifications:** New episode alerts
- **Firebase:** Push notifications + Analytics
- **SAF:** Storage Access Framework for download directory
- **Deep Links:** Android App Links + intent:// handling

### Windows-Specific

- **Window Manager:** Custom window size/position
- **media_kit:** libmpv-based playback
- **File picker:** Native directory selection
- **MSIX packaging:** Windows Store-compatible distribution

### Linux-Specific

- **Audio:** PipeWire/PulseAudio delivery for voice chat
- **PTT overlay suppression:** Desktop PTT overlay hidden on Linux to avoid compositor issues
- **`flutter_webrtc`:** WebRTC audio rendering via libjingle

### Shared

- **Path Provider:** Platform-appropriate storage paths
- **Package Info:** Version detection for update checks
- **Permission Handler:** Runtime permission requests
- **`flutter_webrtc`:** WebRTC voice chat (Android, Windows, Linux)
