import 'package:flutter/material.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

class JkAnimeEpisodeListPage extends StatelessWidget {
  const JkAnimeEpisodeListPage({
    super.key,
    required this.animeTitle,
    required this.episodes,
  });

  final String animeTitle;
  final List<SourceEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('JKAnime episodes • $animeTitle')),
      body: ListView.separated(
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final episode = episodes[index];
          return ListTile(
            title: Text('${episode.number.toInt()}. ${episode.title}'),
            subtitle: Text(episode.episodeUrl.toString()),
          );
        },
      ),
    );
  }
}
