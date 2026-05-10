import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../controllers/paginated_anime_feed_notifier.dart';
import '../support/season_presentation.dart';
import 'anime_detail_page.dart';

class SeasonHubPage extends ConsumerStatefulWidget {
  const SeasonHubPage({super.key});

  @override
  ConsumerState<SeasonHubPage> createState() => _SeasonHubPageState();
}

class _SeasonHubPageState extends ConsumerState<SeasonHubPage> {
  late SeasonalCatalogRequest _request;

  @override
  void initState() {
    super.initState();
    _request = currentSeasonalCatalogRequest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: KumoriyaColors.textPrimary,
        title: Text(context.l10n.seasonHubTitle),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: _SeasonSelector(
                request: _request,
                onChanged: (next) => setState(() => _request = next),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _SeasonChips(
                request: _request,
                onChanged: (next) => setState(() => _request = next),
              ),
            ),
            Expanded(
              child: _SeasonHubBody(
                request: _request,
                onOpenDetail: (anime) => _openDetail(context, anime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: anime.anilistId),
      ),
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  const _SeasonSelector({required this.request, required this.onChanged});

  final SeasonalCatalogRequest request;
  final ValueChanged<SeasonalCatalogRequest> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => onChanged(shiftSeason(request, -1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            displaySeasonYearLabel(context, request.season, request.year),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(shiftSeason(request, 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({required this.request, required this.onChanged});

  final SeasonalCatalogRequest request;
  final ValueChanged<SeasonalCatalogRequest> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AnimeSeason.values
          .map((season) {
            final selected = season == request.season;
            return ChoiceChip(
              label: Text(displaySeasonLabel(context, season)),
              selected: selected,
              onSelected: (_) {
                onChanged(
                  SeasonalCatalogRequest(
                    season: season,
                    year: request.year,
                    page: request.page,
                    perPage: request.perPage,
                    includeCarryovers: request.includeCarryovers,
                  ),
                );
              },
            );
          })
          .toList(growable: false),
    );
  }
}

class _SeasonHubBody extends StatelessWidget {
  const _SeasonHubBody({required this.request, required this.onOpenDetail});

  final SeasonalCatalogRequest request;
  final ValueChanged<Anime> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Tab>[
                Tab(text: context.l10n.seasonHubInSeasonSection),
                Tab(text: context.l10n.seasonHubUpcomingSection),
                Tab(text: context.l10n.seasonHubRecommendedSection),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _SeasonListSection(
                  emptyMessage: context.l10n.seasonHubInSeasonEmpty,
                  request: _browseRequest(
                    statuses: const <AnimeStatus>[AnimeStatus.releasing],
                    sort: AnimeSortType.trending,
                  ),
                  onTap: onOpenDetail,
                ),
                _SeasonListSection(
                  emptyMessage: context.l10n.seasonHubUpcomingEmpty,
                  request: _browseRequest(
                    statuses: const <AnimeStatus>[AnimeStatus.notYetReleased],
                    sort: AnimeSortType.trending,
                  ),
                  onTap: onOpenDetail,
                ),
                _SeasonListSection(
                  emptyMessage: context.l10n.seasonHubRecommendedEmpty,
                  request: _browseRequest(sort: AnimeSortType.score),
                  onTap: onOpenDetail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AnimeBrowseRequest _browseRequest({
    List<AnimeStatus>? statuses,
    AnimeSortType sort = AnimeSortType.trending,
  }) {
    return AnimeBrowseRequest(
      season: request.season,
      seasonYear: request.year,
      statuses: statuses,
      sort: sort,
      page: 1,
      perPage: paginatedAnimeFeedPerPage,
    );
  }
}

class _SeasonListSection extends ConsumerStatefulWidget {
  const _SeasonListSection({
    required this.emptyMessage,
    required this.request,
    required this.onTap,
  });

  final String emptyMessage;
  final AnimeBrowseRequest request;
  final ValueChanged<Anime> onTap;

  @override
  ConsumerState<_SeasonListSection> createState() => _SeasonListSectionState();
}

class _SeasonListSectionState extends ConsumerState<_SeasonListSection> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels < position.maxScrollExtent - 480) return;
    ref
        .read(paginatedAnimeFeedProvider(widget.request).notifier)
        .loadNextPage();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedAnimeFeedProvider(widget.request));
    if (state.isLoadingFirstPage) {
      return LoadingStateView(label: context.l10n.seasonHubLoading);
    }
    final error = state.error;
    if (error != null && state.items.isEmpty) {
      return ErrorStateView(
        message: mapErrorMessage(context, error),
        onRetry: () => ref
            .read(paginatedAnimeFeedProvider(widget.request).notifier)
            .refresh(),
      );
    }
    if (state.items.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_busy_rounded,
        message: widget.emptyMessage,
      );
    }

    return ListView.separated(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: state.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return _SeasonFooter(
            state: state,
            onRetry: () => ref
                .read(paginatedAnimeFeedProvider(widget.request).notifier)
                .loadNextPage(),
          );
        }
        final anime = state.items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KumoriyaRadius.md),
              child: Image.network(
                anime.coverImageUrl ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: KumoriyaColors.surface),
              ),
            ),
          ),
          title: Text(anime.title.romaji),
          subtitle: Text(
            [
              if (anime.releaseYear != null) anime.releaseYear.toString(),
              displayFormatLabel(context, anime.format),
              if (anime.averageScore != null) '★ ${anime.averageScore}',
            ].join(' • '),
          ),
          onTap: () => widget.onTap(anime),
        );
      },
    );
  }
}

class _SeasonFooter extends StatelessWidget {
  const _SeasonFooter({required this.state, required this.onRetry});

  final PaginatedAnimeFeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (state.error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.l10n.retry),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
