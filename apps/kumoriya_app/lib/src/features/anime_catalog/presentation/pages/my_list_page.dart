import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../downloads/application/download_manager_service.dart';
import '../../../player/presentation/pages/player_page.dart';
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
          final children = <Widget>[
            const _DownloadDirectoryCard(),
            const SizedBox(height: 16),
          ];

          if (tasks.isEmpty) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(top: 36),
                child: EmptyStateView(
                  message: context.l10n.myListDownloadsEmpty,
                ),
              ),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: children,
            );
          }

          // Split into active (non-completed) and completed.
          final active = tasks
              .where((t) => t.status != DownloadStatus.completed)
              .toList();
          final completed = tasks
              .where((t) => t.status == DownloadStatus.completed)
              .toList();

          // Group completed by anilistId.
          final groupedCompleted = <int, List<DownloadTask>>{};
          for (final t in completed) {
            groupedCompleted.putIfAbsent(t.anilistId, () => []).add(t);
          }
          // Sort episodes within each group.
          for (final list in groupedCompleted.values) {
            list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
          }

          children.addAll(<Widget>[
            // ── Active downloads ──
            if (active.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.l10n.downloadInProgress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: KumoriyaColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(downloadManagerProvider).cancelAll();
                        ref.invalidate(allDownloadTasksProvider);
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(context.l10n.downloadCancel),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              ...active.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActiveDownloadRow(task: t),
                ),
              ),
              if (groupedCompleted.isNotEmpty) const SizedBox(height: 12),
            ],
            // ── Completed downloads grouped by anime ──
            ...groupedCompleted.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CompletedAnimeCard(
                  anilistId: entry.key,
                  episodes: entry.value,
                ),
              ),
            ),
          ]);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: children,
          );
        },
      ),
    );
  }
}

