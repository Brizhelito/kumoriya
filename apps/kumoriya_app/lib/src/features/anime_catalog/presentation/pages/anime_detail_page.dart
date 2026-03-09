import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/source_availability.dart';
import '../providers/anime_catalog_providers.dart';
import 'episode_list_page.dart';
import 'source_episode_list_page.dart';

class AnimeDetailPage extends ConsumerWidget {
  const AnimeDetailPage({super.key, required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(animeDetailProvider(anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(anilistId),
    );

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
            anilistId: anilistId,
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
    required this.anilistId,
    required this.detail,
    required this.availabilityState,
  });

  final int anilistId;
  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;

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
        _SourceAvailabilityCard(
          anilistId: anilistId,
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

class _SourceAvailabilityCard extends StatelessWidget {
  const _SourceAvailabilityCard({
    required this.anilistId,
    required this.animeTitle,
    required this.availabilityState,
  });

  final int anilistId;
  final String animeTitle;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: availabilityState.when(
          loading: () => _AvailabilityStatusTile(
            title: context.l10n.sourceAvailabilityTitle,
            subtitle: context.l10n.sourceAvailabilityChecking,
            icon: Icons.sync,
            iconColor: Colors.blue,
          ),
          error: (error, _) => _AvailabilityStatusTile(
            title: context.l10n.sourceAvailabilityTitle,
            subtitle: context.l10n.unexpectedStateError(error.toString()),
            icon: Icons.error_outline,
            iconColor: Colors.red,
          ),
          data: (result) => result.fold(
            onFailure: (error) => _AvailabilityStatusTile(
              title: context.l10n.sourceAvailabilityTitle,
              subtitle: mapErrorMessage(context, error),
              icon: Icons.error_outline,
              iconColor: Colors.red,
            ),
            onSuccess: (summary) {
              if (summary.sources.isEmpty) {
                return _AvailabilityStatusTile(
                  title: context.l10n.sourceAvailabilityTitle,
                  subtitle: context.l10n.sourceAvailabilityNone,
                  icon: Icons.remove_circle_outline,
                  iconColor: Colors.orange,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.sourceAvailabilityTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (summary.recommended != null) ...<Widget>[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () =>
                          _openSourceEpisodes(context, summary.recommended!),
                      icon: const Icon(Icons.playlist_play),
                      label: Text(
                        context.l10n.sourceOpenRecommended(
                          summary.recommended!.manifest.displayName,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.sourceRecommended(
                        summary.recommended!.manifest.displayName,
                      ),
                    ),
                  ],
                  if (summary.sources
                          .where(
                            (source) =>
                                source.status ==
                                SourceAvailabilityStatus.available,
                          )
                          .length >
                      1) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(context.l10n.sourceChoosePrompt),
                  ],
                  const SizedBox(height: 8),
                  ...summary.sources.map(
                    (availability) => _SourceAvailabilityListTile(
                      anilistId: anilistId,
                      animeTitle: animeTitle,
                      availability: availability,
                      isRecommended:
                          summary.recommended?.manifest.id ==
                          availability.manifest.id,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openSourceEpisodes(
    BuildContext context,
    SourceAvailability availability,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SourceEpisodeListPage(
          anilistId: anilistId,
          animeTitle: animeTitle,
          sourcePluginId: availability.manifest.id,
          sourceName: availability.manifest.displayName,
          episodes: availability.episodes,
        ),
      ),
    );
  }
}

class _SourceAvailabilityListTile extends StatelessWidget {
  const _SourceAvailabilityListTile({
    required this.anilistId,
    required this.animeTitle,
    required this.availability,
    required this.isRecommended,
  });

  final int anilistId;
  final String animeTitle;
  final SourceAvailability availability;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (availability.status) {
      SourceAvailabilityStatus.available =>
        context.l10n.sourceAvailableEpisodes(availability.episodes.length),
      SourceAvailabilityStatus.error =>
        availability.errorMessage ??
            context.l10n.sourceUnavailableError(
              availability.manifest.displayName,
            ),
      SourceAvailabilityStatus.unavailable =>
        switch (availability.unavailableReason) {
          SourceUnavailableReason.noEpisodes =>
            context.l10n.sourceNotAvailableNoEpisodes(
              availability.manifest.displayName,
            ),
          SourceUnavailableReason.ambiguousMatch =>
            context.l10n.sourceNotAvailableAmbiguous(
              availability.manifest.displayName,
            ),
          _ => context.l10n.sourceNotAvailableNoMatch(
            availability.manifest.displayName,
          ),
        },
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        availability.status == SourceAvailabilityStatus.available
            ? Icons.check_circle_outline
            : availability.status == SourceAvailabilityStatus.error
            ? Icons.error_outline
            : Icons.remove_circle_outline,
        color: availability.status == SourceAvailabilityStatus.available
            ? Colors.green
            : availability.status == SourceAvailabilityStatus.error
            ? Colors.red
            : Colors.orange,
      ),
      title: Row(
        children: <Widget>[
          Expanded(child: Text(availability.manifest.displayName)),
          if (isRecommended)
            Chip(label: Text(context.l10n.sourceRecommendedShort)),
        ],
      ),
      subtitle: Text(subtitle),
      trailing: availability.status == SourceAvailabilityStatus.available
          ? OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SourceEpisodeListPage(
                      anilistId: anilistId,
                      animeTitle: animeTitle,
                      sourcePluginId: availability.manifest.id,
                      sourceName: availability.manifest.displayName,
                      episodes: availability.episodes,
                    ),
                  ),
                );
              },
              child: Text(context.l10n.sourceViewEpisodes),
            )
          : null,
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
