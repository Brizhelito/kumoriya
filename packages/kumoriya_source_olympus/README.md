# kumoriya_source_olympus

Olympus Scanlation source plugin for Kumoriya.

## How it works

Olympus runs two paired domains per mirror: a Nuxt-SSR web frontend and an
API/storage backend.

- Web: `olympusbiblioteca.com` ↔ API: `dashboard.olympusbiblioteca.com`
- Web: `olympusscanlation.com` ↔ API: `dashboard.olympusscanlation.com`
- Web: `tomanhua.com` ↔ API: `dashboard.tomanhua.com`

Endpoints (no auth required):

| Method | URL | Purpose |
|---|---|---|
| GET | `{web}/api/series/list` | Full catalog (840+ entries). Used for search via in-memory filter. |
| GET | `{dashboard}/api/series/{slug}/chapters?page=N&direction=desc&type=comic` | Paginated chapter list. |
| GET | `{web}/series/comic-{slug}` | HTML page; manga detail in `__NUXT_DATA__`. |
| GET | `{web}/capitulo/{chapterId}/comic-{slug}` | HTML page; pages array in `__NUXT_DATA__`. |

The `__NUXT_DATA__` script tag holds a flat-array deref-encoded snapshot of
the page state (Nuxt 3 SSR convention). Each value can be a primitive or an
integer index pointing into the same array. The decoder lives in
`src/internal/nuxt_data_decoder.dart`.

## Mirror rotation

Built on top of `kumoriya_source_runtime`. The plugin holds two
`MirrorRotator`s — one for the web frontend, one for the dashboard API —
so transport-level failures on either layer fall through to the next
mirror pair without exposing rotation to upstream callers.

## Scope

In scope:
- search, getLatestUpdates, getMangaDetail, getChapters, getChapterPages.
- Comic-type series only. Novelas are filtered out at the catalog layer.
- Spanish-language chapters (Olympus only ships ES).

Out of scope:
- User auth (favorites, read state). The `read_by_auth` field is dropped.
- The Cloudflare interactive challenge mentioned in `recon-1.5`. Empirically
  passes with a realistic User-Agent; if it tightens, a `cronet` /
  `cupertino_http` swap at the app layer is the escape hatch.
