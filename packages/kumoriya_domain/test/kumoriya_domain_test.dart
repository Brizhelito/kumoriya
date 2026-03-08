import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:test/test.dart';

void main() {
  test('anime detail keeps typed episode list', () {
    const detail = AnimeDetail(
      anime: Anime(
        anilistId: 1,
        title: AnimeTitle(romaji: 'Test'),
        format: AnimeFormat.tv,
      ),
      episodes: <AnimeEpisode>[AnimeEpisode(number: 1, title: 'Episode 1')],
    );

    expect(detail.episodes.first.title, 'Episode 1');
  });
}
