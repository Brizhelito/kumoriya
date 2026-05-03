import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_reader/kumoriya_reader.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:path/path.dart' as p;

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../manga_downloads/domain/cbz_unpacker.dart';
import '../../../manga_downloads/presentation/providers/manga_download_providers.dart';
import '../providers/manga_catalog_providers.dart';

/// Lists every manga chapter the user has queued for offline reading
/// (Slice 11). Tasks are grouped by manga title so the page stays
/// readable when many chapters of the same series are queued.
///
/// Each row exposes:
///
/// - **Active** rows show a live progress bar and a `cancel` button.
/// - **Completed** rows show a `delete` button (which removes the
///   CBZ on disk).
/// - **Failed** rows show a `retry` button.
///
/// The page subscribes to [mangaDownloadTasksProvider]; the manager
/// pushes a refreshed snapshot on every status transition.
class MangaDownloadsPage extends ConsumerWidget {
  const MangaDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
                        l10n.mangaDownloadsTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.retry,
                      onPressed: () => _refreshMangaDownloads(ref),
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
                  _mangaDownloadsSubtitle(context),
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
                  Tab(text: l10n.downloadsTabCompleted),
                  Tab(text: l10n.downloadsTabActive),
                  Tab(text: l10n.downloadsTabQueue),
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

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(completedMangaDownloadTasksProvider);
    return _TasksStateView(
      state: state,
      emptyIcon: Icons.collections_bookmark_outlined,
      emptyMessage: _mangaDownloadsCompletedEmpty(context),
      contentBuilder: (tasks) => _CompletedMangaList(tasks: tasks),
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeMangaDownloadTasksProvider);
    return _TasksStateView(
      state: state,
      emptyIcon: Icons.download_rounded,
      emptyMessage: context.l10n.downloadsActiveEmpty,
      contentBuilder: (tasks) => _DownloadsList(
        tasks: tasks,
        header: _ActiveDownloadsHeader(tasks: tasks),
      ),
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(queuedMangaDownloadTasksProvider);
    return _TasksStateView(
      state: state,
      emptyIcon: Icons.hourglass_empty_rounded,
      emptyMessage: context.l10n.downloadsQueueEmpty,
      contentBuilder: (tasks) => _DownloadsList(
        tasks: tasks,
        header: _QueueHeader(tasks: tasks),
      ),
    );
  }
}

class _TasksStateView extends ConsumerWidget {
  const _TasksStateView({
    required this.state,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.contentBuilder,
  });

  final AsyncValue<Result<List<MangaDownloadTask>, KumoriyaError>> state;
  final IconData emptyIcon;
  final String emptyMessage;
  final Widget Function(List<MangaDownloadTask> tasks) contentBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onRetry: () => _refreshMangaDownloads(ref),
        ),
        data: (result) => result.fold(
          onFailure: (err) => ErrorStateView(
            message: err.message,
            onRetry: () => _refreshMangaDownloads(ref),
          ),
          onSuccess: (tasks) {
            if (tasks.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => _refreshMangaDownloads(ref),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 36),
                      child: EmptyStateView(
                        icon: emptyIcon,
                        message: emptyMessage,
                        actionLabel: context.l10n.retry,
                        onAction: () => _refreshMangaDownloads(ref),
                      ),
                    ),
                  ],
                ),
              );
            }
            return contentBuilder(tasks);
          },
        ),
      ),
    );
  }
}

class _DownloadsList extends ConsumerWidget {
  const _DownloadsList({required this.tasks, this.header});

  final List<MangaDownloadTask> tasks;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group by manga title (or anilistId when title is missing). Keys
    // are inserted in iteration order so newest-grouped-first follows
    // task ordering.
    final groups = <String, List<MangaDownloadTask>>{};
    for (final t in tasks) {
      final key = (t.mangaTitle?.isNotEmpty ?? false)
          ? t.mangaTitle!
          : '#${t.mangaAnilistId}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    final entries = groups.entries.toList();

    return RefreshIndicator(
      onRefresh: () => _refreshMangaDownloads(ref),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        itemCount: entries.length + (header == null ? 0 : 1),
        itemBuilder: (context, i) {
          if (header != null && i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: header,
            );
          }
          final entry = entries[i - (header == null ? 0 : 1)];
          return _MangaSection(title: entry.key, tasks: entry.value);
        },
      ),
    );
  }
}

