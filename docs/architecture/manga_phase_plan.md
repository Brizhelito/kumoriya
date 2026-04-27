# Kumoriya — Manga Phase Plan

> Living document. Updated as slices land. Anime baseline is considered stable; manga is the next vertical universe.
> Throughout this document **"manga" includes manhwa, manhua, and webtoons** unless explicitly differentiated.

## 0. Goals and non-goals

### Goals

- Reach feature parity-of-experience with the anime side: discovery, search, library, progress, downloads, sync, offline-first.
- Plugin-first from day one: source plugins are independent, the reader is independent, contracts come before implementations.
- AniList remains canonical metadata. Match-or-skip discipline applies to manga the same way as to anime.
- Coexist with anime in the same app without forcing the user to context-switch unnecessarily, and without polluting anime-specific flows.
- Foundations general enough to host a second source (e.g. TMO, Asurascans, Bato) without rewrites — MangaDex ships first.

### Non-goals (this phase)

- Light novels, doujin, or any third media kind. We design `MediaKind` open enough to extend, but we do not implement them.
- Cross-translation of scanlator chapters (we surface what the source provides).
- Image upscaling / AI page enhancement.
- Built-in scanlator / community features.

## 1. Non-negotiables (manga-specific reading of repo rules)

1. **AniList is canonical metadata for manga too.** Source titles align to AniList ids via `kumoriya_matching`. Prefer no match over false match.
2. **Prefer no chapter over wrong chapter.** If the source/AniList disagreement cannot be reconciled with high confidence, surface a degraded state, never silently mismatch.
3. **Plugins are first-class.** `MangaSourcePlugin` is independent from the reader and from any UI. Source A breaking does not affect Source B or the reader.
4. **UI depends on contracts, never on concrete plugins or storage.**
5. **WebView is last-resort infra.** Reader v1 is Flutter native (`extended_image` + `PhotoView`). WebView is only acceptable as a fallback inside a specific source plugin if a site is otherwise unscrapable, never as the reader UX.
6. **Vertical slices.** Each slice ships compiled, tested, and analyzed. Format/analyze/relevant-tests before declaring done.

## 2. Coexistence model (UX)

### Decision: Universe Switch + Library unified

Top-level segmented control in the app shell: **Anime · Manga**. Switching the universe re-renders the tab set and tab content. The selection is persisted (e.g. last-active universe restored on launch).

- Anime tabs (current): `Home · Search · Calendar · Library · Downloads`.
- Manga tabs: `Home · Search · Latest · Library · Downloads`.
  - `Latest` replaces `Calendar` for manga: most-recent chapter releases of titles in the user library, plus a global "latest updated" feed for discovery.
- `Library` is rendered the same widget tree on both universes but **its data model is unified** (see §6) and exposes a filter chip `All / Anime / Manga`. The Library tab in either universe shows the unified library, with the chip preset to that universe.
- `Downloads` likewise: unified store, filter chip presets to current universe.
- `Settings` stays single. Sub-sections per universe where it makes sense (stream quality vs page quality, plugins enabled, reader defaults).
- Detail pages cross-link via AniList relations + `kumoriya_matching`'s `seriesId`. From an anime detail, "Read manga" jumps to the manga detail (and vice versa) when a canonical link exists.

### Universe theming (accent-only)

Switching universe **does not** change layout, typography, density, surfaces, or status colors. It changes the **accent** only:

- `primary`, `primaryDark`, `primaryLight`, `primaryContainer`, `navIndicator`, and any UI element semantically tied to "the active brand color".
- Everything else (`background`, `surface`, `navBackground`, text colors, success/warning/danger/info) is universe-agnostic.

Palettes:

- **Anime** (unchanged): violet `#7C3BED` family.
- **Manga** (proposed): coral `#E5484D` family. Final hue locked in via `uiux-review` once previews exist; teal `#14B8A6` is the runner-up.

Implementation outline:

