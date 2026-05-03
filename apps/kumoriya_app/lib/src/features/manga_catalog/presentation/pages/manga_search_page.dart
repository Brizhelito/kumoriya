import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/manga_catalog_providers.dart';
import '../widgets/manga_card.dart';
import '../widgets/manga_carousel.dart';
import 'manga_detail_page.dart';

/// Manga universe Search: debounced search bar feeding a paginated grid.
class MangaSearchPage extends ConsumerStatefulWidget {
  const MangaSearchPage({super.key});

  @override
  ConsumerState<MangaSearchPage> createState() => _MangaSearchPageState();
}

class _MangaSearchPageState extends ConsumerState<MangaSearchPage> {
  static const _debounce = Duration(milliseconds: 280);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(mangaSearchQueryProvider);
    _focusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_handleSearchFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchFocusChange() {
    setState(() => _searchFocused = _focusNode.hasFocus);
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      ref.read(mangaSearchQueryProvider.notifier).set(value);
    });
    setState(() {});
  }

  void _submit() {
    _debounceTimer?.cancel();
    ref.read(mangaSearchQueryProvider.notifier).set(_controller.text);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _controller.clear();
    ref.read(mangaSearchQueryProvider.notifier).set('');
    setState(() {});
  }

  void _openDetail(Manga manga) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MangaDetailPage(anilistId: manga.anilistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(mangaSearchQueryProvider);
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.mangaSearchTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.mangaSearchEmptyHint,
                    style: const TextStyle(
                      fontSize: 13,
                      color: KumoriyaColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MangaDarkSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    focused: _searchFocused,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                    onClear: _clearSearch,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _SearchBody(
                query: query,
                onClear: _clearSearch,
                onOpenDetail: _openDetail,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({
    required this.query,
    required this.onClear,
    required this.onOpenDetail,
  });
  final String query;
  final VoidCallback onClear;
  final ValueChanged<Manga> onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (query.trim().isEmpty) {
      return _MangaDiscoverBody(
        onOpenDetail: onOpenDetail,
        onInvalidate: () => ref.invalidate(mangaHomeProvider),
      );
    }
    final asyncResults = ref.watch(mangaSearchProvider(query));
    return StateTransitionSwitcher(
      stateKey: asyncResults.isLoading
          ? 'loading'
          : asyncResults.hasError
          ? 'error'
          : 'content',
      child: asyncResults.when(
        loading: () => LoadingStateView(label: l10n.searchLoading),
        error: (_, _) => ErrorStateView(
          message: l10n.mangaHomeError,
          onRetry: () => ref.invalidate(mangaSearchProvider(query)),
        ),
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: EmptyStateView(
                icon: Icons.search_off_rounded,
                message: l10n.mangaSearchNoResults,
                actionLabel: l10n.clearSearch,
                onAction: onClear,
              ),
            );
          }
          return _ResultsGrid(results: results, onOpenDetail: onOpenDetail);
        },
      ),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.results, required this.onOpenDetail});
  final List<Manga> results;
  final ValueChanged<Manga> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Phone (<600): 2 cols, big posters. Tablet (<900): 3. Wider: 4.
    // The previous 3/4/5 split squeezed posters under ~115px on 360dp
    // phones, which combined with the 2-line title overflowed the
    // grid cell vertically. The current ratio (~0.62) keeps the cell
    // taller than the card content for every column count.
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.60,
      ),
      itemBuilder: (_, i) =>
          MangaCard(manga: results[i], onTap: () => onOpenDetail(results[i])),
      itemCount: results.length,
    );
  }
}

class _MangaDiscoverBody extends ConsumerWidget {
  const _MangaDiscoverBody({
    required this.onOpenDetail,
    required this.onInvalidate,
  });

  final ValueChanged<Manga> onOpenDetail;
  final VoidCallback onInvalidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final home = ref.watch(mangaHomeProvider);
    return StateTransitionSwitcher(
      stateKey: home.isLoading
          ? 'loading'
          : home.hasError
          ? 'error'
          : 'content',
      child: home.when(
        loading: () => const LoadingStateView(),
        error: (_, _) =>
            ErrorStateView(message: l10n.mangaHomeError, onRetry: onInvalidate),
        data: (sections) {
          if (sections.isEmpty) {
            return EmptyStateView(
              icon: Icons.menu_book_rounded,
              message: l10n.mangaHomeEmpty,
              actionLabel: l10n.mangaHomeRetry,
              onAction: onInvalidate,
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: <Widget>[
              MangaCarousel(
                title: l10n.mangaHomeTrending,
                manga: sections.trending,
                onMangaTap: onOpenDetail,
                cardWidth: 120,
              ),
              MangaCarousel(
                title: l10n.mangaHomeTopRated,
                manga: sections.topRated,
                onMangaTap: onOpenDetail,
                cardWidth: 120,
              ),
              MangaCarousel(
                title: l10n.mangaHomePopular,
                manga: sections.popular,
                onMangaTap: onOpenDetail,
                cardWidth: 120,
              ),
              MangaCarousel(
                title: l10n.mangaHomeLatest,
                manga: sections.latest,
                onMangaTap: onOpenDetail,
                cardWidth: 120,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MangaDarkSearchBar extends StatelessWidget {
  const _MangaDarkSearchBar({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: focused
              ? <Color>[
                  KumoriyaColors.surface,
                  KumoriyaColors.primaryContainer.withValues(alpha: 0.35),
                ]
              : <Color>[KumoriyaColors.surface, KumoriyaColors.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
        border: Border.all(
          color: focused
              ? KumoriyaColors.primary.withValues(alpha: 0.6)
              : KumoriyaColors.borderSubtle,
          width: focused ? 1.5 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          if (focused)
            BoxShadow(
              color: KumoriyaColors.primary.withValues(alpha: 0.18),
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
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Icon(
              KumoriyaIcons.search,
              size: 22,
              color: focused
                  ? KumoriyaColors.primary
                  : KumoriyaColors.navInactive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                fontSize: 15,
                color: KumoriyaColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: context.l10n.mangaSearchHint,
                hintStyle: TextStyle(
                  color: focused
                      ? KumoriyaColors.textMuted
                      : KumoriyaColors.textDisabled,
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
            duration: const Duration(milliseconds: 200),
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
                        color: KumoriyaColors.textMuted.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        KumoriyaIcons.close,
                        size: 14,
                        color: KumoriyaColors.textSecondary,
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
