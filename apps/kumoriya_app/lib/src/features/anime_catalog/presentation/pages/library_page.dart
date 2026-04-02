import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import 'anime_detail_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: KumoriyaColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.l10n.libraryTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: KumoriyaColors.primary,
                labelColor: KumoriyaColors.primary,
                unselectedLabelColor: KumoriyaColors.navInactive,
                dividerColor: KumoriyaColors.borderSubtle,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                tabs: <Tab>[
                  Tab(text: context.l10n.myListHistory),
                  Tab(text: context.l10n.myListFavorites),
                  Tab(text: context.l10n.myListSubscribed),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _HistoryTab(),
                    _FavoritesTab(),
                    _SubscribedTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(allWatchHistoryProvider);

    return historyState.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        message: context.l10n.genericLoadFailure,
        onRetry: () => ref.invalidate(allWatchHistoryProvider),
      ),
      data: (result) => result.fold(
        onFailure: (error) => ErrorStateView(
          message: mapErrorMessage(context, error),
          onRetry: () => ref.invalidate(allWatchHistoryProvider),
        ),
        onSuccess: (history) {
          if (history.isEmpty) {
            return Center(
              child: EmptyStateView(
                icon: KumoriyaIcons.history,
                message: context.l10n.myListHistoryEmpty,
              ),
            );
          }

          final grouped = _groupHistoryByDate(context, history);
          final sections = grouped.entries.toList();

          return CustomScrollView(
            slivers: <Widget>[
              // Clear-all button row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => _confirmClearAll(context, ref),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: Text(context.l10n.historyClearAllAction),
                        style: TextButton.styleFrom(
                          foregroundColor: KumoriyaColors.statusDanger,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final section in sections) ...<Widget>[
                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      section.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: KumoriyaColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: section.value.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = section.value[index];
                      return Dismissible(
                        key: ValueKey('history_${entry.anilistId}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: KumoriyaColors.statusDanger,
                            borderRadius: BorderRadius.circular(
                              KumoriyaRadius.xxl,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (_) => _confirmDeleteEntry(context),
                        onDismissed: (_) {
                          ref
                              .read(animeProgressStoreProvider)
                              .deleteHistoryEntry(entry.anilistId);
                          ref.invalidate(allWatchHistoryProvider);
                          ref.invalidate(continueWatchingProvider);
                        },
                        child: _HistoryRow(
                          entry: entry,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AnimeDetailPage(anilistId: entry.anilistId),
                            ),
                          ),
                          onDelete: () async {
                            final confirmed = await _confirmDeleteEntry(
                              context,
                            );
                            if (confirmed && context.mounted) {
                              await ref
                                  .read(animeProgressStoreProvider)
                                  .deleteHistoryEntry(entry.anilistId);
                              ref.invalidate(allWatchHistoryProvider);
                              ref.invalidate(continueWatchingProvider);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<AnimeWatchHistory>> _groupHistoryByDate(
    BuildContext context,
    List<AnimeWatchHistory> history,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    final groups = <String, List<AnimeWatchHistory>>{};

    for (final entry in history) {
      final date = DateTime(
        entry.lastAccessedAt.year,
        entry.lastAccessedAt.month,
        entry.lastAccessedAt.day,
      );
      String label;
      if (!date.isBefore(today)) {
        label = context.l10n.historyGroupToday;
      } else if (!date.isBefore(yesterday)) {
        label = context.l10n.historyGroupYesterday;
      } else if (date.isAfter(weekAgo)) {
        label = context.l10n.historyGroupThisWeek;
      } else if (date.isAfter(monthAgo)) {
        label = context.l10n.historyGroupThisMonth;
      } else {
        label = context.l10n.historyGroupOlder;
      }
      groups.putIfAbsent(label, () => <AnimeWatchHistory>[]).add(entry);
    }
    return groups;
  }

  Future<bool> _confirmDeleteEntry(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.historyDeleteEntryTitle),
        content: Text(context.l10n.historyDeleteEntryMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: KumoriyaColors.statusDanger,
            ),
            child: Text(context.l10n.removeAction),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.historyClearAllTitle),
        content: Text(context.l10n.historyClearAllMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancelAction),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(animeProgressStoreProvider).clearAllHistory();
              ref.invalidate(allWatchHistoryProvider);
              ref.invalidate(continueWatchingProvider);
            },
            style: TextButton.styleFrom(
              foregroundColor: KumoriyaColors.statusDanger,
            ),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favState = ref.watch(favoriteAnimeIdsProvider);

    return favState.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        message: context.l10n.genericLoadFailure,
        onRetry: () => ref.invalidate(favoriteAnimeIdsProvider),
      ),
      data: (result) => result.fold(
        onFailure: (error) => ErrorStateView(
          message: mapErrorMessage(context, error),
          onRetry: () => ref.invalidate(favoriteAnimeIdsProvider),
        ),
        onSuccess: (ids) {
          if (ids.isEmpty) {
            return Center(
              child: EmptyStateView(
                icon: KumoriyaIcons.favoriteOutline,
                message: context.l10n.myListFavoritesEmpty,
              ),
            );
          }

          final sortedIds = ids.toList();
          return _AnimeGrid(ids: sortedIds);
        },
      ),
    );
  }
}

class _SubscribedTab extends ConsumerWidget {
  const _SubscribedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscribedAnimeIdsProvider);

    return subState.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        message: context.l10n.genericLoadFailure,
        onRetry: () => ref.invalidate(subscribedAnimeIdsProvider),
      ),
      data: (result) => result.fold(
        onFailure: (error) => ErrorStateView(
          message: mapErrorMessage(context, error),
          onRetry: () => ref.invalidate(subscribedAnimeIdsProvider),
        ),
        onSuccess: (ids) {
          if (ids.isEmpty) {
            return Center(
              child: EmptyStateView(
                icon: KumoriyaIcons.notifications,
                message: context.l10n.myListSubscribedEmpty,
              ),
            );
          }

          final sortedIds = ids.toList();
          return _AnimeGrid(ids: sortedIds, showNotificationBadge: true);
        },
      ),
    );
  }
}

