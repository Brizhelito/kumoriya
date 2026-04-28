import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

/// Detailed source-side payload for a single manga.
///
/// Returned by `MangaSourcePlugin.getMangaDetail`. Only the source's
/// view is captured here — AniList-canonical metadata stays in
/// `MangaDetail` (`kumoriya_manga_domain`) and is reconciled at the
/// repository layer.
final class SourceMangaDetail {
  const SourceMangaDetail({
    required this.sourceId,
    required this.title,
    this.synopsis,
    this.aliases = const <String>[],
    this.authors = const <String>[],
    this.artists = const <String>[],
    this.tags = const <String>[],
    this.thumbnailUrl,
    this.releaseYear,
    this.status = MangaStatus.unknown,
    this.format = MangaFormat.unknown,
    this.country,
    this.originalLanguage,
  });

  final String sourceId;
  final String title;
  final String? synopsis;
  final List<String> aliases;
  final List<String> authors;
  final List<String> artists;

  /// Source-defined tag/genre strings. Not normalized to AniList tags.
  final List<String> tags;

  final Uri? thumbnailUrl;
  final int? releaseYear;
  final MangaStatus status;
  final MangaFormat format;
  final MangaCountryOfOrigin? country;

  /// BCP-47 language code of the source publication, when known
  /// (e.g. `ja`, `ko`, `zh`). Useful for UX badges and as a default
  /// when the user has not chosen a preferred translation language.
  final String? originalLanguage;
}
