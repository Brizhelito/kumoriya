import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../manga_downloads/presentation/providers/manga_download_providers.dart';

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
    final tasksAsync = ref.watch(mangaDownloadTasksProvider);
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        title: Text(l10n.mangaDownloadsTitle),
        backgroundColor: KumoriyaColors.surface,
        foregroundColor: KumoriyaColors.textPrimary,
        elevation: 0,
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (result) => result.fold(
          onSuccess: (tasks) => tasks.isEmpty
              ? const _EmptyState()
              : _DownloadsList(tasks: tasks),
          onFailure: (err) => _ErrorState(message: err.message),
        ),
      ),
    );
  }
}

class _DownloadsList extends ConsumerWidget {
  const _DownloadsList({required this.tasks});

  final List<MangaDownloadTask> tasks;

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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) =>
          _MangaSection(title: entries[i].key, tasks: entries[i].value),
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
    final chapterLabel = _formatChapter(task);
    final isActive =
        task.status == MangaDownloadStatus.downloading ||
        task.status == MangaDownloadStatus.packaging ||
        task.status == MangaDownloadStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          _StatusBadge(status: task.status),
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
                _StatusLine(task: task),
                if (isActive && (task.pageCount ?? 0) > 0) ...<Widget>[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value:
                          (task.pagesDownloaded ?? 0) / (task.pageCount ?? 1),
                      minHeight: 3,
                      color: KumoriyaColors.primary,
                      backgroundColor: KumoriyaColors.background,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _ActionsMenu(
            task: task,
            onDelete: () => manager.delete(task.id),
            onCancel: () => manager.cancel(task.id),
            onRetry: () => manager.retry(task.id),
          ),
        ],
      ),
    );
  }

  String _formatChapter(MangaDownloadTask t) {
    final num = t.chapterNumber == t.chapterNumber.truncateToDouble()
        ? t.chapterNumber.toInt().toString()
        : t.chapterNumber.toStringAsFixed(1);
    final base = 'Ch. $num';
    if (t.chapterTitle != null && t.chapterTitle!.isNotEmpty) {
      return '$base — ${t.chapterTitle}';
    }
    return base;
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.task});
  final MangaDownloadTask task;

  @override
  Widget build(BuildContext context) {
    final text = switch (task.status) {
      MangaDownloadStatus.pending => 'Queued',
      MangaDownloadStatus.downloading =>
        'Downloading ${task.pagesDownloaded ?? 0} / ${task.pageCount ?? '?'}',
      MangaDownloadStatus.paused => 'Paused',
      MangaDownloadStatus.packaging => 'Packaging CBZ…',
      MangaDownloadStatus.disconnected => 'Waiting for connection',
      MangaDownloadStatus.partial => 'Pages ready, packaging will retry',
      MangaDownloadStatus.completed => 'Saved (${task.pageCount ?? 0} pages)',
      MangaDownloadStatus.failed => task.errorMessage ?? 'Download failed',
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
    final (icon, color) = switch (status) {
      MangaDownloadStatus.pending => (Icons.schedule, KumoriyaColors.textMuted),
      MangaDownloadStatus.downloading => (
        Icons.download_rounded,
        KumoriyaColors.primary,
      ),
      MangaDownloadStatus.paused => (
        Icons.pause_circle_outline,
        KumoriyaColors.textMuted,
      ),
      MangaDownloadStatus.packaging => (
        Icons.archive_outlined,
        KumoriyaColors.primary,
      ),
      MangaDownloadStatus.disconnected => (
        Icons.cloud_off_outlined,
        KumoriyaColors.statusWarning,
      ),
      MangaDownloadStatus.partial => (
        Icons.refresh,
        KumoriyaColors.statusWarning,
      ),
      MangaDownloadStatus.completed => (
        Icons.check_circle,
        KumoriyaColors.statusSuccess,
      ),
      MangaDownloadStatus.failed => (
        Icons.error_outline,
        KumoriyaColors.statusDanger,
      ),
    };
    return Icon(icon, color: color, size: 22);
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
              const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
            );
          case MangaDownloadStatus.failed:
          case MangaDownloadStatus.partial:
            entries.add(
              const PopupMenuItem(value: 'retry', child: Text('Retry')),
            );
          case MangaDownloadStatus.completed:
            break;
        }
        entries.add(
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        );
        return entries;
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.collections_bookmark_outlined,
              color: KumoriyaColors.textMuted,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'No downloads yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: KumoriyaColors.textSecondary),
            ),
            SizedBox(height: 6),
            Text(
              'Tap the download icon next to any chapter to save it for offline reading.',
              textAlign: TextAlign.center,
              style: TextStyle(color: KumoriyaColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: KumoriyaColors.statusDanger,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KumoriyaColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
