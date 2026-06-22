import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import '../../../../shared/utils/error_messaging.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
// PosterCard from package:kumoriya_ui
import '../providers/anime_catalog_providers.dart';
import '../widgets/anime_list_tile.dart';
import 'anime_detail_page.dart';
import 'browse_results_page.dart';
import 'tag_guided_find_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _activeQuery = '';
  bool _searchFocused = false;

  void _handleSearchFocusChange() {
    setState(() => _searchFocused = _focusNode.hasFocus);
  }

  void _handleSearchTextChange() {
    _debounce?.cancel();
    final nextQuery = _controller.text.trim();
    _debounce = Timer(CloudMotion.base, () {
      if (!mounted) return;
      setState(() => _activeQuery = nextQuery);
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleSearchFocusChange);
    _controller.addListener(_handleSearchTextChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleSearchTextChange);
    _focusNode.removeListener(_handleSearchFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    _debounce?.cancel();
    final q = _controller.text.trim();
    setState(() => _activeQuery = q);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _activeQuery = '');
  }

  void _openDetail(int anilistId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: anilistId),
      ),
    );
  }

  void _openBrowse({String? genre, AnimeBrowseRequest? request}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowseResultsPage(
          initialGenres: genre != null ? <String>[genre] : null,
          initialRequest: request,
        ),
      ),
    );
  }

  void _openTagFind() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TagGuidedFindPage()));
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchCatalogProvider(_activeQuery));
    final colors = FormFactorProvider.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.discoverTitle,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.discoverSubtitle,
                    style: TextStyle(fontSize: 13, color: colors.textSoft),
                  ),
                  const SizedBox(height: 14),
                  _DarkSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    focused: _searchFocused,
                    onSubmitted: (_) => _submit(),
                    onClear: _clearSearch,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _activeQuery.isEmpty
                  ? _DiscoverBody(
                      onOpenDetail: _openDetail,
                      onOpenGenre: (genre) => _openBrowse(genre: genre),
                      onOpenBrowse: (request) => _openBrowse(request: request),
                      onOpenTagFind: _openTagFind,
                    )
                  : _SearchResults(
                      query: _activeQuery,
                      searchState: searchState,
                      onClear: _clearSearch,
                      onOpenDetail: _openDetail,
                      onInvalidate: () =>
                          ref.invalidate(searchCatalogProvider(_activeQuery)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search results (text search active)
// ---------------------------------------------------------------------------

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.searchState,
    required this.onClear,
    required this.onOpenDetail,
    required this.onInvalidate,
  });

  final String query;
  final AsyncValue<Result<List<Anime>, KumoriyaError>> searchState;
  final VoidCallback onClear;
  final ValueChanged<int> onOpenDetail;
  final VoidCallback onInvalidate;

  @override
  Widget build(BuildContext context) {
    return StateTransitionSwitcher(
      stateKey: searchState.isLoading
          ? 'loading'
          : searchState.hasError
          ? 'error'
          : 'content',
      child: searchState.when(
        loading: () => LoadingStateView(label: context.l10n.searchLoading),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: onInvalidate,
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: onInvalidate,
          ),
          onSuccess: (animeList) {
            if (animeList.isEmpty) {
              return Center(
                child: EmptyStateView(
                  icon: Icons.travel_explore_rounded,
                  message: context.l10n.searchNoResults(query),
                  actionLabel: context.l10n.clearSearch,
                  onAction: onClear,
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: animeList.length,
              itemBuilder: (context, index) {
                final anime = animeList[index];
                return AnimeListTile(
                  anime: anime,
                  onTap: () => onOpenDetail(anime.anilistId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discovery body (idle state)
// ---------------------------------------------------------------------------

class _DiscoverBody extends ConsumerWidget {
  const _DiscoverBody({
    required this.onOpenDetail,
    required this.onOpenGenre,
    required this.onOpenBrowse,
    required this.onOpenTagFind,
  });

  final ValueChanged<int> onOpenDetail;
  final ValueChanged<String> onOpenGenre;
  final ValueChanged<AnimeBrowseRequest> onOpenBrowse;
  final VoidCallback onOpenTagFind;

  static const _trendingRequest = AnimeBrowseRequest(
    sort: AnimeSortType.trending,
    perPage: 20,
  );
  static const _topRatedRequest = AnimeBrowseRequest(
    sort: AnimeSortType.score,
    perPage: 20,
  );
  static const _popularRequest = AnimeBrowseRequest(
    sort: AnimeSortType.popularity,
    perPage: 20,
  );
  static const _topAiringRequest = AnimeBrowseRequest(
    statuses: <AnimeStatus>[AnimeStatus.releasing],
    sort: AnimeSortType.popularity,
    perPage: 20,
  );
  static const _topMoviesRequest = AnimeBrowseRequest(
    formats: <AnimeFormat>[AnimeFormat.movie],
    sort: AnimeSortType.score,
    perPage: 20,
  );
  static const _upcomingRequest = AnimeBrowseRequest(
    statuses: <AnimeStatus>[AnimeStatus.notYetReleased],
    sort: AnimeSortType.popularity,
    perPage: 20,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(browseAnimeCatalogProvider(_trendingRequest));
    final topAiring = ref.watch(browseAnimeCatalogProvider(_topAiringRequest));
    final topRated = ref.watch(browseAnimeCatalogProvider(_topRatedRequest));
    final popular = ref.watch(browseAnimeCatalogProvider(_popularRequest));
    final topMovies = ref.watch(browseAnimeCatalogProvider(_topMoviesRequest));
    final upcoming = ref.watch(browseAnimeCatalogProvider(_upcomingRequest));
    final genres = ref.watch(genreCollectionProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        // -- Trending section
        _AnimeHorizontalSection(
          title: context.l10n.discoverTrending,
          state: trending,
          onOpenDetail: onOpenDetail,
          onSeeAll: () => onOpenBrowse(_trendingRequest),
        ),
        const SizedBox(height: 24),
        _AnimeHorizontalSection(
          title: context.l10n.discoverTopAiring,
          state: topAiring,
          onOpenDetail: onOpenDetail,
          onSeeAll: () => onOpenBrowse(_topAiringRequest),
        ),
        const SizedBox(height: 24),
        // -- Top Rated section
        _AnimeHorizontalSection(
          title: context.l10n.discoverTopRated,
          state: topRated,
          onOpenDetail: onOpenDetail,
          onSeeAll: () => onOpenBrowse(_topRatedRequest),
        ),
        const SizedBox(height: 24),
        // -- Most Popular section
        _AnimeHorizontalSection(
          title: context.l10n.discoverPopular,
          state: popular,
          onOpenDetail: onOpenDetail,
          onSeeAll: () => onOpenBrowse(_popularRequest),
        ),
        const SizedBox(height: 24),
        _AnimeHorizontalSection(
          title: context.l10n.discoverTopMovies,
          state: topMovies,
          onOpenDetail: onOpenDetail,
          onSeeAll: () => onOpenBrowse(_topMoviesRequest),
        ),
        const SizedBox(height: 24),
        _AnimeHorizontalSection(
          title: context.l10n.discoverUpcoming,
          state: upcoming,
          onOpenDetail: onOpenDetail,
          onSeeAll: () => onOpenBrowse(_upcomingRequest),
        ),
        const SizedBox(height: 28),
        // -- Genre chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(title: context.l10n.discoverGenres),
        ),
        const SizedBox(height: 12),
        _GenreChipsSection(
          genres: genres,
          onGenreTap: onOpenGenre,
          onRequestTap: onOpenBrowse,
        ),
        const SizedBox(height: 28),
        // -- "Can't remember the name?" CTA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CantRememberCard(onTap: onOpenTagFind),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal anime section
// ---------------------------------------------------------------------------

class _AnimeHorizontalSection extends StatelessWidget {
  const _AnimeHorizontalSection({
    required this.title,
    required this.state,
    required this.onOpenDetail,
    this.onSeeAll,
  });

  final String title;
  final AsyncValue<Result<List<Anime>, KumoriyaError>> state;
  final ValueChanged<int> onOpenDetail;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: title,
            onSeeAll: onSeeAll,
            seeAllLabel: context.l10n.sectionSeeAll,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 235,
          child: state.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => Center(
              child: Text(
                context.l10n.genericLoadFailure,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
            data: (result) => result.fold(
              onFailure: (_) => Center(
                child: Text(
                  context.l10n.genericLoadFailure,
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
              onSuccess: (animeList) {
                if (animeList.isEmpty) return const SizedBox.shrink();
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: animeList.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final anime = animeList[index];
                    return SizedBox(
                      width: 120,
                      child: PosterCard(
                        imageUrl: anime.coverImageUrl ?? '',
                        title: anime.title.romaji,
                        subtitle: anime.releaseYear?.toString(),
                        episodeCount: anime.totalEpisodes,
                        onTap: () => onOpenDetail(anime.anilistId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Genre chips grid
// ---------------------------------------------------------------------------

class _GenreChipsSection extends StatelessWidget {
  const _GenreChipsSection({
    required this.genres,
    required this.onGenreTap,
    required this.onRequestTap,
  });

  final AsyncValue<Result<List<String>, KumoriyaError>> genres;
  final ValueChanged<String> onGenreTap;
  final ValueChanged<AnimeBrowseRequest> onRequestTap;

  static const List<String> _baseGenres = <String>[
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Horror',
    'Mahou Shoujo',
    'Mecha',
    'Music',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  static const List<_DiscoveryChip> _extraChips = <_DiscoveryChip>[
    _DiscoveryChip(label: 'Isekai', tag: 'Isekai'),
    _DiscoveryChip(label: 'School', tag: 'School'),
    _DiscoveryChip(label: 'Shounen', tag: 'Shounen'),
    _DiscoveryChip(label: 'Seinen', tag: 'Seinen'),
    _DiscoveryChip(label: 'Shoujo', tag: 'Shoujo'),
    _DiscoveryChip(label: 'Josei', tag: 'Josei'),
    _DiscoveryChip(label: 'Rom-Com', tag: 'Romantic Comedy'),
    _DiscoveryChip(label: 'Time Travel', tag: 'Time Manipulation'),
    _DiscoveryChip(label: 'Super Power', tag: 'Super Power'),
    _DiscoveryChip(label: 'Vampire', tag: 'Vampire'),
    _DiscoveryChip(label: 'Idol', tag: 'Idol'),
    _DiscoveryChip(label: 'Iyashikei', tag: 'Iyashikei'),
    _DiscoveryChip(label: 'CGDCT', tag: 'Cute Girls Doing Cute Things'),
    _DiscoveryChip(label: 'Coming of Age', tag: 'Coming of Age'),
    _DiscoveryChip(label: 'Post-Apocalyptic', tag: 'Post-Apocalyptic'),
    _DiscoveryChip(label: 'Urban Fantasy', tag: 'Urban Fantasy'),
  ];

  @override
  Widget build(BuildContext context) {
    return genres.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) => result.fold(
        onFailure: (_) => const SizedBox.shrink(),
        onSuccess: (genreList) {
          final mergedGenres = <String>[
            ..._baseGenres,
            for (final genre in genreList)
              if (!_baseGenres.any(
                (baseGenre) =>
                    baseGenre.toLowerCase().trim() ==
                    genre.toLowerCase().trim(),
              ))
                genre,
          ];
          final chips = <Widget>[
            for (final genre in mergedGenres)
              _DiscoveryActionChip(
                label: displayGenreLabel(context, genre),
                onPressed: () => onGenreTap(genre),
              ),
            for (final chip in _extraChips)
              _DiscoveryActionChip(
                label: displayTagLabel(context, chip.label),
                onPressed: () =>
                    onRequestTap(AnimeBrowseRequest(tags: <String>[chip.tag])),
              ),
          ];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          );
        },
      ),
    );
  }
}

class _DiscoveryChip {
  const _DiscoveryChip({required this.label, required this.tag});

  final String label;
  final String tag;
}

class _DiscoveryActionChip extends StatelessWidget {
  const _DiscoveryActionChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.surface2),
      labelStyle: TextStyle(color: colors.textMuted, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CloudRadius.pill),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Can't remember the name?" card
// ---------------------------------------------------------------------------

class _CantRememberCard extends StatelessWidget {
  const _CantRememberCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CloudRadius.md),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              colors.primarySoft,
              colors.primary.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(CloudRadius.md),
          border: Border.all(color: colors.primary.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.lightbulb_outline_rounded, color: colors.star, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.discoverCantRemember,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.discoverCantRememberSubtitle,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(KumoriyaIcons.chevronRight, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar (preserved from previous design)
// ---------------------------------------------------------------------------

class _DarkSearchBar extends StatelessWidget {
  const _DarkSearchBar({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final hasText = controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: CloudMotion.base,
      curve: Curves.easeOutCubic,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: focused
              ? <Color>[
                  colors.surface,
                  colors.primarySoft.withValues(alpha: 0.35),
                ]
              : <Color>[colors.surface, colors.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(CloudRadius.md),
        border: Border.all(
          color: focused
              ? colors.primary.withValues(alpha: 0.6)
              : colors.surface2,
          width: focused ? 1.5 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          if (focused)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 16),
          AnimatedScale(
            scale: focused ? 1.15 : 1.0,
            duration: CloudMotion.base,
            curve: Curves.easeOutBack,
            child: Icon(
              KumoriyaIcons.search,
              size: 22,
              color: focused ? colors.primary : colors.textSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              style: TextStyle(fontSize: 15, color: colors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: context.l10n.searchHintTitle,
                hintStyle: TextStyle(
                  color: focused ? colors.textMuted : colors.textSoft,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          AnimatedSwitcher(
            duration: CloudMotion.fast,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: hasText
                ? IconButton(
                    key: const ValueKey<String>('clear'),
                    onPressed: onClear,
                    tooltip: context.l10n.clearSearch,
                    icon: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        KumoriyaIcons.close,
                        size: 14,
                        color: colors.textMuted,
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey<String>('empty'), width: 16),
          ),
        ],
      ),
    );
  }
}
