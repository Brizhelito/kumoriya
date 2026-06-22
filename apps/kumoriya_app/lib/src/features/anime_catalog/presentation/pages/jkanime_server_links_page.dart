import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/l10n.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import '../../../../shared/utils/error_messaging.dart';
import '../../application/models/server_quality_registry.dart';
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

            final sorted = _sortByQuality(serverLinks);
            return ListView.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final link = sorted[index];
                final language = link.language;
                final isStream = link.linkType == SourceServerLinkType.stream;
                final tier = ServerQualityRegistry.tierFor(
                  detectedHost: link.detectedHost,
                  serverName: link.serverName,
                );
                return ListTile(
                  leading: Icon(_iconForTier(tier), color: tier.color),
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

  static List<SourceServerLink> _sortByQuality(List<SourceServerLink> links) {
    final sorted = List<SourceServerLink>.of(links);
    sorted.sort((a, b) {
      final ta = ServerQualityRegistry.tierFor(
        detectedHost: a.detectedHost,
        serverName: a.serverName,
      );
      final tb = ServerQualityRegistry.tierFor(
        detectedHost: b.detectedHost,
        serverName: b.serverName,
      );
      return tb.weight.compareTo(ta.weight);
    });
    return sorted;
  }

  static IconData _iconForTier(ServerQualityTier tier) => switch (tier) {
    ServerQualityTier.premium => Icons.verified_rounded,
    ServerQualityTier.good => Icons.thumb_up_alt_outlined,
    ServerQualityTier.average => Icons.dns_outlined,
    ServerQualityTier.low => Icons.warning_amber_rounded,
    ServerQualityTier.unknown => Icons.help_outline,
    ServerQualityTier.unavailable => Icons.block_outlined,
  };
}
