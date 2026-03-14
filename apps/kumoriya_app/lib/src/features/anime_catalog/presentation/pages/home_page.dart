import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/continue_watching_card.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/source_availability.dart';
import '../../../player/presentation/pages/anime_nexus_playground_page.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../support/playback_launch_flow.dart';
import 'anime_detail_page.dart';
import 'episode_list_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeCatalog = ref.watch(homeCatalogProvider);
    final continueWatching = ref.watch(continueWatchingProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: homeCatalog.when(
        loading: () => LoadingStateView(label: context.l10n.homeLoadingCatalog),
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
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.animeList, required this.continueWatching});

  final List<Anime> animeList;
  final AsyncValue<Result<List<AnimeWatchHistory>, KumoriyaError>>
  continueWatching;

  void _openDetail(BuildContext context, int anilistId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: anilistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogById = <int, Anime>{
      for (final anime in animeList) anime.anilistId: anime,
    };

    return CustomScrollView(
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
          ),
        ),
        if (animeList.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
              child: _SectionHeader(title: context.l10n.homeTrendingSection),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final anime = animeList[index];
                return _TrendingRow(
                  anime: anime,
                  rank: index + 1,
                  onTap: () => _openDetail(context, anime.anilistId),
                );
              }, childCount: animeList.length),
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
    );
  }
}

class _MobileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            child: const Text(
              'K',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Kumoriya',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: KumoriyaColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
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
              icon: const Icon(Icons.bug_report_rounded),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: KumoriyaColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TrendingRow extends StatefulWidget {
  const _TrendingRow({
    required this.anime,
    required this.rank,
    required this.onTap,
  });

  final Anime anime;
  final int rank;
  final VoidCallback onTap;

  @override
  State<_TrendingRow> createState() => _TrendingRowState();
}

class _TrendingRowState extends State<_TrendingRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surface.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(
                  '${widget.rank}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KumoriyaColors.primary.withValues(alpha: 0.50),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                child: KumoriyaCachedImage(
                  url: widget.anime.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.anime.title.romaji,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        if (widget.anime.releaseYear != null) ...<Widget>[
                          Text(
                            '${widget.anime.releaseYear}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: KumoriyaColors.textDisabled,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: KumoriyaColors.borderMedium,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          widget.anime.format.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: KumoriyaColors.textDisabled,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: KumoriyaColors.textDisabled,
                size: 20,
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
  });

  final AsyncValue<Result<List<AnimeWatchHistory>, KumoriyaError>>
  continueWatching;
  final Map<int, Anime> catalogById;

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
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) => result.fold(
        onFailure: (_) => const SizedBox.shrink(),
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: KumoriyaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.continueWatchingHint,
                              style: const TextStyle(
                                fontSize: 12,
                                color: KumoriyaColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showDesktopControls) ...<Widget>[
                        _NavArrow(
                          key: const Key('continue-watching-scroll-left'),
                          icon: Icons.arrow_back_rounded,
                          onTap: () => _scrollBy(-_scrollStep),
                        ),
                        const SizedBox(width: 8),
                        _NavArrow(
                          key: const Key('continue-watching-scroll-right'),
                          icon: Icons.arrow_forward_rounded,
                          onTap: () => _scrollBy(_scrollStep),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 163,
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
  const _NavArrow({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: KumoriyaColors.surface,
          borderRadius: BorderRadius.circular(KumoriyaRadius.full),
          border: Border.all(color: KumoriyaColors.borderSubtle),
        ),
        child: Icon(icon, color: KumoriyaColors.textMuted, size: 18),
      ),
    );
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
            onFailure: (_) => 'AniList #${widget.entry.anilistId}',
            onSuccess: (detail) => detail.anime.title.romaji,
          ),
          orElse: () => 'AniList #${widget.entry.anilistId}',
        ) ??
        'AniList #${widget.entry.anilistId}';

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
    showBlockingLoader(context, context.l10n.playbackPreparing);
    var loaderShown = true;

    try {
      final summary = await _loadResumeSummary();
      if (!mounted) return;
      if (summary == null) {
        if (loaderShown) {
          hideBlockingLoader(context);
          loaderShown = false;
        }
        await _openEpisodeListFallback(context, animeTitle);
        return;
      }
      final decision = await _prepareResumeDecision(summary);
      if (!mounted) return;
      if (loaderShown) {
        hideBlockingLoader(context);
        loaderShown = false;
      }
      if (decision == null) {
        await _openEpisodeListFallback(context, animeTitle);
        return;
      }
      await handlePlaybackDecision(
        context: context,
        ref: ref,
        anilistId: widget.entry.anilistId,
        animeTitle: animeTitle,
        decision: decision,
        onUnavailable: () => _openEpisodeListFallback(context, animeTitle),
      );
    } finally {
      if (mounted) {
        if (loaderShown) hideBlockingLoader(context);
        setState(() => _isLaunching = false);
      }
    }
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
