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
import '../../../downloads/application/download_manager_service.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../providers/anime_catalog_providers.dart';
import 'anime_detail_page.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(allDownloadTasksProvider);

    return Scaffold(
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.retry,
                    onPressed: () async {
                      await ref
                          .read(downloadManagerProvider)
                          .syncDownloadedLibrary();
                      ref.invalidate(allDownloadTasksProvider);
                    },
                    icon: const Icon(
                      Icons.sync_rounded,
                      color: KumoriyaColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                context.l10n.downloadsSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: KumoriyaColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: tasksState.when(
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
                  onSuccess: (tasks) => _DownloadsBody(tasks: tasks),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsBody extends ConsumerWidget {
  const _DownloadsBody({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];

    if (tasks.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 36),
          child: EmptyStateView(message: context.l10n.myListDownloadsEmpty),
        ),
      );

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children,
      );
    }

    final active = tasks
        .where((t) => t.status != DownloadStatus.completed)
        .toList();
    final aggregateProgress = ref
        .watch(downloadAggregateProgressProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const DownloadAggregateProgress.empty(),
        );
    final completed = tasks
        .where((t) => t.status == DownloadStatus.completed)
        .toList();

    final groupedCompleted = <int, List<DownloadTask>>{};
    for (final task in completed) {
      groupedCompleted.putIfAbsent(task.anilistId, () => []).add(task);
    }
    for (final list in groupedCompleted.values) {
      list.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }

    children.addAll(<Widget>[
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
                onPressed: () async {
                  await ref.read(downloadManagerProvider).cancelAll();
                  ref.invalidate(allDownloadTasksProvider);
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(context.l10n.downloadCancel),
                style: TextButton.styleFrom(
                  foregroundColor: KumoriyaColors.statusDanger,
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
          (task) => Padding(
            key: ValueKey('active-${task.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActiveDownloadRow(task: task),
          ),
        ),
        if (groupedCompleted.isNotEmpty) const SizedBox(height: 12),
      ],
      ...groupedCompleted.entries.map(
        (entry) => Padding(
          key: ValueKey('completed-${entry.key}'),
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

    final title = task.animeTitle ?? context.l10n.loadingGeneric;

    // Only fetch AniList detail for the cover image (cached & shared).
    final detailState = ref.watch(animeDetailProvider(task.anilistId));
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
                        if (task.status == DownloadStatus.failed &&
                            task.errorMessage != null &&
                            task.errorMessage!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            _downloadErrorSummary(task.errorMessage!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
            await manager.retryFailed(task.id);
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

    // Only fetch AniList detail for the cover image (cached & shared).
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));
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

// ─── Single completed episode tile ───────────────────────────────────────────

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
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: task.anilistId,
          animeTitle:
              task.animeTitle ??
              context.l10n.downloadEpisodeLabel(task.episodeNumber.toInt()),
          episodeNumber: task.episodeNumber.toInt().toString(),
          sourcePluginId: task.sourcePluginId ?? 'offline',
          serverName: task.serverName ?? context.l10n.downloadedSourceLabel,
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

final _whitespaceRe = RegExp(r'\s+');

String _downloadErrorSummary(String rawError) {
  final normalized = rawError.toLowerCase();
  if (normalized.contains('http 403')) {
    return 'Acceso denegado (HTTP 403). El servidor bloqueo la descarga.';
  }
  if (normalized.contains('http 404')) {
    return 'Archivo no encontrado (HTTP 404). El enlace ya no existe.';
  }
  if (normalized.contains('timeout')) {
    return 'Tiempo de espera agotado. Reintenta la descarga.';
  }
  if (normalized.contains('socketexception') ||
      normalized.contains('connection')) {
    return 'Fallo de red durante la descarga. Verifica tu conexion.';
  }

  final compact = rawError.replaceAll(_whitespaceRe, ' ').trim();
  return compact.length <= 140 ? compact : '${compact.substring(0, 140)}...';
}
