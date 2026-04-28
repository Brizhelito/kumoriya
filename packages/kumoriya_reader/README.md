# kumoriya_reader

Manga reader engine and UI for Kumoriya.

## Boundaries

- **No source plugin coupling**. Pages arrive pre-resolved as
  `List<MangaPage>` (already a domain type from `kumoriya_manga_domain`).
- **No storage coupling**. Resume / progress is wired through the
  `ReaderProgressSink` interface; the app supplies a Drift-backed
  implementation.
- **No AniList coupling**. The chapter and manga title arrive
  already-mapped.

## Modes

- `ReaderMode.vertical` — continuous scroll, designed for manhwa /
  webtoon. Pinch zoom on the whole list.
- `ReaderMode.paginated` — one page per swipe, with `PhotoView` zoom.

## Public API

- `ChapterSession` — the value object the UI consumes.
- `MangaReaderPage` — the entry-point widget.
- `ReaderProgressSink` — optional resume hook.
