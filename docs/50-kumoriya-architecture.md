# Kumoriya Architecture (Codex baseline)

## Product shape

Kumoriya is an Android-first otaku app with Windows support, built around:

- AniList as canonical metadata
- source plugins for scraping/catalogs
- resolver plugins for streams
- playback pipeline isolated from scraping/resolution
- offline-first ambitions
- tracking/subscription intelligence

## Package baseline (bootstrapped)

- `apps/kumoriya_app`
- `packages/kumoriya_core`
- `packages/kumoriya_domain`
- `packages/kumoriya_plugins`
- `packages/kumoriya_anilist`
- `packages/kumoriya_storage`
- `packages/kumoriya_testing`

## Deferred package

- `packages/kumoriya_player` is intentionally deferred until playback pipeline contracts are started.

## Vertical slice order

1. AniList catalog/search/detail/episodes
2. JKAnime plugin + conservative matching
3. episode -> server links
4. resolver pipeline
5. playback session + player
6. storage/offline
7. downloads
8. subscriptions/notifications

## Hard rules

- no direct UI dependency on concrete plugins
- no resolver logic inside player widgets
- no aggressive matching heuristics early
- no blind legacy code imports
