import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/continue_watching_card.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/universe/widgets/universe_switch.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../application/models/source_availability.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../player/presentation/pages/anime_nexus_playground_page.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../support/playback_launch_flow.dart';
import '../support/season_presentation.dart';
import '../widgets/anime_ranked_tile.dart';
import 'anime_detail_page.dart';
import 'episode_list_page.dart';
import 'season_hub_page.dart';
import 'trending_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeCatalog = ref.watch(homeCatalogProvider);
    final continueWatching = ref.watch(continueWatchingProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: StateTransitionSwitcher(
        stateKey: homeCatalog.isLoading
            ? 'loading'
            : homeCatalog.hasError
            ? 'error'
            : 'content',
        child: homeCatalog.when(
          loading: () =>
              LoadingStateView(label: context.l10n.homeLoadingCatalog),
          error: (_, _) => ErrorStateView(
            message: context.l10n.genericLoadFailure,
            onRetry: () => ref.invalidate(homeCatalogProvider),
          ),
          data: (result) => result.fold(
            onFailure: (error) => ErrorStateView(
              message: mapErrorMessage(context, error),
              onRetry: () => ref.invalidate(homeCatalogProvider),
            ),
            onSuccess: (animeList) => _HomeBody(
              animeList: animeList,
              continueWatching: continueWatching,
              onRefresh: () {
                ref.invalidate(homeCatalogProvider);
                ref.invalidate(continueWatchingProvider);
                ref.invalidate(allWatchHistoryProvider);
                ref.invalidate(favoriteAnimeIdsProvider);
                ref.invalidate(subscribedAnimeIdsProvider);
                ref.invalidate(calendarCatalogProvider);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.animeList,
    required this.continueWatching,
    this.onRefresh,
  });

  final List<Anime> animeList;
  final AsyncValue<Result<List<AnimeWatchHistory>, KumoriyaError>>
  continueWatching;
  final VoidCallback? onRefresh;

  void _openDetail(BuildContext context, int anilistId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: anilistId),
      ),
    );
  }

  void _openTrending(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TrendingPage()));
  }

  void _openSeasonHub(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SeasonHubPage()));
  }

  @override
  Widget build(BuildContext context) {
    final catalogById = <int, Anime>{
      for (final anime in animeList) anime.anilistId: anime,
    };

    return RefreshIndicator(
      color: KumoriyaColors.primary,
      backgroundColor: KumoriyaColors.surface,
      onRefresh: () async {
        onRefresh?.call();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverSafeArea(
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _MobileHeader(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ContinueWatchingSection(
              continueWatching: continueWatching,
              catalogById: catalogById,
              onRetry: onRefresh,
            ),
          ),
          SliverToBoxAdapter(child: _AiringTodaySection(onRetry: onRefresh)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: KumoriyaSectionHeader(
                title: context.l10n.homeSeasonHubSection,
                onSeeAll: () => _openSeasonHub(context),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SeasonHubSpotlightCard(
                onTap: () => _openSeasonHub(context),
              ),
            ),
          ),
          if (animeList.isNotEmpty) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                child: KumoriyaSectionHeader(
                  title: context.l10n.homeTrendingSection,
                  onSeeAll: () => _openTrending(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final anime = animeList[index];
                  return AnimeRankedTile(
                    anime: anime,
                    rank: index + 1,
                    onTap: () => _openDetail(context, anime.anilistId),
                  );
                }, childCount: animeList.length > 10 ? 10 : animeList.length),
              ),
            ),
          ] else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: EmptyStateView(message: context.l10n.homeEmptyCatalog),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: KumoriyaColors.primary,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: KumoriyaColors.primary.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'K',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Kumoriya',
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                DateFormat.MMMd(
                  Localizations.localeOf(context).toString(),
                ).format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 11,
                  color: KumoriyaColors.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          const UniverseSwitch(),
          if (kDebugMode)
            IconButton(
              tooltip: 'Anime Nexus playground',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AnimeNexusPlaygroundPage(),
                  ),
                );
              },
              icon: const Icon(KumoriyaIcons.bugReport),
            ),
        ],
      ),
    );
  }
}

