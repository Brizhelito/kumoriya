import 'package:kumoriya_domain/kumoriya_domain.dart';

void main() {
  const anime = Anime(
    anilistId: 1,
    title: AnimeTitle(romaji: 'Example Anime'),
    format: AnimeFormat.tv,
  );
  print(anime.title.romaji);
}
