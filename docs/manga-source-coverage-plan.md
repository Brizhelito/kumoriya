# Manga Source Coverage — Master Plan

> **Status as of 2026-04-29:** S0 (recon) ✅ · S1.A (MangaBaka) ✅ · S1.B (MangaUpdates) ✅ · S1.C (composite v2) ✅ · S1.D (MangaBaka matching wired) ✅ · S1.E (source picker + gateway provider) ✅ · S1.F onward pending
> **Owner / driver:** brizhelito · **Plan version:** v3.1
> **Cross-refs:** `docs/dev-diary/2026-04-29.md`, `docs/60-roadmap.md` (Phase 5)

This document is the single source of truth for the **manga source coverage** workstream. It captures everything we have investigated, every decision we made, the slice-by-slice breakdown, the current state, and the residual risk. Update it after each slice closes.

---

## 1. Context and motivation

### 1.1 Why this exists

The manga side of Kumoriya currently ships with a **single source plugin** (`kumoriya_source_mangadex`). MangaDex covers most non-LatAm content well, but our user base skews Spanish-speaking and the LatAm scanlator scene has consolidated around sites that **do not publish to MangaDex**: Olympus Scans, InManga, ManhwaWeb, Ikigai, etc. Until recently, **TMO/LectorTMO** was the de-facto LatAm aggregator; it has now deprecated/blocked third-party access, leaving a gap.

In parallel, the legal Western publishing front (**Webtoons**, **Comikey**, **MangaPlus**) is well-trafficked and we can't ignore it without losing perceived breadth.

### 1.2 What "good" looks like

A user opening any popular manga on Kumoriya should see, **per language**:

1. The official legal source if one exists (priority badge).
2. The most-active scanlator for that language with usage signals (chapter count, last activity, status).
3. A clear "fallback" option (MangaDex / WeebCentral) when nothing else covers them.

The picker needs to **enrich** these options — not just list opaque names, but show "MangaReworks · activo · 234 caps lifetime · última actividad: hace 3 días" so users can pick informed defaults.

### 1.3 Non-negotiables (from `AGENTS.md`)

1. AniList is canonical metadata. **Prefer no match over false match.**
2. **Prefer no stream over wrong stream.**
3. Plugins are first-class. Source plugins, resolver plugins and the player are independent.
4. UI depends on contracts, never on concrete plugins or storage.
5. WebView is last-resort infra, not a UX primitive.
6. Work in vertical slices. No blind copy from legacy.

These constrain every decision below.

---

## 2. Investigation summary (S0 — recon)

This section captures the **field intelligence** we gathered before writing any code, so we don't re-discover the same facts later.

### 2.1 Cloudflare gating per candidate source

Tested with `curl` (browser-realistic UA) against root + API/JSON endpoints:

| Source | Domain | Surface tested | Status |
|---|---|---|---|
| **MangaBaka** | `api.mangabaka.dev` | `/v1/series/search`, `/v1/series/{id}` | ✅ **Open** — JSON, no challenge |
| MangaBaka | `mangabaka.dev` (homepage) | `/` | ⛔ Cloudflare interactive challenge (irrelevant for us) |
| **MangaUpdates** | `api.mangaupdates.com` | REST API | ✅ Open |
| **Olympus** | `olympusscanlation.com` | HTML pages | ⚠️ Light Cloudflare; passes with realistic UA |
| **InManga** | `inmanga.com` | HTML pages | ✅ Open |
| **ManhwaWeb** | `manhwaweb.com` | JSON API | ✅ Open |
| **Ikigai** | `ikigaimangas.com` | HTML pages | ⚠️ Cloudflare on some endpoints |
| **MangaDex** | `api.mangadex.org` | REST | ✅ Open (already integrated) |
| **WeebCentral** | `weebcentral.com` | HTML | ✅ Open |
| **ComicK** | `api.comick.io` | REST | ✅ Open (rotates host) |
| **MangaPlus** | `jumpg-webapi.tokyo-cdn.com` | gRPC/Proto | ✅ Open (binary protocol) |
| **Webtoons** | `webtoons.com` | HTML + mobile API | ✅ Open |
| **Comikey** | `comikey.com` | HTML | ✅ Open |

