import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
import '../support/playback_launch_flow.dart';
import '../widgets/source_badge.dart';

class AnimeDetailPage extends ConsumerStatefulWidget {
  const AnimeDetailPage({super.key, required this.anilistId});

  final int anilistId;

  @override
  ConsumerState<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends ConsumerState<AnimeDetailPage> {
  Future<void> _showDebugPlaybackPreferenceTools() async {
    if (!kDebugMode) {
      return;
    }

    final preferenceResult = await ref.read(
      playbackPreferenceProvider(widget.anilistId).future,
    );
    if (!mounted) {
      return;
    }

    final preference = preferenceResult.fold(
      onFailure: (_) => null,
      onSuccess: (value) => value,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Debug playback preference',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preference == null
                      ? 'No persisted preferred player is stored for this anime.'
                      : _debugPreferenceSummary(preference),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: preference != null,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Clear persisted preferred player'),
                  subtitle: const Text(
                    'Removes the saved source/server/resolver preference for this anime.',
                  ),
                  onTap: preference == null
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          final result = await ref
                              .read(clearPlaybackPreferenceUseCaseProvider)
                              .call(widget.anilistId);
                          if (!mounted) {
                            return;
                          }

                          result.fold(
                            onFailure: (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to clear preferred player: ${error.message}',
                                  ),
                                ),
                              );
                            },
                            onSuccess: (_) {
                              ref.invalidate(
                                playbackPreferenceProvider(widget.anilistId),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Persisted preferred player cleared.',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(widget.anilistId),
    );
    final latestProgressState = ref.watch(
      latestEpisodeProgressProvider(widget.anilistId),
    );

    final content = Scaffold(
      body: detailState.when(
        loading: () => LoadingStateView(label: context.l10n.animeDetailLoading),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: () => ref.invalidate(animeDetailProvider(widget.anilistId)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () =>
                ref.invalidate(animeDetailProvider(widget.anilistId)),
          ),
          onSuccess: (detail) => _AnimeDetailBody(
            detail: detail,
            availabilityState: availabilityState,
            latestProgressState: latestProgressState,
          ),
        ),
      ),
    );

    if (!kDebugMode) {
      return content;
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD):
            _showDebugPlaybackPreferenceTools,
      },
      child: Focus(autofocus: true, child: content),
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
              _PlaybackSummaryCard(availabilityState: availabilityState),
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
              _EpisodeDetailSection(
                detail: detail,
                availabilityState: availabilityState,
                latestProgressState: latestProgressState,
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
  const _PlaybackSummaryCard({required this.availabilityState});

  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;

  @override
  Widget build(BuildContext context) {
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
          Text(
            context.l10n.detailPlaybackHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EpisodeDetailSection extends ConsumerStatefulWidget {
  const _EpisodeDetailSection({
    required this.detail,
    required this.availabilityState,
    required this.latestProgressState,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final AsyncValue<Result<EpisodeProgress?, KumoriyaError>> latestProgressState;

  @override
  ConsumerState<_EpisodeDetailSection> createState() =>
      _EpisodeDetailSectionState();
}

class _EpisodeDetailSectionState extends ConsumerState<_EpisodeDetailSection> {
  static const int _collapsedEpisodeCount = 18;

  bool _isLaunching = false;
  bool _showAllEpisodes = false;

  @override
  Widget build(BuildContext context) {
    final latestProgress = widget.latestProgressState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (progress) => progress,
      ),
      orElse: () => null,
    );
    final progressListState = ref.watch(
      animeEpisodeProgressListProvider(widget.detail.anime.anilistId),
    );
    final preferenceState = ref.watch(
      playbackPreferenceProvider(widget.detail.anime.anilistId),
    );
    final progressList =
        _extractSuccessValue<List<EpisodeProgress>>(progressListState) ??
        const <EpisodeProgress>[];
    final preference = _extractSuccessValue<PlaybackPreference?>(
      preferenceState,
    );
    final summary = _extractSuccessValue<SourceAvailabilitySummary>(
      widget.availabilityState,
    );
    final rows = _buildDetailEpisodeRows(
      animeEpisodes: widget.detail.episodes,
      availabilitySummary: summary,
      progressList: progressList,
      focusedEpisodeNumber: latestProgress?.episodeNumber,
      fallbackTitleBuilder: (episodeNumber) => context.l10n
          .continueWatchingEpisode(episodeNumber.toInt().toString()),
      upcomingLabel: context.l10n.episodeStatusUpcoming,
      readyLabel: context.l10n.episodePlayNowLabel,
    );
    final visibleRows =
        _showAllEpisodes || rows.length <= _collapsedEpisodeCount
        ? rows
        : rows.take(_collapsedEpisodeCount).toList(growable: false);
    final hiddenEpisodeCount = rows.length - visibleRows.length;

    return Container(
      key: const Key('anime-detail-episodes-section'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.episodePreviewTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            latestProgress != null
                ? context.l10n.detailContinueEpisode(
                    latestProgress.episodeNumber.toInt().toString(),
                  )
                : rows.isEmpty
                ? '${widget.detail.episodes.length} ${context.l10n.episodesWord}'
                : context.l10n.detailContinueEpisode(
                    rows.first.number.toInt().toString(),
                  ),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            rows.isEmpty
                ? context.l10n.episodeListEmpty
                : '${rows.length} ${context.l10n.episodesWord}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (summary?.playableSources.isEmpty ?? true)
            _DetailInfoBanner(message: context.l10n.detailPlaybackNotReady)
          else
            _DetailInfoBanner(
              message: preference == null
                  ? context.l10n.episodeListUsingPreference
                  : context.l10n.episodeListUsingRememberedSource(
                      preference.preferredSourcePluginId ?? '',
                      preference.preferredServerName ?? '',
                    ),
              badges: summary!.playableSources
                  .map(
                    (source) => SourceBadge(
                      name: source.manifest.displayName,
                      iconUrl: _sourceIconUrl(source.manifest),
                      audioKinds: source.availableAudioKinds,
                      compact: true,
                      highlighted:
                          summary.recommended?.manifest.id ==
                          source.manifest.id,
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              context.l10n.episodeListEmpty,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...<Widget>[
            ...visibleRows.map(
              (row) => _DetailEpisodeCard(
                row: row,
                onTap:
                    row.playableSources.isEmpty ||
                        summary == null ||
                        _isLaunching
                    ? null
                    : () => _handleEpisodeTap(row, summary),
              ),
            ),
            if (hiddenEpisodeCount > 0) ...<Widget>[
              const SizedBox(height: 6),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showAllEpisodes = true);
                  },
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(
                    '+$hiddenEpisodeCount ${context.l10n.episodesWord}',
                  ),
                ),
              ),
            ] else if (_showAllEpisodes &&
                rows.length > _collapsedEpisodeCount) ...<Widget>[
              const SizedBox(height: 6),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showAllEpisodes = false);
                  },
                  icon: const Icon(Icons.expand_less_rounded),
                  label: Text(context.l10n.episodePreviewTitle),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _handleEpisodeTap(
    _DetailEpisodeRowData row,
    SourceAvailabilitySummary summary,
  ) async {
    setState(() => _isLaunching = true);
    showBlockingLoader(context, context.l10n.playbackPreparing);
    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: widget.detail.anime.anilistId,
          episodeNumber: row.number,
          availabilitySummary: summary,
        );
    if (!mounted) {
      return;
    }
    hideBlockingLoader(context);
    setState(() => _isLaunching = false);
    await handlePlaybackDecision(
      context: context,
      ref: ref,
      anilistId: widget.detail.anime.anilistId,
      animeTitle: widget.detail.anime.title.romaji,
      decision: decision,
    );
  }
}

class _DetailEpisodeCard extends StatelessWidget {
  const _DetailEpisodeCard({required this.row, this.onTap});

  final _DetailEpisodeRowData row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: Key('anime-detail-episode-${row.number.toInt()}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: row.isCurrentEpisode
          ? colorScheme.primaryContainer.withValues(alpha: 0.6)
          : colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: row.playableSources.isEmpty
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.primaryContainer,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      row.number.toInt().toString(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                row.displayTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (row.isCurrentEpisode)
                              _DetailContextChip(
                                label: context.l10n.detailContinueBadge,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row.secondaryText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (row.playableSources.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: row.playableSources
                      .map(
                        (source) => SourceBadge(
                          name: source.manifest.displayName,
                          iconUrl: _sourceIconUrl(source.manifest),
                          audioKinds: source.availableAudioKinds,
                          compact: true,
                        ),
                      )
                      .toList(growable: false),
                )
              else
                Text(
                  context.l10n.episodePlaybackUnavailable,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (row.progressFraction != null) ...<Widget>[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: row.progressFraction,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    row.playableSources.isEmpty
                        ? context.l10n.episodeLockedLabel
                        : context.l10n.episodePlayNowLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailInfoBanner extends StatelessWidget {
  const _DetailInfoBanner({
    required this.message,
    this.badges = const <Widget>[],
  });

  final String message;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (badges.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: badges),
          ],
        ],
      ),
    );
  }
}

class _DetailContextChip extends StatelessWidget {
  const _DetailContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

T? _extractSuccessValue<T>(AsyncValue asyncValue) {
  return asyncValue.maybeWhen(
    data: (result) {
      try {
        final dynamic typedResult = result;
        return typedResult.value as T?;
      } catch (_) {
        return null;
      }
    },
    orElse: () => null,
  );
}

List<_DetailEpisodeRowData> _buildDetailEpisodeRows({
  required List<AnimeEpisode> animeEpisodes,
  required SourceAvailabilitySummary? availabilitySummary,
  required List<EpisodeProgress> progressList,
  required double? focusedEpisodeNumber,
  required String Function(double episodeNumber) fallbackTitleBuilder,
  required String upcomingLabel,
  required String readyLabel,
}) {
  final metadataByNumber = <double, AnimeEpisode>{
    for (final episode in animeEpisodes) episode.number: episode,
  };
  final progressByNumber = <double, EpisodeProgress>{
    for (final progress in progressList) progress.episodeNumber: progress,
  };
  final sourcesByEpisode = <double, List<SourceAvailability>>{};

  for (final source
      in availabilitySummary?.playableSources ?? const <SourceAvailability>[]) {
    for (final episode in source.episodes) {
      sourcesByEpisode
          .putIfAbsent(episode.number, () => <SourceAvailability>[])
          .add(source);
    }
  }

  final allNumbers = <double>{
    ...metadataByNumber.keys,
    ...sourcesByEpisode.keys,
  }.toList(growable: false)..sort();

  EpisodeProgress? latestProgress;
  for (final progress in progressList) {
    if (latestProgress == null ||
        progress.updatedAt.isAfter(latestProgress.updatedAt)) {
      latestProgress = progress;
    }
  }

  return allNumbers
      .map((number) {
        final metadata = metadataByNumber[number];
        final sources =
            sourcesByEpisode[number] ?? const <SourceAvailability>[];
        final progress = progressByNumber[number];

        return _DetailEpisodeRowData(
          number: number,
          displayTitle: metadata?.title.trim().isNotEmpty == true
              ? metadata!.title
              : fallbackTitleBuilder(number),
          secondaryText: metadata?.isAired == false
              ? upcomingLabel
              : metadata?.airDate != null
              ? _formatEpisodeDate(metadata!.airDate!)
              : readyLabel,
          playableSources: sources,
          progressFraction: _progressFraction(progress),
          isCurrentEpisode:
              latestProgress?.episodeNumber == number ||
              focusedEpisodeNumber == number,
        );
      })
      .toList(growable: false);
}

double? _progressFraction(EpisodeProgress? progress) {
  if (progress == null || progress.totalDuration == null) {
    return null;
  }
  if (progress.totalDuration!.inMilliseconds == 0) {
    return null;
  }

  final value =
      progress.position.inMilliseconds / progress.totalDuration!.inMilliseconds;
  return value.clamp(0.0, 1.0);
}

String _formatEpisodeDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

final class _DetailEpisodeRowData {
  const _DetailEpisodeRowData({
    required this.number,
    required this.displayTitle,
    required this.secondaryText,
    required this.playableSources,
    required this.progressFraction,
    required this.isCurrentEpisode,
  });

  final double number;
  final String displayTitle;
  final String secondaryText;
  final List<SourceAvailability> playableSources;
  final double? progressFraction;
  final bool isCurrentEpisode;
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

String _debugPreferenceSummary(PlaybackPreference preference) {
  final parts = <String>[
    if (preference.preferredSourcePluginId != null)
      'Source: ${preference.preferredSourcePluginId}',
    if (preference.preferredServerName != null)
      'Server: ${preference.preferredServerName}',
    if (preference.preferredResolverPluginId != null)
      'Resolver: ${preference.preferredResolverPluginId}',
    if (preference.preferredAudioPreference != null)
      'Audio: ${preference.preferredAudioPreference!.name}',
  ];

  if (parts.isEmpty) {
    return 'A playback preference row exists, but it has no persisted source, server, resolver, or audio signal.';
  }

  return parts.join('\n');
}
