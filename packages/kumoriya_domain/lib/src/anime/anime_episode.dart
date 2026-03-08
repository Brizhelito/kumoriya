final class AnimeEpisode {
  const AnimeEpisode({
    required this.number,
    required this.title,
    this.airDate,
    this.isFiller = false,
  });

  final double number;
  final String title;
  final DateTime? airDate;
  final bool isFiller;
}