/// YouTube-style poster grid for Favorites / Subscribed tabs.
class _AnimeGrid extends StatelessWidget {
  const _AnimeGrid({required this.ids, this.showNotificationBadge = false});

  final List<int> ids;
  final bool showNotificationBadge;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 5 : (width > 600 ? 4 : 3);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.58,
      ),
      itemCount: ids.length,
      itemBuilder: (context, index) {
        return _AnimePosterCard(
          anilistId: ids[index],
          showNotificationBadge: showNotificationBadge,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AnimeDetailPage(anilistId: ids[index]),
            ),
          ),
        );
      },
    );
  }
}

class _AnimePosterCard extends ConsumerWidget {
  const _AnimePosterCard({
    required this.anilistId,
    required this.onTap,
    this.showNotificationBadge = false,
  });

  final int anilistId;
  final VoidCallback onTap;
  final bool showNotificationBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(animeDetailProvider(anilistId));

    final title = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => '',
        onSuccess: (detail) => detail.anime.title.romaji,
      ),
      orElse: () => '',
    );

    final imageUrl = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (detail) =>
            detail.anime.coverImageUrl ?? detail.bannerImageUrl,
      ),
      orElse: () => null,
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                  child: KumoriyaCachedImage(
                    url: imageUrl,
                    bucket: KumoriyaImageCacheBucket.artwork,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                if (showNotificationBadge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: KumoriyaColors.primary,
                        borderRadius: BorderRadius.circular(
                          KumoriyaRadius.full,
                        ),
                      ),
                      child: const Icon(
                        KumoriyaIcons.notificationsActive,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerStatefulWidget {
  const _HistoryRow({required this.entry, required this.onTap, this.onDelete});

  final AnimeWatchHistory entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends ConsumerState<_HistoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.entry.anilistId));

    final title = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => context.l10n.loadingGeneric,
        onSuccess: (detail) => detail.anime.title.romaji,
      ),
      orElse: () => context.l10n.loadingGeneric,
    );

    final imageUrl = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (detail) =>
            detail.anime.coverImageUrl ?? detail.bannerImageUrl,
      ),
      orElse: () => null,
    );

    final progress = widget.entry.lastEpisodeNumber.toInt();
    final total = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (detail) => detail.anime.totalEpisodes,
      ),
      orElse: () => null,
    );

    final progressText = total != null
        ? context.l10n.historyProgressUpTo(progress, total)
        : context.l10n.historyProgressLastWatched(progress);

    final timeAgo = _formatTimeAgo(widget.entry.lastAccessedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        splashColor: KumoriyaColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surfaceDim,
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                    child: KumoriyaCachedImage(
                      url: imageUrl,
                      bucket: KumoriyaImageCacheBucket.artwork,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: KumoriyaColors.primary,
                        borderRadius: BorderRadius.circular(
                          KumoriyaRadius.full,
                        ),
                      ),
                      child: Text(
                        'EP ${widget.entry.lastEpisodeNumber.toInt()}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progressText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KumoriyaColors.textDisabled,
                    ),
                  ),
                  if (widget.onDelete != null)
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        onPressed: widget.onDelete,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: KumoriyaColors.navInactive,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
