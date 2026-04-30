# kumoriya_source_inmanga

InManga source plugin for Kumoriya.

## How it works

Single-mirror plugin (`inmanga.com`) backed by ASP.NET MVC controllers.
Endpoints used:

| Method | Path | Purpose |
|---|---|---|
| GET | `/manga/GetQuickSearch?name={q}` | Free-text search. Envelope is `{data: "<inner-json-string>"}` — the inner string is parsed once more. |
| GET | `/chapter/getall?mangaIdentification={uuid}` | All chapters in one shot. Same double-encoded envelope. |
| GET | `/ver/manga/_/{uuid}` | Manga detail HTML (synopsis, status, cover). |
| GET | `/ver/manga/_/{chapterNumber}/{chapterUuid}` | Chapter reader HTML; page UUIDs live inside `<select id="PageList">`. |

The slug segment in `/ver/manga/{slug}/...` is SEO-only; the controller
routes by UUID. We pass `_` as a placeholder so we never depend on
remembering the slug.

Page CDN URL pattern (template carried in a `var pu = '...'` script
line, which we mostly use to confirm the convention but build URLs
ourselves):

```text
https://cdn1.intomanga.com/i/m/{mangaUuid}/c/{chapterUuid}/o/{pageUuid}.jpg
```

## Scope

In scope: search, getMangaDetail, getChapters, getChapterPages.
Out of scope: getLatestUpdates (no clean unauthenticated endpoint),
favorites, comments, ratings.

## Notes

- All chapters are tagged `language: 'es'` and `scanlator: 'InManga'`.
- Mirror rotation is provided by `kumoriya_source_runtime` for
  consistency with sibling source plugins, but defaults to a
  single-entry list of `https://inmanga.com/`.
