import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/l10n.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import '../../../../shared/utils/error_messaging.dart';
import '../../application/models/server_quality_registry.dart';
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
      body: StateTransitionSwitcher(
        stateKey: serverLinksState.isLoading
            ? 'loading'
            : serverLinksState.hasError
            ? 'error'
            : 'content',
        child: serverLinksState.when(
          loading: () => LoadingStateView(
            label: context.l10n.sourceServerLinksLoading(sourceName),
          ),
          error: (_, _) => ErrorStateView(
            message: context.l10n.genericLoadFailure,
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
            onSuccess: (serverLinks) {
              if (serverLinks.isEmpty) {
                return UnavailableStateView(
                  title: context.l10n.episodeLockedLabel,
                  message: context.l10n.sourceServerLinksEmpty,
                  actionLabel: context.l10n.retry,
                  onAction: () => ref.invalidate(
                    sourceEpisodeServerLinksProvider((
                      sourcePluginId: sourcePluginId,
                      episode: episode,
                    )),
                  ),
                );
              }
              final sorted = _sortByQuality(serverLinks);
              return ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final link = sorted[index];
                  final tier = ServerQualityRegistry.tierFor(
                    detectedHost: link.detectedHost,
                    serverName: link.serverName,
                  );
                  final isTop = index == 0 && tier != ServerQualityTier.unknown;
                  return ListTile(
                    leading: Icon(_iconForTier(tier), color: tier.color),
                    title: Row(
                      children: <Widget>[
                        Flexible(child: Text(link.serverName)),
                        const SizedBox(width: 6),
                        _QualityChip(tier: tier),
                        if (link.language != null) ...<Widget>[
                          const SizedBox(width: 4),
                          _LanguageChip(language: link.language!),
                        ],
                        if (isTop) ...<Widget>[
                          const SizedBox(width: 4),
                          Icon(Icons.star_rounded, color: tier.color, size: 18),
                        ],
                      ],
                    ),
                    subtitle: link.detectedHost != null
                        ? Text(
                            context.l10n.sourceDetectedHost(link.detectedHost!),
                          )
                        : null,
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
              );
            },
          ),
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

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.tier});
  final ServerQualityTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tier.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        tier.label,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: tier.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.language});
  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.35)),
      ),
      child: Text(
        language.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: Colors.blueAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
