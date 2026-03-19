import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
import '../../../../shared/widgets/episode_row.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/meta_chip.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/translated_dynamic_text.dart';
import '../../application/models/source_availability.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../../application/services/mal_metadata_bridge_service.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import 'episode_list_page.dart';
import '../support/episode_display_title.dart';
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
          backgroundColor: KumoriyaColors.background,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: _DetailHero(detail: detail),
            stretchModes: const <StretchMode>[StretchMode.fadeTitle],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              _TitleBlock(detail: detail),
              const SizedBox(height: 14),
              _PlayResumeCta(
                anilistId: detail.anime.anilistId,
                animeTitle: detail.anime.title.romaji,
                availabilityState: availabilityState,
                latestProgressState: latestProgressState,
              ),
              const SizedBox(height: 12),
              _LibraryActions(anilistId: detail.anime.anilistId),
              if (detail.synopsis != null &&
                  detail.synopsis!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _CollapsibleSynopsis(synopsis: detail.synopsis!),
              ],
              if (detail.genres.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detail.genres
                      .map(
                        (genre) =>
                            MetaChip(label: displayGenreLabel(context, genre)),
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
                      (relation) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            KumoriyaRadius.xl,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AnimeDetailPage(
                                anilistId: relation.anime.anilistId,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: KumoriyaColors.surface.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(
                                KumoriyaRadius.xl,
                              ),
                              border: Border.all(
                                color: KumoriyaColors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        relation.anime.title.romaji,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: KumoriyaColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: <Widget>[
                                          _RelationTypeBadge(
                                            type: relation.type,
                                          ),
                                          MetaChip(
                                            label: _formatLabel(
                                              context,
                                              relation.anime.format,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: KumoriyaColors.textDisabled,
                                ),
                              ],
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

class _PlayResumeCta extends ConsumerStatefulWidget {
  const _PlayResumeCta({
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
  ConsumerState<_PlayResumeCta> createState() => _PlayResumeCtaState();
}

class _PlayResumeCtaState extends ConsumerState<_PlayResumeCta> {
  bool _isLaunching = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.availabilityState.maybeWhen(
      data: (result) =>
          result.fold(onFailure: (_) => null, onSuccess: (s) => s),
      orElse: () => null,
    );

    final latestProgress = widget.latestProgressState.maybeWhen(
      data: (result) =>
          result.fold(onFailure: (_) => null, onSuccess: (p) => p),
      orElse: () => null,
    );

    final isAvailable = summary != null && summary.playableSources.isNotEmpty;
    final hasProgress = latestProgress != null;
    final isCheckingSources = widget.availabilityState.isLoading;
    final checkingLabel = summary == null
        ? context.l10n.detailCheckingSources
        : '${context.l10n.detailCheckingSources} (${summary.playableSources.length})';

    final label = isCheckingSources
        ? checkingLabel
        : hasProgress
        ? context.l10n.detailResumeEpisode(latestProgress.episodeNumber.toInt())
        : context.l10n.detailPlay;
    const icon = Icons.play_arrow_rounded;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: isAvailable && !_isLaunching && !isCheckingSources
            // ignore: unnecessary_non_null_assertion
            ? () => _handleTap(summary!, latestProgress)
            : null,
        icon: _isLaunching || isCheckingSources
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: KumoriyaColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KumoriyaColors.surface,
          disabledForegroundColor: KumoriyaColors.textDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    SourceAvailabilitySummary summary,
    EpisodeProgress? latestProgress,
  ) async {
    setState(() => _isLaunching = true);
    showBlockingLoader(context, context.l10n.playbackPreparing);

    final episodeNumber = latestProgress?.episodeNumber ?? 1;

    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: widget.anilistId,
          episodeNumber: episodeNumber,
          availabilitySummary: summary,
        );
    if (!mounted) return;
    hideBlockingLoader(context);
    setState(() => _isLaunching = false);
    await handlePlaybackDecision(
      context: context,
      ref: ref,
      anilistId: widget.anilistId,
      animeTitle: widget.animeTitle,
      decision: decision,
    );
  }
}

class _CollapsibleSynopsis extends StatefulWidget {
  const _CollapsibleSynopsis({required this.synopsis});
  final String synopsis;
  @override
  State<_CollapsibleSynopsis> createState() => _CollapsibleSynopsisState();
}

class _CollapsibleSynopsisState extends State<_CollapsibleSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: <Widget>[
              Text(
                context.l10n.detailSynopsisTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KumoriyaColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: KumoriyaColors.textMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: TranslatedDynamicText(
            widget.synopsis,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: KumoriyaColors.textSecondary,
            ),
          ),
          secondChild: TranslatedDynamicText(
            widget.synopsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: KumoriyaColors.textSecondary,
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
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
        GestureDetector(
          onTap: () => _showArtworkPreview(
            context,
            detail.bannerImageUrl ?? detail.anime.coverImageUrl,
            detail.anime.title.romaji,
          ),
          child: KumoriyaCachedImage(
            url: detail.bannerImageUrl ?? detail.anime.coverImageUrl,
            bucket: KumoriyaImageCacheBucket.artwork,
            fit: BoxFit.cover,
          ),
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
                GestureDetector(
                  onTap: () => _showArtworkPreview(
                    context,
                    detail.anime.coverImageUrl,
                    detail.anime.title.romaji,
                  ),
                  child: KumoriyaCachedImage(
                    url: detail.anime.coverImageUrl,
                    bucket: KumoriyaImageCacheBucket.artwork,
                    width: 120,
                    height: 170,
                    fit: defaultTargetPlatform == TargetPlatform.android
                        ? BoxFit.contain
                        : BoxFit.cover,
                    alignment: Alignment.topCenter,
                    borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
                  ),
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
                            label: _formatLabel(context, detail.anime.format),
                          ),
                          _HeroMetaPill(
                            label: _statusLabel(context, detail.anime.status),
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
                          if (detail.anime.averageScore != null)
                            _HeroMetaPill(
                              label: '★ ${detail.anime.averageScore}/100',
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

Future<void> _showArtworkPreview(
  BuildContext context,
  String? imageUrl,
  String title,
) async {
  if (imageUrl == null || imageUrl.trim().isEmpty) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: <Widget>[
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: KumoriyaCachedImage(
                  url: imageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: title,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
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
    final hasDistinctSecondaryTitle =
        secondaryTitle.trim() != detail.anime.title.romaji.trim();

    if (!hasDistinctSecondaryTitle) {
      return const SizedBox.shrink();
    }

    return Text(
      secondaryTitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: KumoriyaColors.textSecondary,
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
  static const int _collapsedEpisodeCount = 12;
  static const int _longSeriesThreshold = 80;

  bool _isLaunching = false;
  bool _showAllEpisodes = false;
  bool _didAniSkipPrefetch = false;

  void _scheduleAniSkipPrefetch(List<AnimeEpisode> episodes) {
    if (_didAniSkipPrefetch || episodes.isEmpty) {
      return;
    }
    final episodeNumbers = episodes
        .where((episode) => episode.isAired)
        .map((episode) => episode.number.toInt())
        .where((episodeNumber) => episodeNumber > 0)
        .toSet()
        .toList(growable: false);
    if (episodeNumbers.isEmpty) {
      return;
    }
    _didAniSkipPrefetch = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(malMetadataBridgeProvider)
            .prefetchAniSkipForAnime(
              anilistId: widget.detail.anime.anilistId,
              episodeNumbers: episodeNumbers,
            ),
      );
    });
  }

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
    final progressList =
        _extractSuccessValue<List<EpisodeProgress>>(progressListState) ??
        const <EpisodeProgress>[];
    final summary = _extractSuccessValue<SourceAvailabilitySummary>(
      widget.availabilityState,
    );
    final malEpisodeMetadata = ref
        .watch(malEpisodeMetadataProvider(widget.detail.anime.anilistId))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <int, MalEpisodeMetadata>{},
        );
    final totalEpisodeEstimate = math.max(
      widget.detail.episodes.length,
      summary?.playableSources.fold<int>(
            0,
            (maxCount, source) => math.max(maxCount, source.episodes.length),
          ) ??
          0,
    );
    _scheduleAniSkipPrefetch(widget.detail.episodes);
    final isLongSeries = totalEpisodeEstimate >= _longSeriesThreshold;
    final rowsResult = _buildDetailEpisodeRows(
      animeEpisodes: widget.detail.episodes,
      availabilitySummary: summary,
      progressList: progressList,
      malEpisodeMetadata: malEpisodeMetadata,
      focusedEpisodeNumber: latestProgress?.episodeNumber,
      animeTitle: widget.detail.anime.title.romaji,
      fallbackTitleBuilder: (episodeNumber) => context.l10n
          .continueWatchingEpisode(episodeNumber.toInt().toString()),
      upcomingLabel: context.l10n.episodeStatusUpcoming,
      readyLabel: context.l10n.episodePlayNowLabel,
      previewLimit: !_showAllEpisodes && isLongSeries
          ? _collapsedEpisodeCount
          : null,
    );
    final rows = rowsResult.rows;
    final visibleRows =
        _showAllEpisodes || rows.length <= _collapsedEpisodeCount
        ? rows
        : rows.take(_collapsedEpisodeCount).toList(growable: false);
    final hiddenEpisodeCount = rowsResult.totalCount - visibleRows.length;
    final sourceBadges =
        summary?.playableSources
            .map(
              (source) => SourceBadge(
                name: source.manifest.displayName,
                iconUrl: _sourceIconUrl(source.manifest),
                audioKinds: source.availableAudioKinds,
                compact: true,
                highlighted:
                    summary.recommended?.manifest.id == source.manifest.id,
              ),
            )
            .toList(growable: false) ??
        const <Widget>[];
    final contentChildren = <Widget>[
      KumoriyaSectionHeader(
        title: context.l10n.episodePreviewTitle,
        onSeeAll: isLongSeries
            ? () => _openEpisodeListPage(latestProgress)
            : null,
        seeAllLabel: isLongSeries ? context.l10n.viewEpisodeList : null,
      ),
      if (widget.availabilityState.isLoading) ...<Widget>[
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              summary == null
                  ? context.l10n.detailCheckingSources
                  : '${context.l10n.detailCheckingSources} (${summary.playableSources.length})',
              style: const TextStyle(
                fontSize: 12,
                color: KumoriyaColors.textMuted,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 4),
      Text(
        rowsResult.totalCount == 0
            ? context.l10n.episodeListEmpty
            : '${rowsResult.totalCount} ${context.l10n.episodesWord}',
        style: const TextStyle(
          fontSize: 12,
          color: KumoriyaColors.textDisabled,
        ),
      ),
      if (!isLongSeries &&
          rows.any(
            (row) => row.sourceEpisodes.keys.any(
              (id) => id != _excludedDetailDownloadSource,
            ),
          )) ...<Widget>[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _DetailDownloadAllButton(
            rows: rows,
            anilistId: widget.detail.anime.anilistId,
            animeTitle: widget.detail.anime.title.romaji,
            availableSources:
                summary?.playableSources ?? const <SourceAvailability>[],
          ),
        ),
      ],
      const SizedBox(height: 14),
      if (sourceBadges.isEmpty)
        Text(
          context.l10n.detailPlaybackNotReady,
          style: const TextStyle(
            fontSize: 12,
            color: KumoriyaColors.textDisabled,
          ),
        )
      else
        Wrap(spacing: 6, runSpacing: 6, children: sourceBadges),
      const SizedBox(height: 14),
    ];

    if (rows.isEmpty) {
      contentChildren.add(
        Text(
          context.l10n.episodeListEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    } else {
      // Lift download-tasks watch here (1 watch) instead of N per card.
      final dlTasksState = ref.watch(
        downloadTasksByAnimeProvider(widget.detail.anime.anilistId),
      );
      final dlTaskMap = <double, DownloadTask>{};
      dlTasksState.whenData((result) {
        result.fold(
          onSuccess: (tasks) {
            for (final t in tasks) {
              dlTaskMap[t.episodeNumber] = t;
            }
          },
          onFailure: (_) {},
        );
      });

      contentChildren.addAll(
        visibleRows.map((row) {
          DownloadTask? dlTask;
          for (final entry in dlTaskMap.entries) {
            if ((entry.key - row.number).abs() < 0.001) {
              dlTask = entry.value;
              break;
            }
          }
          return _DetailEpisodeCard(
            row: row,
            anilistId: widget.detail.anime.anilistId,
            animeTitle: widget.detail.anime.title.romaji,
            downloadTask: dlTask,
            onTap:
                row.playableSources.isEmpty || summary == null || _isLaunching
                ? null
                : () => _handleEpisodeTap(row, summary),
          );
        }),
      );

      if (hiddenEpisodeCount > 0 && isLongSeries) {
        contentChildren.add(const SizedBox(height: 6));
      } else if (hiddenEpisodeCount > 0) {
        contentChildren.addAll(<Widget>[
          const SizedBox(height: 6),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _showAllEpisodes = true);
              },
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('+$hiddenEpisodeCount ${context.l10n.episodesWord}'),
            ),
          ),
        ]);
      } else if (!isLongSeries &&
          _showAllEpisodes &&
          rows.length > _collapsedEpisodeCount) {
        contentChildren.addAll(<Widget>[
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
        ]);
      }
    }

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
        children: contentChildren,
      ),
    );
  }

  Future<void> _handleEpisodeTap(
    _DetailEpisodeRowData row,
    SourceAvailabilitySummary summary,
  ) async {
    final playbackPreparingLabel = context.l10n.playbackPreparing;

    // Check for completed offline download first.
    final dlTasksState = ref.read(
      downloadTasksByAnimeProvider(widget.detail.anime.anilistId),
    );
    final offlineTask = dlTasksState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (tasks) {
          for (final t in tasks) {
            if ((t.episodeNumber - row.number).abs() < 0.001 &&
                t.status == DownloadStatus.completed &&
                t.filePath != null) {
              return t;
            }
          }
          return null;
        },
      ),
      orElse: () => null,
    );

    if (offlineTask != null) {
      final file = File(offlineTask.filePath!);
      if (await file.exists()) {
        if (!mounted) return;
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerPage(
              anilistId: widget.detail.anime.anilistId,
              animeTitle: widget.detail.anime.title.romaji,
              episodeNumber: row.number.toInt().toString(),
              sourcePluginId: offlineTask.sourcePluginId ?? 'offline',
              serverName: offlineTask.serverName ?? 'Downloaded',
              resolved: ResolvedServerLinkResult(
                resolverId: 'offline',
                resolverName: 'Downloaded',
                streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
              ),
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _isLaunching = true);
    showBlockingLoader(
      Navigator.of(context, rootNavigator: true).context,
      playbackPreparingLabel,
    );
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
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    hideBlockingLoader(rootNavigator.context);
    setState(() => _isLaunching = false);
    await handlePlaybackDecision(
      context: rootNavigator.context,
      ref: ref,
      anilistId: widget.detail.anime.anilistId,
      animeTitle: widget.detail.anime.title.romaji,
      decision: decision,
    );
  }

  Future<void> _openEpisodeListPage(EpisodeProgress? latestProgress) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeListPage(
          anilistId: widget.detail.anime.anilistId,
          animeTitle: widget.detail.anime.title.romaji,
          focusedEpisodeNumber: latestProgress?.episodeNumber,
        ),
      ),
    );
  }
}

class _DetailEpisodeCard extends ConsumerStatefulWidget {
  const _DetailEpisodeCard({
    required this.row,
    required this.anilistId,
    required this.animeTitle,
    this.downloadTask,
    this.onTap,
  });

  final _DetailEpisodeRowData row;
  final int anilistId;
  final String animeTitle;
  final DownloadTask? downloadTask;
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

    final dlTask = widget.downloadTask;

    return KeyedSubtree(
      key: Key('anime-detail-episode-${row.number.toInt()}'),
      child: EpisodeRow(
        number: row.number,
        displayTitle: row.displayTitle,
        secondaryText: row.secondaryText,
        sourceBadges: const <Widget>[],
        progressFraction: row.progressFraction,
        isCurrentEpisode: row.isCurrentEpisode,
        isPlayable: isPlayable,
        onTap: widget.onTap,
        activeLabel: context.l10n.detailContinueBadge,
        trailingAccessory: _buildDownloadWidget(context, dlTask),
        playIconSize: 26,
        showWatchedCheck: false,
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

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

      if (!context.mounted) return;

      if (links.isEmpty) {
        setState(() => _isEnqueuing = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
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
        animeTitle: widget.animeTitle,
      );

      if (!mounted) return;
      setState(() => _isEnqueuing = false);

      final success = result.fold(
        onSuccess: (_) => true,
        onFailure: (_) => false,
      );

      if (success) {
        ref.invalidate(downloadTasksByAnimeProvider(widget.anilistId));
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadQueued)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isEnqueuing = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
      }
    }
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
    final disabled = onTap == null;
    final color = disabled
        ? KumoriyaColors.textDisabled
        : active
        ? KumoriyaColors.primary
        : KumoriyaColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 14 : 16,
          vertical: desktop ? 8 : 10,
        ),
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
            Icon(icon, size: desktop ? 16 : 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: desktop ? 12 : 13,
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

_DetailEpisodeRowsResult _buildDetailEpisodeRows({
  required List<AnimeEpisode> animeEpisodes,
  required SourceAvailabilitySummary? availabilitySummary,
  required List<EpisodeProgress> progressList,
  required Map<int, MalEpisodeMetadata> malEpisodeMetadata,
  required double? focusedEpisodeNumber,
  required String animeTitle,
  required String Function(double episodeNumber) fallbackTitleBuilder,
  required String upcomingLabel,
  required String readyLabel,
  int? previewLimit,
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
  final visibleNumbers =
      previewLimit != null && allNumbers.length > previewLimit
      ? _selectDetailEpisodePreviewNumbers(
          allNumbers: allNumbers,
          previewLimit: previewLimit,
          focusedEpisodeNumber: focusedEpisodeNumber,
        )
      : allNumbers;

  EpisodeProgress? latestProgress;
  for (final progress in progressList) {
    if (latestProgress == null ||
        progress.updatedAt.isAfter(latestProgress.updatedAt)) {
      latestProgress = progress;
    }
  }

  return _DetailEpisodeRowsResult(
    totalCount: allNumbers.length,
    rows: visibleNumbers
        .map((number) {
          final metadata = metadataByNumber[number];
          final jikanMetadata = malEpisodeMetadata[number.toInt()];
          final sources =
              sourcesByEpisode[number] ?? const <SourceAvailability>[];
          final progress = progressByNumber[number];

          return _DetailEpisodeRowData(
            number: number,
            displayTitle:
                (jikanMetadata?.title != null &&
                    jikanMetadata!.title!.trim().isNotEmpty)
                ? jikanMetadata.title!.trim()
                : resolveEpisodeDisplayTitle(
                    episodeNumber: number,
                    animeTitle: animeTitle,
                    metadata: metadata,
                    sourceEpisodes:
                        sourceEpisodesByNumber[number] ??
                        const <String, SourceEpisode>{},
                    fallbackTitle: fallbackTitleBuilder(number),
                  ),
            secondaryText: metadata?.airDate != null
                ? _formatEpisodeDate(metadata!.airDate!)
                : metadata?.isAired == false
                ? upcomingLabel
                : jikanMetadata?.airedAt != null
                ? _formatEpisodeDate(jikanMetadata!.airedAt!)
                : readyLabel,
            playableSources: sources,
            progressFraction: _progressFraction(progress),
            isCurrentEpisode:
                latestProgress?.episodeNumber == number ||
                focusedEpisodeNumber == number,
            sourceEpisodes:
                sourceEpisodesByNumber[number] ??
                const <String, SourceEpisode>{},
          );
        })
        .toList(growable: false),
  );
}

List<double> _selectDetailEpisodePreviewNumbers({
  required List<double> allNumbers,
  required int previewLimit,
  required double? focusedEpisodeNumber,
}) {
  if (allNumbers.length <= previewLimit) {
    return allNumbers;
  }

  final focusIndex = focusedEpisodeNumber == null
      ? -1
      : allNumbers.indexWhere(
          (number) => (number - focusedEpisodeNumber).abs() < 0.001,
        );

  if (focusIndex >= 0) {
    final halfWindow = previewLimit ~/ 2;
    final start = math.max(
      0,
      math.min(focusIndex - halfWindow, allNumbers.length - previewLimit),
    );
    return allNumbers.sublist(start, start + previewLimit);
  }

  return allNumbers.sublist(allNumbers.length - previewLimit);
}

final class _DetailEpisodeRowsResult {
  const _DetailEpisodeRowsResult({
    required this.rows,
    required this.totalCount,
  });

  final List<_DetailEpisodeRowData> rows;
  final int totalCount;
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

String _formatLabel(BuildContext context, AnimeFormat format) {
  return displayFormatLabel(context, format);
}

String _statusLabel(BuildContext context, AnimeStatus status) {
  return switch (status) {
    AnimeStatus.releasing => context.l10n.statusAiring,
    AnimeStatus.notYetReleased => context.l10n.statusUpcoming,
    AnimeStatus.finished => context.l10n.statusFinished,
    AnimeStatus.cancelled => context.l10n.statusCancelled,
    AnimeStatus.hiatus => context.l10n.statusOnHiatus,
    AnimeStatus.unknown => context.l10n.statusUnknown,
  };
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
  String? animeTitle,
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
      animeTitle: animeTitle,
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
    // Listen to live progress events for this task only.
    final liveEvent = ref
        .watch(downloadProgressByTaskProvider(task.id))
        .maybeWhen(data: (event) => event, orElse: () => null);

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
        KumoriyaColors.statusWarning,
      ),
      DownloadStatus.completed => (
        Icons.download_done_rounded,
        KumoriyaColors.statusSuccess,
      ),
      DownloadStatus.failed => (
        Icons.error_outline_rounded,
        KumoriyaColors.statusDanger,
      ),
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
  const _DetailDownloadAllButton({
    required this.rows,
    required this.anilistId,
    required this.animeTitle,
    required this.availableSources,
  });

  final List<_DetailEpisodeRowData> rows;
  final int anilistId;
  final String animeTitle;
  final List<SourceAvailability> availableSources;

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
    final downloadable = widget.rows
        .where((r) => r.sourceEpisodes.isNotEmpty)
        .toList();
    if (downloadable.isEmpty) return;

    final sourceId = await _pickSourceForBulkDownload(context);
    if (sourceId == null) {
      return;
    }

    setState(() => _isEnqueuing = true);
    var queued = 0;

    for (final row in downloadable) {
      final entry = row.sourceEpisodes.entries
          .where((e) => e.key == sourceId)
          .firstOrNull;
      if (entry == null) continue;

      final result = await _enqueueDetailEpisodeDownload(
        ref: ref,
        anilistId: widget.anilistId,
        sourcePluginId: entry.key,
        sourceEpisode: entry.value,
        animeTitle: widget.animeTitle,
      );
      if (result) queued++;
    }

    if (!context.mounted) return;
    setState(() => _isEnqueuing = false);

    if (queued > 0) {
      ref.invalidate(downloadTasksByAnimeProvider(widget.anilistId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadAllQueued)));
    }
  }

  Future<String?> _pickSourceForBulkDownload(BuildContext context) async {
    final availableSources = widget.availableSources
        .where((source) => source.manifest.id != _excludedDetailDownloadSource)
        .where(
          (source) => widget.rows.any(
            (row) => row.sourceEpisodes.containsKey(source.manifest.id),
          ),
        )
        .toList(growable: false);

    if (availableSources.isEmpty) {
      return null;
    }
    if (availableSources.length == 1) {
      return availableSources.first.manifest.id;
    }

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  context.l10n.downloadAllFromSource,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...availableSources.map(
                (source) => ListTile(
                  leading: SourceBadge(
                    name: source.manifest.displayName,
                    iconUrl: source.manifest.iconUrl,
                    compact: true,
                    iconOnly: true,
                  ),
                  title: Text(source.manifest.displayName),
                  onTap: () => Navigator.of(context).pop(source.manifest.id),
                ),
              ),
            ],
          ),
        );
      },
    );
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

class _RelationTypeBadge extends StatelessWidget {
  const _RelationTypeBadge({required this.type});

  final AnimeRelationType type;

  @override
  Widget build(BuildContext context) {
    return MetaChip(
      label: displayRelationTypeLabel(context, type),
      isActive: true,
    );
  }
}
