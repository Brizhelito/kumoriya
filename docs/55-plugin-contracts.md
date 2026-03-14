# Kumoriya Plugin Contracts

## Purpose

Kumoriya keeps plugin boundaries in `packages/kumoriya_plugins`.

This package defines the stable contract that source plugins and resolver plugins must implement so the app can depend on abstractions instead of concrete packages.

Current public entrypoint:

- `packages/kumoriya_plugins/lib/kumoriya_plugins.dart`

## Plugin families

Kumoriya currently has two plugin types:

- `PluginType.source`
- `PluginType.resolver`

These types are defined in `packages/kumoriya_plugins/lib/src/models/plugin_type.dart`.

The separation is intentional:

- source plugins scrape/search/list episodes and extract raw server links
- resolver plugins take a host URL and resolve it into playable streams
- the player does not resolve links
- the UI should not depend on any specific plugin implementation

## Shared metadata

Every plugin exposes a `PluginManifest`.

Defined in `packages/kumoriya_plugins/lib/src/models/plugin_manifest.dart`.

Fields:

- `id`: stable unique plugin identifier such as `kumoriya.source.jkanime`
- `displayName`: user-facing or diagnostic name
- `type`: `source` or `resolver`
- `capabilities`: declared feature set
- `iconUrl`: optional remote icon
- `supportedHosts`: resolver host allowlist or other host metadata
- `baseUrls`: canonical base URLs for the plugin
- `usesWebView`: declares that the plugin may require WebView as last-resort infrastructure

Supported capabilities are currently:

- `search`
- `animeDetail`
- `episodeList`
- `linkExtraction`
- `streamResolution`

Defined in `packages/kumoriya_plugins/lib/src/models/plugin_capability.dart`.

## Result boundary

Plugin operations do not throw domain-facing success values directly.

Both plugin contracts return:

- `Future<Result<T, KumoriyaError>>`

This keeps plugin failures explicit at the boundary and matches the project rule of Result/Either-style error handling.

## Source plugin contract

Defined in `packages/kumoriya_plugins/lib/src/contracts/source_plugin.dart`.

`SourcePlugin` must expose:

- `PluginManifest get manifest`
- `search(SourceSearchQuery query)`
- `getAnimeDetail(String sourceId)`
- `getEpisodes(String sourceId)`
- `getEpisodeServerLinks(SourceEpisode episode)`

Supporting contract models:

- `SourceSearchQuery`
  - input query text
  - pagination fields: `page`, `limit`
- `SourceAnimeMatch`
  - lightweight search result from a source
  - includes `sourceId`, `title`, optional `thumbnailUrl`, optional `releaseYear`, and `AnimeFormat`
- `SourceAnimeDetail`
  - detail payload for a matched source entry
  - includes `sourceId`, `title`, optional `synopsis`, optional `thumbnailUrl`, optional `releaseYear`, and `AnimeFormat`
- `SourceEpisode`
  - source-side episode identity and URL
  - includes `sourceEpisodeId`, `number`, `title`, `episodeUrl`, optional `thumbnailUrl`
- `SourceServerLink`
  - extracted raw server candidate from a source episode page
  - includes `serverId`, `serverName`, `initialUrl`, optional `language`, `linkType`, optional `detectedHost`
- `SourceServerLinkType`
  - `stream`
  - `download`

Responsibilities of a source plugin:

- search a source catalog
- fetch source detail for a source-local id
- list episodes for a source-local anime
- extract raw server links from an episode page

Non-responsibilities:

- selecting the best resolver
- turning host pages into playable media URLs
- playback
- AniList matching policy

## Resolver plugin contract

Defined in `packages/kumoriya_plugins/lib/src/contracts/resolver_plugin.dart`.

`ResolverPlugin` must expose:

- `PluginManifest get manifest`
- `int get priority`
- `bool supports(Uri url)`
- `resolve(Uri url)`

Supporting contract model:

- `ResolvedStream`
  - `url`: playable media URL
  - `qualityLabel`: optional label such as `720p` or `auto`
  - `mimeType`: optional MIME type
  - `isHls`: whether the stream is HLS
  - `headers`: request headers required for playback

Responsibilities of a resolver plugin:

- decide whether it supports a URL
- validate host/path conservatively
- resolve a supported URL into one or more playable streams
- attach required headers such as `Referer` or `Origin`

Non-responsibilities:

- scraping anime catalogs
- episode listing
- source matching
- playback UI

## Runtime consumption in the app

The app composes plugins through Riverpod in:

- `apps/kumoriya_app/lib/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart`

Current runtime pattern:

- source plugins are registered as `List<SourcePlugin>`
- resolver plugins are registered as `List<ResolverPlugin>`
- the app builds a source-plugin map by `manifest.id`
- resolver selection is delegated to `ResolverRegistry`

`ResolverRegistry` lives in:

- `apps/kumoriya_app/lib/src/features/anime_catalog/application/services/resolver_registry.dart`

Selection rules:

- filter resolvers with `supports(url)`
- sort by descending `priority`
- break ties by `manifest.id`
- if the top two priorities are equal, return ambiguity instead of picking arbitrarily

This matches Kumoriya's rule of preferring no stream over the wrong stream.

## Concrete examples

Source plugin example:

- `packages/kumoriya_source_jkanime/lib/src/jkanime_source_plugin.dart`

Resolver plugin example:

- `packages/kumoriya_resolver_streamwish/lib/src/streamwish_resolver_plugin.dart`

In both cases, the concrete package depends on `kumoriya_plugins` for contracts and returns typed `Result` values instead of leaking implementation details to the app.

## Architecture rules these contracts protect

- plugin contracts live in a plugin-facing package, not in the app UI
- the UI depends on `SourcePlugin` and `ResolverPlugin`, not on concrete implementations
- source extraction and stream resolution stay separated
- playback receives already-resolved streams
- plugin metadata is explicit and inspectable through `PluginManifest`
- failures remain explicit through `Result<T, KumoriyaError>`

## Practical guidance for new plugins

When adding a new source plugin:

- implement `SourcePlugin`
- give it a stable `manifest.id`
- keep returned source identifiers source-local
- return no match or no data when confidence is weak

When adding a new resolver plugin:

- implement `ResolverPlugin`
- keep `supports(Uri)` strict
- set `priority` deliberately
- return no streams when extraction is weak or inconsistent

## Intentional gaps

These contracts do not yet define:

- plugin discovery/loading from external packages at runtime
- version negotiation between app and plugins
- a dedicated plugin health/diagnostics contract
- download-specific resolver contracts

Those can be added later if the product needs them, but they are intentionally outside the current baseline.
