import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/source_availability.dart';
import '../providers/anime_catalog_providers.dart';
import 'episode_list_page.dart';
import 'jkanime_episode_list_page.dart';

class AnimeDetailPage extends ConsumerWidget {
  const AnimeDetailPage({super.key, required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(animeDetailProvider(anilistId));
    final availabilityState = ref.watch(jkanimeAvailabilityProvider(anilistId));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.animeDetailTitle)),
      body: detailState.when(
        loading: () => LoadingStateView(label: context.l10n.animeDetailLoading),
        error: (error, _) => ErrorStateView(
          message: context.l10n.unexpectedStateError(error.toString()),
          onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
          ),
          onSuccess: (detail) => _AnimeDetailContent(
            detail: detail,
            availabilityState: availabilityState,
          ),
        ),
      ),
    );
  }
}

class _AnimeDetailContent extends StatelessWidget {
  const _AnimeDetailContent({
    required this.detail,
    required this.availabilityState,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailability, KumoriyaError>> availabilityState;

  @override
  Widget build(BuildContext context) {
    final anime = detail.anime;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (detail.bannerImageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              detail.bannerImageUrl!,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          anime.title.romaji,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          [
            anime.format.name.toUpperCase(),
            anime.status.name.toUpperCase(),
            if (anime.totalEpisodes != null)
              '${anime.totalEpisodes} ${context.l10n.episodesWord}',
          ].join(' | '),
        ),
        if (detail.synopsis != null && detail.synopsis!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(detail.synopsis!),
        ],
        if (detail.genres.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detail.genres
                .map((genre) => Chip(label: Text(genre)))
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EpisodeListPage(
                  anilistId: anime.anilistId,
                  animeTitle: anime.title.romaji,
                ),
              ),
            );
          },
          icon: const Icon(Icons.playlist_play),
          label: Text(context.l10n.viewEpisodeList),
        ),
        const SizedBox(height: 20),
        _JkAnimeAvailabilityCard(
          animeTitle: anime.title.romaji,
          availabilityState: availabilityState,
        ),
        if (detail.episodes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            context.l10n.episodePreviewTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...detail.episodes.take(5).map((episode) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${episode.number.toInt()}. ${episode.title}'),
              subtitle: Text(
                episode.isAired
                    ? context.l10n.episodeStatusAired
                    : context.l10n.episodeStatusUpcoming,
                style: TextStyle(
                  color: episode.isAired ? Colors.green : Colors.orange,
                ),
              ),
            );
          }),
        ],
        if (detail.relations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            context.l10n.relationsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...detail.relations.take(6).map((relation) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(relation.anime.title.romaji),
              subtitle: Text(relation.type.name),
            );
          }),
        ],
      ],
    );
  }
}

class _JkAnimeAvailabilityCard extends ConsumerWidget {
  const _JkAnimeAvailabilityCard({
    required this.animeTitle,
    required this.availabilityState,
  });

  final String animeTitle;
  final AsyncValue<Result<SourceAvailability, KumoriyaError>> availabilityState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceManifest = ref.watch(sourcePluginProvider).manifest;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: availabilityState.when(
          loading: () => _AvailabilityStatusTile(
            title: context.l10n.jkanimeAvailabilityTitle,
            subtitle: context.l10n.jkanimeChecking,
            icon: Icons.sync,
            iconColor: Colors.blue,
          ),
          error: (error, _) => _AvailabilityStatusTile(
            title: context.l10n.jkanimeAvailabilityTitle,
            subtitle: context.l10n.jkanimeErrorConsulting(error.toString()),
            icon: Icons.error_outline,
            iconColor: Colors.red,
          ),
          data: (result) => result.fold(
            onFailure: (error) => _AvailabilityStatusTile(
              title: context.l10n.jkanimeAvailabilityTitle,
              subtitle: mapErrorMessage(context, error),
              icon: Icons.error_outline,
              iconColor: Colors.red,
            ),
            onSuccess: (availability) {
              if (availability.status == SourceAvailabilityStatus.unavailable) {
                return _AvailabilityStatusTile(
                  title: context.l10n.jkanimeAvailabilityTitle,
                  subtitle: context.l10n.jkanimeNotAvailableSimple,
                  icon: Icons.remove_circle_outline,
                  iconColor: Colors.orange,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.jkanimeAvailabilityTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            if (sourceManifest.iconUrl != null)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF101826),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: SizedBox(
                                    height: 26,
                                    child: Image.network(
                                      sourceManifest.iconUrl!,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.centerLeft,
                                      errorBuilder: (_, _, _) =>
                                          Text(sourceManifest.displayName),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(sourceManifest.displayName),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.jkanimeRealEpisodesFound(
                      availability.episodes.length,
                    ),
                  ),
                  if (availability.episodes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    ...availability.episodes.take(3).map((episode) {
                      return Text(
                        '${episode.number.toInt()}. ${episode.title}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JkAnimeEpisodeListPage(
                              animeTitle: animeTitle,
                              episodes: availability.episodes,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_alt),
                      label: Text(context.l10n.jkanimeViewRealEpisodes),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AvailabilityStatusTile extends StatelessWidget {
  const _AvailabilityStatusTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}
