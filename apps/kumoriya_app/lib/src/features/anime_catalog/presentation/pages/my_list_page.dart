import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import 'anime_detail_page.dart';

class MyListPage extends ConsumerWidget {
  const MyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: KumoriyaColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'My List',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: KumoriyaColors.textPrimary,
                  ),
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: KumoriyaColors.primary,
                labelColor: KumoriyaColors.primary,
                unselectedLabelColor: KumoriyaColors.textDisabled,
                dividerColor: KumoriyaColors.borderSubtle,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                tabs: <Tab>[
                  Tab(text: context.l10n.myListHistory),
                  Tab(text: context.l10n.myListFavorites),
                  Tab(text: context.l10n.myListSubscribed),
                  Tab(text: context.l10n.myListDownloads),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _HistoryTab(),
                    _FavoritesTab(),
                    _SubscribedTab(),
                    _DownloadsTab(),
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

// ─── History Tab ────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(continueWatchingProvider);

    return historyState.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        message: context.l10n.genericLoadFailure,
        onRetry: () => ref.invalidate(continueWatchingProvider),
      ),
      data: (result) => result.fold(
        onFailure: (error) => ErrorStateView(
          message: mapErrorMessage(context, error),
          onRetry: () => ref.invalidate(continueWatchingProvider),
        ),
        onSuccess: (history) {
          if (history.isEmpty) {
            return const Center(
              child: EmptyStateView(message: 'No watch history yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = history[index];
              return _HistoryRow(
                entry: entry,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnimeDetailPage(anilistId: entry.anilistId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Favorites Tab ──────────────────────────────────────────────────────────

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
              child: EmptyStateView(message: context.l10n.myListFavoritesEmpty),
            );
          }

          final sortedIds = ids.toList();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: sortedIds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _AnimeLibraryRow(
                anilistId: sortedIds[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AnimeDetailPage(anilistId: sortedIds[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Subscribed Tab ─────────────────────────────────────────────────────────

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
                message: context.l10n.myListSubscribedEmpty,
              ),
            );
          }

          final sortedIds = ids.toList();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: sortedIds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _AnimeLibraryRow(
                anilistId: sortedIds[index],
                showNotificationBadge: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AnimeDetailPage(anilistId: sortedIds[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Downloads Tab ───────────────────────────────────────────────────────────

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(allDownloadTasksProvider);

    return tasksState.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        message: context.l10n.genericLoadFailure,
        onRetry: () => ref.invalidate(allDownloadTasksProvider),
      ),
      data: (result) => result.fold(
        onFailure: (error) => ErrorStateView(
          message: mapErrorMessage(context, error),
          onRetry: () => ref.invalidate(allDownloadTasksProvider),
        ),
        onSuccess: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: EmptyStateView(message: context.l10n.myListDownloadsEmpty),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _DownloadRow(task: task);
            },
          );
        },
      ),
    );
  }
}

class _DownloadRow extends ConsumerStatefulWidget {
  const _DownloadRow({required this.task});

  final DownloadTask task;

  @override
  ConsumerState<_DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends ConsumerState<_DownloadRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final detailState = ref.watch(animeDetailProvider(task.anilistId));

    final title = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => 'AniList #${task.anilistId}',
        onSuccess: (detail) =>
            detail.anime.title.english ?? detail.anime.title.romaji,
      ),
      orElse: () => 'AniList #${task.anilistId}',
    );

    final imageUrl = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (detail) =>
            detail.anime.coverImageUrl ?? detail.bannerImageUrl,
      ),
      orElse: () => null,
    );

    final statusText = _statusText(context, task);
    final statusColor = _statusColor(task.status);
    final progress = _downloadProgress(task);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AnimeDetailPage(anilistId: task.anilistId),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Column(
            children: <Widget>[
              Row(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: KumoriyaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'EP ${task.episodeNumber.toInt()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: KumoriyaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(context, ref, task),
                ],
              ),
              if (progress != null) ...<Widget>[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
  ) {
    final manager = ref.read(downloadManagerProvider);

    switch (task.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause_rounded, size: 18),
          tooltip: context.l10n.downloadPause,
          onPressed: () async {
            await manager.pause(task.id);
            ref.invalidate(allDownloadTasksProvider);
          },
        );
      case DownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          tooltip: context.l10n.downloadResume,
          onPressed: () async {
            await manager.resume(task.id);
            ref.invalidate(allDownloadTasksProvider);
          },
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          tooltip: context.l10n.downloadRetry,
          onPressed: () async {
            await manager.retry(task.id);
            ref.invalidate(allDownloadTasksProvider);
          },
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          tooltip: context.l10n.downloadDelete,
          onPressed: () async {
            await manager.deleteCompleted(task.id);
            ref.invalidate(allDownloadTasksProvider);
          },
        );
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: context.l10n.downloadCancel,
          onPressed: () async {
            await manager.cancel(task.id);
            ref.invalidate(allDownloadTasksProvider);
          },
        );
    }
  }

  String _statusText(BuildContext context, DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.pending:
        return context.l10n.downloadPending;
      case DownloadStatus.downloading:
        return context.l10n.downloadInProgress;
      case DownloadStatus.paused:
        return context.l10n.downloadPaused;
      case DownloadStatus.completed:
        return context.l10n.downloadComplete;
      case DownloadStatus.failed:
        return context.l10n.downloadFailed;
    }
  }

  Color _statusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return KumoriyaColors.textMuted;
      case DownloadStatus.downloading:
        return KumoriyaColors.primary;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }

  double? _downloadProgress(DownloadTask task) {
    if (task.status == DownloadStatus.completed) return 1.0;
    if (task.totalBytes == null || task.totalBytes == 0) return null;
    if (task.downloadedBytes == null) return null;
    return (task.downloadedBytes! / task.totalBytes!).clamp(0.0, 1.0);
  }
}