class _CompletedMangaList extends ConsumerWidget {
  const _CompletedMangaList({required this.tasks});

  final List<MangaDownloadTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <int, List<MangaDownloadTask>>{};
    for (final task in tasks) {
      grouped
          .putIfAbsent(task.mangaAnilistId, () => <MangaDownloadTask>[])
          .add(task);
    }
    for (final chapters in grouped.values) {
      chapters.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    }

    return RefreshIndicator(
      onRefresh: () => _refreshMangaDownloads(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: grouped.entries
            .map(
              (entry) => Padding(
                key: ValueKey('completed-manga-${entry.key}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _CompletedMangaCard(
                  mangaAnilistId: entry.key,
                  chapters: entry.value,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CompletedMangaCard extends ConsumerStatefulWidget {
  const _CompletedMangaCard({
    required this.mangaAnilistId,
    required this.chapters,
  });

  final int mangaAnilistId;
  final List<MangaDownloadTask> chapters;

  @override
  ConsumerState<_CompletedMangaCard> createState() =>
      _CompletedMangaCardState();
}

class _CompletedMangaCardState extends ConsumerState<_CompletedMangaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title =
        widget.chapters.first.mangaTitle ?? '#${widget.mangaAnilistId}';
    final coverImageUrl = ref
        .watch(mangaDetailProvider(widget.mangaAnilistId))
        .maybeWhen(
          data: (detail) => detail.manga.coverImageUrl,
          orElse: () => null,
        );
    final totalSize = widget.chapters.fold<int>(
      0,
      (sum, task) => sum + _completedTaskSize(task),
    );

    return Container(
      decoration: BoxDecoration(
        color: KumoriyaColors.surfaceDim,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: () => _showMangaContextMenu(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  KumoriyaCachedImage(
                    url: coverImageUrl,
                    bucket: KumoriyaImageCacheBucket.artwork,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                    errorFallback: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: KumoriyaColors.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: KumoriyaColors.primary,
                        size: 28,
                      ),
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
                            const Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: KumoriyaColors.statusSuccess,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_downloadChaptersCount(context, widget.chapters.length)} · ${_fmtBytes(totalSize)}',
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
          if (_expanded) ...<Widget>[
            const Divider(height: 1, color: KumoriyaColors.borderSubtle),
            ...widget.chapters.map((task) => _CompletedChapterTile(task: task)),
          ],
        ],
      ),
    );
  }

  Future<void> _showMangaContextMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_rounded,
                color: KumoriyaColors.statusDanger,
              ),
              title: Text(
                _downloadDeleteAllChapters(context),
                style: const TextStyle(color: KumoriyaColors.statusDanger),
              ),
              onTap: () => Navigator.of(ctx).pop('delete_all'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action != 'delete_all') return;

    final confirmed = await _confirmDelete(
      context,
      title: _downloadDeleteAllConfirmTitle(context),
      message: _downloadDeleteAllConfirmMessage(context),
      actionLabel: context.l10n.deleteAction,
    );
    if (confirmed != true) return;

    final manager = ref.read(mangaDownloadManagerProvider);
    for (final chapter in widget.chapters) {
      await manager.delete(chapter.id);
    }
    _invalidateMangaDownloadProviders(ref);
  }
}

class _CompletedChapterTile extends ConsumerWidget {
  const _CompletedChapterTile({required this.task});

