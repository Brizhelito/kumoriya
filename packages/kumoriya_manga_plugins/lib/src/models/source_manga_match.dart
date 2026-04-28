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
    this.externalIds = const <String, String>{},
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

  /// Cross-database identifiers exposed by the source, keyed by short
  /// database codes that match the wire format the source uses.
  ///
  /// Common keys:
  ///
  /// - `'al'`  — AniList numeric id (as string)
  /// - `'mu'`  — MangaUpdates id
  /// - `'mal'` — MyAnimeList numeric id
  ///
  /// The map is intentionally untyped to accommodate future databases
  /// without growing the contract. Callers MUST treat missing keys as
  /// "unknown", never as "no match".
  final Map<String, String> externalIds;
}