class _SeasonHubSpotlightCard extends StatelessWidget {
  const _SeasonHubSpotlightCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final request = currentSeasonalCatalogRequest();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            gradient: LinearGradient(
              colors: <Color>[
                KumoriyaColors.surface,
                KumoriyaColors.surfaceDim,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: KumoriyaColors.borderMedium),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.homeSeasonHubTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displaySeasonYearLabel(
                        context,
                        request.season,
                        request.year,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: KumoriyaColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.homeSeasonHubSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KumoriyaColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.auto_awesome_rounded,
                color: KumoriyaColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueWatchingSection extends StatefulWidget {
  const _ContinueWatchingSection({
    required this.continueWatching,
    required this.catalogById,
    this.onRetry,
  });

  final AsyncValue<Result<List<AnimeWatchHistory>, KumoriyaError>>
  continueWatching;
  final Map<int, Anime> catalogById;
  final VoidCallback? onRetry;

  @override
  State<_ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<_ContinueWatchingSection> {
  static const double _scrollStep = 340;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isDesktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return false;
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_isDesktopPlatform || !_scrollController.hasClients) return;
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return widget.continueWatching.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: LoadingStateView(label: context.l10n.loadingGeneric),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: UnavailableStateView(
          title: context.l10n.continueWatching,
          message: context.l10n.genericLoadFailure,
          actionLabel: context.l10n.retry,
          onAction: widget.onRetry,
        ),
      ),
      data: (result) => result.fold(
        onFailure: (_) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: UnavailableStateView(
            title: context.l10n.continueWatching,
            message: context.l10n.genericLoadFailure,
            actionLabel: context.l10n.retry,
            onAction: widget.onRetry,
          ),
        ),
        onSuccess: (history) {
          if (history.isEmpty) return const SizedBox.shrink();

          final showDesktopControls = _isDesktopPlatform && history.length > 1;

          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.continueWatching,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.continueWatchingHint,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (showDesktopControls) ...<Widget>[
                        _NavArrow(
                          key: const Key('continue-watching-scroll-left'),
                          icon: Icons.arrow_back_rounded,
                          onTap: () => _scrollBy(-_scrollStep),
                          tooltip: 'Scroll left',
                        ),
                        const SizedBox(width: 8),
                        _NavArrow(
                          key: const Key('continue-watching-scroll-right'),
                          icon: Icons.arrow_forward_rounded,
                          onTap: () => _scrollBy(_scrollStep),
                          tooltip: 'Scroll right',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 170,
                  child: Listener(
                    onPointerSignal: _handlePointerSignal,
                    child: ListView.separated(
                      key: const Key('continue-watching-list'),
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        return _ContinueWatchingCardWrapper(
                          entry: entry,
                          fallbackAnime: widget.catalogById[entry.anilistId],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      splashColor: KumoriyaColors.primary.withValues(alpha: 0.08),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: KumoriyaColors.surface,
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
          border: Border.all(color: KumoriyaColors.borderSubtle),
        ),
        child: Icon(icon, color: KumoriyaColors.textMuted, size: 18),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class _ContinueWatchingCardWrapper extends ConsumerStatefulWidget {
  const _ContinueWatchingCardWrapper({
    required this.entry,
    required this.fallbackAnime,
  });

  final AnimeWatchHistory entry;
  final Anime? fallbackAnime;

  @override
  ConsumerState<_ContinueWatchingCardWrapper> createState() =>
      _ContinueWatchingCardWrapperState();
}

class _ContinueWatchingCardWrapperState
    extends ConsumerState<_ContinueWatchingCardWrapper> {
  static const Duration _resumePreparationTimeout = Duration(seconds: 6);

  bool _isLaunching = false;

  @override
  Widget build(BuildContext context) {
    final detailState = widget.fallbackAnime == null
        ? ref.watch(animeDetailProvider(widget.entry.anilistId))
        : null;

    final title =
        widget.fallbackAnime?.title.romaji ??
        detailState?.maybeWhen(
          data: (result) => result.fold(
            onFailure: (_) => context.l10n.loadingGeneric,
            onSuccess: (detail) => detail.anime.title.romaji,
          ),
          orElse: () => context.l10n.loadingGeneric,
        ) ??
        context.l10n.loadingGeneric;

    final imageUrl =
        widget.fallbackAnime?.coverImageUrl ??
        detailState?.maybeWhen(
          data: (result) => result.fold(
            onFailure: (_) => null,
            onSuccess: (detail) =>
                detail.anime.coverImageUrl ?? detail.bannerImageUrl,
          ),
          orElse: () => null,
        );

    return ContinueWatchingCard(
      key: Key('continue-watching-card-${widget.entry.anilistId}'),
      entry: widget.entry,
      title: title,
      imageUrl: imageUrl,
      isLaunching: _isLaunching,
      onResume: () => _handleResumeTap(title),
    );
  }

  Future<void> _handleResumeTap(String animeTitle) async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    // Capture the root navigator up-front so the loader can always be
    // dismissed, even if this ContinueWatchingCard is rebuilt or unmounted
    // during the async work below. Without this, a list refresh mid-flight
    // would leave a phantom "Preparando reproducción…" modal stuck on top
    // of Home (reproduced in the evidence video).
    final rootNavigatorContext = Navigator.of(
      context,
      rootNavigator: true,
    ).context;
    showBlockingLoader(rootNavigatorContext, context.l10n.playbackPreparing);
    var loaderShown = true;

    try {
      final openedOffline = await _openDownloadedEpisodeIfAvailable(animeTitle);
      if (openedOffline) {
        return;
      }
      if (!mounted) return;

      final summary = await _loadResumeSummary();
      if (!mounted) return;
      if (summary == null) {
        if (loaderShown) {
          // Intentional: `rootNavigatorContext` targets the root Navigator
          // dialog, not this widget's subtree.
          // ignore: use_build_context_synchronously
          hideBlockingLoader(rootNavigatorContext);
          loaderShown = false;
        }
        await _openEpisodeListFallback(context, animeTitle);
        return;
      }
      final decision = await _prepareResumeDecision(summary);
      if (!mounted) return;
      if (loaderShown) {
        // ignore: use_build_context_synchronously
        hideBlockingLoader(rootNavigatorContext);
        loaderShown = false;
      }
      if (decision == null) {
        await _openEpisodeListFallback(context, animeTitle);
        return;
      }

      final detailResult = await ref.read(
        animeDetailProvider(widget.entry.anilistId).future,
      );
      if (!mounted) return;
      final totalEpisodes = detailResult.fold(
        onFailure: (_) => null,
        onSuccess: (detail) => detail.anime.totalEpisodes,
      );
      final nextAiringEpisodeNumber = detailResult.fold(
        onFailure: (_) => null,
        onSuccess: (detail) => detail.anime.nextAiringEpisodeNumber?.toDouble(),
      );

      // ignore: use_build_context_synchronously
      await handlePlaybackDecision(
        context: context,
        ref: ref,
        anilistId: widget.entry.anilistId,
        animeTitle: animeTitle,
        decision: decision,
        onUnavailable: () => _openEpisodeListFallback(context, animeTitle),
        totalEpisodes: totalEpisodes,
        nextAiringEpisodeNumber: nextAiringEpisodeNumber,
      );
    } finally {
      // Dismiss the loader via the root navigator regardless of mount state;
      // the dialog lives on the root navigator, not on this widget's subtree.
      if (loaderShown) {
        // ignore: use_build_context_synchronously
        hideBlockingLoader(rootNavigatorContext);
      }
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  Future<bool> _openDownloadedEpisodeIfAvailable(String animeTitle) async {
    final downloadTask = await ref
        .read(downloadManagerProvider)
        .findTaskByEpisode(
          widget.entry.anilistId,
          widget.entry.lastEpisodeNumber,
        );
    if (downloadTask == null ||
        downloadTask.status != DownloadStatus.completed ||
        downloadTask.filePath == null ||
        downloadTask.filePath!.trim().isEmpty) {
      return false;
    }

    final file = File(downloadTask.filePath!);
    if (!await file.exists()) {
      unawaited(
        ref.read(downloadManagerProvider).deleteCompleted(downloadTask.id),
      );
      return false;
    }

    if (!mounted) {
      return true;
    }

    // Fetch totalEpisodes for next episode button
    final detailResult = await ref.read(
      animeDetailProvider(widget.entry.anilistId).future,
    );
    final totalEpisodes = detailResult.fold(
      onFailure: (_) => null,
      onSuccess: (detail) => detail.anime.totalEpisodes,
    );
    final nextAiringEpisodeNumber = detailResult.fold(
      onFailure: (_) => null,
      onSuccess: (detail) => detail.anime.nextAiringEpisodeNumber?.toDouble(),
    );

    if (!mounted) {
      return true;
    }

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: widget.entry.anilistId,
          animeTitle: animeTitle,
          episodeNumber: widget.entry.lastEpisodeNumber.toInt().toString(),
          persistSelection: false,
          sourcePluginId: downloadTask.sourcePluginId ?? 'offline',
          serverName:
              downloadTask.serverName ?? context.l10n.downloadedSourceLabel,
          resolved: ResolvedServerLinkResult(
            resolverId: 'offline',
            resolverName: context.l10n.downloadedSourceLabel,
            streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
          ),
          totalEpisodes: totalEpisodes,
          nextAiringEpisodeNumber: nextAiringEpisodeNumber,
        ),
      ),
    );
    return true;
  }

  Future<SourceAvailabilitySummary?> _loadResumeSummary() async {
    try {
      final result = await ref
          .read(
            sourceAvailabilitySummaryProvider(widget.entry.anilistId).future,
          )
          .timeout(_resumePreparationTimeout);
      return result.fold(onFailure: (_) => null, onSuccess: (value) => value);
    } catch (_) {
      return null;
    }
  }

  Future<EpisodePlaybackDecision?> _prepareResumeDecision(
    SourceAvailabilitySummary summary,
  ) async {
    try {
      return await ref
          .read(startEpisodePlaybackUseCaseProvider)
          .call(
            anilistId: widget.entry.anilistId,
            episodeNumber: widget.entry.lastEpisodeNumber,
            availabilitySummary: summary,
          )
          .timeout(_resumePreparationTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEpisodeListFallback(
    BuildContext context,
    String animeTitle,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeListPage(
          anilistId: widget.entry.anilistId,
          animeTitle: animeTitle,
          focusedEpisodeNumber: widget.entry.lastEpisodeNumber,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Airing Today section
// ---------------------------------------------------------------------------

class _AiringTodaySection extends ConsumerWidget {
  const _AiringTodaySection({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airingToday = ref.watch(calendarCatalogProvider);
    return airingToday.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 18),
        child: SizedBox(height: 88, child: LoadingStateView()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: UnavailableStateView(
          title: context.l10n.homeAiringToday,
          message: context.l10n.genericLoadFailure,
          actionLabel: context.l10n.retry,
          onAction: onRetry,
        ),
      ),
      data: (result) => result.fold(
        onFailure: (_) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: UnavailableStateView(
            title: context.l10n.homeAiringToday,
            message: context.l10n.genericLoadFailure,
            actionLabel: context.l10n.retry,
            onAction: onRetry,
          ),
        ),
        onSuccess: (animeList) {
          final todayAiring = filterAiringTodayAnime(animeList, DateTime.now());

          if (todayAiring.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: KumoriyaSectionHeader(
                    title: context.l10n.homeAiringToday,
                  ),
                ),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: todayAiring.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final anime = todayAiring[index];
                      return _AiringTodayCard(
                        anime: anime,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AnimeDetailPage(anilistId: anime.anilistId),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

@visibleForTesting
DateTime startOfLocalDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

@visibleForTesting
List<Anime> filterAiringTodayAnime(Iterable<Anime> animeList, DateTime now) {
  final today = startOfLocalDay(now);

  final filtered =
      animeList
          .where((anime) {
            if (anime.status != AnimeStatus.releasing &&
                anime.status != AnimeStatus.notYetReleased) {
              return false;
            }

            final nextAiringAt = anime.nextAiringAt?.toLocal();
            if (nextAiringAt == null) {
              return false;
            }

            final airingDay = DateTime(
              nextAiringAt.year,
              nextAiringAt.month,
              nextAiringAt.day,
            );
            return airingDay == today;
          })
          .toList(growable: false)
        ..sort((left, right) {
          final leftTime = left.nextAiringAt?.toLocal();
          final rightTime = right.nextAiringAt?.toLocal();
          if (leftTime == null && rightTime == null) {
            return 0;
          }
          if (leftTime == null) {
            return 1;
          }
          if (rightTime == null) {
            return -1;
          }
          return leftTime.compareTo(rightTime);
        });

  return filtered;
}

class _AiringTodayCard extends StatefulWidget {
  const _AiringTodayCard({required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  @override
  State<_AiringTodayCard> createState() => _AiringTodayCardState();
}

class _AiringTodayCardState extends State<_AiringTodayCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final localNext = anime.nextAiringAt?.toLocal();
    final timeLabel = localNext != null
        ? DateFormat.Hm(
            Localizations.localeOf(context).toString(),
          ).format(localNext)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        splashColor: KumoriyaColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 260,
          padding: const EdgeInsets.all(12),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surfaceDim,
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                child: KumoriyaCachedImage(
                  url: anime.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  width: 72,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      anime.title.romaji,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    if (anime.nextAiringEpisodeNumber != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'EP ${anime.nextAiringEpisodeNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: KumoriyaColors.primary,
                        ),
                      ),
                    ],
                    if (timeLabel != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: KumoriyaColors.textDisabled,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              timeLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: KumoriyaColors.textDisabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
