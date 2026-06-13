import 'package:kumoriya_source_miruro/src/miruro_plugin.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() async {
  final plugin = MiruroSourcePlugin();

  print('Testing search...');
  final searchResult = await plugin.search(
    const SourceSearchQuery(query: 'naruto', limit: 2),
  );
  searchResult.fold(
    onSuccess: (matches) {
      for (final match in matches) {
        print('- ${match.title} (ID: ${match.sourceId})');
      }
    },
    onFailure: (err) => print('Search error: ${err.message}'),
  );

  print('\nTesting getAnimeDetail...');
  final detailResult = await plugin.getAnimeDetail('21'); // One Piece
  detailResult.fold(
    onSuccess: (detail) {
      print('Title: ${detail.title}');
      print('Episodes: ${detail.totalEpisodes}');
      print('Synopsis length: ${detail.synopsis?.length}');
    },
    onFailure: (err) => print('Detail error: ${err.message}'),
  );

  print('\nTesting getEpisodes...');
  final episodesResult = await plugin.getEpisodes('21');
  SourceEpisode? firstEpisode;
  episodesResult.fold(
    onSuccess: (episodes) {
      print('Total episodes: ${episodes.length}');
      if (episodes.isNotEmpty) {
        firstEpisode = episodes.first;
        print(
          'First episode: ${firstEpisode!.title} (ID: ${firstEpisode!.sourceEpisodeId})',
        );
      }
    },
    onFailure: (err) => print('Episodes error: ${err.message}'),
  );

  if (firstEpisode != null) {
    print('\nTesting getEpisodeServerLinks...');
    final linksResult = await plugin.getEpisodeServerLinks(firstEpisode!);
    linksResult.fold(
      onSuccess: (links) {
        print('Total links: ${links.length}');
        for (final link in links) {
          print('- ${link.serverName}: ${link.initialUrl}');
        }
      },
      onFailure: (err) => print('Links error: ${err.message}'),
    );
  }
}