class _DownloadDirectoryCard extends ConsumerWidget {
  const _DownloadDirectoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directoryInfoState = ref.watch(downloadDirectoryInfoProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: directoryInfoState.when(
        loading: () => const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.downloadFolderTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: KumoriyaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.genericLoadFailure,
              style: const TextStyle(color: KumoriyaColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(downloadDirectoryInfoProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
        data: (info) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.folder_copy_outlined,
                  color: KumoriyaColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.downloadFolderTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: KumoriyaColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: KumoriyaColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    info.isCustom
                        ? context.l10n.downloadFolderCustom
                        : context.l10n.downloadFolderDefault,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: KumoriyaColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.downloadFolderDescription,
              style: const TextStyle(
                color: KumoriyaColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KumoriyaColors.background.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                border: Border.all(color: KumoriyaColors.borderSubtle),
              ),
              child: SelectableText(
                info.path,
                style: const TextStyle(
                  fontSize: 12,
                  color: KumoriyaColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () async {
                    final result = await ref
                        .read(downloadDirectoryServiceProvider)
                        .selectDirectory();
                    if (!context.mounted) {
                      return;
                    }

                    result.fold(
                      onFailure: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.code ==
                                      'download.directory_permission_denied'
                                  ? context.l10n.downloadFolderPermissionDenied
                                  : mapErrorMessage(context, error),
                            ),
                          ),
                        );
                      },
                      onSuccess: (outcome) {
                        ref.invalidate(downloadDirectoryInfoProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              outcome.changed
                                  ? context.l10n.downloadFolderSaved
                                  : context
                                        .l10n
                                        .downloadFolderSelectionCancelled,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(context.l10n.downloadFolderChange),
                ),
                if (info.isCustom)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await ref
                          .read(downloadDirectoryServiceProvider)
                          .resetToDefault();
                      if (!context.mounted) {
                        return;
                      }

                      result.fold(
                        onFailure: (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(mapErrorMessage(context, error)),
                            ),
                          );
                        },
                        onSuccess: (_) {
                          ref.invalidate(downloadDirectoryInfoProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.downloadFolderResetDone,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(context.l10n.downloadFolderReset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active download row (flat, with progress) ──────────────────────────────

class _ActiveDownloadRow extends ConsumerStatefulWidget {
  const _ActiveDownloadRow({required this.task});
  final DownloadTask task;

  @override
  ConsumerState<_ActiveDownloadRow> createState() => _ActiveDownloadRowState();
}

class _ActiveDownloadRowState extends ConsumerState<_ActiveDownloadRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final detailState = ref.watch(animeDetailProvider(task.anilistId));

    final liveProgress = ref
        .watch(downloadProgressByTaskProvider(task.id))
        .maybeWhen(data: (e) => e, orElse: () => null);

    final title = detailState.maybeWhen(
      data: (r) => r.fold(
        onFailure: (_) => task.animeTitle ?? 'AniList #${task.anilistId}',
        onSuccess: (d) => d.anime.title.english ?? d.anime.title.romaji,
      ),
      orElse: () => task.animeTitle ?? 'AniList #${task.anilistId}',
    );

    final imageUrl = detailState.maybeWhen(
      data: (r) => r.fold(
        onFailure: (_) => null,
        onSuccess: (d) => d.anime.coverImageUrl ?? d.bannerImageUrl,
      ),
      orElse: () => null,
    );

    final statusColor = _dlStatusColor(task.status);
    final progress = liveProgress?.fraction ?? _dlProgress(task);
    final label = _dlLabel(task, liveProgress);

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
                      width: 48,
                      height: 48,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: KumoriyaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EP ${task.episodeNumber.toInt()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: KumoriyaColors.textMuted,
                          ),
                        ),
                        if (label != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: KumoriyaColors.textDisabled,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dlStatusText(context, task),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  _buildActiveAction(context, ref, task),
                ],
              ),
              if (task.status == DownloadStatus.downloading ||
                  task.status == DownloadStatus.paused) ...<Widget>[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (progress != null && progress > 0) ? progress : null,
                    minHeight: 4,
                    backgroundColor: KumoriyaColors.borderSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveAction(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
  ) {
    final manager = ref.read(downloadManagerProvider);
    switch (task.status) {
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.pause_rounded, size: 18),
              tooltip: context.l10n.downloadPause,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              onPressed: () async {
                await manager.pause(task.id);
                ref.invalidate(allDownloadTasksProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: context.l10n.downloadCancel,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              onPressed: () async {
                await manager.cancel(task.id);
                ref.invalidate(allDownloadTasksProvider);
              },
            ),
          ],
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
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: context.l10n.downloadCancel,
          onPressed: () async {
            await manager.cancel(task.id);
            ref.invalidate(allDownloadTasksProvider);
          },
        );
      case DownloadStatus.completed:
        return const SizedBox.shrink();
    }
  }
}

// ─── Completed anime card (grouped episodes) ────────────────────────────────

class _CompletedAnimeCard extends ConsumerStatefulWidget {
  const _CompletedAnimeCard({required this.anilistId, required this.episodes});

  final int anilistId;
  final List<DownloadTask> episodes;

  @override
  ConsumerState<_CompletedAnimeCard> createState() =>
      _CompletedAnimeCardState();
}

class _CompletedAnimeCardState extends ConsumerState<_CompletedAnimeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));

    final title = detailState.maybeWhen(
      data: (r) => r.fold(
        onFailure: (_) =>
            widget.episodes.first.animeTitle ?? 'AniList #${widget.anilistId}',
        onSuccess: (d) => d.anime.title.english ?? d.anime.title.romaji,
      ),
      orElse: () =>
          widget.episodes.first.animeTitle ?? 'AniList #${widget.anilistId}',
    );

    final imageUrl = detailState.maybeWhen(
      data: (r) => r.fold(
        onFailure: (_) => null,
        onSuccess: (d) => d.anime.coverImageUrl ?? d.bannerImageUrl,
      ),
      orElse: () => null,
    );

    final totalSize = widget.episodes.fold<int>(
      0,
      (sum, t) => sum + (t.totalBytes ?? t.downloadedBytes ?? 0),
    );

    return Container(
      decoration: BoxDecoration(
        color: KumoriyaColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        children: <Widget>[
          // ── Card header ──
          InkWell(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: KumoriyaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.episodes.length} ${widget.episodes.length == 1 ? 'episodio' : 'episodios'}'
                              ' · ${_fmtBytes(totalSize)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: KumoriyaColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: KumoriyaColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded episode list ──
          if (_expanded) ...<Widget>[
            const Divider(height: 1, color: KumoriyaColors.borderSubtle),
            ...widget.episodes.map(
              (task) => _CompletedEpisodeTile(
                task: task,
                onDelete: () {
                  ref.read(downloadManagerProvider).deleteCompleted(task.id);
                  ref.invalidate(allDownloadTasksProvider);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Single completed episode tile ──────────────────────────────────────────

class _CompletedEpisodeTile extends StatelessWidget {
  const _CompletedEpisodeTile({required this.task, required this.onDelete});

  final DownloadTask task;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final quality = task.qualityLabel;
    final server = task.serverName;
    final size = task.totalBytes ?? task.downloadedBytes ?? 0;

    return InkWell(
      onTap: () => _playDownloaded(context, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            // Play icon
            const Icon(
              Icons.play_circle_filled_rounded,
              size: 28,
              color: KumoriyaColors.primary,
            ),
            const SizedBox(width: 10),
            // Episode info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Episodio ${task.episodeNumber.toInt()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KumoriyaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (server != null) server,
                      if (quality != null) quality,
                      _fmtBytes(size),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 10,
                      color: KumoriyaColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              tooltip: context.l10n.downloadDelete,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _playDownloaded(BuildContext context, DownloadTask task) {
    if (task.filePath == null) return;
    final file = File(task.filePath!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: task.anilistId,
          animeTitle:
              task.animeTitle ?? 'Episode ${task.episodeNumber.toInt()}',
          episodeNumber: task.episodeNumber.toInt().toString(),
          sourcePluginId: task.sourcePluginId ?? 'offline',
          serverName: task.serverName ?? 'Downloaded',
          resolved: ResolvedServerLinkResult(
            resolverId: 'offline',
            resolverName: 'Downloaded',
            streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
          ),
        ),
      ),
    );
  }
}

// ─── Download helpers ────────────────────────────────────────────────────────

String _dlStatusText(BuildContext context, DownloadTask task) {
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

Color _dlStatusColor(DownloadStatus status) {
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

double? _dlProgress(DownloadTask task) {
  if (task.status == DownloadStatus.completed) return 1.0;
  if (task.totalBytes == null || task.totalBytes == 0) return null;
  if (task.downloadedBytes == null) return null;
  return (task.downloadedBytes! / task.totalBytes!).clamp(0.0, 1.0);
}

String? _dlLabel(DownloadTask task, DownloadProgressEvent? live) {
  if (task.status == DownloadStatus.completed) {
    return _fmtBytes(task.totalBytes ?? task.downloadedBytes ?? 0);
  }
  if (task.status != DownloadStatus.downloading &&
      task.status != DownloadStatus.paused) {
    return null;
  }

  final downloaded = live?.downloadedBytes ?? task.downloadedBytes ?? 0;
  final total = live?.totalBytes ?? task.totalBytes ?? 0;
  final speed = live?.bytesPerSecond ?? 0;

  final parts = <String>[];
  if (total > 0) {
    final pct = ((downloaded / total) * 100).toStringAsFixed(0);
    parts.add('$pct%');
    parts.add('${_fmtBytes(downloaded)} / ${_fmtBytes(total)}');
  } else if (downloaded > 0) {
    parts.add(_fmtBytes(downloaded));
  }
  if (speed > 0 && task.status == DownloadStatus.downloading) {
    parts.add('${_fmtBytes(speed)}/s');
  }
  return parts.isNotEmpty ? parts.join(' · ') : null;
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
