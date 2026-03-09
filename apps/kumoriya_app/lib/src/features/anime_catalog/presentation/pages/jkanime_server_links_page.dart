import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import 'resolve_server_link_page.dart';

class JkAnimeServerLinksPage extends ConsumerWidget {
  const JkAnimeServerLinksPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    required this.episode,
  });

  final int anilistId;
  final String animeTitle;
  final SourceEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverLinksState = ref.watch(
      jkanimeEpisodeServerLinksProvider(episode),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.jkanimeServerLinksTitle(
            animeTitle,
            episode.number.toInt().toString(),
          ),
        ),
      ),
      body: serverLinksState.when(
        loading: () =>
            LoadingStateView(label: context.l10n.jkanimeServerLinksLoading),
        error: (error, _) => ErrorStateView(
          message: context.l10n.unexpectedStateError(error.toString()),
          onRetry: () =>
              ref.invalidate(jkanimeEpisodeServerLinksProvider(episode)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () =>
                ref.invalidate(jkanimeEpisodeServerLinksProvider(episode)),
          ),
          onSuccess: (serverLinks) {
            if (serverLinks.isEmpty) {
              return EmptyStateView(
                message: context.l10n.jkanimeServerLinksEmpty,
              );
            }

            return ListView.separated(
              itemCount: serverLinks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final link = serverLinks[index];
                final language = link.language;
                final isStream = link.linkType == SourceServerLinkType.stream;
                return ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(link.serverName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(link.initialUrl.toString()),
                      if (link.detectedHost != null)
                        Text(
                          context.l10n.jkanimeDetectedHost(link.detectedHost!),
                        ),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        isStream
                            ? context.l10n.jkanimeLinkTypeStream
                            : context.l10n.jkanimeLinkTypeDownload,
                      ),
                      if (language != null) Text(language.toUpperCase()),
                      OutlinedButton(
                        onPressed: isStream
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ResolveServerLinkPage(
                                      anilistId: anilistId,
                                      animeTitle: animeTitle,
                                      episodeNumber: episode.number
                                          .toInt()
                                          .toString(),
                                      sourcePluginId: 'kumoriya.source.jkanime',
                                      serverLink: link,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text(
                          isStream
                              ? context.l10n.resolveServerLink
                              : context.l10n.jkanimeDownloadOnly,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
