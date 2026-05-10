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
  });
}
