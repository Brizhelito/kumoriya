import 'anime_format.dart';
import 'anime_title.dart';

final class Anime {
  const Anime({
    required this.anilistId,
    required this.title,
    required this.format,
    this.releaseYear,
  });

  final int anilistId;
  final AnimeTitle title;
  final AnimeFormat format;
  final int? releaseYear;
}
