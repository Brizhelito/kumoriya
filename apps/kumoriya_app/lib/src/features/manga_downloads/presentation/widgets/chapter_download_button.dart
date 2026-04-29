import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../manga_catalog/application/services/composite_manga_catalog_repository.dart';
import '../../../manga_catalog/presentation/providers/manga_catalog_providers.dart';
import '../providers/manga_download_providers.dart';

/// State-aware download icon for a single manga chapter row.
///
/// Talks to [mangaDownloadManagerProvider]. Tap actions:
///
/// - **idle / completed**: enqueue a new download
/// - **downloading / packaging**: cancel the in-flight download
/// - **failed / partial**: retry
///
/// Resolves the source-side ids by looking up the cached
/// [SourceChapter] on [CompositeMangaCatalogRepository] — which the
/// chapter list page has already warmed by calling
/// `fetchMangaChapters` before this widget builds.
class ChapterDownloadButton extends ConsumerWidget {
  const ChapterDownloadButton({
    super.key,
    required this.mangaAnilistId,
    required this.mangaTitle,
    required this.chapter,
  });

  final int mangaAnilistId;
  final String? mangaTitle;
  final MangaChapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(mangaCatalogRepositoryProvider);
    if (repo is! CompositeMangaCatalogRepository) {
      // Other catalog impls (none today) don't expose source ids; just
      // hide the button rather than guess.
      return const SizedBox.shrink();
    }

    final source = repo.lookupSourceChapter(
      mangaAnilistId: mangaAnilistId,
      chapter: chapter,
    );
    if (source == null) {
      // Cache not warm yet — the parent screen calls
      // `fetchMangaChapters` before listing rows, so this is rare.
      // Fall back to a disabled icon instead of triggering a fetch
      // here (we'd otherwise spawn N requests for N rows).
      return const _DisabledIcon();
    }

    final pluginId = ref.watch(mangaSourcePluginProvider).manifest.id;
    final taskAsync = ref.watch(
      mangaDownloadTaskByChapterProvider(
        chapterRefKey(
          mangaAnilistId: mangaAnilistId,
          sourceId: pluginId,
          sourceChapterId: source.sourceChapterId,
        ),
      ),
    );

    return taskAsync.when(
      loading: () => const _DisabledIcon(),
      error: (_, _) => const _DisabledIcon(),
      data: (task) => _DownloadIconButton(
        task: task,
        onPressed: () => _onTap(ref, task: task, source: source),
      ),
    );
  }

  Future<void> _onTap(
    WidgetRef ref, {
    required MangaDownloadTask? task,
    required SourceChapter source,
  }) async {
    final manager = ref.read(mangaDownloadManagerProvider);
    final pluginId = ref.read(mangaSourcePluginProvider).manifest.id;

    if (task == null || task.status == MangaDownloadStatus.failed) {
      // Fresh enqueue or retry.
      final id = task?.id ?? _newTaskId(pluginId, source.sourceChapterId);
      await manager.enqueue(
        MangaDownloadTask(
          id: id,
          mangaAnilistId: mangaAnilistId,
          sourceId: pluginId,
          sourceMangaId: source.sourceMangaId,
          sourceChapterId: source.sourceChapterId,
          chapterNumber: chapter.number,
          volume: source.volume,
          language: (chapter.language?.isNotEmpty ?? false)
              ? chapter.language!
              : source.language,
          scanlator: chapter.scanlator ?? source.scanlator,
          mangaTitle: mangaTitle,
          chapterTitle: chapter.title.isNotEmpty ? chapter.title : source.title,
          status: MangaDownloadStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }

    switch (task.status) {
      case MangaDownloadStatus.pending:
      case MangaDownloadStatus.downloading:
      case MangaDownloadStatus.packaging:
      case MangaDownloadStatus.paused:
      case MangaDownloadStatus.disconnected:
        await manager.cancel(task.id);
      case MangaDownloadStatus.partial:
        await manager.retry(task.id);
      case MangaDownloadStatus.completed:
        // Tap on a completed entry deletes — long-press would be ideal
        // but a single-tap delete with the green check feels
        // surprising. Keep tap as a no-op here; the dedicated
        // downloads page exposes a delete action.
        break;
      case MangaDownloadStatus.failed:
        // handled above
        break;
    }
  }

  static String _newTaskId(String sourceId, String sourceChapterId) =>
      '$sourceId-$sourceChapterId';
}

class _DisabledIcon extends StatelessWidget {
  const _DisabledIcon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.download_outlined,
        color: KumoriyaColors.textMuted,
        size: 22,
      ),
    );
  }
}

class _DownloadIconButton extends StatelessWidget {
  const _DownloadIconButton({required this.task, required this.onPressed});

  final MangaDownloadTask? task;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(task);
    return Tooltip(
      message: visual.tooltip,
      child: InkResponse(
        onTap: () {
          // ignore: discarded_futures
          onPressed();
        },
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (visual.showProgress &&
                  task != null &&
                  (task!.pageCount ?? 0) > 0)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value:
                        (task!.pagesDownloaded ?? 0) / (task!.pageCount ?? 1),
                    color: KumoriyaColors.primary,
                    backgroundColor: KumoriyaColors.surface,
                  ),
                ),
              Icon(visual.icon, color: visual.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  _Visual _visualFor(MangaDownloadTask? task) {
    if (task == null) {
      return const _Visual(
        icon: Icons.download_outlined,
        color: KumoriyaColors.textMuted,
        tooltip: 'Download chapter',
      );
    }
    switch (task.status) {
      case MangaDownloadStatus.pending:
        return const _Visual(
          icon: Icons.schedule,
          color: KumoriyaColors.textMuted,
          tooltip: 'Queued',
          showProgress: false,
        );
      case MangaDownloadStatus.downloading:
        return const _Visual(
          icon: Icons.download_rounded,
          color: KumoriyaColors.primary,
          tooltip: 'Downloading… tap to cancel',
          showProgress: true,
        );
      case MangaDownloadStatus.packaging:
        return const _Visual(
          icon: Icons.archive_outlined,
          color: KumoriyaColors.primary,
          tooltip: 'Packaging…',
          showProgress: true,
        );
      case MangaDownloadStatus.paused:
      case MangaDownloadStatus.disconnected:
        return const _Visual(
          icon: Icons.pause_circle_outline,
          color: KumoriyaColors.textMuted,
          tooltip: 'Paused',
        );
      case MangaDownloadStatus.partial:
        return const _Visual(
          icon: Icons.refresh,
          color: KumoriyaColors.statusWarning,
          tooltip: 'Resume packaging',
        );
      case MangaDownloadStatus.completed:
        return const _Visual(
          icon: Icons.check_circle,
          color: KumoriyaColors.statusSuccess,
          tooltip: 'Downloaded',
        );
      case MangaDownloadStatus.failed:
        return const _Visual(
          icon: Icons.error_outline,
          color: KumoriyaColors.statusDanger,
          tooltip: 'Failed — tap to retry',
        );
    }
  }
}

class _Visual {
  const _Visual({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.showProgress = false,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final bool showProgress;
}