**Conclusion:** No source we care about requires a Cloudflare-bypass proxy. Original plan included a `MangaBaka via Cloudflare Worker` slice (S11 in v3); **cancelled** — saves ~1 day.

### 2.2 MangaBaka capability assessment

Live-captured fixtures for Solo Leveling (now in `packages/kumoriya_mangabaka/test/fixtures/`):

**What MangaBaka gives us:**
- ⭐ **Title corpus** — 27 title variants in many languages (`secondary_titles` flattened across langs). The killer feature for fuzzy matching against scanlators that title series in their local language.
- ⭐ **Cross-tracker IDs** — per series: `anilist`, `my_anime_list`, `kitsu`, `manga_updates` (string), `anime_planet` (slug), `anime_news_network`, `shikimori`. Feeds the picker enrichment slice (S1.F) directly.
- Cover URLs (with imgproxy CDN variants), descriptions, ratings, authors, artists, genres, status, year, type (manga/manhwa/manhua/novel).

**What MangaBaka does NOT give us:**
- ❌ MangaDex / Bato.to / ComicK ids in the `source` block (still extracted via per-source fuzzy search).
- ❌ Slugs for Olympus, InManga, ManhwaWeb, Ikigai (not indexed).
- ❌ The `links[]` array points to **publishers** (Tappytoon, KakaoPage, Manta, Webnovel, Yen Press, Piccoma) — useful for legal-source detection but **not scanlators**.

**Implication:** MangaBaka is a **corpus expander** plus a **cross-ID resolver**, not a magic source-id resolver. The matching pipeline still does per-source fuzzy search, but with a much richer set of candidate titles to try.

**Operational details:**
- Endpoint: `https://api.mangabaka.dev/v1/`
- 404 envelope: `{"status":404,"message":"NOT_FOUND"}` (and the API also surfaces logical 404 inside a 200 envelope for permanently deleted records).
- Has `state` field: `active`, `merged`, `deleted`. Merged rows redirect via `merged_with` (we follow once).
- Some `source.<provider>.id` values come back as strings (numeric strings or slugs); the mapper coerces.

### 2.3 Source landscape (post-TMO classification)

| Tier | Source | Lang | Status | Notes |
|---|---|---|---|---|
| Legal (official) | **MangaPlus** (Shueisha) | EN, ES | Active | gRPC + image descrambling |
| Legal (official) | **Webtoons** | EN, ES, multi | Active | Korean originals, large catalog |
| Legal (official) | **Comikey** | EN, ES | Active | KR/CN/JP licensed |
| Legal (official) | **Manta**, **Tappytoon**, **KakaoPage**, **Piccoma** | varies | Active | Paywalled — out of scope |
| LatAm scanlator | **Olympus Scans** | ES | Active, rotates domains | High coverage manhwa |
| LatAm scanlator | **InManga** | ES | Active | LatAm classics |
| LatAm scanlator | **ManhwaWeb** | ES | Active | JSON-friendly |
| LatAm scanlator | **Ikigai Mangas** | ES | Active | Rebrand of Lectormanga |
| LatAm aggregator | **TMO / LectorTMO** | ES | ⛔ Deprecated | Reason this whole plan exists |
| Backbone (en) | **MangaDex** | multi | Active | Already integrated |
| Backbone (en) | **WeebCentral** | EN | Active | TMO-style aggregator, JSON-able |
| Backbone (en) | **ComicK** | multi | Active | Rotates hosts (M2 needed) |

### 2.4 Field intelligence on individual sources

Stored as concrete recon notes for the workers who will implement each plugin:

- **Olympus** rotates `olympusscanlation.com` ↔ `olympusbiblioteca.com` ↔ `tomanhua.com`. Plugin must support a configurable base URL with fallback list (M2 in the slice plan).
- **ComicK** uses `api.comick.io` which sometimes shifts subdomain when DDoS'd. Same M2 base-URL rotation pattern.
- **MangaPlus** speaks gRPC over HTTP/2 with protobuf payloads, and chapter pages are XOR-descrambled with a key embedded in the response. Non-trivial. Budget 3 days minimum.
- **Webtoons** has an undocumented mobile JSON API that's much friendlier than HTML scraping. Use that path.
- **InManga** uses chapter ids that look like UUIDs; their search returns paginated HTML.
- **ManhwaWeb** exposes `/api/comics?...` and `/api/chapters/...` JSON natively — easiest plugin in the LatAm tier.

