# kumoriya_source_visormanga

Visor TMO Manga (`visormanga.com`) source plugin for Kumoriya. ES catalog
covering manga, manhwa, and manhua. Pure SSR HTML scrape — no public REST
API exists for this site.

## Endpoints (HTML routes)

- **Search**: `GET /biblioteca?search={q}&page={p}` (1-indexed pagination)
- **Detail + chapters**: `GET /manga/{slug}` (single round-trip; chapter list
  embedded in the same page)
- **Pages**: `GET /leer/{slug}-{number}` — image URLs live inside
  `<div id="image-alls">`

## Identifiers

- `sourceMangaId` = manga slug (e.g., `dios-te-bendiga`)
- `sourceChapterId` = chapter number with two decimals (e.g., `43.00`),
  matching the URL convention `/leer/{slug}-{N.NN}`

## Notes

- Hosted behind Cloudflare. A realistic Chrome-like User-Agent is enough
  for clean HTTP access today.
- Image CDN is `v2.imgvtmo.com/tmpimg/`. No special headers needed.
- The S2.C per-plugin URL override lets the user pin a working mirror
  if the brand redeploys to a different domain.
