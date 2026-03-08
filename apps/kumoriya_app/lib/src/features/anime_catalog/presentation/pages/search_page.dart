import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
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
  String _activeQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchCatalogProvider(_activeQuery));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.searchTitle)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _controller,
              hintText: context.l10n.searchHintTitle,
              onSubmitted: (value) {
                setState(() {
                  _activeQuery = value.trim();
                });
              },
              trailing: <Widget>[
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _activeQuery = _controller.text.trim();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _activeQuery.isEmpty
                ? EmptyStateView(message: context.l10n.searchEmptyPrompt)
                : searchState.when(
                    loading: () =>
                        LoadingStateView(label: context.l10n.searchLoading),
                    error: (error, _) => ErrorStateView(
                      message: context.l10n.unexpectedStateError(
                        error.toString(),
                      ),
                      onRetry: () =>
                          ref.invalidate(searchCatalogProvider(_activeQuery)),
                    ),
                    data: (result) => result.fold(
                      onFailure: (error) => ErrorStateView(
                        message: mapErrorMessage(context, error),
                        onRetry: () =>
                            ref.invalidate(searchCatalogProvider(_activeQuery)),
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
      return EmptyStateView(message: context.l10n.searchNoResults(query));
    }

    return ListView.builder(
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