1. New value object `UniverseAccent { primary, primaryDark, primaryLight, primaryContainer, navIndicator }`, with two static instances `UniverseAccent.anime` / `UniverseAccent.manga`.
2. Riverpod `currentUniverseAccentProvider` derived from `currentUniverseProvider`.
3. `KumoriyaTheme.dark` becomes a function of `UniverseAccent`. `MaterialApp` rebuilds its `ThemeData` when the universe changes.
4. Migrate call sites from `KumoriyaColors.primary` to `Theme.of(context).colorScheme.primary`, in waves:
   - Wave A (slice 7.5): shell, nav rail / bottom bar, active tab indicator, logo mark, fallback banners.
   - Wave B (slice 7.6): primary buttons, progress indicators, focus borders, snackbars.
   - Wave C (deferred / on-demand): detail page chips, cards, ad-hoc usages — driven by `uiux-review` findings.
5. `KumoriyaColors.primary` stays as a backwards-compat constant equal to the anime accent so the migration can be incremental and bisectable. New code must never reference it; lint rule (custom analyzer hint or doc-only) discourages new uses.
6. Cross-fade 200 ms via `AnimatedTheme` on universe change. No additional flourish.

This work is its own pair of slices (7.5, 7.6) inside the slice plan (§10).

### What this implies for the shell

- `KumoriyaTab` enum becomes universe-scoped. Either:
  - Option (a) split into `KumoriyaAnimeTab` and `KumoriyaMangaTab`, or
  - Option (b) keep one enum with a `MediaKind` axis: `(MediaKind.anime, AnimeTab.home)`.
  - **Choose (a)**. Less type gymnastics, and Calendar/Latest are not symmetric.
- `AppNavigationShell` accepts a `currentUniverse` and a per-universe tab builder map. Persistence via a `current_universe` key in settings.
- The Universe Switch widget lives above the tab body (mobile) or at the top of the desktop rail.

## 3. Domain & package layout

### MediaKind

Add to `kumoriya_core`:

```dart
enum MediaKind { anime, manga }
```

Used **only** by truly cross-cutting entities: `LibraryEntry`, `DownloadEntry`, `HistoryEntry`, sync payloads, deep links. Anime and manga domain entities themselves do **not** carry `MediaKind` — their type already implies it.

### Packages (new)

| Package | Responsibility |
|---|---|
| `kumoriya_manga_domain` | `Manga`, `MangaDetail`, `MangaChapter`, `MangaPage`, `MangaStatus`, `MangaFormat (manga/manhwa/manhua/oneShot/novel)`, `MangaCatalogRepository`, `MangaSearchRequest`, `MangaBrowseRequest`. |
| `kumoriya_manga_plugins` | `MangaSourcePlugin` contract + shared models (`SourceMangaMatch`, `SourceMangaDetail`, `SourceChapter`, `SourcePage`). Reuses `PluginManifest` from `kumoriya_plugins`. |
| `kumoriya_reader` | Reader engine and contract: vertical webtoon + paginated. Prefetch, page cache, resume, zoom, gestures. No plugin/source coupling. |
| `kumoriya_source_mangadex` | First source plugin (MangaDex API). |

### Packages (extended, not refactored)

| Package | Extension |
|---|---|
| `kumoriya_anilist` | Add MANGA queries: `searchManga`, `browseManga`, `fetchMangaDetail`, `fetchBatchMangaByIds`, `fetchTrendingManga`, `fetchMangaGenreCollection`. Internally parameterize the underlying GraphQL by `MediaType`. Keep all existing anime methods. |
| `kumoriya_storage` | Add stores: `manga_progress_store`, `manga_library_store`, `chapter_cache_store`, `manga_download_store`. Drift migrations are **additive**: new tables, no rewrite of anime tables. Library + Downloads gain a `media_kind` column-driven aggregate view at the repository layer. |
| `kumoriya_matching` | Already neutral via `CanonicalSeries`. Confirm fingerprint builder handles manga formats; add `MediaKind` to `SeriesRecord` for disambiguation when same title exists as anime+manga. |
| `kumoriya_sync` | Add manga progress + manga library payloads. Same protocol pattern as anime. |

