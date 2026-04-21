import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/translated_dynamic_text.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../../downloads/application/download_manager_service.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import 'anime_detail_page.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

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
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.l10n.downloadsTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.retry,
                      onPressed: () => _refreshDownloads(ref),
                      icon: const Icon(
                        KumoriyaIcons.sync,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  context.l10n.downloadsSubtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: KumoriyaColors.textTertiary,
                  ),
                ),
              ),
              TabBar(
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                indicatorColor: KumoriyaColors.primary,
                labelColor: KumoriyaColors.primary,
                unselectedLabelColor: KumoriyaColors.textSecondary,
                dividerColor: KumoriyaColors.borderSubtle,
                tabs: <Tab>[
                  Tab(text: context.l10n.downloadsTabCompleted),
                  Tab(text: context.l10n.downloadsTabActive),
                  Tab(text: context.l10n.downloadsTabQueue),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _CompletedTab(),
                    _ActiveTab(),
                    _QueueTab(),
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

// ─── Per-tab ConsumerWidgets (each watches only its own provider) ────────────

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(completedDownloadTasksProvider);

    return StateTransitionSwitcher(
      stateKey: state.isLoading
          ? 'loading'
          : state.hasError
          ? 'error'
          : 'content',
      child: state.when(
        loading: () => const LoadingStateView(),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: () => _refreshDownloads(ref),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => _refreshDownloads(ref),
          ),
          onSuccess: (tasks) {
            final grouped = _groupCompletedTasks(tasks);
            return _CompletedTabContent(grouped: grouped, ref: ref);
          },
        ),
      ),
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeDownloadTasksProvider);

    return StateTransitionSwitcher(
      stateKey: state.isLoading
          ? 'loading'
          : state.hasError
          ? 'error'
          : 'content',
      child: state.when(
        loading: () => const LoadingStateView(),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: () => _refreshDownloads(ref),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => _refreshDownloads(ref),
          ),
          onSuccess: (tasks) => _ActiveTabContent(tasks: tasks, ref: ref),
        ),
      ),
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(queuedDownloadTasksProvider);

    return StateTransitionSwitcher(
      stateKey: state.isLoading
          ? 'loading'
          : state.hasError
          ? 'error'
          : 'content',
      child: state.when(
        loading: () => const LoadingStateView(),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: () => _refreshDownloads(ref),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => _refreshDownloads(ref),
          ),
          onSuccess: (tasks) => _QueueTabContent(tasks: tasks, ref: ref),
        ),
      ),
    );
  }
}

// ─── Tab content widgets ──────────────────────────────────────────────────────

class _ActiveTabContent extends StatelessWidget {
  const _ActiveTabContent({required this.tasks, required this.ref});

