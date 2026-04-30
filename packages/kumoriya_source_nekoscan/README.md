# kumoriya_source_nekoscan

NekoScan (nekoproject.org) source plugin for Kumoriya.

## Architecture

NekoScan is a WordPress site using the **mangareader** theme. It stores manga
series as **categories** and chapters as **posts**. The plugin uses a hybrid
REST + HTML approach:

- **Search**: WP REST API (`/wp-json/wp/v2/categories?search=…`)
- **Detail**: HTML scrape of `/manga/{slug}/` for metadata (cover, synopsis,
  status, type, author, artist, genres, alt titles)
- **Chapters**: HTML scrape of the same detail page (`<div class="eplister">`)
- **Pages**: WP REST API (`/wp-json/wp/v2/posts?slug=…`) → extract `<img src>`
  from `content.rendered`

## Identifiers

- `sourceMangaId` = category slug (e.g., `hana-y-el-hombre-bestia`)
- `sourceChapterId` = chapter post slug (e.g., `hana-y-el-hombre-bestia-extra-4`)

## Images

Chapter images are hosted on `blogger.googleusercontent.com`. No special headers
or hotlink protection.