---

## 3. Architectural decisions

### 3.1 Plan version evolution

| Version | Cimiento | Cobertura proyectada | Costo extra | Estado |
|---|---|---|---|---|
| v3 (initial) | AniList only + naïve title fuzzy | ~92% | +1d Cloudflare Worker | superseded |
| **v3.1 (current)** | AniList + **MangaBaka corpus** + multi-source fuzzy | **~95%** | +0.5d (API directa, sin proxy) | active |

Key insight that triggered v3.1: MangaBaka is **valuable as a title corpus**, not as an ID oracle. With 27 known title variants per series instead of AniList's 3-4, fuzzy matching against scanlators that title in Spanish/Portuguese/Russian becomes much more reliable.

### 3.2 Architecture invariants (preserved)

- **Plugin contract unchanged.** New sources implement the existing `MangaSourcePlugin` interface (defined in `packages/kumoriya_manga_plugins`).
- **Composite repository** in the app layer is the only place that knows about multiple plugins. Plugins themselves remain independent.
- **Metadata gateways** (`AnilistMetadataGateway`, `MangaBakaMetadataGateway`) are **separate concerns** from source plugins. They live in their own packages and feed the composite repository, not the plugins.
- **UI stays plugin-agnostic.** The picker takes a list of "options" (scanlator + source + language tuples) without knowing which plugin produced each one.
- **Storage stays catalog-agnostic.** Drift schemas don't grow new tables for the multi-source feature; preferences persist as `(anilistId) → preferred_source_id, preferred_scanlator, preferred_language` on existing rows.

### 3.3 New architectural seams introduced by this workstream

```
┌─────────────────────────────────────────────────────────────────┐
│                    Composite Manga Repository                    │
│  (refactored in S1.C; consumes N plugins + metadata gateways)   │
└──────────┬──────────────────┬─────────────────┬─────────────────┘
           │                  │                 │
   ┌───────▼─────────┐  ┌─────▼─────────┐  ┌────▼─────────────┐
   │ AniList gateway │  │MangaBaka gw   │  │MangaUpdates gw   │
   │ (canonical)     │  │(corpus + IDs) │  │(picker enrich)   │
   └─────────────────┘  └───────────────┘  └──────────────────┘
           │
   ┌───────┴─────────────────────────────────────────────────────┐
   │  Source plugins (independent, parallel-fanned-out by N)      │
   │                                                              │
   │  MangaDex · Olympus · InManga · ManhwaWeb · Ikigai ·         │
   │  MangaPlus · Webtoons · Comikey · WeebCentral · ComicK       │
   └──────────────────────────────────────────────────────────────┘
```

**Three new gateway packages**, **six+ new plugin packages**, **zero changes** to the plugin contract or domain models.

---

## 4. Slice breakdown (master plan)

Each slice is atomic, testable, and ships green before the next starts. Sub-slices use the `flutter-vertical-slice` skill conventions.

