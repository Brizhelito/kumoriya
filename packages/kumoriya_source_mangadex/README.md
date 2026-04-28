# kumoriya_source_mangadex

MangaDex source plugin for Kumoriya. Implements `MangaSourcePlugin` from
`kumoriya_manga_plugins` against the public MangaDex API
(`https://api.mangadex.org`).

## Capabilities

- `supportsLanguageFilter`: yes (BCP-47 codes via
  `availableTranslatedLanguage[]` / `translatedLanguage[]`).
- `supportsScanlatorFilter`: yes (post-filtered against the chapter's
  scanlation group relationships).
- `supportsLatestFeed`: yes (latest uploaded chapter ordering).
- `requiresPageHeaders`: no (MD\@Home returns plain image URLs without
  Referer/Origin pinning).

## Notes

- Endpoints used:
  - `GET /manga?title=…` — search
  - `GET /manga?order[latestUploadedChapter]=desc` — latest updates
  - `GET /manga/{id}?includes[]=cover_art&includes[]=author&includes[]=artist`
  - `GET /manga/{id}/feed?translatedLanguage[]=…&order[chapter]=asc&includes[]=scanlation_group`
  - `GET /at-home/server/{chapterId}` — page URL bundle
- Page URLs are constructed as `{baseUrl}/data/{hash}/{filename}` per
  the MD\@Home contract. Plugin uses the non-data-saver bucket.
- The plugin never throws across the contract boundary; failures are
  reported via `Result.failure(KumoriyaError)`.

## Testing

All tests use recorded JSON fixtures under `test/fixtures/`. No live
network calls. Use `package:http/testing.dart` `MockClient` to stub the
HTTP layer.
