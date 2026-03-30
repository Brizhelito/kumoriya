import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import '../widgets/anime_ranked_tile.dart';
import 'anime_detail_page.dart';

class TrendingPage extends ConsumerWidget {
  const TrendingPage({super.key});

  static const int _pageSize = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingCatalogProvider(_pageSize));

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: KumoriyaColors.textPrimary,
        title: Text(context.l10n.trendingPageTitle),
      ),
      body: SafeArea(
        top: false,
        child: trendingAsync.when(
          loading: () =>
              LoadingStateView(label: context.l10n.homeLoadingCatalog),
          error: (_, _) => ErrorStateView(
            message: context.l10n.genericLoadFailure,
            onRetry: () => ref.invalidate(trendingCatalogProvider(_pageSize)),
          ),
          data: (result) => result.fold(
            onFailure: (error) => ErrorStateView(
              message: mapErrorMessage(context, error),
              onRetry: () => ref.invalidate(trendingCatalogProvider(_pageSize)),
            ),
            onSuccess: (animeList) {
              if (animeList.isEmpty) {
                return EmptyStateView(message: context.l10n.homeEmptyCatalog);
              }

              return CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        context.l10n.trendingPageSubtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KumoriyaColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: animeList.length,
                      itemBuilder: (context, index) {
                        final anime = animeList[index];
                        return AnimeRankedTile(
                          anime: anime,
                          rank: index + 1,
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
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
