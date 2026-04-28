/// Source-side chapter descriptor.
///
/// `number` is a `double` so fractional/side-story chapters
/// (e.g. `12.5`, `0.5`) round-trip without loss. `pageCount` is
/// optional because some sources only reveal it inside
/// `getChapterPages`.
///
/// `language` is BCP-47 (`en`, `es`, `es-419`). `scanlator` is the
/// source's opaque name/id; UI surfaces it verbatim.
final class SourceChapter {
  const SourceChapter({
    required this.sourceMangaId,
    required this.sourceChapterId,
    required this.number,
    this.title,
    this.volume,
    this.language = 'en',
    this.scanlator,
    this.publishedAt,
    this.pageCount,
  });

  final String sourceMangaId;
  final String sourceChapterId;

  /// Chapter number. Fractional values (`12.5`) are supported and
  /// must be preserved by callers.
  final double number;

  final String? title;

  /// Volume number when the source exposes it. Null for sources that
  /// only expose chapter granularity.
  final int? volume;

  /// BCP-47 language code of the chapter content.
  final String language;

  /// Scanlator name/id, when the source supports per-scanlator variants.
  final String? scanlator;

  /// Source-published timestamp (UTC). Null if the source does not
  /// expose it.
  final DateTime? publishedAt;

  /// Number of pages in the chapter, when the source exposes it.
  final int? pageCount;
}
