import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/universe/widgets/universe_switch.dart';
import '../providers/manga_catalog_providers.dart';
import '../widgets/manga_carousel.dart';
import '../widgets/manga_hero_card.dart';
import 'manga_detail_page.dart';

/// Manga universe Home: hero featured card + four horizontal carousels
/// (Trending, Popular, Latest, Top Rated).
class MangaHomePage extends ConsumerWidget {
  const MangaHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final asyncHome = ref.watch(mangaHomeProvider);
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(mangaHomeProvider),
          child: CustomScrollView(
            slivers: <Widget>[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: UniverseSwitch(),
                  ),
                ),
              ),
              ...asyncHome.when(
                loading: () => const <Widget>[
                  SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => <Widget>[
                  SliverFillRemaining(
                    child: _HomeErrorState(
                      error: e.toString(),
                      onRetry: () => ref.invalidate(mangaHomeProvider),
                    ),
                  ),
                ],
                data: (home) {
                  if (home.isEmpty) {
                    return <Widget>[
                      SliverFillRemaining(
                        child: _HomeEmptyState(
                          message: l10n.mangaHomeEmpty,
                          onRetry: () => ref.invalidate(mangaHomeProvider),
                        ),
                      ),
                    ];
                  }
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: home.trending.isNotEmpty
                          ? MangaHeroCard(
                              manga: home.trending.first,
                              featuredLabel: l10n.mangaHomeFeaturedTag,
                              actionLabel: l10n.mangaHomeReadAction,
                              onAction: () =>
                                  _open(context, home.trending.first),
                            )
                          : const SizedBox.shrink(),
                    ),
                    SliverToBoxAdapter(
                      child: MangaCarousel(
                        title: l10n.mangaHomeTrending,
                        manga: home.trending,
                        onMangaTap: (m) => _open(context, m),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: MangaCarousel(
                        title: l10n.mangaHomePopular,
                        manga: home.popular,
                        onMangaTap: (m) => _open(context, m),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: MangaCarousel(
                        title: l10n.mangaHomeLatest,
                        manga: home.latest,
                        onMangaTap: (m) => _open(context, m),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: MangaCarousel(
                        title: l10n.mangaHomeTopRated,
                        manga: home.topRated,
                        onMangaTap: (m) => _open(context, m),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Manga manga) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MangaDetailPage(anilistId: manga.anilistId),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            color: KumoriyaColors.statusDanger,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KumoriyaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(context.l10n.mangaHomeRetry),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.menu_book_rounded,
            color: KumoriyaColors.textMuted,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KumoriyaColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(context.l10n.mangaHomeRetry),
          ),
        ],
      ),
    );
  }
}
