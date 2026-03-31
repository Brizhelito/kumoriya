import 'anime.dart';
import 'anime_episode.dart';
import 'anime_relation.dart';

final class AnimeDetail {
  const AnimeDetail({
    required this.anime,
    this.episodes = const <AnimeEpisode>[],
    this.relations = const <AnimeRelation>[],
  });

  final Anime anime;
  final List<AnimeEpisode> episodes;
  final List<AnimeRelation> relations;

  /// Convenience accessors delegating to [anime].
  String? get synopsis => anime.synopsis;
  List<String> get genres => anime.genres;
  String? get bannerImageUrl => anime.bannerImageUrl;
}
