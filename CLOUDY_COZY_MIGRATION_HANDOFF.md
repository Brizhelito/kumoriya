# Kumoriya Cloudy Cozy UI Migration — Handoff v2

**Branch:** `feat/cloudy-cozy-ui-migration`
**Last updated:** June 22, 2026
**Status:** 16 of 18 pages migrated. Theme root swapped. Fonts integrated. Missing: player_page, ~25 widget/aux files, Cloud primitive adoption.

---

## Executive Summary

### What was accomplished (this session)

The migration graduated from **mechanical token swap** (replacing `KumoriyaColors.primary` → `colors.primary`) to **structural Cloudy Cozy adoption**:

1. **Domain contracts centralized** — `DownloadStatus` (8 states) and `SourceAudioKind` moved from app/storage to `kumoriya_domain`. Both storage and UI packages now depend on canonical domain contracts.
2. **6 widgets deleted** — `state_views.dart`, `continue_watching_card.dart`, `episode_row.dart`, `meta_chip.dart`, `section_header.dart`, `status_pill.dart`. Replaced by `kumoriya_ui` equivalents.
3. **3 new cloud components created** — `PosterCard` (with real image, episode badge, hover gradient/play), `RankedTile` (ranked list tile with cover), `CloudCachedImage` (bucket-aware cached network image with cloud tokens).
4. **2 old widgets deleted** — `AnimeCard`, `AnimeRankedTile`. Replaced by cloud equivalents.
5. **16 of 18 pages migrated** — Old `KumoriyaColors`/`KumoriyaRadius`/`Theme.of(context).textTheme` → `FormFactorProvider.colorsOf(context)`/`CloudRadius`/explicit `TextStyle`.
6. **Root theme swapped** — `KumoriyaTheme.forUniverse(accent)` → `CloudTheme.build(CloudColors.noche())`. `Theme.of(context)` now returns Cloudy Cozy ThemeData across the entire app. All Material widgets (FilledButton, TextButton, Chip, Card, TextField, etc.) automatically get cloud-styled overrides (pill shapes, cloud shadows, cloud radii, cloud typography).
7. **Typography updated** — `google_fonts` integrated. Display: Zen Maru Gothic. Body: M PLUS Rounded 1c. Mono: JetBrains Mono. Previously: Be Vietnam Pro.
8. **Backward compatibility preserved** — `KumoriyaCachedImage`, `KumoriyaImageCacheBucket`, `KumoriyaVisualCacheManager` are typedefs to their `kumoriya_ui` equivalents. 14+ existing files continue to work unchanged.
9. **SourceBadge extended** — Now supports `iconUrl` (cached via `CloudCachedImage`), `audioKinds` (SUB/DUB pills via `SourceAudioKind`), `iconOnly` mode.
10. **EpisodeRow extended** — Now supports `trailingAccessory`, `activeLabel`, flexible `sourceBadges`.
11. **StatusPill refactored** — Now accepts `AnimeStatus` from domain directly, with optional `label` override for localization.
12. **SectionHeader extended** — Now supports `seeAllLabel` parameter.
13. **`mapErrorMessage` restored** — Created `shared/utils/error_messaging.dart`. Imported into 17 files.
14. **`DownloadRow` fixed** — Uses domain `DownloadStatus` (8 states: pending, downloading, paused, remuxing, disconnected, completed, failed, cancelled).
15. **`PosterCard` upgraded** — Real image (CloudCachedImage), episode count badge, hover gradient overlay, hover play button. No CloudCard wrapper (removed to avoid double hover conflict).
16. **Tests updated** — `KumoriyaAnimeTab.calendar` → `.party`, `.downloads` → `.profile`.

### What still needs work

