# Kumoriya Design System

Extracted from the Figma export (`visual_reference/`) and adapted to Flutter + Kumoriya product rules.
Use this as the single source of visual truth for all Kumoriya UI work.

---

## Color Palette

### Dark Theme (primary — Android & Windows)

| Token | Hex | Usage |
|---|---|---|
| `background` | `#130D1A` | Scaffold background, page root |
| `surface` | `#1E1629` | Cards, containers, inputs |
| `navBackground` | `#171121` | Bottom nav bar, desktop rail |
| `primary` | `#7C3BED` | Accent, CTA buttons, active states, badges, progress |
| `primaryDark` | `#6831C9` | Primary pressed/hover |
| `primaryLight` | `#9055EB` | Gradient tail, lighter accent |
| `primaryContainer` | `#2A1654` | Pill backgrounds, card tints for active state |
| `textPrimary` | `#FFFFFF` | Headlines, titles |
| `textSecondary` | `#CBD5E1` | Body text, card subtitles |
| `textMuted` | `#94A3B8` | Secondary info, timestamps |
| `textDisabled` | `#64748B` | Inactive nav labels, placeholder |
| `statusAiring` | `#34D399` | Airing status text |
| `borderSubtle` | `#1E293B` | Card borders, dividers |
| `borderMedium` | `#334155` | Hover borders, focus rings |

### Overlay helpers

| Usage | Value |
|---|---|
| Image dim (default) | `rgba(0,0,0,0.60)` |
| Image dim (hover) | `rgba(0,0,0,0.40)` |
| Gradient bottom | `rgba(#130D1A, 0.80)` → transparent |
| Primary glow shadow | `0 0 10px rgba(124,59,237,0.50)` |
| Primary surface tint 10% | `rgba(124,59,237,0.10)` |
| Primary surface tint 20% | `rgba(124,59,237,0.20)` |

---

## Typography

**Font family:** `Be Vietnam Pro` (Google Fonts), fallback `sans-serif`

| Scale token | Size | Weight | Letter spacing | Usage |
|---|---|---|---|---|
| `displayLarge` | 48px | 800 | -0.5 | Hero titles |
| `displaySmall` | 32px | 700 | -0.25 | Section hero |
| `headlineMedium` | 24px | 800 | 0 | Page headings, detail title |
| `headlineSmall` | 20px | 700 | 0 | Section headings |
| `titleLarge` | 18px | 700 | 0 | Card titles |
| `titleMedium` | 16px | 600 | 0 | Episode titles |
| `bodyLarge` | 16px | 400 | 0 | Synopsis, descriptions |
| `bodyMedium` | 14px | 400 | 0 | Secondary info |
| `bodySmall` | 12px | 400 | 0 | Timestamps, captions |
| `labelLarge` | 14px | 700 | 0 | Buttons |
| `labelMedium` | 12px | 600 | 0 | Badges, chips |
| `labelSmall` | 10px | 700 | 0.8 | Micro badges, nav labels (uppercase) |

---

## Spacing Scale

| Token | Value | Usage |
|---|---|---|
| `xs` | 4px | Tight gaps, badge inner padding |
| `sm` | 8px | Icon-to-text, between pills |
| `md` | 12px | List gaps, card inner spacing |
| `lg` | 16px | Page horizontal padding, section gaps |
| `xl` | 20px | Card padding |
| `xxl` | 24px | Large card padding |
| `xxxl` | 32px | Section vertical spacing |

**Page horizontal padding:** `16px` (mobile) / `48px` (desktop)
**Section vertical gap:** `32px`

---

## Border Radius

| Token | Value | Usage |
|---|---|---|
| `sm` | 8px | Small chips, corner badges |
| `md` | 12px | Episode number box, action icons |
| `lg` | 16px | Episode rows, filter chips |
| `xl` | 20px | Search input, action buttons |
| `xxl` | 24px | Cards, banners, playback summary |
| `full` | 9999px | Pills, source badges, progress bars, avatars |

---

## Shadows

| Token | Value | Usage |
|---|---|---|
| `primaryGlow` | `0 0 10px rgba(124,59,237,0.50)` | Primary button, active progress bar |
| `cardShadow` | `0 4px 24px rgba(0,0,0,0.40)` | Elevated cards on detail page |

---

## Component Patterns

