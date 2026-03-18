# Kumoriya Design System

**Version:** 1.0 — March 2026  
**Stack:** Flutter · Material 3 · Be Vietnam Pro · Dark-only  
**Source of truth:** `kumoriya_theme.dart` + this document

---

## Table of Contents

1. [Color Tokens](#1-color-tokens)
2. [Typography Tokens](#2-typography-tokens)
3. [Spacing & Layout](#3-spacing--layout)
4. [Radius & Elevation](#4-radius--elevation)
5. [Component Specifications](#5-component-specifications)
6. [Layout Rules](#6-layout-rules)
7. [Interaction Rules](#7-interaction-rules)
8. [State Patterns](#8-state-patterns)

---

## 1. Color Tokens

### 1.1 Base Palette (keep as-is)

| Token | Hex | Usage |
|---|---|---|
| `background` | `#130D1A` | Scaffold background, deepest layer |
| `surface` | `#1E1629` | Cards, rows, sheets, input fills |
| `navBackground` | `#171121` | Bottom bar, rail background |
| `borderSubtle` | `#1E293B` | Default borders on cards/rows |
| `borderMedium` | `#334155` | Dividers, separator dots |

### 1.2 Primary Scale (keep as-is)

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#7C3BED` | Active state, CTA fill, progress bar |
| `primaryDark` | `#6831C9` | Pressed state for primary buttons |
| `primaryLight` | `#9055EB` | Secondary highlight, source badge text |
| `primaryContainer` | `#2A1654` | Chip/badge background that must read purple |
| `primarySurface10` | `primary @ 10%` | Subtle hover tint on rows |
| `primarySurface20` | `primary @ 20%` | Active episode row background |
| `primaryBorder30` | `primary @ 30%` | Active border on episode row |

### 1.3 Semantic Status Colors — **NEW, required**

Add these to `KumoriyaColors`. Replace all raw `Colors.green`, `Colors.orange`, `Colors.red` usages.

| Token | Hex | Usage |
|---|---|---|
| `statusAiring` | `#34D399` | Keep existing — airing badge, watched checkmark |
| `statusSuccess` | `#34D399` | Download completed, offline available — **alias of statusAiring** |
| `statusWarning` | `#F59E0B` | Download paused/queued, partial availability |
| `statusDanger` | `#F87171` | Download failed, playback error, destructive actions |
| `statusInfo` | `#60A5FA` | Informational badges, upcoming status |

**Surface tints for status** (generated, not stored — use `.withValues(alpha:)`):

| Usage | Formula |
|---|---|
| Success container fill | `statusSuccess @ 12%` |
| Warning container fill | `statusWarning @ 12%` |
| Danger container fill | `statusDanger @ 12%` |
| Info container fill | `statusInfo @ 12%` |

### 1.4 Text Colors (keep as-is)

| Token | Hex | Contrast role |
|---|---|---|
| `textPrimary` | `#FFFFFF` | Titles, active labels |
| `textSecondary` | `#CBD5E1` | Body, secondary labels |
| `textMuted` | `#94A3B8` | Captions, metadata |
| `textDisabled` | `#64748B` | Placeholders, disabled |

### 1.5 Surface Variants — **NEW, named constants**

The codebase currently uses ad-hoc `surface.withValues(alpha: 0.40/0.55)`. Replace with named tokens:

| Token | Formula | Usage |
|---|---|---|
| `surfaceDim` | `surface @ 50%` | Default row/card fill (resting, not focused) |
| `surfaceBright` | `surface` (100%) | Hovered row, focused card, active sheet |
| `surfaceOverlay` | `#000000 @ 60%` | Background scrim behind bottom sheets |
| `playerOverlayGradient` | `#000000 @ 0% → 85%` | Player control fade-in overlay |
| `bannerScrim` | `background @ 85%` (vertical, stops 0.3→1.0) | Detail banner fade |
| `bannerSideScrim` | `background @ 80%` (horizontal, stops 0.0→0.6) | Continue-watching left vignette |

> **Implementation note:** `surfaceDim` and `surfaceBright` are not Color constants — they are `Color get` helpers:
> ```dart
> static Color get surfaceDim => surface.withValues(alpha: 0.50);
> static Color get surfaceBright => surface;
> ```

### 1.6 Overlay Colors for Player/Sheets

| Token | Value | Usage |
|---|---|---|
| `scrimLight` | `#000000 @ 40%` | Soft overlay behind dialogs |
| `scrimHeavy` | `#000000 @ 72%` | Player back/fullscreen overlay |
| `playerControlBg` | `#000000 @ 55%` | Icon button backgrounds in player |
| `playerBarGradient` | `transparent → #000000 @ 80%` | Top and bottom player bar fades |

---

## 2. Typography Tokens

### 2.1 Existing Scale → Semantic Roles

The TextTheme is correct. Map it to semantic roles so feature code never references font sizes directly.

| TextTheme key | Size / Weight | Semantic Role |
|---|---|---|
| `displayLarge` | 48 / w800 | Hero banners (unused in current screens) |
| `displayMedium` | 40 / w800 | Reserved for splash / onboarding |
| `displaySmall` | 32 / w700 | Reserved for future large headers |
| `headlineLarge` | 28 / w800 | Page title in player overlay |
| `headlineMedium` | 24 / w800 | Detail page anime title |
| `headlineSmall` | 20 / w700 | Dialog titles |
| **`titleLarge`** | **18 / w700** | **Screen-level section header (L1)** |
| **`titleMedium`** | **15 / w600** | **Card-level section header (L2)** |
| **`titleSmall`** | **14 / w600 / textSecondary** | **Row primary label** |
| `bodyLarge` | 16 / w400 | Synopsis, description paragraphs |
| `bodyMedium` | 14 / w400 / textMuted | Supporting body text |
| `bodySmall` | 12 / w400 / textMuted | Footnotes, captions |
| `labelLarge` | 14 / w700 | Button text, active tab label |
| `labelMedium` | 12 / w600 / textMuted | Chip/badge label, meta chip |
| `labelSmall` | 10 / w700 / textDisabled / ls0.8 | Source badge text, status pill text |

### 2.2 Component-Specific Overrides

These are fixed styles (not from TextTheme) for tight layout components. Encode as constants or private `TextStyle` getters, not inline.

| Semantic Name | Size / Weight / Color | Used In |
|---|---|---|
| `episodeTitleActive` | 14 / w700 / textPrimary | EpisodeRow active state |
| `episodeTitleDefault` | 14 / w700 / textSecondary | EpisodeRow default state |
| `episodeSecondary` | 11 / w400 / textDisabled | EpisodeRow secondary line |
| `continueWatchingTitle` | 11 / w500 / textSecondary | ContinueWatchingCard anime name |
| `continueWatchingEp` | 15 / w800 / textPrimary | ContinueWatchingCard episode label |
| `posterTitle` | 13 / w700 / textPrimary | AnimeCard poster label |
| `posterMeta` | 11 / w400 / textMuted | AnimeCard year/meta below title |
| `navLabel` | 10 / w600 / ls0.5 | Bottom nav selected label |
| `navLabelUnselected` | 10 / w500 | Bottom nav unselected label |

### 2.3 Section Header Levels

Two levels only. No ad-hoc sizes anywhere.

| Level | TextTheme Key | Use Case |
|---|---|---|
| **L1 — Screen Header** | `titleLarge` (18/w700) | Home "Trending", Library section titles, top of screen sections |
| **L2 — Card Header** | `titleMedium` (15/w600) | Inline headers within cards, episode count labels, sub-sections |

**Section header rules:**
- L1 always has `16px` bottom spacing before its list.
- L1 optionally carries a `TextButton` "See all" trailing action (right-aligned, `labelMedium`, `textMuted` color).
- L2 has `12px` bottom spacing.
- Never use raw fontSize in a section header widget.

---

## 3. Spacing & Layout

### 3.1 Spacing Scale (confirm as-is)

| Token | Value | Typical Use |
|---|---|---|
| `xs` | 4px | Icon-to-label gaps, badge internal padding |
| `sm` | 8px | Row gap, chip internal V-padding |
| `md` | 12px | Card internal padding (compact), list item gap |
| `lg` | 16px | Screen horizontal padding, button V-padding |
| `xl` | 20px | Card internal padding (standard) |
| `xxl` | 24px | Section spacing, large card padding |
| `xxxl` | 32px | Page top padding, large section spacing |

### 3.2 Standard Content Padding

| Context | Padding |
|---|---|
| Screen horizontal padding (mobile) | `EdgeInsets.symmetric(horizontal: KumoriyaSpacing.lg)` = 16px |
| Screen horizontal padding (desktop) | `EdgeInsets.symmetric(horizontal: KumoriyaSpacing.xxxl)` = 32px |
| Screen top padding (below AppBar) | `KumoriyaSpacing.md` = 12px |
| Screen bottom padding (above nav bar) | `KumoriyaSpacing.xxl` = 24px (+ safe area) |
| Card internal padding (standard) | `EdgeInsets.all(KumoriyaSpacing.xl)` = 20px |
| Card internal padding (compact/row) | `EdgeInsets.symmetric(h: 14, v: 12)` |
| Bottom sheet internal padding | `EdgeInsets.fromLTRB(16, 12, 16, 24)` + safe area bottom |

### 3.3 Row Spacing

| Context | Gap |
|---|---|
| Between episode rows | `8px` (bottom margin on each row) |
| Between anime rows (search list) | `6px` vertical card margin |
| Between cards in horizontal scroll | `12px` |
| Between section blocks | `24px` |
| Between section header and first item | `12px` |

### 3.4 Section Spacing

Each section block on Home/MyList:
```
[Section Header L1]
8px
[See All link, if applicable]
12px
[Content]
24px ← gap before next section
```

### 3.5 Breakpoints

| Name | Condition | Layout mode |
|---|---|---|
| `mobile` | `width < 600px` | Bottom nav, single column |
| `tablet` | `600px ≤ width < 960px` | Bottom nav OR rail (configurable), 2-col grid possible |
| `desktop` | `width ≥ 960px` | Rail nav always, expanded layout |

Check: `defaultTargetPlatform == TargetPlatform.windows/linux/macOS` → treat as desktop regardless of pixel width (current shell behavior is correct).

### 3.6 Max Widths

| Context | Max width |
|---|---|
| Centered page content (desktop) | `1200px` |
| Detail page banner + synopsis | `960px` |
| Bottom sheet / dialog | `560px` |
| State view (loading/empty/error) | `400px` centered |

---

## 4. Radius & Elevation

### 4.1 Radius Scale (confirm as-is)

| Token | Value |
|---|---|
| `sm` | 8px |
| `md` | 12px |
| `lg` | 16px |
| `xl` | 20px |
| `xxl` | 24px |
| `full` | 9999px |

### 4.2 Radius Assignment Rules

| Component | Radius |
|---|---|
| Poster image (AnimeCard, search cover) | `xl` (20px) |
| Row/list tile card | `xxl` (24px) |
| ContinueWatchingCard | `xxl` (24px) |
| Bottom sheet | `xxl` top corners only |
| Chip / badge / pill | `full` |
| Source badge | `full` |
| Input fields | `xl` (20px) |
| Buttons (filled) | `xl` (20px) |
| Buttons (outlined) | `lg` (16px) |
| Dialog | `xxl` (24px) |
| Snackbar | `lg` (16px) |
| Episode number box | `md` (12px) |
| Player control icon buttons | `full` |
| Download group card | `xxl` (24px) |
| Image placeholder (cover fail) | `xl` (20px) |

### 4.3 Elevation Rules

The app is **flat**. Use elevation only as exceptions:

| Context | Elevation | Note |
|---|---|---|
| All cards / rows | 0 | Use border (`borderSubtle`) instead |
| AppBar | 0 | Transparent |
| Nav bar / rail | 0 | Use background color distinction |
| Bottom sheet | 0 | Platform default removed |
| Player controls popup (server sheet) | 2dp | Only case with visible elevation |
| Dialogs | 0 | Use scrim overlay only |

**Shadow use:** Forbidden for layout. Allowed only for text legibility (player overlay text: `Shadow(color: Colors.black54, blurRadius: 4)`).

---

## 5. Component Specifications

---

### 5a. Compact Anime Row

**Purpose:** Unified base for all horizontal-layout anime entries: trending, airing, library rows, history. Replaces `AnimeListTile` (which currently bypasses tokens) and any inline row implementations.

**Variants:**
- `default` — title + meta chips + chevron
- `withProgress` — adds progress bar below title (history/continue)
- `withBadge` — corner badge on cover (e.g. "NEW")
- `withDownloadStatus` — trailing download icon instead of chevron

**Slots:**
```
[Cover 68×92] [12px] [Column: Title / MetaChips] [12px] [Trailing]
```

**Token usage:**
| Property | Token |
|---|---|
| Background (resting) | `surfaceDim` (`surface @ 50%`) |
| Background (hover) | `surfaceBright` (`surface`) |
| Border | `borderSubtle` |
| Radius | `KumoriyaRadius.xxl` |
| Padding | `EdgeInsets.all(KumoriyaSpacing.md)` = 12px all sides |
| Cover radius | `KumoriyaRadius.lg` = 16px |
| Cover size | `68×92` |
| Title style | `titleSmall` (14/w600/textSecondary) |
| Meta chips | `MetaChip` component (see 5f) |
| Trailing (default) | `Icons.chevron_right_rounded`, `textMuted` |
| Trailing (download) | `DownloadStatusIcon` component |
| Margin between rows | `EdgeInsets.only(bottom: KumoriyaSpacing.sm)` = 8px |

**States:**

| State | Background | Border | Trailing opacity |
|---|---|---|---|
| Default | `surfaceDim` | `borderSubtle` | 0.5 |
| Hover (desktop) | `surfaceBright` | `borderMedium` | 1.0 |
| Pressed | `primarySurface10` | `primaryBorder30` | 1.0 |
| Disabled | `surfaceDim @ 30%` | `borderSubtle @ 40%` | 0.2 |

**Mobile vs desktop:** On desktop add `MouseRegion` hover. On mobile: `InkWell` ripple with `splashColor: primarySurface10`. No behavioral difference otherwise.

**Cover fallback:** `surfaceContainerHighest` fill + `Icons.movie_outlined` centered, textMuted color. Same radius as cover.

---

### 5b. Search Result Card

**Purpose:** Full-width row in search results. Richer than CompactAnimeRow — more vertical space, all metadata visible at a glance.

**Slots:**
```
[Cover 72×96] [12px] [Column:
  Title (2 lines max)
  12px spacer
  MetaChip row (format, year, episodes)
  8px spacer
  Genre chips (max 3, overflow hidden)
] [12px] [Chevron]
```

**Token usage:**
| Property | Token |
|---|---|
| Background | `surface` |
| Border | `borderSubtle` |
| Radius | `KumoriyaRadius.xxl` |
| Padding | `EdgeInsets.all(KumoriyaSpacing.md)` = 12px |
| Margin | `EdgeInsets.symmetric(h: 16, v: 6)` |
| Cover size | `72×96` |
| Cover radius | `KumoriyaRadius.lg` |
| Title style | `titleMedium` (15/w600/textPrimary) |
| Meta row | `MetaChip` components |
| Genre chips | `MetaChip` with cap at 3 items |
| Chevron | `KumoriyaColors.borderMedium` |

**Difference from CompactAnimeRow:** Full `surface` background (not dim), slightly taller cover, 2-line title, genre chips slot.

**States:** Same hover/press logic as CompactAnimeRow.

---

### 5c. Continue Watching Card

**Current implementation is well-formed — minimal changes needed.**

**Spec (confirm):**

| Property | Value |
|---|---|
| Width | `320px` fixed (horizontal scroll) |
| Aspect ratio | `21:9` cinematic |
| Radius | `KumoriyaRadius.xxl` |
| Border | `borderSubtle` |
| Background (fallback) | `surfaceDim` |
| Cover opacity (resting) | `0.60` |
| Cover opacity (hover) | `0.80` |
| Cover scale (hover) | `1.05` |
| Scale animation | `400ms easeOutCubic` |
| Opacity animation | `300ms` |
| Gradient (bottom) | `transparent → background @ 85%`, stops `[0.3, 1.0]` |
| Gradient (left) | `background @ 80% → transparent`, stops `[0.0, 0.6]` |
| EpisodePill | `KumoriyaRadius.full`, `primaryContainer` bg, `primaryLight` text, `labelSmall` style |
| Anime name | `continueWatchingTitle` (11/w500/textSecondary) |
| Episode label | `continueWatchingEp` (15/w800/textPrimary + black54 shadow) |
| Resume button | Visible only on hover, `AnimatedOpacity 220ms` |
| Loading state | `CircularProgressIndicator` size 20, stroke 2, white — top-right slot |

**Resume button spec:**
- Filled button, `primaryDark` bg, `textPrimary` label, `KumoriyaRadius.full`, height 32px, padding `h:16 v:6`
- Label: "Resume" with `Icons.play_arrow_rounded` leading icon, 14px

---

### 5d. Episode Row — THE unified row

**One implementation only.** Remove `_DetailEpisodeCard` from `anime_detail_page.dart` and use `EpisodeRow` everywhere.

**Current `EpisodeRow` in `shared/widgets/episode_row.dart` is the canonical source.** The spec below reconciles it with missing states.

**Variants:**
- `default` — watchable, unplayed
- `active` — currently playing / last played
- `watched` — completed
- `notPlayable` — no source available
- `downloading` — in-progress download (future)
- `downloaded` — offline available

**Slots:**
```
[EpisodeNumberBox 44×44] [12px] [Column:
  Row: [Title] [Spacer] [StatusIcon]
  5px
  Row: [SourceBadges...] [dot] [SecondaryText]
  (if progress) 8px + ProgressBar
] [10px] [PlayIcon: animated opacity]
```

**Token usage:**
| Property | Token / Value |
|---|---|
| Background (default) | `surfaceDim` |
| Background (hover) | `surfaceBright` |
| Background (active) | `primarySurface20` |
| Background (notPlayable) | `surfaceDim @ 60%` |
| Border (default) | `borderSubtle` |
| Border (active) | `primaryBorder30` |
| Border (hover) | `borderMedium` |
| Radius | `KumoriyaRadius.xxl` |
| Padding | `EdgeInsets.symmetric(h: 14, v: 12)` |
| Bottom margin | `8px` |
| Episode number box radius | `KumoriyaRadius.md` |
| Episode number box (default) bg | `borderSubtle` |
| Episode number box (active) bg | `primaryContainer` |
| Episode number box (notPlayable) bg | `borderSubtle @ 50%` |
| Episode number text (active) | `textPrimary`, 15/w800 |
| Episode number text (default) | `textMuted`, 14/w700 |
| Title (active) | `episodeTitleActive` |
| Title (default) | `episodeTitleDefault` |
| Watched icon | `Icons.check_circle_rounded`, 16px, `statusSuccess` |
| NowPlaying badge | purple pill, `primaryContainer` bg, `primaryLight` text |
| SecondaryText | `episodeSecondary` |
| Separator dot | `borderMedium`, 3×3 circle |
| Progress bar | 3px height, `primary` value, `borderSubtle` track |
| Play icon (visible) | `Icons.play_circle_outline_rounded`, 28px |
| Play icon color (active) | `primary` |
| Play icon color (hover default) | `textMuted` |
| notPlayable opacity | `0.45` on whole row |
| Animation duration | `200ms` |

**State matrix:**

| State | BG | Border | Title color | Play icon | NumberBox |
|---|---|---|---|---|---|
| Default | `surfaceDim` | `borderSubtle` | `textSecondary` | opacity 0→1 on hover | `borderSubtle` fill |
| Hover | `surfaceBright` | `borderMedium` | `textPrimary` | opacity 1.0 | `borderSubtle` fill |
| Active | `primarySurface20` | `primaryBorder30` | `textPrimary` | always visible, `primary` | `primaryContainer` fill |
| Watched | `surfaceDim` | `borderSubtle` | `textMuted` | opacity 0 | `borderSubtle` fill |
| NotPlayable | `surfaceDim @ 60%` | `borderSubtle` | `textDisabled` | hidden | `borderSubtle @ 50%` fill |
| Downloaded | `surfaceDim` + `statusSuccess @ 8%` tint | `statusSuccess @ 20%` | `textSecondary` | opacity 0→1 | `borderSubtle` fill |

**Downloaded indicator:** Small `Icons.download_done_rounded` (14px, `statusSuccess`) shown in trailing next to play icon when offline available.

---

### 5e. Section Header

**Two levels only. Never inline font sizes in a header context.**

#### L1 — Screen Section Header

```dart
// Widget: KumoriyaSectionHeader
// Required: title (String)
// Optional: onSeeAll (VoidCallback?)
Row(
  children: [
    Expanded(Text(title, style: theme.textTheme.titleLarge)),
    if (onSeeAll != null)
      TextButton('See all', style: labelMedium/textMuted, onPressed: onSeeAll)
  ]
)
```

| Property | Token |
|---|---|
| Title style | `titleLarge` (18/w700/textPrimary) |
| See All style | `labelMedium` (12/w600/textMuted) |
| See All padding | `EdgeInsets.zero` |
| Bottom spacing (caller's responsibility) | `12px` before first content item |

#### L2 — Card Section Header

```dart
// Widget: KumoriyaCardHeader  
// Required: title (String)
Text(title, style: theme.textTheme.titleMedium)
```

| Property | Token |
|---|---|
| Title style | `titleMedium` (15/w600/textPrimary) |
| Bottom spacing | `8px` |

---

### 5f. Meta Chip

**Single implementation used everywhere.** Current `_MetaChip` private class in `AnimeListTile` uses `colorScheme.surfaceContainerHighest` — replace with token.

**Variants:**
- `default` — format, year, episode count
- `genre` — genre tag (same visual, distinct semantic)

| Property | Token |
|---|---|
| Background | `borderSubtle` |
| Border | none |
| Radius | `full` |
| Padding | `EdgeInsets.symmetric(h: 8, v: 4)` |
| Text style | `labelMedium` (12/w600/textMuted) |
| Text transform | uppercase for format, as-is for others |

**States:**
| State | Background | Text |
|---|---|---|
| Default | `borderSubtle` | `textMuted` |
| Active/selected | `primaryContainer` | `primaryLight` |

---

### 5g. Source Badge

**Current implementation is correct. Spec confirmation only.**

| Property | Current / Confirmed |
|---|---|
| Height standard | 30px |
| Height compact | 26px |
| H-padding standard | 12px |
| H-padding compact | 10px |
| Background (default) | `surface` |
| Background (highlighted) | `primaryContainer` |
| Border (default) | `primary @ 25%` |
| Border (highlighted) | `primary @ 60%` |
| Text (default) | `primary` |
| Text (highlighted) | `primaryLight` |
| Text style | `labelSmall` (10/w700/ls0.8) |
| Icon size standard | 18px |
| Icon size compact | 16px |
| Radius | `full` |

**Audio kind indicators:** SUB / DUB tags rendered as smaller inline labels at `9px/w800/textDisabled` after the source name.

---

### 5h. Status Pill

**Generalize the private `_StatusPill` in `calendar_page.dart` into a shared widget `KumoriyaStatusPill`.**

**Variants (AnimeStatus mapped to visual):**

| Status | Background fill | Text | Label |
|---|---|---|---|
| `releasing` | `primary @ 14%` | `primaryLight` | "AIRING" |
| `not_yet_released` | `borderSubtle` | `textMuted` | "UPCOMING" |
| `finished` | `statusSuccess @ 12%` | `statusSuccess` | "FINISHED" |
| `cancelled` | `statusDanger @ 12%` | `statusDanger` | "CANCELLED" |
| `hiatus` | `statusWarning @ 12%` | `statusWarning` | "ON HIATUS" |

| Property | Token |
|---|---|
| Padding | `EdgeInsets.symmetric(h: 9, v: 4)` |
| Radius | `full` |
| Text style | `labelSmall` (10/w700/ls0.8 — but override letterSpacing: 0.6) |

---

### 5i. State Views

**Current views are minimal. Upgrade to contextual, icon-guided, token-compliant views.**

#### LoadingStateView

```
[centered]
  CircularProgressIndicator (primary, 32px)
  12px
  Text(label ?? "Loading...", bodyMedium)
```

| Property | Token |
|---|---|
| Indicator color | `primary` |
| Indicator track | `borderSubtle` |
| Indicator size | 32px |
| Label style | `bodyMedium` (14/w400/textMuted) |
| Max width | 400px centered |

#### EmptyStateView

```
[centered, maxWidth 400]
  Icon(icon ?? Icons.inbox_outlined, 48px, textDisabled)
  16px
  Text(title, titleMedium, textPrimary, center)
  8px
  Text(message, bodyMedium, textMuted, center)
  (if action) 20px + FilledButton
```

| Property | Token |
|---|---|
| Icon size | 48px |
| Icon color | `textDisabled` |
| Title style | `titleMedium` |
| Message style | `bodyMedium` |
| CTA | Standard filled button |
| Padding | `EdgeInsets.all(24)` |

**Context-specific presets:**

| Context | Icon | Title | Message |
|---|---|---|---|
| No search results | `Icons.search_off_rounded` | "No results found" | "Try a different title or check spelling" |
| Empty library | `Icons.bookmarks_outlined` | "Your library is empty" | "Add anime to your list to see them here" |
| No downloads | `Icons.download_for_offline_outlined` | "No downloads yet" | "Download episodes for offline viewing" |
| No episodes | `Icons.video_library_outlined` | "No episodes available" | "No source plugin has episodes for this title" |

#### ErrorStateView

```
[centered, maxWidth 400]
  Icon(Icons.error_outline_rounded, 48px, statusDanger)
  16px
  Text(title ?? "Something went wrong", titleMedium, textPrimary, center)
  8px
  Text(message, bodyMedium, textMuted, center)
  (if onRetry) 20px + [Retry button]
```

| Property | Token |
|---|---|
| Icon | `Icons.error_outline_rounded` |
| Icon size | 48px |
| Icon color | `statusDanger` |
| Retry button | Outlined style, `Icons.refresh` leading, "Try again" label |

---

### 5j. Action Bar

**Purpose:** Primary CTA row on detail screen and other pages with a dominant action + secondary icon actions.

**Structure:**
```
Row(
  [Primary FilledButton — expanded]  [16px]  [SecondaryIconButton]  [8px]  [SecondaryIconButton]
)
```

| Property | Token |
|---|---|
| Height | 52px (matches button minimumSize) |
| Primary button | `FilledButton`, full theme defaults apply |
| Primary radius | `KumoriyaRadius.xl` |
| Secondary button | `IconButton` (outlined style), 52×52 |
| Secondary icon color | `textMuted` |
| Secondary border | `borderSubtle` |
| Secondary radius | `KumoriyaRadius.lg` |
| Secondary overlay | `primary @ 10%` |
| Padding | Same as screen horizontal padding |
| Bottom area | Always include `MediaQuery.paddingOf(context).bottom` safe area |

**Variants:**
- `primaryOnly` — full width FilledButton, no secondary slots
- `primaryWithActions` — expanded primary + up to 3 icon buttons
- `actionsOnly` — no primary, horizontal row of icon buttons

**Standard detail page actions:**
1. "Watch now" / "Resume" (primary filled)
2. Library toggle (outlined icon: `Icons.bookmark_add_outlined` / `Icons.bookmark_rounded`)
3. Download (outlined icon: `Icons.download_outlined` / `Icons.download_done_rounded`)

---

### 5k. Download Row (active)

**Generalize current `_ActiveDownloadRow` into `KumoriyaDownloadRow`.**

**Structure:**
```
[Cover 52×70] [12px] [Column:
  Text: anime title (titleSmall)
  4px
  Text: episode label (bodySmall)
  8px
  Row: [StatusChip] [Spacer] [ProgressFraction text]
  6px
  LinearProgressIndicator (3px)
]
```

**Download status colors:**

| Status | Icon | Color token |
|---|---|---|
| `queued` | `Icons.schedule_rounded` | `textDisabled` |
| `downloading` | `Icons.download_rounded` (animated) | `statusInfo` |
| `paused` | `Icons.pause_circle_outline_rounded` | `statusWarning` |
| `completed` | `Icons.download_done_rounded` | `statusSuccess` |
| `failed` | `Icons.error_outline_rounded` | `statusDanger` |
| `cancelled` | `Icons.cancel_outlined` | `textDisabled` |

Replace all `Colors.green/orange/red` with these tokens.

| Property | Token |
|---|---|
| Background (resting) | `surfaceDim` |
| Background (hover) | `surfaceBright` |
| Border | `borderSubtle` |
| Radius | `KumoriyaRadius.xxl` |
| Padding | `EdgeInsets.all(KumoriyaSpacing.md)` |
| Cover size | 52×70 |
| Cover radius | `KumoriyaRadius.md` |
| Progress bar height | 3px |
| Progress bar color | `primary` (downloading), `statusWarning` (paused), `statusDanger` (failed) |
| Progress track | `borderSubtle` |
| Animation duration | `180ms` |

---

### 5l. Download Group Card (completed)

**Purpose:** Shows all downloaded episodes for one anime title. Groups them visually.

**Structure:**
```
Container(radius: xxl, border: borderSubtle, bg: surfaceDim)
  Padding(16)
  [Cover 48×64] [12px] [Column:
    Text: anime title (titleSmall/textPrimary)
    4px
    Text: "N episodes downloaded" (bodySmall/textMuted)
  ] [Spacer] [chevron]
  8px
  [Episode pill list — horizontal scroll or wrap]
```

**Episode pills:**
- Each pill: rounded full, `borderSubtle` bg, `textMuted` text, `labelSmall`, padding `h:8 v:4`
- On tap opens detail page for that episode

| Property | Token |
|---|---|
| Card background | `surfaceDim` |
| Card border | `borderSubtle` |
| Card radius | `KumoriyaRadius.xxl` |
| Card padding | 16px all |
| Divider between header and pills | 1px `borderSubtle` |
| Pill -> episode | `MetaChip` with `default` variant |
| Hover | elevates border to `borderMedium` |

---

### 5m. Nav Shell

**Current shell is correct structurally. Spec confirmation + token audit.**

**Mobile Bottom Bar:**

| Property | Token |
|---|---|
| Background | `navBackground @ 95%` |
| Selected icon color | `primary` |
| Unselected icon color | `textDisabled` |
| Selected label color | `primary` |
| Selected label style | `navLabel` (10/w600/ls0.5) |
| Unselected label style | `navLabelUnselected` (10/w500) |
| Icon size | 24px |
| Elevation | 0 |
| Indicator (selected) | `primary @ 10%`, radius `full`, height 28px |
| Border top | 1px `borderSubtle` |

**Tabs:** Home · Search · Calendar · My List  
**Icons:** `home_rounded` / `search_rounded` / `calendar_today_rounded` / `bookmark_rounded` (selected) vs outlined variants (unselected)

**Desktop Rail:**

| Property | Token |
|---|---|
| Background | `navBackground @ 95%` |
| Min width | 88px |
| Selected icon | `primary`, 24px |
| Unselected icon | `textDisabled`, 24px |
| Indicator color | `primary @ 10%` |
| Label style (selected) | 10/w700/`primary`/ls0.5 |
| Label style (unselected) | 10/w400/`textDisabled` |
| Elevation | 0 |
| Border right | 1px `borderSubtle` |

**Transition:** Fade + slide (200ms) when switching tabs. Current `IndexedStack` is correct — do not animate the stack children itself, only nav indicators.

---

### 5n. Player Controls Overlay

**Purpose:** Fullscreen control surface rendered over the video. Currently uses raw Material colors — needs token compliance.**

**Overlay layers (bottom-to-top):**

```
[Video surface]
[Top gradient: #000 80% → transparent, height 120px]
[Bottom gradient: transparent → #000 80%, height 180px]
[Top bar: back button + anime title + episode]
[Center: play/pause + skip controls]
[Bottom bar: scrubber + time + quality + settings]
[Side panels: server/quality sheets (optional)]
```

**Token usage:**

| Element | Token |
|---|---|
| Top/bottom gradient | `playerBarGradient` |
| Icon button background | `playerControlBg` = `#000 @ 55%` |
| Icon button radius | `full` |
| Icon button size | 44×44 touch target, 24px icon |
| Icon color | `textPrimary` |
| Icon disabled color | `textPrimary @ 40%` |
| Play/pause button | 64×64 touch, 36px icon |
| Title text | `headlineLarge` (28/w800) — anime name |
| Episode text | `bodySmall` (12/w400/textSecondary) |
| Time text | `labelMedium` (12/w600/textPrimary) |
| Scrubber track color | `textPrimary @ 30%` |
| Scrubber active color | `primary` |
| Scrubber thumb | `primaryLight`, 14px |
| Quality badge | `MetaChip` active variant |
| Error text | `statusDanger` color |
| All overlay controls | `AnimatedOpacity`, 300ms, hide after 3s idle |

**Gesture rules (see section 7):**
- Single tap: toggle controls visibility
- Double tap left: −10s
- Double tap right: +10s
- Horizontal drag: scrub
- Vertical drag on left half: brightness (mobile only)
- Vertical drag on right half: volume (mobile only)

---

## 6. Layout Rules

### 6.1 Standard Page Structure

```
Scaffold(
  backgroundColor: KumoriyaColors.background
  appBar: (transparent, 0 elevation)
  body: SafeArea(
    top: true
    bottom: false ← nav bar handles bottom padding
    child: CustomScrollView / ListView
      slivers / children:
        SliverPadding(horizontal: 16[mobile] / 32[desktop])
          [Content sections]
        SliverPadding(bottom: 24)  ← breathing room above nav
  )
)
```

### 6.2 Detail Page Structure

```
Scaffold(
  body: Stack(
    [Backdrop banner (full bleed, max-height 280px)]
    [Gradient scrim (bannerScrim)]
    [ScrollView:
      SliverAppBar(expandedHeight: 260, pinned: true, transparent)
      SliverToBoxAdapter: metadata, action bar, genres
      SliverPadding(h:16): section header + episode list
    ]
  )
)
```

### 6.3 Home Page Structure

```
Scaffold
  CustomScrollView
    SliverToBoxAdapter: Continue Watching horizontal scroll (if entries exist)
    SliverToBoxAdapter: Section [Trending] + 2-row poster grid or horizontal scroll
    SliverToBoxAdapter: Section [Airing This Season] + horizontal scroll
    SliverToBoxAdapter: Section [Recently Updated] + vertical list
```

Horizontal scroll sections: `ListView.separated` with `scrollDirection: Axis.horizontal`, `itemExtent` approximately `120px` for poster cards.

### 6.4 Safe Area Rules

- Top safe area: `SafeArea(top: true)` wraps all scrollable content
- Bottom safe area: Applied at the scroll view's bottom padding, not per-widget
- Player page: `SafeArea(top: false, bottom: false)` — player is full bleed
- Bottom sheets: Always add `MediaQuery.paddingOf(context).bottom` to bottom padding

### 6.5 Desktop Adaptation

| Element | Mobile | Desktop |
|---|---|---|
| Nav | Bottom bar | Left rail |
| Screen padding | 16px h | 32px h |
| Poster grid | 2–3 columns | 4–6 columns |
| Detail layout | Single column | Two-panel (metadata left, episodes right) |
| Cards | `MouseRegion` hover | `MouseRegion` hover + cursor pointer |
| Max content width | full | 1200px centered |

---

## 7. Interaction Rules

### 7.1 Hover Behavior (desktop)

All interactive surfaces that use `GestureDetector` must gain `MouseRegion` on desktop.

| Component | Hover effect |
|---|---|
| CompactAnimeRow | BG: `surfaceDim → surfaceBright`, border: `borderSubtle → borderMedium` |
| AnimeCard (poster) | Scale 1.0 → 1.05 + gradient overlay |
| ContinueWatchingCard | Scale 1.05, opacity 0.60 → 0.80, ResumeButton visible |
| EpisodeRow | BG: `surfaceDim → surfaceBright`, PlayIcon opacity 0 → 1 |
| DownloadRow | BG: `surfaceDim → surfaceBright` |
| Nav items | `indicatorColor` tint |

**Cursor:** Always `SystemMouseCursors.click` on interactive components. Use `MouseRegion(cursor: SystemMouseCursors.click)`.

### 7.2 Press/Tap Feedback

| Component | Feedback |
|---|---|
| FilledButton | BG presses to `primaryDark` (via WidgetState) |
| OutlinedButton | Overlay ripple `primary @ 8%` |
| IconButton | Overlay `primary @ 10%` |
| Row items | `InkWell` with `splashColor: primarySurface10`, `borderRadius: xxl` |
| Poster cards | `GestureDetector` (no ripple — scale handles feedback) |

### 7.3 Animation Durations

| Action | Duration | Curve |
|---|---|---|
| Row hover BG | 200ms | linear |
| Poster scale (card) | 400ms | easeOutCubic |
| ContinueWatching scale | 500ms | easeOutCubic |
| ContinueWatching opacity | 300ms | linear |
| Player controls fade | 300ms | linear |
| Player progress scrub | immediate | — |
| Screen transitions | 250ms | easeInOut |
| Bottom sheet open | 300ms | easeOut |
| AnimatedOpacity (icons) | 220ms | linear |
| Snackbar appear/dismiss | 200ms | — |

### 7.4 Player Gesture Rules

| Gesture | Behavior |
|---|---|
| Single tap | Toggle controls overlay (3s auto-hide) |
| Double tap left 1/3 | Seek −10s, flash indicator |
| Double tap right 1/3 | Seek +10s, flash indicator |
| Horizontal swipe | Scrub preview (show time balloon) |
| Vertical swipe left | Brightness (mobile only) |
| Vertical swipe right | Volume (mobile only) |
| Long press | 2× speed (hold duration) |
| Back gesture / back button | Pause + save progress + pop |

### 7.5 Transition Patterns

- **Push navigation:** `MaterialPageRoute` with default slide from right. Do not customize unless truly necessary.
- **Player enter:** Fade + scale-up (250ms). Player exit: reverse.
- **Bottom sheets:** Standard `showModalBottomSheet` with `isScrollControlled: true`, `backgroundColor: surface`, radius applied to top corners only.
- **Tab switch (shell):** No animation — `IndexedStack` is instant. Nav indicator slides (handled by Material).

---

## 8. State Patterns

### 8.1 Loading State Visual Treatment

- **Full screen loading:** `LoadingStateView` centered, `CircularProgressIndicator` `primary` color.
- **List skeleton:** Not yet in system — when implemented, use `borderSubtle` placeholder boxes with the same dimensions as the actual card, `borderRadius: xxl`. No shimmer animation initially (adds complexity, low priority).
- **Inline loading (button):** Replace button label with `SizedBox(16×16, CircularProgressIndicator(strokeWidth: 2, color: white))`. Preserve button dimensions.
- **ContinueWatchingCard loading:** Top-right `20×20` circular indicator, white, stroke 2.

### 8.2 Empty State Visual Treatment

Use the upgraded `EmptyStateView` (spec 5i) with:
- Context-appropriate icon from presets
- Descriptive title + shorter hint message
- CTA action only when a clear next step exists (e.g., "Browse anime" for empty library)

**Do not:** Show empty state while data is still loading. Gate on `AsyncValue.hasValue && value.isEmpty`.

### 8.3 Error State Visual Treatment

Use `ErrorStateView` (spec 5i) with:
- `statusDanger` icon
- Error title: short, human ("Couldn't load anime" not "KumoriyaError: network.timeout")
- Error detail: message from `mapErrorMessage()` — keep this mapping complete
- Retry button when retryable (network errors always are; data not found is not)

### 8.4 Retry Patterns

| Error type | Show retry | Auto-retry |
|---|---|---|
| Network timeout | Yes | No |
| Not found (404) | No | No |
| Plugin resolve failed | Yes (with fallback label) | No |
| Player candidate failed | Yes (automatic via orchestrator) | Yes (next candidate) |
| Player all failed | Yes (manual retry button) | No |
| Download failed | Yes | No |

### 8.5 Partial / Degraded Data States

| Scenario | Treatment |
|---|---|
| Cover image fails | Placeholder box with `Icons.broken_image_outlined`, `textDisabled`, same size/radius |
| No source plugins available | Episode list shows `EmptyStateView("No sources available")` with icon `Icons.cloud_off_outlined` |
| Source available but no match | "Not available on [Source]" inline badge, not an error state |
| Partially loaded (episodes paginating) | Show loaded items first, loading indicator at bottom |

---

## Implementation Checklist

To bring the codebase into compliance with this spec, address in order:

### Phase 1 — Token Additions (1 file, ~15 lines)
- [ ] Add `statusSuccess`, `statusWarning`, `statusDanger`, `statusInfo` to `KumoriyaColors`
- [ ] Add `surfaceDim` and `surfaceBright` getters to `KumoriyaColors`
- [ ] Confirm `KumoriyaRadius.xxl` exists (it does, value 24)

### Phase 2 — Color Leak Fixes (4 files)
- [ ] `my_list_page.dart`: Replace `Colors.green/orange/red` in `_dlStatusColor()` with `KumoriyaColors.statusSuccess/Warning/Danger`
- [ ] `episode_list_page.dart`: Same replacement
- [ ] `anime_detail_page.dart`: Same for download status icons
- [ ] `player_page.dart`: Replace `Colors.red.shade700` and `Colors.redAccent` with `KumoriyaColors.statusDanger`

### Phase 3 — Component Token Compliance (2 files)
- [ ] `AnimeListTile`: Replace `colorScheme.surface/surfaceContainerHighest` with `KumoriyaColors.surface/borderSubtle`
- [ ] `_MetaChip` in `AnimeListTile`: Replace `colorScheme.surfaceContainerHighest` with `KumoriyaColors.borderSubtle`

### Phase 4 — Shared Component Extraction (new shared widgets)
- [ ] Extract `KumoriyaSectionHeader` (L1) from `home_page.dart` `_SectionHeader`
- [ ] Extract `KumoriyaStatusPill` from `calendar_page.dart` `_StatusPill`
- [ ] Extract `MetaChip` from `AnimeListTile._MetaChip` as shared widget
- [ ] Upgrade `LoadingStateView`, `EmptyStateView`, `ErrorStateView` per spec 5i

### Phase 5 — Episode Row Unification
- [ ] Extend `EpisodeRow` to support `downloaded` variant
- [ ] Replace `_DetailEpisodeCard` in `anime_detail_page.dart` with `EpisodeRow`

### Phase 6 — Player Token Pass
- [ ] Replace all raw Material colors in `player_page.dart` with design system tokens

---

## Appendix A — Token Quick Reference

```dart
// Colors
KumoriyaColors.background          // #130D1A
KumoriyaColors.surface             // #1E1629
KumoriyaColors.navBackground       // #171121
KumoriyaColors.primary             // #7C3BED
KumoriyaColors.primaryDark         // #6831C9
KumoriyaColors.primaryLight        // #9055EB
KumoriyaColors.primaryContainer    // #2A1654
KumoriyaColors.primarySurface10    // primary @ 10%
KumoriyaColors.primarySurface20    // primary @ 20%
KumoriyaColors.primaryBorder30     // primary @ 30%
KumoriyaColors.textPrimary         // #FFFFFF
KumoriyaColors.textSecondary       // #CBD5E1
KumoriyaColors.textMuted           // #94A3B8
KumoriyaColors.textDisabled        // #64748B
KumoriyaColors.statusAiring        // #34D399
KumoriyaColors.statusSuccess       // #34D399 [NEW]
KumoriyaColors.statusWarning       // #F59E0B [NEW]
KumoriyaColors.statusDanger        // #F87171 [NEW]
KumoriyaColors.statusInfo          // #60A5FA [NEW]
KumoriyaColors.borderSubtle        // #1E293B
KumoriyaColors.borderMedium        // #334155
KumoriyaColors.surfaceDim          // surface @ 50% [NEW getter]
KumoriyaColors.surfaceBright       // surface       [NEW getter]

// Spacing
KumoriyaSpacing.xs   // 4
KumoriyaSpacing.sm   // 8
KumoriyaSpacing.md   // 12
KumoriyaSpacing.lg   // 16
KumoriyaSpacing.xl   // 20
KumoriyaSpacing.xxl  // 24
KumoriyaSpacing.xxxl // 32

// Radius
KumoriyaRadius.sm    // 8
KumoriyaRadius.md    // 12
KumoriyaRadius.lg    // 16
KumoriyaRadius.xl    // 20
KumoriyaRadius.xxl   // 24
KumoriyaRadius.full  // 9999
```

---

*This document is authoritative. When a component's code conflicts with this spec, the spec wins unless there is a documented technical exception.*
