import 'anime.dart';

enum AnimeRelationType {
  prequel,
  sequel,
  sideStory,
  adaptation,
  spinOff,
  other,
}

final class AnimeRelation {
  const AnimeRelation({required this.type, required this.anime});

  final AnimeRelationType type;
  final Anime anime;
}
