/// A single chapter as exposed to the UI.
///
/// `number` is a `double` to support fractional chapters (e.g. `12.5`,
/// extras, side-stories) which are common in manga.
///
/// `language` and `scanlator` are optional and surface-level: they help
/// the user disambiguate when a source serves multiple translations of
/// the same chapter. Source-specific identifiers belong in the plugin
/// contracts, not here.
final class MangaChapter {
  const MangaChapter({
    required this.number,
    required this.title,
    this.volume,
    this.language,
    this.scanlator,
    this.publishedAt,
    this.pageCount,
    this.externalUrl,
    this.sourceId,
  });

  final double number;
  final String title;
  final int? volume;
  final String? language;
  final String? scanlator;
  final DateTime? publishedAt;
  final int? pageCount;

  /// When non-null, the chapter is hosted by an external publisher
  /// (MangaPlus, Viz Media, ComiXology, …) and is **not playable
  /// inside the app reader**. The UI surfaces these in a separate
  /// section with an "open in browser" action.
  final Uri? externalUrl;

  /// Identifier of the source plugin that produced this chapter
  /// (e.g. `mangadex`, `olympus`). Null on legacy single-source code
  /// paths and when constructed from cache rows that pre-date the
  /// multi-source slice. Required by [CompositeMangaCatalogRepository]
  /// to route reader/download requests to the right plugin when more
  /// than one source contributes chapters for the same manga.
  final String? sourceId;
}