  final List<DownloadTask> tasks;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshDownloads(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: EmptyStateView(
                icon: Icons.download_rounded,
                message: context.l10n.downloadsActiveEmpty,
                actionLabel: context.l10n.retry,
                onAction: () => _refreshDownloads(ref),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDownloads(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActiveDownloadsHeader(),
          ),
          ...tasks.map(
            (task) => Padding(
              key: ValueKey('active-${task.id}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActiveDownloadRow(task: task),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTabContent extends StatelessWidget {
  const _QueueTabContent({required this.tasks, required this.ref});

  final List<DownloadTask> tasks;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshDownloads(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: EmptyStateView(
                icon: Icons.hourglass_empty_rounded,
                message: context.l10n.downloadsQueueEmpty,
                actionLabel: context.l10n.retry,
                onAction: () => _refreshDownloads(ref),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDownloads(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.downloadsTabQueue,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (tasks.any((t) => t.status == DownloadStatus.failed))
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(downloadManagerProvider).retryAllFailed();
                      _invalidateTabProviders(ref);
                    },
                    icon: const Icon(KumoriyaIcons.sync, size: 16),
                    label: Text(context.l10n.downloadRetryAllFailed),
                    style: TextButton.styleFrom(
                      foregroundColor: KumoriyaColors.primary,
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: KumoriyaColors.surfaceElevated,
                        title: Text(
                          context.l10n.downloadClearQueueConfirmTitle,
                        ),
                        content: Text(
                          context.l10n.downloadClearQueueConfirmMessage,
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(context.l10n.cancelAction),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: KumoriyaColors.statusDanger,
                            ),
                            child: Text(context.l10n.downloadClearQueue),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(downloadManagerProvider).clearQueue();
                      _invalidateTabProviders(ref);
                    }
                  },
                  icon: const Icon(KumoriyaIcons.close, size: 16),
                  label: Text(context.l10n.downloadClearQueue),
                  style: TextButton.styleFrom(
                    foregroundColor: KumoriyaColors.statusDanger,
                    textStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          ...tasks.map(
            (task) => Padding(
              key: ValueKey('queue-${task.id}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActiveDownloadRow(task: task),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTabContent extends StatelessWidget {
  const _CompletedTabContent({required this.grouped, required this.ref});

  final Map<int, List<DownloadTask>> grouped;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refreshDownloads(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: EmptyStateView(
                icon: Icons.download_done_rounded,
                message: context.l10n.downloadsCompletedEmpty,
                actionLabel: context.l10n.retry,
                onAction: () => _refreshDownloads(ref),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDownloads(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: grouped.entries
            .map(
              (entry) => Padding(
                key: ValueKey('completed-${entry.key}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _CompletedAnimeCard(
                  anilistId: entry.key,
                  episodes: entry.value,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Active downloads header ─────────────────────────────────────────────────

class _ActiveDownloadsHeader extends ConsumerWidget {
  const _ActiveDownloadsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggregateProgress = ref
        .watch(downloadAggregateProgressProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const DownloadAggregateProgress.empty(),
        );

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            context.l10n.downloadInProgress,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (aggregateProgress.bytesPerSecond > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${_fmtBytes(aggregateProgress.bytesPerSecond)}/s',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KumoriyaColors.textMuted,
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => ref.read(downloadManagerProvider).cancelAll(),
          icon: const Icon(KumoriyaIcons.close, size: 16),
          label: Text(context.l10n.downloadCancel),
          style: TextButton.styleFrom(
            foregroundColor: KumoriyaColors.statusDanger,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }
}

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

    final liveProgress = ref
        .watch(downloadProgressByTaskProvider(task.id))
        .maybeWhen(data: (e) => e, orElse: () => null);
    final localCoverPath = ref
        .watch(downloadCoverPathProvider(task.anilistId))
        .maybeWhen(data: (value) => value, orElse: () => null);

    final title = task.animeTitle ?? context.l10n.loadingGeneric;

    final statusColor = _dlStatusColor(task.status);
    final progress = liveProgress?.fraction ?? _dlProgress(task);
    final label = _dlLabel(task, liveProgress);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        splashColor: KumoriyaColors.primary.withValues(alpha: 0.08),
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
                : KumoriyaColors.surfaceDim,
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
                      url: null,
                      bucket: KumoriyaImageCacheBucket.artwork,
                      localFileFallback: localCoverPath,
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
                          context.l10n.downloadEpisodeLabel(
                            task.episodeNumber.toInt(),
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: KumoriyaColors.textMuted,
                          ),
                        ),
                        if (task.episodeTitle != null &&
                            task.episodeTitle!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          TranslatedDynamicText(
                            task.episodeTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: KumoriyaColors.textDisabled,
                            ),
                          ),
                        ],
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
                        if (task.status == DownloadStatus.failed &&
                            task.errorMessage != null &&
                            task.errorMessage!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            _downloadErrorSummary(task.errorMessage!),
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 10,
                              color: KumoriyaColors.statusDanger,
                              fontWeight: FontWeight.w600,
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
                  _buildActiveAction(context, task),
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

  Widget _buildActiveAction(BuildContext context, DownloadTask task) {
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
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: context.l10n.downloadCancel,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              onPressed: () async {
                await manager.cancel(task.id);
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
          },
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          tooltip: context.l10n.downloadRetry,
          onPressed: () async {
            await manager.retryFailed(task.id);
          },
        );
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: context.l10n.downloadCancel,
          onPressed: () async {
            await manager.cancel(task.id);
          },
        );
      case DownloadStatus.completed:
        return const SizedBox.shrink();
    }
  }
}

// ─── Completed anime card (grouped episodes) ─────────────────────────────────

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
    final title =
        widget.episodes.first.animeTitle ?? context.l10n.loadingGeneric;
    final localCoverPath = ref
        .watch(downloadCoverPathProvider(widget.anilistId))
        .maybeWhen(data: (value) => value, orElse: () => null);

    final totalSize = widget.episodes.fold<int>(
      0,
      (sum, t) => sum + (t.totalBytes ?? t.downloadedBytes ?? 0),
    );

    return Container(
      decoration: BoxDecoration(
        color: KumoriyaColors.surfaceDim,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        children: <Widget>[
          // ── Card header ──
          InkWell(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: () => _showAnimeContextMenu(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                    child: KumoriyaCachedImage(
                      url: null,
                      bucket: KumoriyaImageCacheBucket.artwork,
                      localFileFallback: localCoverPath,
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
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: KumoriyaColors.statusSuccess,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${context.l10n.downloadEpisodesCount(widget.episodes.length)} · ${_fmtBytes(totalSize)}',
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
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAnimeContextMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(context.l10n.downloadViewAnimeDetails),
              onTap: () => Navigator.of(ctx).pop('details'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_rounded,
                color: KumoriyaColors.statusDanger,
              ),
              title: Text(
                context.l10n.downloadDeleteAllEpisodes,
                style: const TextStyle(color: KumoriyaColors.statusDanger),
              ),
              onTap: () => Navigator.of(ctx).pop('delete_all'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'details') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AnimeDetailPage(anilistId: widget.anilistId),
        ),
      );
    } else if (action == 'delete_all') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.downloadDeleteAllConfirmTitle),
          content: Text(context.l10n.downloadDeleteAllConfirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: KumoriyaColors.statusDanger,
              ),
              child: Text(context.l10n.deleteAction),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final manager = ref.read(downloadManagerProvider);
        for (final ep in widget.episodes) {
          manager.deleteCompleted(ep.id);
        }
      }
    }
  }
}

// ─── Single completed episode tile ───────────────────────────────────────────

class _CompletedEpisodeTile extends ConsumerWidget {
  const _CompletedEpisodeTile({required this.task, required this.onDelete});

  final DownloadTask task;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = task.qualityLabel;
    final server = task.serverName;
    final size = task.totalBytes ?? task.downloadedBytes ?? 0;

    return Dismissible(
      key: ValueKey('ep-tile-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.downloadDeleteConfirmTitle),
            content: Text(context.l10n.downloadDeleteConfirmMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.l10n.cancelAction),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: KumoriyaColors.statusDanger,
                ),
                child: Text(context.l10n.downloadDelete),
              ),
            ],
          ),
        );
        return confirmed == true;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: KumoriyaColors.statusDanger,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => _playDownloaded(context, ref, task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.play_circle_filled_rounded,
                size: 28,
                color: KumoriyaColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.downloadEpisodeLabel(
                        task.episodeNumber.toInt(),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    if (task.episodeTitle != null &&
                        task.episodeTitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      TranslatedDynamicText(
                        task.episodeTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: KumoriyaColors.textDisabled,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      [server, quality, _fmtBytes(size)].nonNulls.join(' · '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: KumoriyaColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: context.l10n.downloadDelete,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.l10n.downloadDeleteConfirmTitle),
                      content: Text(context.l10n.downloadDeleteConfirmMessage),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(context.l10n.cancelAction),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: KumoriyaColors.statusDanger,
                          ),
                          child: Text(context.l10n.downloadDelete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playDownloaded(BuildContext context, WidgetRef ref, DownloadTask task) {
    if (task.filePath == null) return;
    final file = File(task.filePath!);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.downloadFileNotFound)),
      );
      // Clean up the orphan DB record — the file has been removed externally.
      ref.read(downloadManagerProvider).deleteCompleted(task.id);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: task.anilistId,
          animeTitle:
              task.animeTitle ??
              context.l10n.downloadEpisodeLabel(task.episodeNumber.toInt()),
          episodeNumber: task.episodeNumber.toInt().toString(),
          persistSelection: false,
          sourcePluginId: task.sourcePluginId ?? 'offline',
          serverName: task.serverName ?? context.l10n.downloadedSourceLabel,
          episodeTitle: task.episodeTitle,
          resolved: ResolvedServerLinkResult(
            resolverId: 'offline',
            resolverName: context.l10n.downloadedSourceLabel,
            streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
          ),
        ),
      ),
    );
  }
}

// ─── Download helpers ─────────────────────────────────────────────────────────

Future<void> _refreshDownloads(WidgetRef ref) async {
  final manager = ref.read(downloadManagerProvider);
  await manager.syncDownloadedLibrary();
  _invalidateTabProviders(ref);
}

void _invalidateTabProviders(WidgetRef ref) {
  try {
    ref.invalidate(completedDownloadTasksProvider);
    ref.invalidate(activeDownloadTasksProvider);
    ref.invalidate(queuedDownloadTasksProvider);
  } catch (_) {
    // Widget may have been unmounted during the async operation.
  }
}

Map<int, List<DownloadTask>> _groupCompletedTasks(List<DownloadTask> tasks) {
  final groupedCompleted = <int, List<DownloadTask>>{};
  for (final task in tasks) {
    groupedCompleted
        .putIfAbsent(task.anilistId, () => <DownloadTask>[])
        .add(task);
  }
  for (final list in groupedCompleted.values) {
    list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }
  return groupedCompleted;
}

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
      return KumoriyaColors.statusWarning;
    case DownloadStatus.completed:
      return KumoriyaColors.statusSuccess;
    case DownloadStatus.failed:
      return KumoriyaColors.statusDanger;
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

String _downloadErrorSummary(String rawError) {
  final compact = rawError
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(
        RegExp(
          r'^(Exception|HttpException|SocketException|ClientException|FileSystemException|TimeoutException):\s*',
        ),
        '',
      )
      .trim();
  final normalized = compact.toLowerCase();

  if (normalized.contains('http 403') && !normalized.contains('forbidden')) {
    return '$compact (HTTP 403 Forbidden)';
  }
  if (normalized.contains('http 404') && !normalized.contains('not found')) {
    return '$compact (HTTP 404 Not Found)';
  }
  if (compact.isEmpty) {
    return 'No se pudo completar la descarga. Intenta de nuevo.';
  }
  return compact;
}