// ─── Shared row widgets ──────────────────────────────────────────────────────

class _AnimeLibraryRow extends ConsumerStatefulWidget {
  const _AnimeLibraryRow({
    required this.anilistId,
    required this.onTap,
    this.showNotificationBadge = false,
  });

  final int anilistId;
  final VoidCallback onTap;
  final bool showNotificationBadge;

  @override
  ConsumerState<_AnimeLibraryRow> createState() => _AnimeLibraryRowState();
}

class _AnimeLibraryRowState extends ConsumerState<_AnimeLibraryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));

    final title = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => 'AniList #${widget.anilistId}',
        onSuccess: (detail) =>
            detail.anime.title.english ?? detail.anime.title.romaji,
      ),
      orElse: () => 'AniList #${widget.anilistId}',
    );

    final imageUrl = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (detail) =>
            detail.anime.coverImageUrl ?? detail.bannerImageUrl,
      ),
      orElse: () => null,
    );

    final episodes = detailState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (detail) => detail.anime.totalEpisodes,
      ),
      orElse: () => null,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    if (episodes != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        '$episodes ${context.l10n.episodesWord}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: KumoriyaColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.showNotificationBadge) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 16,
                  color: KumoriyaColors.primary,
                ),
              ],
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: KumoriyaColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends ConsumerStatefulWidget {
  const _HistoryRow({required this.entry, required this.onTap});

  final AnimeWatchHistory entry;
  final VoidCallback onTap;

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
        onFailure: (_) => 'AniList #${widget.entry.anilistId}',
        onSuccess: (detail) =>
            detail.anime.title.english ?? detail.anime.title.romaji,
      ),
      orElse: () => 'AniList #${widget.entry.anilistId}',
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
        ? 'Up to EP $progress / $total'
        : 'Last watched EP $progress';

    final timeAgo = _formatTimeAgo(widget.entry.lastAccessedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surface.withValues(alpha: 0.55),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KumoriyaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgo,
                style: const TextStyle(
                  fontSize: 11,
                  color: KumoriyaColors.textDisabled,
                ),
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