  final MangaDownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('chapter-tile-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await _confirmDelete(
          context,
          title: context.l10n.downloadDeleteConfirmTitle,
          message: _mangaDownloadDeleteMessage(context),
          actionLabel: context.l10n.downloadDelete,
        );
        return confirmed == true;
      },
      onDismissed: (_) async {
        await ref.read(mangaDownloadManagerProvider).delete(task.id);
        _invalidateMangaDownloadProviders(ref);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: KumoriyaColors.statusDanger,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => _openDownloadedChapter(context, ref, task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: KumoriyaColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _formatChapterLabel(task),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        task.sourceId,
                        if ((task.scanlator ?? '').trim().isNotEmpty)
                          task.scanlator!,
                        _fmtBytes(_completedTaskSize(task)),
                      ].join(' · '),
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
                  final confirmed = await _confirmDelete(
                    context,
                    title: context.l10n.downloadDeleteConfirmTitle,
                    message: _mangaDownloadDeleteMessage(context),
                    actionLabel: context.l10n.downloadDelete,
                  );
                  if (confirmed != true) return;
                  await ref.read(mangaDownloadManagerProvider).delete(task.id);
                  _invalidateMangaDownloadProviders(ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveDownloadsHeader extends ConsumerWidget {
  const _ActiveDownloadsHeader({required this.tasks});

  final List<MangaDownloadTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            context.l10n.downloadInProgress,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final manager = ref.read(mangaDownloadManagerProvider);
            for (final task in tasks) {
              await manager.cancel(task.id);
            }
            _invalidateMangaDownloadProviders(ref);
          },
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

class _QueueHeader extends ConsumerWidget {
  const _QueueHeader({required this.tasks});

  final List<MangaDownloadTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retryable = tasks.where(_canRetry).toList();
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            context.l10n.downloadsTabQueue,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (retryable.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final manager = ref.read(mangaDownloadManagerProvider);
              for (final task in retryable) {
                await manager.retry(task.id);
              }
              _invalidateMangaDownloadProviders(ref);
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
            final confirmed = await _confirmDelete(
              context,
              title: context.l10n.downloadClearQueueConfirmTitle,
              message: context.l10n.downloadClearQueueConfirmMessage,
              actionLabel: context.l10n.downloadClearQueue,
            );
            if (confirmed != true) return;
            final manager = ref.read(mangaDownloadManagerProvider);
            for (final task in tasks) {
              await manager.delete(task.id);
            }
            _invalidateMangaDownloadProviders(ref);
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
    );
  }
}

class _MangaSection extends StatelessWidget {
  const _MangaSection({required this.title, required this.tasks});

  final String title;
  final List<MangaDownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: KumoriyaColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        ...tasks.map((t) => _TaskRow(task: t)),
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final MangaDownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(mangaDownloadManagerProvider);
    final liveProgress = ref
        .watch(mangaDownloadProgressProvider(task.id))
        .maybeWhen(data: (event) => event, orElse: () => null);
    final pagesDownloaded =
        liveProgress?.pagesDownloaded ?? task.pagesDownloaded ?? 0;
    final pageCount = liveProgress?.totalPages ?? task.pageCount ?? 0;
    final effectiveStatus = liveProgress?.status ?? task.status;
    final chapterLabel = _formatChapter(task);
    final isActive =
        effectiveStatus == MangaDownloadStatus.downloading ||
        effectiveStatus == MangaDownloadStatus.packaging ||
        effectiveStatus == MangaDownloadStatus.paused ||
        effectiveStatus == MangaDownloadStatus.disconnected ||
        effectiveStatus == MangaDownloadStatus.pending;

    return InkWell(
      onTap: task.status == MangaDownloadStatus.completed
          ? () => _openDownloadedChapter(context, ref, task)
          : null,
      borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: KumoriyaColors.surface,
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          border: Border.all(color: KumoriyaColors.borderSubtle),
        ),
        child: Row(
          children: <Widget>[
            _StatusBadge(status: effectiveStatus),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chapterLabel,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusLine(
                    task: task,
                    pagesDownloaded: pagesDownloaded,
                    pageCount: pageCount,
                    status: effectiveStatus,
                  ),
                  if (isActive && pageCount > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                      child: LinearProgressIndicator(
                        value: pagesDownloaded / pageCount,
                        minHeight: 4,
                        color: _statusColor(effectiveStatus),
                        backgroundColor: KumoriyaColors.background,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (task.status == MangaDownloadStatus.completed)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: KumoriyaColors.primary,
                ),
              ),
            _ActionsMenu(
              task: task,
              onDelete: () async {
                final confirmed = await _confirmDelete(
                  context,
                  title: context.l10n.downloadDeleteConfirmTitle,
                  message: _mangaDownloadDeleteMessage(context),
                  actionLabel: context.l10n.downloadDelete,
                );
                if (confirmed == true) {
                  await manager.delete(task.id);
                  _invalidateMangaDownloadProviders(ref);
                }
              },
              onCancel: () async {
                await manager.cancel(task.id);
                _invalidateMangaDownloadProviders(ref);
              },
              onRetry: () async {
                await manager.retry(task.id);
                _invalidateMangaDownloadProviders(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatChapter(MangaDownloadTask t) {
    return _formatChapterLabel(t);
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.task,
    required this.pagesDownloaded,
    required this.pageCount,
    required this.status,
  });

  final MangaDownloadTask task;
  final int pagesDownloaded;
  final int pageCount;
  final MangaDownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      MangaDownloadStatus.pending => context.l10n.downloadPending,
      MangaDownloadStatus.downloading =>
        '${context.l10n.downloadInProgress} $pagesDownloaded / ${pageCount > 0 ? pageCount : '?'}',
      MangaDownloadStatus.paused => context.l10n.downloadPaused,
      MangaDownloadStatus.packaging => _mangaDownloadPackagingLabel(context),
      MangaDownloadStatus.disconnected => _mangaDownloadDisconnectedLabel(
        context,
      ),
      MangaDownloadStatus.partial => _mangaDownloadPartialLabel(context),
      MangaDownloadStatus.completed => _mangaDownloadSavedLabel(
        context,
        pageCount,
      ),
      MangaDownloadStatus.failed =>
        task.errorMessage ?? context.l10n.downloadFailed,
    };
    return Text(
      text,
      style: const TextStyle(color: KumoriyaColors.textMuted, fontSize: 12),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MangaDownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      MangaDownloadStatus.pending => Icons.schedule,
      MangaDownloadStatus.downloading => Icons.download_rounded,
      MangaDownloadStatus.paused => Icons.pause_circle_outline,
      MangaDownloadStatus.packaging => Icons.archive_outlined,
      MangaDownloadStatus.disconnected => Icons.cloud_off_outlined,
      MangaDownloadStatus.partial => Icons.refresh,
      MangaDownloadStatus.completed => Icons.check_circle,
      MangaDownloadStatus.failed => Icons.error_outline,
    };
    return Icon(icon, color: _statusColor(status), size: 22);
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.task,
    required this.onDelete,
    required this.onCancel,
    required this.onRetry,
  });

  final MangaDownloadTask task;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: KumoriyaColors.surface,
      icon: const Icon(Icons.more_vert, color: KumoriyaColors.textMuted),
      onSelected: (action) {
        switch (action) {
          case 'cancel':
            onCancel();
          case 'retry':
            onRetry();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) {
        final entries = <PopupMenuEntry<String>>[];
        switch (task.status) {
          case MangaDownloadStatus.pending:
          case MangaDownloadStatus.downloading:
          case MangaDownloadStatus.packaging:
          case MangaDownloadStatus.paused:
          case MangaDownloadStatus.disconnected:
            entries.add(
              PopupMenuItem(
                value: 'cancel',
                child: Text(context.l10n.downloadCancel),
              ),
            );
          case MangaDownloadStatus.failed:
          case MangaDownloadStatus.partial:
            entries.add(
              PopupMenuItem(
                value: 'retry',
                child: Text(context.l10n.downloadRetry),
              ),
            );
          case MangaDownloadStatus.completed:
            break;
        }
        entries.add(
          PopupMenuItem(
            value: 'delete',
            child: Text(context.l10n.downloadDelete),
          ),
        );
        return entries;
      },
    );
  }
}

Future<void> _refreshMangaDownloads(WidgetRef ref) async {
  _invalidateMangaDownloadProviders(ref);
}

void _invalidateMangaDownloadProviders(WidgetRef ref) {
  ref.invalidate(mangaDownloadTasksProvider);
  ref.invalidate(completedMangaDownloadTasksProvider);
  ref.invalidate(activeMangaDownloadTasksProvider);
  ref.invalidate(queuedMangaDownloadTasksProvider);
}

Future<bool?> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: KumoriyaColors.surfaceElevated,
      title: Text(title),
      content: Text(message),
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
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

Future<void> _openDownloadedChapter(
  BuildContext context,
  WidgetRef ref,
  MangaDownloadTask task,
) async {
  final cbzPath = task.cbzPath;
  if (cbzPath == null || cbzPath.isEmpty || !await File(cbzPath).exists()) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.downloadFileNotFound)));
    await ref.read(mangaDownloadManagerProvider).delete(task.id);
    _invalidateMangaDownloadProviders(ref);
    return;
  }

  final root = await ref.read(mangaDownloadsRootDirProvider)();
  final extractDir = Directory(p.join(root.path, '_extracted', task.id));
  final unpack = await CbzUnpacker.extract(
    cbzFile: File(cbzPath),
    extractDir: extractDir,
  );
  final pages = unpack.fold<List<MangaPage>?>(
    onSuccess: (value) => value,
    onFailure: (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.message)));
      }
      return null;
    },
  );
  if (pages == null || !context.mounted) return;

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => MangaReaderPage(
        session: ChapterSession(
          mangaAnilistId: task.mangaAnilistId,
          sourceId: task.sourceId,
          chapter: MangaChapter(
            number: task.chapterNumber,
            title: task.chapterTitle ?? '',
            volume: task.volume,
            language: task.language,
            scanlator: task.scanlator,
            pageCount: task.pageCount,
            sourceId: task.sourceId,
          ),
          pages: pages,
          mode: ReaderMode.paginated,
          title: task.chapterTitle,
        ),
      ),
    ),
  );
}