| Category | Count | Details |
|----------|-------|---------|
| Pages unmigrated | 1 | `player_page.dart` (5077L, 89 KumoriyaColors, 19 KumoriyaRadius, 55 KumoriyaSpacing, 9 Theme.of(context).textTheme) |
| Widgets using old tokens | ~25 | `anime_list_tile`, `manga_card`, `manga_hero_card`, `manga_carousel`, `manga_placeholder_body`, `party_player_overlay`, `party_exit_dialog`, `active_party_banner`, `chapter_download_button`, `download_path_dialog`, `update_available_dialog`, `post_update_release_notes_dialog`, `login_page`, `profile_page`, `oauth_callback_page`, `unified_library_page`, `manga_home_page`, `bug_report_button`, playground pages, `universe_switch`, `app_navigation_shell` |
| Cloud primitives adopted | 0 of 9 | CloudCard, CloudButton, CloudChip, CloudSearchBar, CloudSurface, CloudDivider, CloudBadge, CloudTooltip, CloudTabBar — **none used in app code** |
| Cloud spacing tokens adopted | 0% | `CloudSpacing` is never referenced from app/src |
| `FormFactorProvider.formFactorOf` | 0 usages | Adaptive layout logic centralized in package but never called from app features |
| `UniverseBackground` | 1 page | Only `home_page.dart` has it |
| Material widgets remaining | Many | `anime_detail_page`: 11 Material buttons. `library_page`: 8 TextButton. `search_page`: raw TextField instead of CloudSearchBar |

---

## Adoption Metrics

| Layer | Adoption | Status |
|-------|----------|--------|
| `FormFactorProvider.colorsOf` (colors) | 19 files (strong) | ✅ |
| `CloudRadius` tokens | 15 files | ✅ |
| `CloudMotion` tokens | 10 files | ✅ |
| `CloudCachedImage` + bucket | 12 files | ✅ |
| Composite components (PosterCard, RankedTile, etc.) | 1-7 files each | ⚠️ Partial |
| `CloudSpacing` tokens | 0 files | ❌ |
| Cloud primitives (Card, Button, Chip, etc.) | 0 files | ❌ |
| `FormFactorProvider.formFactorOf` | 0 files | ❌ |
| `UniverseBackground` | 1 page | ❌ |
| Old `kumoriya_theme` imports | 25 files remaining | ⚠️ |
| Old `KumoriyaRadius` | 12 files remaining | ⚠️ |

**True cloud design adoption: ~30% (tokens + composites). Primitives + full token suite: ~0%.**

---

## Architecture Changes

### Domain layer

```
packages/kumoriya_domain/lib/src/
├── downloads/
│   └── download_status.dart          ← NEW: canonical DownloadStatus enum, 8 states
├── source_availability/
│   └── source_audio_kind.dart        ← NEW: SourceAudioKind enum + helper
└── kumoriya_domain.dart              ← UPDATED: exports both new files
```

### kumoriya_ui package

```
packages/kumoriya_ui/lib/src/
├── primitives/
│   └── cloud_cached_image.dart       ← NEW: cached network image with cloud tokens + cache manager
├── components/
│   ├── poster_card.dart              ← REWRITTEN: real image, episode badge, hover effects
│   ├── ranked_tile.dart              ← NEW: ranked list tile for top anime lists
│   ├── source_badge.dart             ← EXTENDED: iconUrl, audioKinds, iconOnly
│   ├── episode_row.dart              ← EXTENDED: trailingAccessory, activeLabel, sourceBadges
│   ├── download_row.dart             ← FIXED: uses domain DownloadStatus (8 states)
│   ├── section_header.dart           ← EXTENDED: seeAllLabel parameter
│   └── status_pill.dart              ← REFACTORED: uses AnimeStatus from domain, optional label
├── tokens/
│   ├── cloud_colors.dart             ← EXTENDED: copyWith method
│   └── cloud_typography.dart         ← REWRITTEN: uses google_fonts (Zen Maru Gothic, M PLUS Rounded 1c, JetBrains Mono)
└── pubspec.yaml                      ← UPDATED: cached_network_image, flutter_cache_manager, google_fonts
```

### App layer

```
apps/kumoriya_app/lib/src/
├── app/
│   └── kumoriya_app.dart             ← UPDATED: KumoriyaTheme.forUniverse() → CloudTheme.build(CloudColors.noche())
├── shared/
│   ├── utils/
│   │   └── error_messaging.dart      ← NEW: mapErrorMessage function (depends on context.l10n)
│   └── widgets/
│       ├── anime_card.dart           ← DELETED (replaced by PosterCard)
│       ├── kumoriya_cached_image.dart ← REPLACED: typedefs to kumoriya_ui equivalents
│       └── (6 old widget files)      ← DELETED
```

