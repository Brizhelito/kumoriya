# kumoriya_source_lectortmo

LectorTMOo source plugin for Kumoriya. Heir of TuMangaOnline, ES-first
manga/manhwa/manhua catalog.

## Endpoints

| Method | URL | Purpose |
|---|---|---|
| GET | `/wp-json/wp/v2/manga?search={q}&page={p}&_embed=wp:featuredmedia` | Search by free text. |
| GET | `/wp-json/wp/v2/manga/{id}?_embed=wp:featuredmedia` | Manga detail (with cover via `_embedded.wp:featuredmedia`). |
| GET | `/wp-json/eastmanga/v1/chapters?manga_id={id}` | Chapter index (custom endpoint, returns `{manga_id, count, chapters[]}`). |
| GET | `/wp-json/wp/v2/posts/{chapterId}` | Chapter content; pages parsed from `<img src="…">` in `content.rendered`. |

`sourceMangaId` is the WP post ID (numeric string). `sourceChapterId`
is also a numeric WP post ID — the chapter post.

## Default mirror

`https://lectortmoo.com/`. Sibling clone `https://lectortmo.vip/`
exposes the same WP+CPT+eastmanga schema (verified via recon) so it can
be plugged in via the per-plugin URL override (S2.C) without code
changes.

## Scope

In scope: search, getMangaDetail, getChapters, getChapterPages.
Out of scope: latest feed (`/eastheme/search` requires a browser nonce
we can't synthesize server-side; the home feed is already covered by
sibling sources).
