/// Request value object for `MangaSourcePlugin.search`.
///
/// Free-text search against the source. Pagination is 1-indexed to
/// match how most manga sources expose their search endpoints.
/// `languages` is a soft hint: plugins that do not honor language
/// filtering simply ignore it (see `MangaSourceCapabilities`).
final class MangaSearchQuery {
  const MangaSearchQuery({
    required this.query,
    this.page = 1,
    this.limit = 20,
    this.languages = const <String>[],
  }) : assert(page >= 1, 'page must be 1-indexed'),
       assert(limit > 0, 'limit must be positive');

  final String query;
  final int page;
  final int limit;

  /// BCP-47 language codes the caller prefers (e.g. `['es', 'en']`).
  /// Order matters: earlier codes are higher priority.
  final List<String> languages;
}