### Packages explicitly NOT touched

- `kumoriya_exoplayer` and all `kumoriya_resolver_*` — irrelevant for manga.
- `kumoriya_source_*` (anime sources) — untouched.

### Why parallel and not generic-from-the-start

Forcing a generic `Series`/`Chapterable`/`Episodeable` abstraction now would:

- Conflate fields that diverge fast (fractional chapter numbers like `12.5`, scanlator + language per chapter, page assets, webtoon vs paginated layout, side-stories vs OVAs).
- Slow every anime change because every anime change becomes a generic-API change.

We pay a small duplication cost at the entity level and gain a hard isolation boundary. We **only** generalize at the integration edge: Library, Downloads, History, Sync, deep linking — where the user really thinks unified.

## 4. Plugin contract (MangaSourcePlugin)

```dart
abstract interface class MangaSourcePlugin {
  PluginManifest get manifest;

  // Capability flags so the UI can adapt without sniffing the implementation.
  MangaSourceCapabilities get capabilities;

  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    SourceMangaSearchQuery query,
  );

  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceId,
  );

  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    String sourceId, {
    SourceChapterFilter filter, // language, scanlator, etc.
  });

  // Returns ready-to-load page descriptors. Per-page imageUrl is the
  // canonical playable artifact; headers carry Referer/UA when needed.
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    String sourceChapterId,
  );

  // Optional: latest releases feed for the "Latest" tab.
  Future<Result<List<SourceLatestUpdate>, KumoriyaError>> getLatestUpdates({
    int page = 1,
  });
}
```

Models:

- `SourceMangaMatch` — `sourceId`, `title`, `aliases`, `coverUrl`, `releaseYear`, `format`.
- `SourceMangaDetail` — adds `synopsis`, `authors`, `artists`, `tags`, `status`, `originalLanguage`.
- `SourceChapter` — `sourceChapterId`, `number` (double, allows `12.5`), `title?`, `volume?`, `language`, `scanlator?`, `publishedAt?`, `pageCount?`.
- `SourcePage` — `index`, `imageUrl`, `headers`, optional `width/height` if known.
- `MangaSourceCapabilities` — `supportsLanguageFilter`, `supportsScanlatorFilter`, `supportsLatestFeed`, `requiresPageHeaders`.

This contract intentionally has **no resolver layer**: pages are URLs the reader can fetch directly. If a source needs decryption (rare), it does it inside `getChapterPages` and returns plain URLs (or data URIs). If decryption is per-page-request and uncacheable, we extend the contract with a `resolvePage(SourcePage)` hook in a later slice — only when the second or third source proves we need it.

## 5. Reader (kumoriya_reader)

### Modes

- **Vertical continuous** (default for manhwa/webtoon). Infinite-scroll-like list of pages with prefetch.
- **Paginated** (default for manga/manhua/oneShot). Horizontal swipe per page; double-tap zoom; pinch zoom via `PhotoView`.

Mode is per-title (auto-default by `MangaFormat`, override saved per manga).

### Engine responsibilities

- Prefetch N pages ahead (default 3, configurable).
- Disk cache via `chapter_cache_store` with TTL and per-chapter eviction policy. Cache key = `(sourceId, sourceChapterId, pageIndex)`.
- Resume: persists `(mangaId, chapterId, pageIndex, scrollOffset)` in `manga_progress_store` on debounced events (e.g. every 1.5 s of scroll quiescence + on dispose).
- Headers: respects per-page `headers` from `SourcePage` (e.g. Referer for hotlink-protected CDNs).
- Error handling: per-page retry with exponential backoff; "tap to retry" UI; never silently swap a wrong page.

### Reader is not coupled to plugins

The reader takes a `ChapterSession` value object (already-fetched `List<MangaPage>` plus metadata). The slice that wires plugin → reader lives in the app, not in `kumoriya_reader`.

