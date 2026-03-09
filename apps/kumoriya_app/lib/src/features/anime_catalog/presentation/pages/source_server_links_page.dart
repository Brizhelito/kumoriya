import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import 'resolve_server_link_page.dart';

class SourceServerLinksPage extends ConsumerWidget {
  const SourceServerLinksPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    required this.sourcePluginId,
    required this.sourceName,
    required this.episode,
  });

  final int anilistId;
  final String animeTitle;
  final String sourcePluginId;
  final String sourceName;
  final SourceEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverLinksState = ref.watch(
      sourceEpisodeServerLinksProvider((
        sourcePluginId: sourcePluginId,
        episode: episode,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.sourceServerLinksTitle(
            sourceName,
            animeTitle,
            episode.number.toInt().toString(),
          ),
        ),
      ),
      body: serverLinksState.when(
        loading: () => LoadingStateView(
          label: context.l10n.sourceServerLinksLoading(sourceName),
        ),
        error: (error, _) => ErrorStateView(
          message: context.l10n.unexpectedStateError(error.toString()),
          onRetry: () => ref.invalidate(
            sourceEpisodeServerLinksProvider((
              sourcePluginId: sourcePluginId,
              episode: episode,
            )),
          ),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => ref.invalidate(
              sourceEpisodeServerLinksProvider((
                sourcePluginId: sourcePluginId,
                episode: episode,
              )),
            ),
          ),
          onSuccess: (serverLinks) => ListView.separated(
            itemCount: serverLinks.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final link = serverLinks[index];
              return ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(link.serverName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(link.initialUrl.toString()),
                    if (link.detectedHost != null)
                      Text(context.l10n.sourceDetectedHost(link.detectedHost!)),
                  ],
                ),
                trailing: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ResolveServerLinkPage(
                          anilistId: anilistId,
                          animeTitle: animeTitle,
                          episodeNumber: episode.number.toInt().toString(),
                          sourcePluginId: sourcePluginId,
                          serverLink: link,
                        ),
                      ),
                    );
                  },
                  child: Text(context.l10n.resolveServerLink),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
