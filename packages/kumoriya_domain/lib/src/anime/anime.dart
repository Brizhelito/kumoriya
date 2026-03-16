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
    this.totalEpisodes,
    this.nextAiringEpisodeNumber,
    this.nextAiringAt,
    this.averageScore,
    this.status = AnimeStatus.unknown,
  });

  final int anilistId;
  final AnimeTitle title;
  final AnimeFormat format;
  final int? releaseYear;
  final String? coverImageUrl;
  final int? totalEpisodes;
  final int? nextAiringEpisodeNumber;
  final DateTime? nextAiringAt;
  final int? averageScore;
  final AnimeStatus status;
}
