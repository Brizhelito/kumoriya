/// Per-plugin feature flags for manga source plugins.
///
/// Anime sources advertise capabilities via the shared `PluginCapability`
/// enum on `PluginManifest.capabilities`. Manga sources advertise their
/// own feature set here because the relevant axes differ:
///
/// - whether the source filters by chapter language,
/// - whether scanlator filtering is meaningful (usually only on
///   aggregator sources like MangaDex),
/// - whether a "latest updates" feed exists separately from search,
/// - whether per-page HTTP headers are required to fetch images
///   (Referer / Origin / Cookie pinning, hotlink protection).
///
/// The contract layer never introspects these flags. Higher layers
/// (UI, repositories) read them to decide which filters to surface
/// and which network primitives to engage.
final class MangaSourceCapabilities {
  const MangaSourceCapabilities({
    this.supportsLanguageFilter = false,
    this.supportsScanlatorFilter = false,
    this.supportsLatestFeed = false,
    this.requiresPageHeaders = false,
  });

  /// `true` when [MangaSourcePlugin.search] / `getChapters` honor a
  /// language filter (BCP-47 codes like `en`, `es-419`).
  final bool supportsLanguageFilter;

  /// `true` when the source exposes per-scanlator chapter variants and
  /// the plugin allows filtering by them.
  final bool supportsScanlatorFilter;

  /// `true` when the source has a dedicated "latest chapter releases"
  /// feed separate from search (used by the manga `Latest` tab).
  final bool supportsLatestFeed;

  /// `true` when fetching images returned by `getChapterPages` requires
  /// the headers attached to each `SourcePage` (Referer, Origin, etc.).
  /// Readers that ignore this flag may get 403/404 responses.
  final bool requiresPageHeaders;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaSourceCapabilities &&
          supportsLanguageFilter == other.supportsLanguageFilter &&
          supportsScanlatorFilter == other.supportsScanlatorFilter &&
          supportsLatestFeed == other.supportsLatestFeed &&
          requiresPageHeaders == other.requiresPageHeaders;

  @override
  int get hashCode => Object.hash(
    supportsLanguageFilter,
    supportsScanlatorFilter,
    supportsLatestFeed,
    requiresPageHeaders,
  );
}
