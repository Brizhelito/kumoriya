# kumoriya_source_manhwaweb

ManhwaWeb source plugin for Kumoriya.

## How it works

Two-host plugin: the marketing site lives at `manhwaweb.com` but every
content endpoint is on a separate API host.

| Method | URL | Purpose |
|---|---|---|
| GET | `{api}/manhwa/library?buscar={q}&page={n}&...` | Free-text search; clean `{data:[…]}` JSON. |
| GET | `{api}/manhwa/see/{slug}` | Manga detail + chapter list in one call. |
| GET | `{api}/chapters/see/{slug}-{chapter}` | Chapter pages (ordered `chapter.img[]`). |

API host: `https://manhwawebbackend-production.up.railway.app/`
(it changes occasionally — the per-plugin URL override from S2.C lets
the user pin a working backend without redeploying the app).

`sourceMangaId` is the slug returned by the API (`{title-slug}_{epoch}`).
`sourceChapterId` is `{slug}-{chapterNumber}` for direct lookup.

## Scope

In scope: search, getMangaDetail, getChapters, getChapterPages.
Out of scope: latest feed (returned via `/manhwa/nuevos` but redundant
with the home feed we get from MangaDex/Olympus), comments.
