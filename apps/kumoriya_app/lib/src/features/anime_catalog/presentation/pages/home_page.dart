import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import '../widgets/anime_list_tile.dart';
import 'anime_detail_page.dart';
import 'search_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeCatalog = ref.watch(homeCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              );
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: homeCatalog.when(
        loading: () => LoadingStateView(label: context.l10n.homeLoadingCatalog),
        error: (error, _) => ErrorStateView(
          message: context.l10n.unexpectedStateError(error.toString()),
          onRetry: () => ref.invalidate(homeCatalogProvider),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => ref.invalidate(homeCatalogProvider),
          ),
          onSuccess: (animeList) => _HomeCatalogList(animeList: animeList),
        ),
      ),
    );
  }
}

class _HomeCatalogList extends StatelessWidget {
  const _HomeCatalogList({required this.animeList});

  final List<Anime> animeList;

  @override
  Widget build(BuildContext context) {
    if (animeList.isEmpty) {
      return EmptyStateView(message: context.l10n.homeEmptyCatalog);
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
