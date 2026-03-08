import 'anime.dart';
import 'anime_episode.dart';

final class AnimeDetail {
  const AnimeDetail({
    required this.anime,
    this.synopsis,
    this.episodes = const <AnimeEpisode>[],
  });

  final Anime anime;
  final String? synopsis;
  final List<AnimeEpisode> episodes;
}
