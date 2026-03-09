import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../widgets/anime_list_tile.dart';
import 'anime_detail_page.dart';
import 'search_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeCatalog = ref.watch(homeCatalogProvider);
    final continueWatching = ref.watch(continueWatchingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appTitle)),
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

  @override
  Widget build(BuildContext context) {
    final catalogById = <int, Anime>{
      for (final anime in animeList) anime.anilistId: anime,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _HeroSearchCard(),
        const SizedBox(height: 18),
        _ContinueWatchingSection(
          continueWatching: continueWatching,
          catalogById: catalogById,
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.homeTrendingSection,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.homeTrendingHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (animeList.isEmpty)
          EmptyStateView(message: context.l10n.homeEmptyCatalog)
        else
          ...animeList.map(
            (anime) => AnimeListTile(
              anime: anime,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnimeDetailPage(anilistId: anime.anilistId),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HeroSearchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.homeHeroTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.homeHeroSubtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.searchHintTitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SearchPage(),
                        ),
                      );
                    },
                    child: Text(context.l10n.homeSearchAction),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingSection extends StatelessWidget {
  const _ContinueWatchingSection({
    required this.continueWatching,
    required this.catalogById,
  });

  final AsyncValue<Result<List<AnimeWatchHistory>, KumoriyaError>>
  continueWatching;
  final Map<int, Anime> catalogById;

  @override
  Widget build(BuildContext context) {
    return continueWatching.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) => result.fold(
        onFailure: (_) => const SizedBox.shrink(),
        onSuccess: (history) {
          if (history.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.continueWatching,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.continueWatchingHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    return _ContinueWatchingCard(
                      entry: entry,
                      fallbackAnime: catalogById[entry.anilistId],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContinueWatchingCard extends ConsumerWidget {
  const _ContinueWatchingCard({
    required this.entry,
    required this.fallbackAnime,
  });

  final AnimeWatchHistory entry;
  final Anime? fallbackAnime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = fallbackAnime == null
        ? ref.watch(animeDetailProvider(entry.anilistId))
        : null;

    final title =
        fallbackAnime?.title.romaji ??
        detailState?.maybeWhen(
          data: (result) => result.fold(
            onFailure: (_) => 'AniList #${entry.anilistId}',
            onSuccess: (detail) => detail.anime.title.romaji,
          ),
          orElse: () => 'AniList #${entry.anilistId}',
        ) ??
        'AniList #${entry.anilistId}';

    final imageUrl =
        fallbackAnime?.coverImageUrl ??
        detailState?.maybeWhen(
          data: (result) => result.fold(
            onFailure: (_) => null,
            onSuccess: (detail) =>
                detail.anime.coverImageUrl ?? detail.bannerImageUrl,
          ),
          orElse: () => null,
        );

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AnimeDetailPage(anilistId: entry.anilistId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 248,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            KumoriyaCachedImage(
              url: imageUrl,
              bucket: KumoriyaImageCacheBucket.artwork,
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PillLabel(
                    label: context.l10n.continueWatchingEpisode(
                      entry.lastEpisodeNumber.toInt().toString(),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimeAgo(context, entry.lastAccessedAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return context.l10n.timeAgoMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.timeAgoHours(diff.inHours);
    }
    return context.l10n.timeAgoDays(diff.inDays);
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