### Continue Watching Card
- **Size:** `w=85vw` mobile / `w=480px` desktop / aspect `21:9`
- **Background:** `surface` + 50% alpha, border `borderSubtle`
- **Image:** fills card, opacity 60%, hover 80%
- **Overlay:** `gradient-to-t` from `background` via `background/50` to transparent + `gradient-to-r` from `background/80` to transparent
- **Episode pill:** top-left, `primary` bg, text white, 10px bold uppercase
- **Progress bar:** height 1.5px, track `white/10`, fill `primary`, glow shadow
- **Resume button:** `primary` bg, rounded-xl, uppercase bold, icon + "RESUME"

### Anime Poster Card
- **Aspect:** `3:4`
- **Radius:** `xl` (20px)
- **Background:** `surface`
- **Border:** `borderSubtle`
- **Hover overlay:** play button center, `primary/90` circle
- **Episode count badge:** bottom-left, `black/60` backdrop, white text
- **NEW badge:** top-left, `primary` bg, 10px uppercase

### Trending Row
- **Layout:** horizontal, rank number + 64×64 thumb + info + star
- **Background:** `surface/20`, hover `surface/40`, border `borderMedium/30`
- **Radius:** `xxl`
- **Rank:** 24px bold `primary` italic, 50% opacity

### Episode Row
- **Layout:** horizontal — episode number box + content + actions
- **Background:** `surface/50`, border `borderSubtle`
- **Active state bg:** `primary/10`, border `primary/30`
- **Number box:** `48×48`, radius `md`, `surface` bg inactive / `primary` bg active
- **Progress bar:** height 4px, track `borderSubtle`, fill `primary`
- **Audio badge:** 10px uppercase, `surface/50` bg, `textDisabled` text
- **Source name:** 10px `textMuted`
- **Watched indicator:** emerald-400 check icon

### Source Badge (dark)
- **Height:** 28px, `px=12px`
- **Background:** `surface`
- **Border:** `primary/20`
- **Text:** 10px bold `primary`
- **Highlighted:** border `primary`, bg `primaryContainer`

### Status/Audio Badge
- **SUB/DUB:** 9px uppercase, `surface/50` bg, rounded, `textDisabled` text
- **AIRING:** `primary` bg, white text, 10px uppercase tracking-widest
- **NEW:** `primary` bg, white text, top-corner pill

---

## Navigation

### Mobile Bottom Nav (4 tabs only)
- **Tabs:** Home · Search · Calendar · My List
- **Height:** 64px + safe area bottom
- **Background:** `navBackground` (`#171121`) at 90% + backdrop blur
- **Border top:** `borderSubtle`
- **Active color:** `primary`
- **Inactive color:** `textDisabled`
- **Label:** 10px medium uppercase tracking-wide

### Desktop Navigation Rail
- **Width:** 88px
- **Background:** `navBackground` at 95%
- **Border right:** `borderSubtle`
- **Logo mark:** top, 40×40 `primary` circle with "K"
- **Active:** icon + bg `primary/10`, text `primary`
- **Inactive:** icon `textDisabled`, tooltip on hover
- **Item icon size:** 24px, `stroke-width: 2`
- **Indicator radius:** 16px

---

## Interaction Patterns

- **Hover (desktop):** background lightens by ~`surface/40`, image scales 105%, play button appears
- **Press (mobile):** ripple with `primary/10` overlay
- **Loading states:** shimmer pattern or `SizedBox.shrink()` (never show broken states)
- **Error states:** hide silently or show minimal retry (no raw error messages)
- **Transitions:** `Curves.easeOutCubic`, 220ms for scroll / 300ms for opacity / 500ms for scale

---

## Screens Summary

### HomeScreen
- Mobile header: Kumoriya logo + avatar (hidden on desktop)
- **Section 1 — Continue Watching** (highest priority, always first)
  - Horizontal scroll, 21:9 cards, progress bar, RESUME button
- **Section 2 — New Episodes** — 3:4 poster grid (2 col mobile / 4-5 col desktop)
- **Section 3 — Trending Now** — vertical list of TrendingRows

### AnimeDetailScreen
- **Hero:** full-width banner, `450px` height, gradient overlays
- **Poster:** inline bottom-left of hero (desktop only / small on mobile)
- **Action row:** primary RESUME/PLAY button (full width) + Follow / Favorite / Download secondary icons
- **Source availability bar:** separator line + compact source badges
- **Episodes section:** episode count header + episode rows inline (no navigation push)

### SearchScreen
- Search bar: `surface` bg, `primary` glow on focus, radius `xl`
- Filter chips: horizontal scroll, `primary` for active
- Results: vertical list of search result cards (poster + title + year + status + source badges)

### DownloadsScreen (My List tab)
- Storage indicator card
- Active queue section
- Completed section
