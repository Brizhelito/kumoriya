import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/source_availability.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../widgets/source_badge.dart';
import 'episode_list_page.dart';

class AnimeDetailPage extends ConsumerWidget {
  const AnimeDetailPage({super.key, required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(animeDetailProvider(anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(anilistId),
    );
    final latestProgressState = ref.watch(
      latestEpisodeProgressProvider(anilistId),
    );

    return Scaffold(
      body: detailState.when(
        loading: () => LoadingStateView(label: context.l10n.animeDetailLoading),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
          ),
          onSuccess: (detail) => _AnimeDetailBody(
            detail: detail,
            availabilityState: availabilityState,
            latestProgressState: latestProgressState,
          ),
        ),
      ),
    );
  }
}

class _AnimeDetailBody extends StatelessWidget {
  const _AnimeDetailBody({
    required this.detail,
    required this.availabilityState,
    required this.latestProgressState,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final AsyncValue<Result<EpisodeProgress?, KumoriyaError>> latestProgressState;

  @override
  Widget build(BuildContext context) {
    final anime = detail.anime;

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          stretch: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          flexibleSpace: FlexibleSpaceBar(
            background: _DetailHero(detail: detail),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              _TitleBlock(detail: detail),
              const SizedBox(height: 18),
              _PlaybackSummaryCard(
                anilistId: anime.anilistId,
                animeTitle: anime.title.romaji,
                availabilityState: availabilityState,
                latestProgressState: latestProgressState,
              ),
              if (detail.synopsis != null &&
                  detail.synopsis!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                Text(
                  context.l10n.detailSynopsisTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail.synopsis!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (detail.genres.isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detail.genres
                      .map((genre) => Chip(label: Text(genre)))
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 22),
              _EpisodePreviewSection(
                anilistId: anime.anilistId,
                animeTitle: anime.title.romaji,
                previewEpisodes: detail.episodes
                    .take(5)
                    .toList(growable: false),
                availabilityState: availabilityState,
              ),
              if (detail.relations.isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                Text(
                  context.l10n.relationsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...detail.relations
                    .take(6)
                    .map(
                      (relation) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(relation.anime.title.romaji),
                        subtitle: Text(relation.type.name),
                      ),
                    ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        KumoriyaCachedImage(
          url: detail.bannerImageUrl ?? detail.anime.coverImageUrl,
          bucket: KumoriyaImageCacheBucket.artwork,
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.78),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 84, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                KumoriyaCachedImage(
                  url: detail.anime.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  width: 120,
                  height: 170,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        detail.anime.title.romaji,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _HeroMetaPill(
                            label: detail.anime.format.name.toUpperCase(),
                          ),
                          _HeroMetaPill(
                            label: detail.anime.status.name.toUpperCase(),
                          ),
                          if (detail.anime.releaseYear != null)
                            _HeroMetaPill(
                              label: detail.anime.releaseYear.toString(),
                            ),
                          if (detail.anime.totalEpisodes != null)
                            _HeroMetaPill(
                              label:
                                  '${detail.anime.totalEpisodes} ${context.l10n.episodesWord}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    final secondaryTitle =
        detail.anime.title.english ??
        detail.anime.title.native ??
        detail.anime.title.romaji;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          secondaryTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.detailDiscoverPrompt,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PlaybackSummaryCard extends StatelessWidget {
  const _PlaybackSummaryCard({
    required this.anilistId,
    required this.animeTitle,
    required this.availabilityState,
    required this.latestProgressState,
  });

  final int anilistId;
  final String animeTitle;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final AsyncValue<Result<EpisodeProgress?, KumoriyaError>> latestProgressState;

  @override
  Widget build(BuildContext context) {
    final latestProgress = latestProgressState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (progress) => progress,
      ),
      orElse: () => null,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          availabilityState.when(
            loading: () => Text(
              context.l10n.sourceAvailabilityChecking,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            error: (_, _) => Text(context.l10n.detailPlaybackNotReady),
            data: (result) => result.fold(
              onFailure: (_) => Text(context.l10n.detailPlaybackNotReady),
              onSuccess: (summary) {
                final playable = summary.playableSources;
                if (playable.isEmpty) {
                  return Text(
                    context.l10n.detailPlaybackNotReady,
                    style: Theme.of(context).textTheme.bodyLarge,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.detailPlaybackSources(playable.length),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: playable
                          .map(
                            (source) => SourceBadge(
                              name: source.manifest.displayName,
                              iconUrl: _sourceIconUrl(source.manifest),
                              audioKinds: source.availableAudioKinds,
                              highlighted:
                                  summary.recommended?.manifest.id ==
                                  source.manifest.id,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          latestProgressState.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (result) => result.fold(
              onFailure: (_) => const SizedBox.shrink(),
              onSuccess: (progress) {
                if (progress == null) {
                  return Text(
                    context.l10n.detailPlaybackHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.detailContinueEpisode(
                        progress.episodeNumber.toInt().toString(),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.detailPlaybackHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EpisodeListPage(
                    anilistId: anilistId,
                    animeTitle: animeTitle,
                    focusedEpisodeNumber: latestProgress?.episodeNumber,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: Text(
              latestProgress == null
                  ? context.l10n.viewEpisodeList
                  : context.l10n.detailContinueEpisode(
                      latestProgress.episodeNumber.toInt().toString(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodePreviewSection extends StatelessWidget {
  const _EpisodePreviewSection({
    required this.anilistId,
    required this.animeTitle,
    required this.previewEpisodes,
    required this.availabilityState,
  });

  final int anilistId;
  final String animeTitle;
  final List<AnimeEpisode> previewEpisodes;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;

  @override
  Widget build(BuildContext context) {
    if (previewEpisodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableByEpisode = availabilityState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => const <double, List<SourceAvailability>>{},
        onSuccess: (summary) {
          final map = <double, List<SourceAvailability>>{};
          for (final source in summary.playableSources) {
            for (final episode in source.episodes.take(20)) {
              map
                  .putIfAbsent(episode.number, () => <SourceAvailability>[])
                  .add(source);
            }
          }
          return map;
        },
      ),
      orElse: () => const <double, List<SourceAvailability>>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.episodePreviewTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...previewEpisodes.map((episode) {
          final sources =
              availableByEpisode[episode.number] ??
              const <SourceAvailability>[];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('${episode.number.toInt()}. ${episode.title}'),
              subtitle: sources.isEmpty
                  ? Text(
                      episode.isAired
                          ? context.l10n.episodeStatusAired
                          : context.l10n.episodeStatusUpcoming,
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sources
                          .take(3)
                          .map(
                            (source) => SourceBadge(
                              name: source.manifest.displayName,
                              iconUrl: _sourceIconUrl(source.manifest),
                              audioKinds: source.availableAudioKinds,
                              compact: true,
                            ),
                          )
                          .toList(growable: false),
                    ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EpisodeListPage(
                      anilistId: anilistId,
                      animeTitle: animeTitle,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _HeroMetaPill extends StatelessWidget {
  const _HeroMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String? _sourceIconUrl(PluginManifest manifest) {
  if (manifest.iconUrl != null && manifest.iconUrl!.trim().isNotEmpty) {
    return manifest.iconUrl;
  }
  if (manifest.baseUrls.isEmpty) {
    return null;
  }

  final base = Uri.tryParse(manifest.baseUrls.first);
  if (base == null || !base.hasScheme) {
    return null;
  }

  return base.resolve('/favicon.ico').toString();
}