## 6. Storage model

### New Drift tables (additive)

- `manga` — local cache mirror of AniList manga (id, titles JSON, format, status, cover, etc.).
- `manga_chapters` — `(sourceId, sourceChapterId)` → metadata, indexed by `(mangaId, number)`.
- `manga_progress` — last read per `(mangaId, chapterId, pageIndex, scrollOffset, updatedAt)`.
- `manga_library` — `(mangaId, addedAt, listCategory)`. The aggregate library view joins this and `library` (anime) at repo level into a unified stream.
- `chapter_cache` — page blob index keyed by `(sourceId, sourceChapterId, pageIndex)`. Bytes live on disk under app cache dir; Drift holds the index + size + ttl.
- `manga_downloads` — durable downloads, one row per chapter, bundled to CBZ on completion (see §7).

### Repository layer

- `MangaCatalogRepository` (in `kumoriya_manga_domain`) — analogous to `AnimeCatalogRepository`. Implementation in app layer combines AniList + matching + source plugin.
- `UnifiedLibraryRepository` (new, in `kumoriya_domain` or a new `kumoriya_shared_domain`) — exposes `Stream<List<LibraryEntry>>` where `LibraryEntry` carries `MediaKind`. Composes anime `LibraryStore` + manga `MangaLibraryStore`.
- Same approach for `UnifiedDownloadsRepository` and `UnifiedHistoryRepository`.

### Migrations

Strictly additive in this phase. No anime table is altered. Migration version bumps once per slice that introduces tables.

## 7. Downloads

- Unit of download = **chapter**. Surfacing per-page partial state in UI; storage materializes a single CBZ (zip with images) per chapter on completion, stored under the user's configured download directory.
- Reuses the existing download pipeline scaffolding (queue, retries, progress notifications) via an adapter that:
  - Takes a `SourceChapter` + `List<SourcePage>`.
  - Streams page downloads with concurrency cap (default 4) and per-page retry.
  - On success, packages into `<title>/Vol_<v>_Ch_<n>_<scanlator>.cbz`.
  - On failure, marks chapter as `partial` and resumable.
- Offline read path: reader prefers the CBZ when present, falls back to network/cache otherwise. The reader does not know about downloads — the chapter session loader resolves the right source.

## 8. AniList integration for manga

- Reuse `AnilistMetadataGateway` by parameterizing the GraphQL `MediaType`.
- Add explicit manga-named methods to keep call sites readable, all delegating to the same parameterized internal client.
- AniList user lists for manga (`MediaListStatus` for manga lists) integrate with the unified library when the user is logged in.
- Calendar is anime-only. For manga we drive `Latest` from the active source's latest updates intersected with the user's library and AniList "currently reading".

## 9. Cross-link anime ↔ manga

- `kumoriya_matching` provides `seriesId` keyed by canonical metadata. We extend `SeriesRecord` with `MediaKind`, so the same intellectual property can yield two records (one anime, one manga) sharing the same canonical "franchise" id when AniList relations confirm it.
- AniList `relations` already encodes `ADAPTATION` / `SOURCE`. The detail page reads relations and surfaces a "Read manga" / "Watch anime" button when a high-confidence linked entry exists.

## 10. Slice plan (vertical, in order)

