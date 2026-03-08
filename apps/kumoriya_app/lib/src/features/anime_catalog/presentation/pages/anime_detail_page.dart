import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

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
      appBar: AppBar(title: const Text('Anime detail')),
      body: detailState.when(
        loading: () => const LoadingStateView(label: 'Loading anime detail...'),
        error: (error, _) => ErrorStateView(
          message: 'Unexpected state error: $error',
          onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(error),
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
            if (anime.totalEpisodes != null) '${anime.totalEpisodes} episodes',
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
          label: const Text('View episode list'),
        ),
        const SizedBox(height: 20),
        _JkAnimeAvailabilityCard(
          animeTitle: anime.title.romaji,
          availabilityState: availabilityState,
        ),
        if (detail.episodes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            'Episode preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...detail.episodes.take(5).map((episode) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${episode.number.toInt()}. ${episode.title}'),
              subtitle: Text(
                episode.isAired ? 'Aired' : 'Upcoming',
                style: TextStyle(
                  color: episode.isAired ? Colors.green : Colors.orange,
                ),
              ),
            );
          }),
        ],
        if (detail.relations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text('Relations', style: Theme.of(context).textTheme.titleMedium),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: availabilityState.when(
          loading: () => const _AvailabilityStatusTile(
            title: 'JKAnime availability',
            subtitle: 'Checking availability in JKAnime...',
            icon: Icons.sync,
            iconColor: Colors.blue,
          ),
          error: (error, _) => _AvailabilityStatusTile(
            title: 'JKAnime availability',
            subtitle: 'Error consulting JKAnime: $error',
            icon: Icons.error_outline,
            iconColor: Colors.red,
          ),
          data: (result) => result.fold(
            onFailure: (error) => _AvailabilityStatusTile(
              title: 'JKAnime availability',
              subtitle: mapErrorMessage(error),
              icon: Icons.error_outline,
              iconColor: Colors.red,
            ),
            onSuccess: (availability) {
              if (availability.status == SourceAvailabilityStatus.unavailable) {
                return _AvailabilityStatusTile(
                  title: 'JKAnime availability',
                  subtitle:
                      'Not available in JKAnime (${availability.decision.reason})',
                  icon: Icons.remove_circle_outline,
                  iconColor: Colors.orange,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _AvailabilityStatusTile(
                    title: 'JKAnime availability',
                    subtitle: 'Available in JKAnime',
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text('Real episodes found: ${availability.episodes.length}'),
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
                      label: const Text('View real JKAnime episodes'),
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
