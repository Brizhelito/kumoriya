import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import '../widgets/anime_list_tile.dart';
import 'anime_detail_page.dart';

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
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchCatalogProvider(_activeQuery));

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
                    context.l10n.searchPageTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: KumoriyaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.searchEmptyPrompt,
                    style: const TextStyle(
                      fontSize: 13,
                      color: KumoriyaColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DarkSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                    focused: _searchFocused,
                    onSubmitted: (_) => _submit(),
                    onClear: () {
                      _controller.clear();
                      setState(() => _activeQuery = '');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _activeQuery.isEmpty
                  ? Center(
                      child: EmptyStateView(
                        icon: Icons.search_rounded,
                        message: context.l10n.searchPromptShort,
                      ),
                    )
                  : searchState.when(
                      loading: () =>
                          LoadingStateView(label: context.l10n.searchLoading),
                      error: (_, _) => ErrorStateView(
                        message: context.l10n.genericLoadFailure,
                        onRetry: () =>
                            ref.invalidate(searchCatalogProvider(_activeQuery)),
                      ),
                      data: (result) => result.fold(
                        onFailure: (error) => ErrorStateView(
                          message: mapErrorMessage(context, error),
                          onRetry: () => ref.invalidate(
                            searchCatalogProvider(_activeQuery),
                          ),
                        ),
                        onSuccess: (animeList) => _SearchResultsList(
                          animeList: animeList,
                          query: _activeQuery,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        border: Border.all(
          color: focused
              ? KumoriyaColors.primary.withValues(alpha: 0.60)
              : KumoriyaColors.borderSubtle,
          width: focused ? 1.5 : 1.0,
        ),
        boxShadow: focused
            ? <BoxShadow>[
                BoxShadow(
                  color: KumoriyaColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: focused
                ? KumoriyaColors.primary
                : KumoriyaColors.textDisabled,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                fontSize: 15,
                color: KumoriyaColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: context.l10n.searchHintTitle,
                hintStyle: const TextStyle(
                  color: KumoriyaColors.textDisabled,
                  fontSize: 15,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: KumoriyaColors.textDisabled,
                ),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({required this.animeList, required this.query});

  final List<Anime> animeList;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (animeList.isEmpty) {
      return Center(
        child: EmptyStateView(message: context.l10n.searchNoResults(query)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: animeList.length,
      itemBuilder: (context, index) {
        final anime = animeList[index];
        return AnimeListTile(
          anime: anime,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AnimeDetailPage(anilistId: anime.anilistId),
              ),
            );
          },
        );
      },
    );
  }
}