### File deletions (10 total)
- `shared/widgets/state_views.dart`
- `shared/widgets/continue_watching_card.dart`
- `shared/widgets/episode_row.dart`
- `shared/widgets/meta_chip.dart`
- `shared/widgets/section_header.dart`
- `shared/widgets/status_pill.dart`
- `shared/widgets/anime_card.dart`
- `features/.../widgets/source_badge.dart`
- `features/.../widgets/anime_ranked_tile.dart`

---

## Token Migration Maps

### Colors (KumoriyaColors → CloudColors via FormFactorProvider)

| Old | New | Notes |
|-----|-----|-------|
| `primary` | `colors.primary` | |
| `surface` | `colors.surface` | |
| `surfaceDim` | `colors.surface.withValues(alpha: 0.5)` | No direct equivalent |
| `textPrimary` | `colors.text` | |
| `textSecondary` | `colors.textMuted` | |
| `textMuted` | `colors.textMuted` | |
| `textTertiary` | `colors.textSoft` | |
| `textDisabled` | `colors.textSoft` | |
| `borderSubtle` | `colors.surface2` | |
| `borderMedium` | `colors.mist` | |
| `statusSuccess` | `colors.success` | |
| `statusWarning` | `colors.warning` | |
| `statusDanger` | `colors.error` | |
| `accentAmber` | `colors.star` | |
| `background` | `colors.bg` | |
| `primaryContainer` | `colors.primarySoft` | |
| `primaryLight` | `colors.primarySoft` | |
| `primaryDark` | `colors.primary` | |
| `surfaceElevated` | `colors.surface.withValues(alpha: 0.70)` | |
| `playerControlBg` | `Colors.black.withValues(alpha: 0.55)` | |

### Radius (KumoriyaRadius → CloudRadius)

| Old | New | Values |
|-----|-----|--------|
| `sm` | `CloudRadius.sm` | 8 → 12 |
| `md` | `CloudRadius.md` | 12 → 16 |
| `lg` | `CloudRadius.md` | 16 → 16 |
| `xl` | `CloudRadius.lg` | 20 → 24 |
| `xxl` | `CloudRadius.lg` | 24 → 24 |
| `full` | `CloudRadius.pill` | 9999 → 999 |

### Spacing (KumoriyaSpacing → CloudSpacing)

| Old | New | Values |
|-----|-----|--------|
| `xs` | `CloudSpacing.s1` | 4 → 4 |
| `sm` | `CloudSpacing.s2` | 8 → 8 |
| `md` | `CloudSpacing.s3` | 12 → 12 |
| `lg` | `CloudSpacing.s4` | 16 → 16 |
| `xl` | `CloudSpacing.s5` | 20 → 24 |
| `xxl` | `CloudSpacing.s5` | 24 → 24 |
| `xxxl` | `CloudSpacing.s6` | 32 → 32 |

### Motion (Duration → CloudMotion)

| Old | New |
|-----|-----|
| `Duration(milliseconds: 150-200)` | `CloudMotion.fast` (200ms) |
| `Duration(milliseconds: 300-400)` | `CloudMotion.base` (400ms) |
| `Duration(milliseconds: 500-600)` | `CloudMotion.slow` (600ms) |

---

## Page Migration Status

### ✅ Fully migrated (16 pages)

| Page | Lines | Token refs migrated | Quality |
|------|-------|---------------------|---------|
| home_page | 1092 | All KumoriyaColors/Radius + imports + CachedImage → cloud | **BEST** — UniverseBackground, all cloud tokens, no old imports |
| search_page | 789 | All colors/radius + Theme.textTheme → cloud | GOOD — cloud tokens + explicit text styles. Missing UniverseBackground |
| anime_detail_page | 3310 | All colors/radius/colorScheme + textTheme → cloud + CloudCachedImage | GOOD — strong cloud token usage. Still has Material buttons |
| episode_list_page | 1690 | All colors + textTheme → cloud | GOOD |
| calendar_page | 624 | All colors/radius + CachedImage → cloud | GOOD |
| library_page | 826 | All colors/radius + CachedImage → cloud | GOOD — but heavy TextButton usage |
| downloads_page | 1261 | All colors/radius + CachedImage → cloud | GOOD |
| browse_results_page | 1090 | All colors/radius + textTheme → cloud | GOOD |
| tag_guided_find_page | 613 | All colors/radius + textTheme → cloud | GOOD |
| settings_page | 1349 | All colors/radius + textTheme → cloud | GOOD |
| manga_search_page | 411 | All colors/radius + textTheme → cloud | GOOD |
| manga_detail_page | 1418 | All colors/radius + CachedImage + textTheme → cloud | GOOD |
| manga_downloads_page | 1129 | All colors/radius + CachedImage → cloud | GOOD |
| party_anime_page | 2069 | All colors/radius + CachedImage + textTheme → cloud | GOOD |
| party_episode_list_page | 639 | All colors/radius + CachedImage → cloud | GOOD |
| **trivial trio** (my_list, trending, season_hub) | ~466 | All colors/radius → cloud | GOOD |

