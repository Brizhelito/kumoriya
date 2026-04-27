import 'manga_country_of_origin.dart';
import 'manga_format.dart';
import 'manga_status.dart';
import 'manga_title.dart';

/// Catalog-level manga record.
///
/// AniList-canonical metadata, no source-plugin coupling and no chapter
/// list. Use `MangaDetail` when chapters and relations are needed.
final class Manga {
  const Manga({
    required this.anilistId,
    required this.title,
    required this.format,
    this.releaseYear,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.totalChapters,
    this.totalVolumes,
    this.averageScore,
    this.popularity,
    this.synopsis,
    this.genres = const <String>[],
    this.status = MangaStatus.unknown,
    this.countryOfOrigin,
  });

  final int anilistId;
  final MangaTitle title;
  final MangaFormat format;
  final int? releaseYear;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final int? totalChapters;
  final int? totalVolumes;
  final int? averageScore;
  final int? popularity;
  final String? synopsis;
  final List<String> genres;
  final MangaStatus status;
  final MangaCountryOfOrigin? countryOfOrigin;
}
