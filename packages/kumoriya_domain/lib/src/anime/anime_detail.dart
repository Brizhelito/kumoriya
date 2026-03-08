import 'anime.dart';
import 'anime_episode.dart';
import 'anime_relation.dart';

final class AnimeDetail {
  const AnimeDetail({
    required this.anime,
    this.synopsis,
    this.episodes = const <AnimeEpisode>[],
    this.genres = const <String>[],
    this.bannerImageUrl,
    this.relations = const <AnimeRelation>[],
  });

  final Anime anime;
  final String? synopsis;
  final List<AnimeEpisode> episodes;
  final List<String> genres;
  final String? bannerImageUrl;
  final List<AnimeRelation> relations;
}
