# Plugin System

> **Plugin-first architecture: contracts, registration, resolution, and the matching engine.**

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Plugin Contracts](#plugin-contracts)
3. [Source Plugins](#source-plugins)
4. [Resolver Plugins](#resolver-plugins)
5. [Resolver Registry](#resolver-registry)
6. [Matching Engine](#matching-engine)
7. [Plugin Manifest](#plugin-manifest)
8. [Adding New Plugins](#adding-new-plugins)

---

## Design Philosophy

Kumoriya's plugin system is built on three non-negotiable principles:

1. **UI depends on contracts, never on concrete plugins**
2. **Source extraction and stream resolution are independent**
3. **Prefer no match/stream over a wrong match/stream**

This ensures the core application remains stable even when:
- Third-party websites change their DOM structures
- Hosting services modify their embed/stream URLs
- New sources need to be added or old ones removed

---

## Plugin Contracts

All contracts live in `packages/kumoriya_plugins/` — a pure Dart package with zero UI dependencies.

### Contract Package Structure

```
kumoriya_plugins/
└── lib/
    ├── kumoriya_plugins.dart          # Public API barrel
    └── src/
        ├── contracts/
        │   ├── source_plugin.dart     # SourcePlugin abstract interface
        │   └── resolver_plugin.dart   # ResolverPlugin abstract interface
        └── models/
            ├── plugin_type.dart       # PluginType enum (source, resolver)
            ├── plugin_manifest.dart   # Plugin metadata
            ├── plugin_capability.dart # Declared feature set
            ├── source_search_query.dart
            ├── source_anime_match.dart
            ├── source_anime_detail.dart
            ├── source_episode.dart
            ├── source_server_link.dart
            ├── source_server_link_type.dart
            └── resolved_stream.dart
```

### Result Boundary

All plugin operations return `Future<Result<T, KumoriyaError>>`:

```dart
Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(SourceSearchQuery query);
```

This keeps failures explicit and prevents exception-driven control flow.

---

## Source Plugins

### Contract

```dart
abstract class SourcePlugin {
  PluginManifest get manifest;

  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  );

  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  );

  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  );

  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  );
}
```

### Responsibilities

- Search a source catalog by title
- Fetch detailed metadata for a source-local ID
- List episodes for a source-local anime entry
- Extract raw server/hosting links from an episode page

### Non-Responsibilities

- Selecting the best resolver for a link
- Converting hosting pages into playable media URLs
- Playback or player configuration
- AniList matching policy (that's the matching engine's job)

### Implemented Source Plugins

| Plugin | Package | Content Type |
|:---|:---|:---|
| Miruro | `kumoriya_source_miruro` | Anime |
| JKAnime | `kumoriya_source_jkanime` | Anime |
| AnimeFLV | `kumoriya_source_animeflv` | Anime |
| AnimeAv1 | `kumoriya_source_animeav1` | Anime |
| Anime Nexus | `kumoriya_source_anime_nexus` | Anime |
| MangaDex | `kumoriya_source_mangadex` | Manga |
| InManga | `kumoriya_source_inmanga` | Manga |
| LectorTMO | `kumoriya_source_lectortmo` | Manga |
| ManhwaWeb | `kumoriya_source_manhwaweb` | Manga |
| NekoScan | `kumoriya_source_nekoscan` | Manga |
| Olympus | `kumoriya_source_olympus` | Manga |
| VisorManga | `kumoriya_source_visormanga` | Manga |

---

## Resolver Plugins

### Contract

```dart
abstract class ResolverPlugin {
  PluginManifest get manifest;
  int get priority;

  bool supports(Uri url);
  Future<Result<ResolvedStream, KumoriyaError>> resolve(Uri url);
}
```

### Responsibilities

- Gate: decide whether this resolver can handle a given URL (`supports()`)
- Validate host/path conservatively (strict allowlisting)
- Extract playable media URL from hosting service page
- Attach required HTTP headers (Referer, Origin, User-Agent)

### Non-Responsibilities

- Scraping anime catalogs or episode listings
- Source-to-anime matching
- Playback UI or player controls

### Implemented Resolver Plugins (21)

| Plugin | Package | Host |
|:---|:---|:---|
| Doodstream | `kumoriya_resolver_doodstream` | doodstream.com |
| Filemoon | `kumoriya_resolver_filemoon` | filemoon.sx |
| HQQ | `kumoriya_resolver_hqq` | hqq.tv |
| JKPlayer | `kumoriya_resolver_jkplayer` | jkplayer.net |
| MediaFire | `kumoriya_resolver_mediafire` | mediafire.com |
| MixDrop | `kumoriya_resolver_mixdrop` | mixdrop.co |
| MP4Upload | `kumoriya_resolver_mp4upload` | mp4upload.com |
| Okru | `kumoriya_resolver_okru` | ok.ru |
| PixelDrain | `kumoriya_resolver_pixeldrain` | pixeldrain.com |
| Streamtape | `kumoriya_resolver_streamtape` | streamtape.com |
| StreamWish | `kumoriya_resolver_streamwish` | streamwish.com |
| UpnShare | `kumoriya_resolver_upnshare` | upnshare.com |
| VidHide | `kumoriya_resolver_vidhide` | vidhide.com |
| VOE | `kumoriya_resolver_voe` | voe.sx |
| YourUpload | `kumoriya_resolver_yourupload` | yourupload.com |
| Zilla | `kumoriya_resolver_zilla` | zilla-x.com |
| Anime Nexus | `kumoriya_resolver_anime_nexus` | anime_nexus (custom) |
| Miruro AniDB | `kumoriya_resolver_miruro_anidb` | hls.anidb.app |
| Miruro Kwik | `kumoriya_resolver_miruro_kwik` | cdn.kwik.si, kwik.cx, uwucdn.top, owocdn.top |
| Miruro VibePlayer | `kumoriya_resolver_miruro_vibeplayer` | vibeplayer.site |
| Miruro VidTube | `kumoriya_resolver_miruro_vidtube` | mt.nekostream.site |

### Common Resolver Utilities

`kumoriya_resolver_common` provides shared infrastructure:
- **Dean Edwards Unpacker:** JavaScript obfuscation decoder
- **Payload Normalizer:** Standardizes extracted URLs
- **Response Guard:** Validates HTTP responses
- **Stream Verifier:** Checks playable stream validity
- **URL Helpers:** Host extraction, parameter manipulation

---

## Resolver Registry

### Selection Algorithm

Located in `apps/kumoriya_app/lib/src/features/anime_catalog/application/services/resolver_registry.dart`:

```
Input: List<SourceServerLink>
Output: Map<SourceServerLink, ResolverPlugin>

For each server link:
  1. Filter resolvers where supports(link.url) == true
  2. Sort by descending priority
  3. If empty → no resolver available (graceful degradation)
  4. If top two have equal priority → return ambiguity (prefer no stream)
  5. Otherwise → return highest priority resolver
```

### Priority System

Resolvers declare a numeric priority. Higher = preferred:

- **High priority (100+):** Reliable, fast resolvers
- **Medium priority (50-99):** Working but slower
- **Low priority (1-49):** Fallback options
- **Negative priority:** Deprecated/experimental

### Ambiguity Detection

When two resolvers have equal top priority, the registry returns **ambiguity** instead of picking arbitrarily. This enforces the principle: **prefer no stream over wrong stream**.

---

## Matching Engine

### Purpose

Maps scraped source entries to canonical AniList IDs. This is the **data normalization layer** that turns unstructured web data into a unified catalog.

### Package: `kumoriya_matching`

```
kumoriya_matching/
└── lib/src/
    ├── normalization/     # Title cleaning and normalization
    ├── scoring/           # Match confidence scoring
    ├── pipeline/          # Multi-stage matching pipeline
    ├── blocking/          # Candidate blocking/pre-filtering
    └── models/            # Match result types
```

### Matching Pipeline

```
Source Title (dirty)
       │
       ▼
Stage 1: Normalization
  - Lowercase, trim
  - Remove special characters
  - Normalize Unicode (NFKD)
  - Expand abbreviations
       │
       ▼
Stage 2: Candidate Blocking
  - Query AniList search with normalized title
  - Filter by format (TV, Movie, OVA)
  - Filter by release year (±2 years)
       │
       ▼
Stage 3: Scoring
  - Exact title match: confidence 1.0
  - Synonym/alternative title match: confidence 0.9
  - Fuzzy match (Levenshtein): confidence 0.7-0.9
  - Partial word match: confidence 0.5-0.7
       │
       ▼
Stage 4: Decision
  - Confidence ≥ 0.9 → Auto-match
  - Confidence 0.7-0.9 → Match with warning
  - Confidence < 0.7 → No match (prefer no match over false match)
```

### Confidence Rules

| Confidence | Action |
|:---|:---|
| ≥ 0.95 | Exact match — auto-accept |
| 0.90 – 0.95 | High confidence — accept with low risk |
| 0.70 – 0.90 | Medium — flag for review |
| < 0.70 | Low — reject, return no match |

---

## Plugin Manifest

Every plugin exposes a `PluginManifest` with structured metadata:

```dart
class PluginManifest {
  final String id;              // e.g., "kumoriya.source.jkanime"
  final String displayName;     // e.g., "JKAnime"
  final PluginType type;        // source or resolver
  final Set<PluginCapability> capabilities;
  final String? iconUrl;
  final List<String>? supportedHosts;
  final List<String>? baseUrls;
  final bool usesWebView;       // Requires WebView fallback?
}
```

### Capabilities

```dart
enum PluginCapability {
  search,           // Can search the source catalog
  animeDetail,      // Can fetch detailed metadata
  episodeList,      // Can list episodes
  linkExtraction,   // Can extract server links
  streamResolution, // Can resolve to playable streams
}
```

---

## Adding New Plugins

### New Source Plugin Checklist

1. Create package: `packages/kumoriya_source_{name}/`
2. Implement `SourcePlugin` interface
3. Define a stable `manifest.id` (e.g., `kumoriya.source.{name}`)
4. Keep source identifiers source-local (don't leak AniList IDs)
5. Return `Result.failure()` when data is incomplete or confidence is low
6. Register in `plugin_runtime_catalog.dart`
7. Add tests with fixture HTML files
8. Run `dart analyze` and `dart format`

### New Resolver Plugin Checklist

1. Create package: `packages/kumoriya_resolver_{name}/`
2. Implement `ResolverPlugin` interface
3. Keep `supports(Uri)` strict — validate host and path pattern
4. Set `priority` deliberately relative to existing resolvers
5. Return `ResolvedStream` with required headers
6. Return `Result.failure()` when extraction is weak
7. Register in `plugin_runtime_catalog.dart`
8. Add tests with fixture HTML/HTTP responses
9. Run `dart analyze` and `dart format`
