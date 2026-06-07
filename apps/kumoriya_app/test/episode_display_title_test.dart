import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/support/episode_display_title.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  group('resolveEpisodeDisplayTitle', () {
    test('prefers specific AniList metadata title over English fallback', () {
      final title = resolveEpisodeDisplayTitle(
        episodeNumber: 1,
        fallbackTitle: 'Cruelty',
        metadata: const AnimeEpisode(number: 1, title: 'Crueldad'),
      );

      expect(title, 'Crueldad');
    });

    test('prefers specific source title over English fallback', () {
      final title = resolveEpisodeDisplayTitle(
        episodeNumber: 1,
        fallbackTitle: 'Cruelty',
        sourceEpisodes: <String, SourceEpisode>{
          'source': SourceEpisode(
            sourceEpisodeId: '1',
            number: 1,
            title: 'Crueldad',
            episodeUrl: Uri.parse('https://example.test/1'),
          ),
        },
      );

      expect(title, 'Crueldad');
    });

    test('treats anime title plus episode number as generic source title', () {
      final title = resolveEpisodeDisplayTitle(
        episodeNumber: 10,
        animeTitle:
            'Otonari no Tenshi-sama ni Itsunomanika Dame Ningen ni Sareteita Ken 2nd Season',
        fallbackTitle: 'Episode 10',
        sourceEpisodes: <String, SourceEpisode>{
          'source': SourceEpisode(
            sourceEpisodeId: '10',
            number: 10,
            title:
                'Otonari no Tenshi-sama ni Itsunomanika Dame Ningen ni Sareteita Ken 2 10',
            episodeUrl: Uri.parse('https://example.test/10'),
          ),
        },
      );

      expect(title, 'Episode 10');
    });

    test('treats anime title plus capitulo as generic source title', () {
      final title = resolveEpisodeDisplayTitle(
        episodeNumber: 10,
        animeTitle:
            'Otonari no Tenshi-sama ni Itsunomanika Dame Ningen ni Sareteita Ken 2nd Season',
        fallbackTitle: 'Episode 10',
        sourceEpisodes: <String, SourceEpisode>{
          'source': SourceEpisode(
            sourceEpisodeId: '10',
            number: 10,
            title:
                'Otonari no Tenshi-sama ni Itsunomanika Dame Ningen ni Sareteita Ken Season 2 Capitulo 10',
            episodeUrl: Uri.parse('https://example.test/10'),
          ),
        },
      );

      expect(title, 'Episode 10');
    });
  });
}