bool _canRetry(MangaDownloadTask task) {
  return task.status == MangaDownloadStatus.failed ||
      task.status == MangaDownloadStatus.partial;
}

String _formatChapterLabel(MangaDownloadTask task) {
  final num = task.chapterNumber == task.chapterNumber.truncateToDouble()
      ? task.chapterNumber.toInt().toString()
      : task.chapterNumber.toStringAsFixed(1);
  final base = 'Ch. $num';
  if (task.chapterTitle != null && task.chapterTitle!.isNotEmpty) {
    return '$base — ${task.chapterTitle}';
  }
  return base;
}

int _completedTaskSize(MangaDownloadTask task) {
  return task.totalBytes ?? task.downloadedBytes ?? 0;
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

Color _statusColor(MangaDownloadStatus status) {
  return switch (status) {
    MangaDownloadStatus.pending => KumoriyaColors.textMuted,
    MangaDownloadStatus.downloading => KumoriyaColors.primary,
    MangaDownloadStatus.paused => KumoriyaColors.statusWarning,
    MangaDownloadStatus.packaging => KumoriyaColors.statusSuccess,
    MangaDownloadStatus.disconnected => KumoriyaColors.textMuted,
    MangaDownloadStatus.partial => KumoriyaColors.statusWarning,
    MangaDownloadStatus.completed => KumoriyaColors.statusSuccess,
    MangaDownloadStatus.failed => KumoriyaColors.statusDanger,
  };
}

String _mangaDownloadsSubtitle(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Capítulos sin conexión'
      : 'Offline chapters';
}

String _mangaDownloadsCompletedEmpty(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'No hay capítulos descargados.'
      : 'No completed manga downloads.';
}

String _mangaDownloadDeleteMessage(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Este capítulo descargado será eliminado permanentemente de tu dispositivo.'
      : 'This downloaded chapter will be permanently removed from your device.';
}

String _downloadChaptersCount(BuildContext context, int count) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? '$count capítulos'
      : count == 1
      ? '1 chapter'
      : '$count chapters';
}

String _downloadDeleteAllChapters(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Eliminar todos los capítulos'
      : 'Delete all chapters';
}

String _downloadDeleteAllConfirmTitle(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? '¿Eliminar todos los capítulos?'
      : 'Delete all chapters?';
}

String _downloadDeleteAllConfirmMessage(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Todos los capítulos descargados de este manga serán eliminados permanentemente de tu dispositivo.'
      : 'All downloaded chapters for this manga will be permanently removed from your device.';
}

String _mangaDownloadPackagingLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Empaquetando CBZ…'
      : 'Packaging CBZ…';
}

String _mangaDownloadDisconnectedLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Esperando conexión'
      : 'Waiting for connection';
}

String _mangaDownloadPartialLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Páginas listas, el empaquetado se reintentará'
      : 'Pages ready, packaging will retry';
}

String _mangaDownloadSavedLabel(BuildContext context, int pageCount) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Guardado ($pageCount páginas)'
      : 'Saved ($pageCount pages)';
}