| Slice | Scope | Depends on | Estimate | Status |
|---|---|---|---|---|
| **S0** | Recon (Cloudflare, MangaBaka API, source landscape) | — | — | ✅ done |
| **S1.A** | `kumoriya_mangabaka` package (client + gateway + tests) | — | 0.5d | ✅ done |
| **S1.B** | `kumoriya_mangaupdates` package (client + gateway + tests) | — | 0.5d | ✅ done |
| **S1.C** | Composite repo v2: `List<MangaSourcePlugin>` + parallel fan-out + dedup | — | 1d | ✅ done |
| **S1.D** | Wire MangaBaka corpus into composite v2 matching | S1.A + S1.C | 0.5d | ✅ done |
| **S1.E** | UI: source picker chip + Drift v21 + MangaBaka gateway provider + l10n | S1.C + S1.D | 0.5d | ✅ done |
| **S1.F** | M8: scanlator picker enrichment via MU groups | S1.B + S1.E | 1.5d | ✅ done |
| **S2 (M2)** | Configurable base URL + fallback list contract | S1.C | 1d | ✅ done |
| **S3** | `kumoriya_source_olympus` plugin | S1.D + S2 | 1.5d | ✅ done |
| **S4** | `kumoriya_source_inmanga` plugin | S1.D | 1d | ✅ done |
| **S5** | `kumoriya_source_manhwaweb` plugin (JSON-native, easiest) | S1.D | 1d | ✅ done |
| **S6** | `kumoriya_source_ikigai` plugin | S1.D + S2 | 1d | ⏳ pending |
| **S7** | `kumoriya_source_lectortmo` plugin (TMO heir, ES core) | S1.D + S2 | 1.5d | ⏳ pending |
| **S8** | `kumoriya_source_lectormanga` plugin (ES, active) | S1.D + S2 | 1d | ⏳ pending |
| **S9** | `kumoriya_source_nekoscan` plugin (ES manhwa) | S1.D + S2 | 1d | ⏳ pending |
| **S10** | `kumoriya_source_visormanhwas` plugin (ES manhwa) | S1.D + S2 | 1d | ⏳ pending |
| **S11** | `kumoriya_source_webtoons_es` plugin (legal, `es.webtoons.com`) | S1.D | 1.5d | ⏳ pending |
| **S12** | `kumoriya_source_mangaplus` plugin (Shueisha, ES filter) | S1.D | 3d | ⏳ pending |
| **S13** | M4 (plugin health probes) + M5 (lang-aware ranking) + M8 polish | All sources | 3d | ⏳ pending |

**Out of scope** (cut from earlier draft as part of the ES-first rescope on 2026-04-30):

| Slice | Source | Reason |
|---|---|---|
| ~~S8b~~ | `kumoriya_source_comikey` | EN-first; ES catalog too thin to justify a full plugin. |
| ~~S9a~~ | `kumoriya_source_weebcentral` | EN-only aggregator. |
| ~~S9b~~ | `kumoriya_source_comick` | Multi-language aggregator, but ES tier overlaps almost entirely with MangaDex + Olympus + LectorTMO; deliberate redundancy with low signal. |

**Totals (ES-first rescope)**
- ✅ Done: S0 + S1.* + S2 + S3-S5 (~9d delivered).
- LatAm core remaining (S6 + S7 + S8 + S9 + S10): ~5.5 days → covers the active LatAm ecosystem post-TMO.
- Legal long-tail (S11 + S12): ~4.5 days → official publishers with ES support.
- Production polish (S13): ~3 days.
- **Grand total remaining: ~13 days** to reach ~95% **ES manga/manhwa** coverage.

### 4.1 Slice S1.A — MangaBaka client foundation ✅ DONE

Delivered 2026-04-29. Commit `92714c2`. Diary entry: `docs/dev-diary/2026-04-29.md`.

- Package `packages/kumoriya_mangabaka/` with sealed errors, defensive mapper, HTTP client (rate-limit + Retry-After + TTL cache + 404/5xx/429), gateway with `searchSeries` + `fetchSeriesById` (single-hop merge follow).
- Real fixtures captured from live API.
- 37/37 tests pass · `dart format` clean · `dart analyze` clean (workspace).
- No app-side wiring yet (leaf package; lands in S1.D).

### 4.2 Slice S1.B — MangaUpdates client (next)

Same shape as S1.A. Public REST API at `api.mangaupdates.com`. Two operations needed:

- `searchSeries(query)` — for cases where MangaBaka doesn't have the row.
- `fetchGroupActivity(groupName | groupId)` — for the picker enrichment in S1.F: returns latest release timestamp + lifetime release count + activity status (active/inactive).

Test strategy mirrors S1.A: MockClient + JSON fixtures captured live.

### 4.3 Slice S1.C — Composite repository v2

Refactor `apps/kumoriya_app/lib/src/features/manga_catalog/application/services/composite_manga_catalog_repository.dart`:

- Constructor takes `List<MangaSourcePlugin>` (currently single).
- `fetchMangaChapters(anilistId)` fans out in parallel to every plugin with a per-plugin timeout. One plugin failing must NOT fail the whole call.
- Dedup key becomes `(chapterNumber, language, sourceId)` — same chapter from two sources is fine, picker disambiguates.
- New `availableSources(anilistId)` provider returns the list of `(sourceId, scanlator, language, count)` tuples for the picker.

