import 'anime_format.dart';
import 'anime_status.dart';
import 'anime_title.dart';

final class Anime {
  const Anime({
    required this.anilistId,
    required this.title,
    required this.format,
    this.releaseYear,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.totalEpisodes,
    this.nextAiringEpisodeNumber,
    this.nextAiringAt,
    this.averageScore,
    this.popularity,
    this.season,
    this.synopsis,
    this.genres = const <String>[],
    this.status = AnimeStatus.unknown,
  });

  final int anilistId;
  final AnimeTitle title;
  final AnimeFormat format;
  final int? releaseYear;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final int? totalEpisodes;
  final int? nextAiringEpisodeNumber;
  final DateTime? nextAiringAt;
  final int? averageScore;
  final int? popularity;
  final String? season;
  final String? synopsis;
  final List<String> genres;
  final AnimeStatus status;
}
