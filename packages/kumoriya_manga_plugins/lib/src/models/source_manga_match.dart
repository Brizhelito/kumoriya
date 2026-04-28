import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

/// Result row of `MangaSourcePlugin.search`.
///
/// Contains the minimum fields needed to align a source title to an
/// AniList canonical id via `kumoriya_matching`. Detail-only fields
/// (synopsis, authors, tags, full status) live on
/// [SourceMangaDetail] to keep search payloads light.
final class SourceMangaMatch {
  const SourceMangaMatch({
    required this.sourceId,
    required this.title,
    this.aliases = const <String>[],
    this.thumbnailUrl,
    this.releaseYear,
    this.format = MangaFormat.unknown,
    this.country,
  });

  /// Source-side opaque identifier. Stable across detail/chapter calls.
  final String sourceId;

  /// Primary title as the source presents it (any language).
  final String title;

  /// Alternate titles published by the source. Used by matching to
  /// boost confidence; never shown verbatim without UI shaping.
  final List<String> aliases;

  final Uri? thumbnailUrl;
  final int? releaseYear;
  final MangaFormat format;
  final MangaCountryOfOrigin? country;
}