Boundary: still uses AniList title for matching (no MangaBaka yet). Tests use fake plugins.

### 4.4 Slice S1.D — Wire MangaBaka corpus

In the composite v2, before fanning out to plugins, fetch the MangaBaka series for the given AniList id (`searchSeries(title)` + filter by `crossIds.anilistId`, cached). For each plugin, attempt match using `series.titleCorpus` (priority-ordered iterable) until one variant returns hits. This is what gives us the +3% coverage jump over plain AniList-title matching.

### 4.5 Slice S1.E — Source picker dimension UI

Today's picker in `manga_detail_page.dart` only chooses scanlator + language. Extend it with a third dimension: source plugin (e.g. "MangaDex", "Olympus", "Webtoons"). l10n strings in `app_en.arb` / `app_es.arb`. Widget tests for the selection flow.

### 4.6 Slice S1.F — Picker enrichment (M8)

For each scanlator option, decorate with:
- Status badge: `activo` / `inactivo` / `desconocido` (derived from MU group last-release timestamp).
- Lifetime chapter count for that group (across all series, MU `releases_count`).
- Last-activity humanized: "hace 3 días", "hace 2 meses".

Cache aggressively (24h TTL on disk via Drift, not in-memory only — this metadata barely changes). Use MangaBaka's `manga_updates.id` to find the right MU series, then MU's groups endpoint.

### 4.7 Slices S2-S10 — Source plugins and polish

Each source-plugin slice follows the `source-plugin-jkanime` skill template:
1. Static recon (HTML/JSON shape, pagination, chapter URL patterns).
2. Defensive parser with fixture-based tests.
3. Plugin contract implementation (`search`, `getDetail`, `getChapters`, `getPages`).
4. Resolver wiring (if pages are hosted on third-party CDN with quirks).
5. Composite repo registration.

S2 (M2 base-URL config) is a horizontal infra slice that unblocks Olympus, ComicK, and any future host-rotating source.