### ❌ Not yet migrated

| Page | Lines | Old token refs | Notes |
|------|-------|---------------|-------|
| player_page | 5077 | 89 KumoriyaColors, 19 KumoriyaRadius, 55 KumoriyaSpacing, 9 Theme.of(context).textTheme | Largest file. Needs Spacing migration too. |

### ⚠️ Widgets/aux files with old tokens

~25 files including: `anime_list_tile`, `manga_card`, `manga_hero_card`, `manga_carousel`, `manga_placeholder_body`, `party_player_overlay`, `party_exit_dialog`, `active_party_banner`, `chapter_download_button`, `download_path_dialog`, `update_available_dialog`, `post_update_release_notes_dialog`, `login_page`, `profile_page`, `oauth_callback_page`, `unified_library_page`, `manga_home_page`, `bug_report_button`, playground pages, `universe_switch`, `app_navigation_shell`, `resolver_playground_page`, `player_flow_playground_page`.

---

## Next Steps (recommended)

### Phase 5B — Player page migration (high priority)
- `player_page.dart`: 5077 lines, 163 old token refs. Isolate as single stream.
- Includes Spacing migration (`KumoriyaSpacing` → `CloudSpacing`).

### Phase 6 — Widget/auxiliary cleanup (medium priority)
- 25 files with old token refs. Can be done in 3 parallel streams.
- Includes auth pages, manga widgets, app_update dialogs, shared widgets.

### Phase 7 — Cloud primitive adoption (lower priority, design upgrade)
- Replace Material widgets with cloud equivalents across migrated pages:
  - `FilledButton`/`TextButton`/`OutlinedButton` → `CloudButton`
  - `Container` cards → `CloudCard`
  - `Container` chips → `CloudChip`
  - `TextField` search inputs → `CloudSearchBar`
  - Raw `Padding` → `CloudSpacing` tokens
- Add `UniverseBackground` to all pages
- Wire `FormFactorProvider.formFactorOf` for adaptive layouts

### Verification commands
```bash
cd apps/kumoriya_app
dart analyze          # 0 errors currently, 4 info-level avoid_print
dart format .
flutter test           # not yet run after migration
flutter build apk --debug  # build check
```

---

## Common Pitfalls (from this migration)

1. **`colors.background` does NOT exist** — CloudColors uses `bg`, not `background`. Use `colors.bg`.
2. **`colors.primaryContainer`/`primaryLight`/`primaryDark` do NOT exist** — Use `colors.primarySoft` or `colors.primary`.
3. **`colors.textTertiary`/`textDisabled` do NOT exist** — Use `colors.textSoft`.
4. **`colors.borderSubtle`/`borderMedium` do NOT exist** — Use `colors.surface2` and `colors.mist`.
5. **`colors.surfaceDim` does NOT exist** — Use `colors.surface.withValues(alpha: 0.5)`.
6. **Remove `const`** from any widget that uses `colors.X` at runtime (Icon, TextStyle, Container, etc.).
7. **`colorScheme` is not a standalone variable** — It must be accessed via `Theme.of(context).colorScheme`. After root theme swap, this returns cloud ColorScheme.
8. **`KumoriyaCachedImage`/`KumoriyaImageCacheBucket`** — Now typedefs to `CloudCachedImage`/`CloudImageCacheBucket`. Remove old import, use cloud names directly.
9. **`noche()` is dark-mode CloudColors** — The app is dark-mode only for now. Light mode (Nublado) can be added later.
10. **Root theme swap** — `CloudTheme.build(colors)` now provides cloud-styled ThemeData including FilledButton, TextButton, Card, Chip, TextField, etc. All Material widgets get pill shapes, cloud shadows, cloud radii, cloud typography automatically.
