import 'package:flutter/material.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/l10n.dart';
import 'jkanime_server_links_page.dart';

class JkAnimeEpisodeListPage extends StatelessWidget {
  const JkAnimeEpisodeListPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    required this.episodes,
  });

  final int anilistId;
  final String animeTitle;
  final List<SourceEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.jkanimeEpisodesTitle(animeTitle)),
      ),
      body: ListView.separated(
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final episode = episodes[index];
          return ListTile(
            title: Text('${episode.number.toInt()}. ${episode.title}'),
            subtitle: Text(episode.episodeUrl.toString()),
            trailing: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => JkAnimeServerLinksPage(
                      anilistId: anilistId,
                      animeTitle: animeTitle,
                      episode: episode,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.dns_outlined),
              label: Text(context.l10n.viewServerLinks),
            ),
          );
        },
      ),
    );
  }
}