S10 wraps up:
- **M4** — plugin health probes (light HEAD checks + circuit breaker per plugin so a dead source doesn't stall the composite).
- **M5** — language-aware ranking inside the picker (Spanish user sees Spanish options first).
- **M8** polish — additional enrichment chips (e.g. translation quality if MU exposes it).

---

## 5. Current status

### 5.1 Completed

- ✅ **S0 — Recon** (no commit; documented here)
- ✅ **S1.A — MangaBaka client** (commit `92714c2`, diary 2026-04-29)
- ✅ **S1.B — MangaUpdates client** (diary 2026-04-29 second entry)
- ✅ **S1.C — Composite repository v2** (diary 2026-04-29 fourth entry; multi-source fan-out, sourceId tagging, per-plugin timeout, failure isolation, `availableSources` picker catalog). The scanlator-picker work was committed first to keep the diff readable.
- ✅ **S1.D — MangaBaka matching wired** (diary 2026-04-29 fifth entry). New Strategy A2 (cross-tracker bypass via `mu`/`mal` aligned to `MangaBakaCrossIds`) and Strategy B+ (fuzzy candidate pool expanded with `titleCorpus`). Per-AniList-id memoization. Gateway transport failures are non-fatal; resolver degrades to legacy A+B path. Optional `mangaBaka: MangaBakaMetadataGateway?` constructor param keeps existing call sites unchanged.
- ✅ **S1.E — Source picker UI + gateway provider** (diary 2026-04-29 sixth entry). Drift schema v21 adds `preferred_source_id` column. New `setPreferredSourceId` on `MangaLibraryStore` + `SyncAwareMangaLibraryStore`. Real `HttpMangaBakaMetadataGateway` provider wired into the composite — Strategies A2 / B+ active for users. `_SourcePicker` chip in `manga_detail_page` mirrors the scanlator picker layout. New l10n keys in en + es. Fan-out is now end-to-end visible to the user.
- ✅ **S1.F — Scanlator picker enrichment via MU groups** (diary 2026-04-29 seventh entry). `ScanlatorOption.lastReleaseAt` populated from MU `searchReleases(seriesId)` (series id sourced from MB cross-ids). MU transport failures + missing cross-ids degrade silently. `mangaUpdatesMetadataGatewayProvider` wired. Picker bottom-sheet shows "Última publicación hace N días" hints. Three new l10n keys per locale.

### 5.2 In progress

_None as of 2026-04-30 00:30._

### 5.3 Next up

**S2 (M2) ✅ done (2026-04-30).** Mirror-switching contract landed: new `kumoriya_source_runtime` package (`MirrorList` + `MirrorRotator` + `TransportFailure`), MangaDex source plugin migrated to consume the rotator, Drift v22 schema with `plugin_base_url_override` table, Settings UI under "App → Plugin base URLs (advanced)", l10n in en + es. 19 + 3 + 7 = 29 new tests across runtime, MangaDex regression, and storage. Health probes deferred to S10 (M4) per plan.

**S3 (`kumoriya_source_olympus`) ✅ done (2026-04-30).** First LatAm source plugin. Olympus turned out to be Nuxt 3 SSR + an unauthenticated REST API on a paired `dashboard.*` subdomain. Plugin owns two `MirrorRotator`s (web + dashboard) so transport failures on either layer fall through to the next mirror pair. Internal `NuxtDataDecoder` decodes the `__NUXT_DATA__` flat-array deref format used to embed manga detail and reader pages in the SSR HTML. 24/24 tests (9 decoder + 15 plugin). MangaDex unchanged.

**S4 (`kumoriya_source_inmanga`) ✅ done (2026-04-30).** Second LatAm source. ASP.NET MVC site with a quirky double-envelope JSON (`{"data":"<inner-json>"}`) for search and chapters, plus SSR HTML scrape for detail metadata and reader page UUIDs. Single mirror; rotator wired anyway so the S2.C URL override still applies. 16/16 tests with live fixtures. Composite repo unchanged.

**S5 (`kumoriya_source_manhwaweb`) ✅ done (2026-04-30).** Third LatAm source. JSON-native REST on a Railway-hosted backend; detail + chapter list in a single `/manhwa/see/{slug}` call, ordered image URLs in `chapter.img[]`. The Railway host is the explicit reason S2.C exists — users can pin a working backend through the Settings UI when the deployment URL rotates. 12/12 tests.

### 5.4 Rescope decision — 2026-04-30 (ES-first)

Tesis explícita: **especializar el catálogo de manga/manhwa al ecosistema en español (LatAm + España)**. Las fuentes EN-only o que no aportan delta sobre MangaDex en español salen del scope.

**Cambios en el plan**:

- ➕ **Agregadas como slices de primera clase**: LectorTMO (heredero TMO, prioridad alta), LectorManga, NekoScan, VisorManhwas. Las cuatro son ES-first, scanlation activa post-TMO, y cubren el long-tail manhwa que MangaDex no tiene.
- ➖ **Removidas**: WeebCentral (EN-only), Comikey (EN-first, catálogo ES marginal), Comick (overlapping con MangaDex en ES).
- ✂️ **Reducidas**: Webtoons-ES queda como slice independiente (legal, gigante en LatAm); Comikey desaparece. MangaPlus se mantiene pero con filtro estricto a `es-419`/`es` para no inflar el catálogo con chapters EN duplicados.

### 5.5 Next up

**S6 — `kumoriya_source_ikigai`.** Cloudflare-protected on some endpoints per recon; budget 1d. Primer slice donde S2.C URL override probablemente sea necesario en producción para usuarios con CF challenges agresivos.

**S7 — `kumoriya_source_lectortmo` (NUEVO).** Heredero directo de TuMangaOnline. Sigue siendo la referencia para manga ES. Probable Cloudflare; recon antes de presupuestar pero 1.5d esperado.

---

## 6. Risks and residuals

### 6.1 Architectural

- **Multiple plugins fanning out per chapter list** raises latency. Mitigation: per-plugin timeout (e.g. 4s) + circuit breaker (M4). Worst case: only the fastest sources contribute; user sees a partial list and a "loading more" indicator.
- **MangaBaka availability** — single point of failure for the corpus. Mitigation: gateway is optional in S1.D; composite falls back to AniList-only titles when MangaBaka returns transport errors. Already structured this way via `Result`.
- **Cross-ID drift** — MangaBaka data is community-curated, so an `anilist.id` may point to a different work occasionally. Mitigation: never trust the ID blindly; always verify the matched series title is within edit-distance of the AniList title (existing `kumoriya_matching` fuzzy-match guards).

### 6.2 Operational

- **TLS/UA fingerprinting on Olympus and Ikigai.** Cloudflare may upgrade challenges over time. Mitigation: M2 base-URL rotation + an `http_client_factory` that lets us swap in `cronet`/`cupertino_http` per-source if needed.
- **MangaPlus image descrambling key rotation.** Shueisha has historically rotated the XOR key. Mitigation: drive the key from the proto response (it's per-chapter), not from a hardcoded constant.
- **Webtoons CDN signatures** expire fast. Resolver step needs to fetch the manifest and the pages within the same window.

### 6.3 Product

- **Picker overload.** Adding source + scanlator + language + enrichment chips can overwhelm casual users. Mitigation: show "Auto" as default with a single chip, expand to advanced view on tap.
- **Stale enrichment.** MU group activity TTL of 24h means a group that died yesterday still shows "activo" today. Acceptable; the alternative (probe per render) is too expensive.

---

## 7. Out of scope (explicitly deferred)

These were considered and rejected for the current workstream — recorded so we don't re-litigate:

- **Cloudflare bypass via custom Worker proxy.** Originally planned (S11 in v3); cancelled because `api.mangabaka.dev` works directly.
- **Aggregator rebuild of TMO.** TMO is gone; replicating it would mean shipping a meta-aggregator plugin that re-parses other sources. Higher complexity, lower trust. Better to ship the underlying sources directly.
- **Paywalled publishers** (Manta, Tappytoon, KakaoPage, Piccoma). Useful for "where to buy" badges, not for streaming. Future "External Reading" slice.
- **MangaPlus subscription content.** Free titles only. Subscription requires Shueisha account flow — out of scope for now.
- **Per-chapter source picker** (long-press a chapter → choose between Olympus/MangaDex variants). The per-manga picker covers ~95% of demand; per-chapter is a layered addition once the foundation lands.
- **Per-language preferred scanlator.** Today's contract is one preferred scanlator per manga. If users ask for "MangaReworks for EN, GeekDoTrans for ES", the storage column grows into a JSON map without a new table.
- **AniList → MangaDex direct ID lookup.** MangaBaka does not expose MangaDex IDs in `source`. We continue to fuzzy-match per source with the title corpus.
- **OAuth flows for trackers.** AniList sync is a separate workstream; this plan only consumes public endpoints.

---

## 8. Cross-references

- **Architecture skill:** `.agents/skills/kumoriya-architecture/` — invariants this plan honors.
- **Vertical slice skill:** `.agents/skills/flutter-vertical-slice/` — the protocol every sub-slice follows.
- **Source plugin template:** `.agents/skills/source-plugin-jkanime/` — to be reused for each manga source plugin (S3-S9), parametrized on the new source.
- **Resolver runtime audit skill:** `.agents/skills/resolver-runtime-audit/` — for diagnosing CDN/page-fetch failures during S7/S8.
- **AniList matching skill:** `.agents/skills/anilist-matching/` — the matching heuristics that will consume `MangaBakaSeries.titleCorpus`.
- **Dev diary:** `docs/dev-diary/2026-04-29.md` — first entry covering S1.A.
- **Roadmap:** `docs/60-roadmap.md` — Phase 5 ("manga/manhwa expansion, second source") is what this plan executes against.
- **Plugin contracts:** `docs/55-plugin-contracts.md` — the `MangaSourcePlugin` contract every new source slice implements.

---

## 9. Update protocol

After every closed slice:

1. Move it from "pending" to "done" in the table in §4.
2. Add a one-line bullet under §5.1 with date + commit hash.
3. If the slice changed the plan (new findings, scope cut, scope grown), update §6 (risks) and §7 (out of scope) accordingly.
4. Bump the date and version line at the top.
5. Commit with `docs(plan): manga coverage — <slice id> closed`.

Do not let this document drift from reality. If it disagrees with the dev diary, the dev diary wins; reconcile here on the next update.
