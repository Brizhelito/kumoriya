/// Request value object for `MangaSourcePlugin.getChapters`.
///
/// `languages` and `scanlators` act as soft hints when the plugin
/// declares the matching capability (see `MangaSourceCapabilities`).
/// Plugins that do not support a filter must return the full list,
/// not an empty list.
final class MangaChapterQuery {
  const MangaChapterQuery({
    required this.sourceMangaId,
    this.languages = const <String>[],
    this.scanlators = const <String>[],
    this.page = 1,
    this.limit = 100,
  }) : assert(page >= 1, 'page must be 1-indexed'),
       assert(limit > 0, 'limit must be positive');

  /// Source-side identifier returned by `search` / `getMangaDetail`.
  final String sourceMangaId;

  /// BCP-47 language codes the caller prefers.
  final List<String> languages;

  /// Scanlator names / ids the caller prefers. Source-defined opaque
  /// strings; UI is expected to surface them as-is.
  final List<String> scanlators;

  final int page;
  final int limit;
}