| # | Slice | Output | Closes when |
|---|---|---|---|
| 1 | `MediaKind` in `kumoriya_core` | enum + serialization helpers + tests | format, analyze, tests green |
| 2 | `kumoriya_manga_domain` core entities + `MangaCatalogRepository` contract | package compiles, model tests | green |
| 3 | `kumoriya_anilist` MANGA extension | new methods + mapper + tests against fixtures | green |
| 4 | `kumoriya_manga_plugins` contracts + models + `MangaSourceCapabilities` | package compiles + contract docs | green |
| 5 | `kumoriya_storage` manga stores + Drift migrations (additive) | stores + DAO tests | green, migration test passes |
| 6 | `kumoriya_source_mangadex` v1: search + detail + chapters + pages | plugin tests with recorded API fixtures | green |
| 7 | App shell: split `KumoriyaTab` into anime/manga, add `UniverseSwitch`, persist selection, render manga placeholders | manual smoke + widget tests | green |
| 7.5 | Universe theming wave A: `UniverseAccent` + provider + `AnimatedTheme` + migrate shell/nav/banners to `Theme.of(context).colorScheme.primary` | widget + golden tests | green |
| 7.6 | Universe theming wave B: migrate primary buttons / progress / focus / snackbars | widget + golden tests | green |
| 8 | Manga Home + Search + Detail (AniList + matching + MangaDex) | end-to-end discovery → detail | green, smoke ok |
| 9 | `kumoriya_reader` MVP (vertical + paginated, prefetch, resume, zoom) | reader tests + golden tests for layout | green |
| 10 | Manga Library (unified) + progress + sync hooks | library tab works for both universes with chip filter | green |
| 11 | Manga Downloads (CBZ pipeline) + offline reader path | download a chapter, read offline, resume | green |
| 12 | Cross-link anime↔manga in detail pages via `kumoriya_matching` + AniList relations | jump A↔M when applicable | green |
| 13 | Second source scaffolding (no implementation) — verify contract surface holds, document plugin authoring guide | doc + dummy plugin compiles against contracts | green |

Each slice ends with: format, analyze, relevant tests, dev-diary entry per `.agents/skills/dev-diary`. Conventional commits. One concern per commit.

## 11. Risks and open questions

- **MangaDex rate limits / availability.** Mitigate with cache TTL + retry with backoff. Keep fixtures so tests do not hit network.
- **Chapter numbering ambiguity.** Fractional, side-story, oneshot chapters complicate progress and library "next chapter" computations. The domain models support `double number`, `volume`, `title` to disambiguate.
- **Language + scanlator picking.** First-run UX picks user's preferred languages (settings); the chapter list filters but always allows revealing all. We do not auto-pick scanlators silently when multiple exist for the same chapter — we surface a chooser the first time, remember the user's preference per manga.
- **Webtoon-vs-paginated default.** AniList `format` plus `country_of_origin` is good but imperfect. Allow per-manga override and remember it.
- **Page size + cache footprint.** Webtoon chapters can be 30+ MB. Cache eviction policy + a hard cap configurable in Settings.
- **CBZ vs raw folder.** CBZ is portable but slower to update partial state. We persist partial state as a folder, repackage to CBZ only on full success.
- **AniList manga list parity.** AniList list status names differ slightly for manga (`PLANNING`, `CURRENT`, `COMPLETED`, `DROPPED`, `PAUSED`, `REPEATING`) — same enum values, but UX copy must use "Reading" instead of "Watching". Localization keys split per universe.
- **Detail page generalization.** We may end up wanting a single `SeriesDetailPage` skeleton with two strategies. Defer: build the manga page fresh, extract shared widgets only when duplication actually hurts.

## 12. Skills and contracts ownership

- New skills to add (later, when surface stabilizes):
  - `manga-source-plugin` — analogous to `source-plugin-jkanime`, parametrizable per source.
  - `reader-slice` — analogous to `player-slice` but for the manga reader.
- Existing skills that already cover manga work without changes:
  - `anilist-matching`, `flutter-vertical-slice`, `storage-drift`, `uiux-review`, `validate-task`, `changelog-release-notes`, `dev-diary`.

## 13. Definition of done for the manga phase

- A user can: switch to the manga universe, discover via Home, search any manga, open detail, read a chapter (vertical or paginated), resume across sessions, mark as library, download a chapter, read it offline, and see latest updates of titles they follow.
- AniList list state for manga is synced when logged in.
- Anime experience is unaffected.
- A second source can be authored without modifying any contract in the published packages.
- Documented in CHANGELOG and in `docs/dev-diary/` per slice.
