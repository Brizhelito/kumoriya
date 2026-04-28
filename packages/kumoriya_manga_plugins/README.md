# kumoriya_manga_plugins

Plugin contracts for manga sources.

This package defines the `MangaSourcePlugin` interface and the source-side
value objects (`SourceMangaMatch`, `SourceMangaDetail`, `SourceChapter`,
`SourcePage`) plus per-plugin `MangaSourceCapabilities`.

It is parallel to `kumoriya_plugins` (which targets anime sources) and
deliberately separate: chapter / page semantics differ enough from
episode / stream semantics that conflating both contracts would force
ugly compromises on either side.

The package only contains contracts. Concrete source implementations
live in their own packages (e.g. `kumoriya_source_mangadex`). The
reader, the AniList gateway and the storage layer never depend on a
concrete plugin — only on these contracts.

## Reuse from `kumoriya_plugins`

`PluginManifest`, `PluginType` and the resolver/source split are
reused as-is. Manga-specific capabilities live on
`MangaSourceCapabilities`, separate from the anime-flavored
`PluginCapability` enum.
