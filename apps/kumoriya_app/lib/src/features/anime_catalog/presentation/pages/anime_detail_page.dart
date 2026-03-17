import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/source_availability.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../../../downloads/presentation/download_providers.dart';
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
          expandedHeight: 420,
          pinned: true,
          stretch: true,
          backgroundColor: KumoriyaColors.background,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: _DetailHero(detail: detail),
            stretchModes: const <StretchMode>[
              StretchMode.zoomBackground,
              StretchMode.fadeTitle,
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              _TitleBlock(detail: detail),
              const SizedBox(height: 12),
              _LibraryActions(anilistId: detail.anime.anilistId),
              const SizedBox(height: 18),
              _PlaybackSummaryCard(availabilityState: availabilityState),
              if (detail.synopsis != null &&
                  detail.synopsis!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                const Text(
                  'Synopsis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KumoriyaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.synopsis!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: KumoriyaColors.textSecondary,
                  ),
                ),
              ],
              if (detail.genres.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detail.genres
                      .map(
                        (genre) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: KumoriyaColors.surface,
                            borderRadius: BorderRadius.circular(
                              KumoriyaRadius.full,
                            ),
                            border: Border.all(
                              color: KumoriyaColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: KumoriyaColors.textSecondary,
                            ),
                          ),
                        ),
                      )
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
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: KumoriyaColors.textDisabled,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AnimeDetailPage(
                              anilistId: relation.anime.anilistId,
                            ),
                          ),
                        ),
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: KumoriyaColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.detailDiscoverPrompt,
          style: const TextStyle(fontSize: 13, color: KumoriyaColors.textMuted),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(
          color: KumoriyaColors.primary.withValues(alpha: 0.20),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: KumoriyaColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          availabilityState.when(
            loading: () => const Text(
              'Checking sources…',
              style: TextStyle(color: KumoriyaColors.textMuted, fontSize: 13),
            ),
            error: (_, _) => Text(
              context.l10n.detailPlaybackNotReady,
              style: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 13,
              ),
            ),
            data: (result) => result.fold(
              onFailure: (_) => Text(
                context.l10n.detailPlaybackNotReady,
                style: const TextStyle(
                  color: KumoriyaColors.textMuted,
                  fontSize: 13,
                ),
              ),
              onSuccess: (summary) {
                final playable = summary.playableSources;
                if (playable.isEmpty) {
                  return Text(
                    context.l10n.detailPlaybackNotReady,
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 13,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.detailPlaybackSources(playable.length),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
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
          const SizedBox(height: 12),
          Text(
            context.l10n.detailPlaybackHint,
            style: const TextStyle(
              fontSize: 12,
              color: KumoriyaColors.textDisabled,
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.episodePreviewTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: KumoriyaColors.textPrimary,
                  ),
                ),
              ),
              if (rows.any(
                (r) => r.sourceEpisodes.keys.any(
                  (id) => id != _excludedDetailDownloadSource,
                ),
              ))
                _DetailDownloadAllButton(
                  rows: rows,
                  anilistId: widget.detail.anime.anilistId,
                ),
              const SizedBox(width: 8),
              Text(
                rows.isEmpty
                    ? context.l10n.episodeListEmpty
                    : '${rows.length} ${context.l10n.episodesWord}',
                style: const TextStyle(
                  fontSize: 12,
                  color: KumoriyaColors.textDisabled,
                ),
              ),
            ],
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
                anilistId: widget.detail.anime.anilistId,
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

class _DetailEpisodeCard extends ConsumerStatefulWidget {
  const _DetailEpisodeCard({
    required this.row,
    required this.anilistId,
    this.onTap,
  });

  final _DetailEpisodeRowData row;
  final int anilistId;
  final VoidCallback? onTap;

  @override
  ConsumerState<_DetailEpisodeCard> createState() => _DetailEpisodeCardState();
}

class _DetailEpisodeCardState extends ConsumerState<_DetailEpisodeCard> {
  bool _isEnqueuing = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isPlayable = row.playableSources.isNotEmpty;

    // Check for existing download task.
    final dlTasksState = ref.watch(
      downloadTasksByAnimeProvider(widget.anilistId),
    );
    final dlTask = dlTasksState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (tasks) {
          for (final t in tasks) {
            if ((t.episodeNumber - row.number).abs() < 0.001) return t;
          }
          return null;
        },
      ),
      orElse: () => null,
    );

    return GestureDetector(
      key: Key('anime-detail-episode-${row.number.toInt()}'),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: row.isCurrentEpisode
              ? KumoriyaColors.primary.withValues(alpha: 0.10)
              : KumoriyaColors.background,
          borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
          border: Border.all(
            color: row.isCurrentEpisode
                ? KumoriyaColors.primary.withValues(alpha: 0.30)
                : KumoriyaColors.borderSubtle,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: row.isCurrentEpisode
                    ? KumoriyaColors.primary
                    : isPlayable
                    ? KumoriyaColors.surface
                    : KumoriyaColors.borderSubtle,
                borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                border: row.isCurrentEpisode
                    ? null
                    : Border.all(color: KumoriyaColors.borderSubtle),
                boxShadow: row.isCurrentEpisode
                    ? <BoxShadow>[
                        BoxShadow(
                          color: KumoriyaColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                row.number.toInt().toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: row.isCurrentEpisode
                      ? Colors.white
                      : isPlayable
                      ? KumoriyaColors.textMuted
                      : KumoriyaColors.textDisabled,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: row.isCurrentEpisode
                                ? KumoriyaColors.textPrimary
                                : KumoriyaColors.textSecondary,
                          ),
                        ),
                      ),
                      if (row.isCurrentEpisode)
                        _DetailContextChip(
                          label: context.l10n.detailContinueBadge,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      if (row.playableSources.isNotEmpty) ...<Widget>[
                        ...row.playableSources
                            .take(2)
                            .map(
                              (source) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: SourceBadge(
                                  name: source.manifest.displayName,
                                  iconUrl: _sourceIconUrl(source.manifest),
                                  audioKinds: source.availableAudioKinds,
                                  compact: true,
                                ),
                              ),
                            ),
                      ],
                      Flexible(
                        child: Text(
                          row.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: KumoriyaColors.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (row.progressFraction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                      child: LinearProgressIndicator(
                        value: row.progressFraction,
                        minHeight: 3,
                        backgroundColor: KumoriyaColors.borderSubtle,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          KumoriyaColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildDownloadWidget(context, dlTask),
            if (isPlayable) ...<Widget>[
              const SizedBox(width: 4),
              Icon(
                Icons.play_circle_outline_rounded,
                size: 26,
                color: row.isCurrentEpisode
                    ? KumoriyaColors.primary
                    : KumoriyaColors.textDisabled,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadWidget(BuildContext context, DownloadTask? dlTask) {
    if (_isEnqueuing) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (dlTask != null) {
      return _DetailDownloadStatusIcon(task: dlTask);
    }

    // Only show download if there's a downloadable (non-excluded) source.
    final hasDownloadableSource = widget.row.sourceEpisodes.keys.any(
      (id) => id != _excludedDetailDownloadSource,
    );
    if (!hasDownloadableSource) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _handleDownload(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.download_rounded,
          size: 22,
          color: KumoriyaColors.textDisabled,
        ),
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isEnqueuing) return;

    // Get downloadable sources (excluding Anime Nexus).
    final entries = widget.row.sourceEpisodes.entries
        .where((e) => e.key != _excludedDetailDownloadSource)
        .toList();
    if (entries.isEmpty) return;

    // Use the first available source plugin.
    final entry = entries.first;

    setState(() => _isEnqueuing = true);

    try {
      final sourcePlugin = ref.read(sourcePluginByIdProvider(entry.key));
      final registry = ref.read(resolverRegistryProvider);

      final linksResult = await GetSourceEpisodeServerLinksUseCase(
        sourcePlugin: sourcePlugin,
        registry: registry,
      ).call(entry.value);

      final links = linksResult.fold(
        onSuccess: (l) => l,
        onFailure: (_) => <SourceServerLink>[],
      );

      if (!mounted) return;

      if (links.isEmpty) {
        setState(() => _isEnqueuing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.downloadFailed)));
        return;
      }

      // If multiple servers, let user choose.
      SourceServerLink chosenLink;
      if (links.length > 1) {
        setState(() => _isEnqueuing = false);
        final picked = await _showServerPicker(context, links);
        if (picked == null || !mounted) return;
        chosenLink = picked;
        setState(() => _isEnqueuing = true);
      } else {
        chosenLink = links.first;
      }

      final enqueueUseCase = ref.read(enqueueDownloadUseCaseProvider);
      final result = await enqueueUseCase.call(
        anilistId: widget.anilistId,
        episodeNumber: entry.value.number,
        serverLink: chosenLink,
        sourcePluginId: entry.key,
      );

      if (!mounted) return;
      setState(() => _isEnqueuing = false);

      final success = result.fold(
        onSuccess: (_) => true,
        onFailure: (_) => false,
      );

      final messenger = ScaffoldMessenger.of(context);
      if (success) {
        ref.invalidate(downloadTasksByAnimeProvider(widget.anilistId));
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.downloadQueued)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.downloadFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isEnqueuing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.downloadFailed)));
      }
    }
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KumoriyaColors.background,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: KumoriyaColors.textDisabled,
            ),
          ),
          if (badges.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: badges),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        color: KumoriyaColors.primary.withValues(alpha: 0.18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: KumoriyaColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LibraryActions extends ConsumerWidget {
  const _LibraryActions({required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavAsync = ref.watch(isFavoriteProvider(anilistId));
    final isSubAsync = ref.watch(isSubscribedProvider(anilistId));
    final isAutoDownloadAsync = ref.watch(isAutoDownloadProvider(anilistId));

    final isFav = isFavAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final isSub = isSubAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final isAutoDl = isAutoDownloadAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    return Row(
      children: <Widget>[
        _ActionButton(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: isFav ? context.l10n.removeFavorite : context.l10n.addFavorite,
          active: isFav,
          onTap: () async {
            await ref
                .read(libraryStoreProvider)
                .setFavorite(anilistId, isFavorite: !isFav);
            ref.invalidate(favoriteAnimeIdsProvider);
          },
        ),
        const SizedBox(width: 10),
        _ActionButton(
          icon: isSub
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          label: isSub ? context.l10n.unsubscribe : context.l10n.subscribe,
          active: isSub,
          onTap: isFav
              ? () async {
                  // Request POST_NOTIFICATIONS permission on Android 13+
                  // before toggling subscription on.
                  if (!isSub && Platform.isAndroid) {
                    final status = await Permission.notification.request();
                    if (!status.isGranted) return;
                  }
                  await ref
                      .read(libraryStoreProvider)
                      .setSubscription(anilistId, notify: !isSub);
                  ref.invalidate(subscribedAnimeIdsProvider);
                }
              : null,
        ),
        const SizedBox(width: 10),
        _ActionButton(
          icon: isAutoDl ? Icons.download_done_rounded : Icons.download_rounded,
          label: context.l10n.autoDownload,
          active: isAutoDl,
          onTap: isSub
              ? () async {
                  await ref
                      .read(libraryStoreProvider)
                      .setAutoDownload(anilistId, autoDownload: !isAutoDl);
                  ref.invalidate(autoDownloadAnimeIdsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isAutoDl
                              ? context.l10n.autoDownloadDisabled
                              : context.l10n.autoDownloadEnabled,
                        ),
                      ),
                    );
                  }
                }
              : null,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = disabled
        ? KumoriyaColors.textDisabled
        : active
        ? KumoriyaColors.primary
        : KumoriyaColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? KumoriyaColors.primary.withValues(alpha: 0.12)
              : KumoriyaColors.surface,
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
          border: Border.all(
            color: active
                ? KumoriyaColors.primary.withValues(alpha: 0.35)
                : KumoriyaColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
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
  final sourceEpisodesByNumber = <double, Map<String, SourceEpisode>>{};

  for (final source
      in availabilitySummary?.playableSources ?? const <SourceAvailability>[]) {
    for (final episode in source.episodes) {
      sourcesByEpisode
          .putIfAbsent(episode.number, () => <SourceAvailability>[])
          .add(source);
      sourceEpisodesByNumber.putIfAbsent(
        episode.number,
        () => <String, SourceEpisode>{},
      )[source.manifest.id] = episode;
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
          sourceEpisodes:
              sourceEpisodesByNumber[number] ?? const <String, SourceEpisode>{},
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
    this.sourceEpisodes = const <String, SourceEpisode>{},
  });

  final double number;
  final String displayTitle;
  final String secondaryText;
  final List<SourceAvailability> playableSources;
  final double? progressFraction;
  final bool isCurrentEpisode;

  /// Map of source plugin ID → SourceEpisode for download support.
  final Map<String, SourceEpisode> sourceEpisodes;
}

class _HeroMetaPill extends StatelessWidget {
  const _HeroMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        color: Colors.black.withValues(alpha: 0.40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

String? _sourceIconUrl(PluginManifest manifest) {
  if (manifest.iconUrl != null && manifest.iconUrl!.trim().isNotEmpty) {
    return manifest.iconUrl;
  }
  return null;
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

// ─── Download helpers for detail page ────────────────────────────────────────

/// Source plugin excluded from downloads.
const _excludedDetailDownloadSource = 'kumoriya.source.anime_nexus';

/// Resolves server links for [sourceEpisode] via [sourcePluginId], picks the
/// best stream, and enqueues a download task. Returns true on success.
Future<bool> _enqueueDetailEpisodeDownload({
  required WidgetRef ref,
  required int anilistId,
  required String sourcePluginId,
  required SourceEpisode sourceEpisode,
}) async {
  try {
    final sourcePlugin = ref.read(sourcePluginByIdProvider(sourcePluginId));
    final registry = ref.read(resolverRegistryProvider);

    final linksResult = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: sourcePlugin,
      registry: registry,
    ).call(sourceEpisode);

    final links = linksResult.fold(
      onSuccess: (l) => l,
      onFailure: (_) => <SourceServerLink>[],
    );
    if (links.isEmpty) return false;

    final enqueueUseCase = ref.read(enqueueDownloadUseCaseProvider);
    final result = await enqueueUseCase.call(
      anilistId: anilistId,
      episodeNumber: sourceEpisode.number,
      serverLink: links.first,
      sourcePluginId: sourcePluginId,
    );

    return result.fold(onSuccess: (_) => true, onFailure: (_) => false);
  } catch (_) {
    return false;
  }
}

class _DetailDownloadStatusIcon extends ConsumerWidget {
  const _DetailDownloadStatusIcon({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to live progress events.
    final progressAsync = ref.watch(downloadProgressStreamProvider);
    final liveEvent = progressAsync.maybeWhen(
      data: (event) => event.taskId == task.id ? event : null,
      orElse: () => null,
    );

    final (icon, color) = switch (task.status) {
      DownloadStatus.pending => (
        Icons.hourglass_top_rounded,
        KumoriyaColors.textDisabled,
      ),
      DownloadStatus.downloading => (
        Icons.downloading_rounded,
        KumoriyaColors.primary,
      ),
      DownloadStatus.paused => (
        Icons.pause_circle_outline_rounded,
        Colors.orange,
      ),
      DownloadStatus.completed => (Icons.download_done_rounded, Colors.green),
      DownloadStatus.failed => (Icons.error_outline_rounded, Colors.red),
    };

    // Show circular progress around the icon when downloading.
    if (task.status == DownloadStatus.downloading) {
      final fraction = liveEvent?.fraction ?? _storedFraction(task);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2.5,
                backgroundColor: KumoriyaColors.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, size: 22, color: color),
    );
  }

  double? _storedFraction(DownloadTask task) {
    if (task.totalBytes == null ||
        task.totalBytes == 0 ||
        task.downloadedBytes == null) {
      return null;
    }
    return (task.downloadedBytes! / task.totalBytes!).clamp(0.0, 1.0);
  }
}

class _DetailDownloadAllButton extends ConsumerStatefulWidget {
  const _DetailDownloadAllButton({required this.rows, required this.anilistId});

  final List<_DetailEpisodeRowData> rows;
  final int anilistId;

  @override
  ConsumerState<_DetailDownloadAllButton> createState() =>
      _DetailDownloadAllButtonState();
}

class _DetailDownloadAllButtonState
    extends ConsumerState<_DetailDownloadAllButton> {
  bool _isEnqueuing = false;

  @override
  Widget build(BuildContext context) {
    return _isEnqueuing
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : GestureDetector(
            onTap: () => _downloadAll(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: KumoriyaColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.downloadAll,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KumoriyaColors.primary,
                  ),
                ),
              ],
            ),
          );
  }

  Future<void> _downloadAll(BuildContext context) async {
    if (_isEnqueuing) return;
    setState(() => _isEnqueuing = true);

    final downloadable = widget.rows
        .where((r) => r.sourceEpisodes.isNotEmpty)
        .toList();
    var queued = 0;

    for (final row in downloadable) {
      final entry = row.sourceEpisodes.entries
          .where((e) => e.key != _excludedDetailDownloadSource)
          .firstOrNull;
      if (entry == null) continue;

      final result = await _enqueueDetailEpisodeDownload(
        ref: ref,
        anilistId: widget.anilistId,
        sourcePluginId: entry.key,
        sourceEpisode: entry.value,
      );
      if (result) queued++;
    }

    if (!mounted) return;
    setState(() => _isEnqueuing = false);

    if (queued > 0) {
      ref.invalidate(downloadTasksByAnimeProvider(widget.anilistId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadAllQueued)));
    }
  }
}

// ─── Server picker dialog ────────────────────────────────────────────────────

Future<SourceServerLink?> _showServerPicker(
  BuildContext context,
  List<SourceServerLink> links,
) {
  return showModalBottomSheet<SourceServerLink>(
    context: context,
    backgroundColor: KumoriyaColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.dns_rounded,
                  size: 20,
                  color: KumoriyaColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.downloadSelectServer,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: KumoriyaColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ...links.map(
            (link) => ListTile(
              leading: const Icon(Icons.cloud_download_rounded, size: 20),
              title: Text(
                link.serverName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: link.detectedHost != null
                  ? Text(
                      link.detectedHost!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: KumoriyaColors.textDisabled,
                      ),
                    )
                  : null,
              onTap: () => Navigator.of(ctx).pop(link),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
