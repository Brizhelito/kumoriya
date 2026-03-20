import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../application/models/source_availability.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../../application/services/mal_metadata_bridge_service.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../support/episode_display_title.dart';
import '../support/playback_launch_flow.dart';
import '../widgets/source_badge.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

class EpisodeListPage extends ConsumerStatefulWidget {
  const EpisodeListPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    this.focusedEpisodeNumber,
  });

  final int anilistId;
  final String animeTitle;
  final double? focusedEpisodeNumber;

  @override
  ConsumerState<EpisodeListPage> createState() => _EpisodeListPageState();
}

class _EpisodeListPageState extends ConsumerState<EpisodeListPage> {
  bool _isLaunching = false;
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToFocus = false;
  bool _didAutoDownloadCheck = false;
  bool _didAniSkipPrefetch = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episodesState = ref.watch(animeEpisodesProvider(widget.anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(widget.anilistId),
    );
    final progressState = ref.watch(
      animeEpisodeProgressListProvider(widget.anilistId),
    );
    final preferenceState = ref.watch(
      playbackPreferenceProvider(widget.anilistId),
    );

    final animeEpisodes =
        _extractSuccessValue<List<AnimeEpisode>>(episodesState) ??
        const <AnimeEpisode>[];
    final sourceSummary = _extractSuccessValue<SourceAvailabilitySummary>(
      availabilityState,
    );
    final progressList =
        _extractSuccessValue<List<EpisodeProgress>>(progressState) ??
        const <EpisodeProgress>[];
    final preference = _extractSuccessValue<PlaybackPreference?>(
      preferenceState,
    );
    final malEpisodeMetadata = ref
        .watch(malEpisodeMetadataProvider(widget.anilistId))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <int, MalEpisodeMetadata>{},
        );

    final hasAnyData =
        animeEpisodes.isNotEmpty ||
        (sourceSummary?.playableSources.isNotEmpty ?? false);

    if (!hasAnyData &&
        (episodesState.isLoading || availabilityState.isLoading)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.episodeListTitle(widget.animeTitle)),
        ),
        body: LoadingStateView(label: context.l10n.episodeListLoading),
      );
    }

    final rows = _buildEpisodeRows(
      animeEpisodes: animeEpisodes,
      availabilitySummary: sourceSummary,
      progressList: progressList,
      malEpisodeMetadata: malEpisodeMetadata,
      focusedEpisodeNumber: widget.focusedEpisodeNumber,
      animeTitle: widget.animeTitle,
      fallbackTitleBuilder: (episodeNumber) => context.l10n
          .continueWatchingEpisode(episodeNumber.toInt().toString()),
      upcomingLabel: context.l10n.episodeStatusUpcoming,
      readyLabel: context.l10n.episodePlayNowLabel,
    );
    _scheduleScrollToFocus(rows);
    _scheduleAutoDownloadCheck(rows);
    _scheduleAniSkipPrefetch(animeEpisodes);

    // Lift download-tasks watch here so individual _EpisodeCard widgets don't
    // each independently watch the same provider (N cards → N rebuilds).
    final dlTasksState = ref.watch(
      downloadTasksByAnimeProvider(widget.anilistId),
    );
    final dlTaskMap = <double, DownloadTask>{};
    dlTasksState.whenData((result) {
      result.fold(
        onSuccess: (tasks) {
          for (final t in tasks) {
            dlTaskMap[t.episodeNumber] = t;
          }
        },
        onFailure: (_) {},
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.episodeListTitle(widget.animeTitle)),
      ),
      body: rows.isEmpty
          ? EmptyStateView(message: context.l10n.episodeListEmpty)
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                _EpisodeListHeader(
                  summary: sourceSummary,
                  preference: preference,
                  anilistId: widget.anilistId,
                  animeTitle: widget.animeTitle,
                  rows: rows,
                ),
                const SizedBox(height: 12),
                ...rows.map((row) {
                  // Find matching download task by episode number.
                  DownloadTask? dlTask;
                  for (final entry in dlTaskMap.entries) {
                    if ((entry.key - row.number).abs() < 0.001) {
                      dlTask = entry.value;
                      break;
                    }
                  }
                  return _EpisodeCard(
                    key: ValueKey('ep-${row.number}'),
                    row: row,
                    anilistId: widget.anilistId,
                    animeTitle: widget.animeTitle,
                    downloadTask: dlTask,
                    onTap:
                        row.playableSources.isEmpty ||
                            sourceSummary == null ||
                            _isLaunching
                        ? null
                        : () => _handleEpisodeTap(row, sourceSummary),
                  );
                }),
              ],
            ),
    );
  }

  void _scheduleAniSkipPrefetch(List<AnimeEpisode> animeEpisodes) {
    if (_didAniSkipPrefetch || animeEpisodes.isEmpty) {
      return;
    }
    final episodeNumbers = animeEpisodes
        .where((episode) => episode.isAired)
        .map((episode) => episode.number.toInt())
        .where((episodeNumber) => episodeNumber > 0)
        .toSet()
        .toList(growable: false);
    if (episodeNumbers.isEmpty) {
      return;
    }
    _didAniSkipPrefetch = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(malMetadataBridgeProvider)
            .prefetchAniSkipForAnime(
              anilistId: widget.anilistId,
              episodeNumbers: episodeNumbers,
            ),
      );
    });
  }

  Future<void> _handleEpisodeTap(
    _EpisodeRowData row,
    SourceAvailabilitySummary summary,
  ) async {
    final playbackPreparingLabel = context.l10n.playbackPreparing;

    // Check for completed offline download first.
    final dlTasksState = ref.read(
      downloadTasksByAnimeProvider(widget.anilistId),
    );
    final offlineTask = dlTasksState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (tasks) {
          for (final t in tasks) {
            if ((t.episodeNumber - row.number).abs() < 0.001 &&
                t.status == DownloadStatus.completed &&
                t.filePath != null) {
              return t;
            }
          }
          return null;
        },
      ),
      orElse: () => null,
    );

    if (offlineTask != null) {
      final file = File(offlineTask.filePath!);
      if (await file.exists()) {
        if (!mounted) return;
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerPage(
              anilistId: widget.anilistId,
              animeTitle: widget.animeTitle,
              episodeNumber: row.number.toInt().toString(),
              sourcePluginId: offlineTask.sourcePluginId ?? 'offline',
              serverName: offlineTask.serverName ?? 'Downloaded',
              resolved: ResolvedServerLinkResult(
                resolverId: 'offline',
                resolverName: 'Downloaded',
                streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
              ),
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _isLaunching = true);
    showBlockingLoader(
      Navigator.of(context, rootNavigator: true).context,
      playbackPreparingLabel,
    );
    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: widget.anilistId,
          episodeNumber: row.number,
          availabilitySummary: summary,
        );
    if (!mounted) {
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    hideBlockingLoader(rootNavigator.context);
    setState(() => _isLaunching = false);
    await handlePlaybackDecision(
      context: rootNavigator.context,
      ref: ref,
      anilistId: widget.anilistId,
      animeTitle: widget.animeTitle,
      decision: decision,
    );
  }

  T? _extractSuccessValue<T>(AsyncValue<Result<T, KumoriyaError>> asyncValue) {
    return asyncValue.maybeWhen(
      data: (result) => result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      ),
      orElse: () => null,
    );
  }

  void _scheduleScrollToFocus(List<_EpisodeRowData> rows) {
    if (_didScrollToFocus || widget.focusedEpisodeNumber == null) {
      return;
    }

    final focusIndex = rows.indexWhere(
      (row) => (row.number - widget.focusedEpisodeNumber!).abs() < 0.001,
    );
    if (focusIndex == -1) {
      return;
    }

    _didScrollToFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final offset = (focusIndex * 152.0).clamp(0.0, double.infinity);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// On first load, if auto-download is enabled for this anime, enqueue any
  /// episodes that don't yet have a download task.
  void _scheduleAutoDownloadCheck(List<_EpisodeRowData> rows) {
    if (_didAutoDownloadCheck) return;

    // Wait until source episodes are actually available. Initial builds may
    // contain metadata-only rows and would permanently skip auto-download.
    final hasDownloadableRows = rows.any(
      (row) => row.sourceEpisodes.keys.any(
        (sourceId) => sourceId != _excludedDownloadSource,
      ),
    );
    if (!hasDownloadableRows) {
      return;
    }

    _didAutoDownloadCheck = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final isAutoDl = await ref.read(
        isAutoDownloadProvider(widget.anilistId).future,
      );
      if (!isAutoDl) return;

      final existingResult = await ref.read(
        downloadTasksByAnimeProvider(widget.anilistId).future,
      );
      final existingEps = existingResult.fold(
        onSuccess: (tasks) => tasks.map((t) => t.episodeNumber).toSet(),
        onFailure: (_) => <double>{},
      );

      final downloadable = rows.where(
        (r) =>
            r.sourceEpisodes.keys.any(
              (sourceId) => sourceId != _excludedDownloadSource,
            ) &&
            !existingEps.contains(r.number),
      );

      // Resolve-and-enqueue sequentially: stream URLs (m3u8 tokens) expire
      // quickly, so each must be enqueued right after resolution. The download
      // manager handles true download concurrency (up to maxConcurrent).
      for (final row in downloadable) {
        final entry = row.sourceEpisodes.entries.first;
        await _enqueueEpisodeDownload(
          ref: ref,
          anilistId: widget.anilistId,
          sourcePluginId: entry.key,
          sourceEpisode: entry.value,
          animeTitle: widget.animeTitle,
          coverImageUrl: _resolveCoverUrl(ref, widget.anilistId),
        );
      }

      if (mounted && downloadable.isNotEmpty) {
        ref.invalidate(downloadTasksByAnimeProvider(widget.anilistId));
      }
    });
  }
}

class _EpisodeListHeader extends ConsumerWidget {
  const _EpisodeListHeader({
    required this.summary,
    required this.preference,
    required this.anilistId,
    required this.animeTitle,
    required this.rows,
  });

  final SourceAvailabilitySummary? summary;
  final PlaybackPreference? preference;
  final int anilistId;
  final String animeTitle;
  final List<_EpisodeRowData> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playableSources =
        summary?.playableSources ?? const <SourceAvailability>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (playableSources.isEmpty)
          _InfoBanner(message: context.l10n.detailPlaybackNotReady)
        else
          _InfoBanner(
            message: preference == null
                ? context.l10n.episodeListUsingPreference
                : context.l10n.episodeListUsingRememberedSource(
                    preference!.preferredSourcePluginId ?? '',
                    preference!.preferredServerName ?? '',
                  ),
            badges: playableSources
                .map(
                  (source) => SourceBadge(
                    name: source.manifest.displayName,
                    iconUrl: _sourceIcon(source.manifest),
                    audioKinds: source.availableAudioKinds,
                    compact: true,
                    highlighted:
                        summary?.recommended?.manifest.id == source.manifest.id,
                  ),
                )
                .toList(growable: false),
          ),
        if (playableSources.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _downloadAll(context, ref),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(context.l10n.downloadAll),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _downloadAll(BuildContext context, WidgetRef ref) async {
    final downloadable = rows
        .where((r) => r.sourceEpisodes.isNotEmpty)
        .toList();
    if (downloadable.isEmpty) return;

    final sourceId = await _pickSourceForBulkDownload(context);
    if (sourceId == null) {
      return;
    }

    // Resolve-and-enqueue sequentially: stream URLs carry short-lived tokens
    // that expire in ~30-60s. Parallel resolution causes later downloads to
    // hit 403. The download manager handles true concurrent transfers.
    var queued = 0;
    for (final row in downloadable) {
      final entry = row.sourceEpisodes.entries
          .where((e) => e.key == sourceId)
          .firstOrNull;
      if (entry == null) continue;

      final result = await _enqueueEpisodeDownload(
        ref: ref,
        anilistId: anilistId,
        sourcePluginId: entry.key,
        sourceEpisode: entry.value,
        animeTitle: animeTitle,
        coverImageUrl: _resolveCoverUrl(ref, anilistId),
      );
      if (result) queued++;
    }

    if (context.mounted && queued > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadAllQueued)));
      ref.invalidate(downloadTasksByAnimeProvider(anilistId));
    }
  }

  Future<String?> _pickSourceForBulkDownload(BuildContext context) async {
    final playableSources =
        summary?.playableSources
            .where((source) => source.manifest.id != _excludedDownloadSource)
            .toList(growable: false) ??
        const <SourceAvailability>[];
    if (playableSources.isEmpty) {
      return null;
    }
    if (playableSources.length == 1) {
      return playableSources.first.manifest.id;
    }

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  context.l10n.downloadAllFromSource,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...playableSources.map(
                (source) => ListTile(
                  leading: SourceBadge(
                    name: source.manifest.displayName,
                    iconUrl: _sourceIcon(source.manifest),
                    compact: true,
                    iconOnly: true,
                  ),
                  title: Text(source.manifest.displayName),
                  onTap: () => Navigator.of(context).pop(source.manifest.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeCard extends ConsumerStatefulWidget {
  const _EpisodeCard({
    super.key,
    required this.row,
    required this.anilistId,
    required this.animeTitle,
    this.downloadTask,
    this.onTap,
  });

  final _EpisodeRowData row;
  final int anilistId;
  final String animeTitle;
  final DownloadTask? downloadTask;
  final VoidCallback? onTap;

  @override
  ConsumerState<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends ConsumerState<_EpisodeCard> {
  bool _isEnqueuing = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final row = widget.row;
    final progress = row.progressFraction;

    final dlTask = widget.downloadTask;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: row.isCurrentEpisode
          ? colorScheme.primaryContainer.withValues(alpha: 0.6)
          : colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: row.playableSources.isEmpty
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.primaryContainer,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      row.number.toInt().toString(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                row.displayTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (row.isCurrentEpisode)
                              _ContextChip(
                                label: context.l10n.detailContinueBadge,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row.secondaryText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (row.playableSources.isEmpty)
                Text(
                  context.l10n.episodePlaybackUnavailable,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (progress != null) ...<Widget>[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _buildDownloadButton(context, dlTask),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      row.playableSources.isEmpty
                          ? context.l10n.playEpisode
                          : context.l10n.detailPlay,
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

  Widget _buildDownloadButton(BuildContext context, DownloadTask? dlTask) {
    if (_isEnqueuing) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (dlTask != null) {
      return _DownloadStatusChip(task: dlTask);
    }

    if (widget.row.sourceEpisodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasDownloadableSource = widget.row.sourceEpisodes.keys.any(
      (id) => id != _excludedDownloadSource,
    );
    if (!hasDownloadableSource) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.download_rounded),
      tooltip: context.l10n.downloadEpisode,
      onPressed: () => _handleDownload(context),
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isEnqueuing) return;
    setState(() => _isEnqueuing = true);

    // Pick the first non-excluded source for download.
    final entry = widget.row.sourceEpisodes.entries
        .where((e) => e.key != _excludedDownloadSource)
        .firstOrNull;

    final success = entry != null
        ? await _enqueueEpisodeDownload(
            ref: ref,
            anilistId: widget.anilistId,
            sourcePluginId: entry.key,
            sourceEpisode: entry.value,
            animeTitle: widget.animeTitle,
            coverImageUrl: _resolveCoverUrl(ref, widget.anilistId),
          )
        : false;

    if (!context.mounted) return;
    setState(() => _isEnqueuing = false);
    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      ref.invalidate(downloadTasksByAnimeProvider(widget.anilistId));
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.downloadQueued)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.downloadFailed)),
      );
    }
  }
}

class _DownloadStatusChip extends StatelessWidget {
  const _DownloadStatusChip({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (task.status) {
      DownloadStatus.pending => (
        Icons.hourglass_top_rounded,
        KumoriyaColors.textMuted,
        context.l10n.downloadPending,
      ),
      DownloadStatus.downloading => (
        Icons.downloading_rounded,
        Theme.of(context).colorScheme.primary,
        context.l10n.downloadInProgress,
      ),
      DownloadStatus.paused => (
        Icons.pause_circle_rounded,
        KumoriyaColors.statusWarning,
        context.l10n.downloadPaused,
      ),
      DownloadStatus.completed => (
        Icons.check_circle_rounded,
        KumoriyaColors.statusSuccess,
        context.l10n.downloadComplete,
      ),
      DownloadStatus.failed => (
        Icons.error_rounded,
        KumoriyaColors.statusDanger,
        context.l10n.downloadFailed,
      ),
    };

    return Tooltip(
      message: label,
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, this.badges = const <Widget>[]});

  final String message;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (badges.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: badges),
          ],
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

List<_EpisodeRowData> _buildEpisodeRows({
  required List<AnimeEpisode> animeEpisodes,
  required SourceAvailabilitySummary? availabilitySummary,
  required List<EpisodeProgress> progressList,
  required Map<int, MalEpisodeMetadata> malEpisodeMetadata,
  required double? focusedEpisodeNumber,
  required String animeTitle,
  required String Function(double episodeNumber) fallbackTitleBuilder,
  required String upcomingLabel,
  required String readyLabel,
}) {
  final metadataByNumber = <double, AnimeEpisode>{
    for (final episode in animeEpisodes) episode.number: episode,
  };
  final progressByNumber = <double, EpisodeProgress>{
    for (final progress in progressList) progress.episodeNumber: progress,
  };
  final sourcesByEpisode = <double, List<SourceAvailability>>{};
  final sourceEpisodesByNumber = <double, Map<String, SourceEpisode>>{};

  for (final source
      in availabilitySummary?.playableSources ?? const <SourceAvailability>[]) {
    for (final episode in source.episodes) {
      sourcesByEpisode
          .putIfAbsent(episode.number, () => <SourceAvailability>[])
          .add(source);
      sourceEpisodesByNumber.putIfAbsent(
        episode.number,
        () => <String, SourceEpisode>{},
      )[source.manifest.id] = episode;
    }
  }

  final allNumbers = <double>{
    ...metadataByNumber.keys,
    ...sourcesByEpisode.keys,
  }.toList(growable: false)..sort();

  EpisodeProgress? latestProgress;
  for (final progress in progressList) {
    if (latestProgress == null ||
        progress.updatedAt.isAfter(latestProgress.updatedAt)) {
      latestProgress = progress;
    }
  }

  return allNumbers
      .map((number) {
        final metadata = metadataByNumber[number];
        final jikanMetadata = malEpisodeMetadata[number.toInt()];
        final sources =
            sourcesByEpisode[number] ?? const <SourceAvailability>[];
        final progress = progressByNumber[number];

        return _EpisodeRowData(
          number: number,
          displayTitle:
              (jikanMetadata?.title != null &&
                  jikanMetadata!.title!.trim().isNotEmpty)
              ? jikanMetadata.title!.trim()
              : resolveEpisodeDisplayTitle(
                  episodeNumber: number,
                  animeTitle: animeTitle,
                  metadata: metadata,
                  sourceEpisodes:
                      sourceEpisodesByNumber[number] ??
                      const <String, SourceEpisode>{},
                  fallbackTitle: fallbackTitleBuilder(number),
                ),
          secondaryText: metadata?.airDate != null
              ? _formatDate(metadata!.airDate!)
              : metadata?.isAired == false
              ? upcomingLabel
              : jikanMetadata?.airedAt != null
              ? _formatDate(jikanMetadata!.airedAt!)
              : readyLabel,
          playableSources: sources,
          progressFraction: _progressFraction(progress),
          isCurrentEpisode:
              latestProgress?.episodeNumber == number ||
              focusedEpisodeNumber == number,
          sourceEpisodes:
              sourceEpisodesByNumber[number] ?? const <String, SourceEpisode>{},
        );
      })
      .toList(growable: false);
}

double? _progressFraction(EpisodeProgress? progress) {
  if (progress == null || progress.totalDuration == null) {
    return null;
  }
  if (progress.totalDuration!.inMilliseconds == 0) {
    return null;
  }
  final value =
      progress.position.inMilliseconds / progress.totalDuration!.inMilliseconds;
  return value.clamp(0.0, 1.0);
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String? _sourceIcon(PluginManifest manifest) {
  if (manifest.iconUrl != null && manifest.iconUrl!.trim().isNotEmpty) {
    return manifest.iconUrl;
  }
  return null;
}

final class _EpisodeRowData {
  const _EpisodeRowData({
    required this.number,
    required this.displayTitle,
    required this.secondaryText,
    required this.playableSources,
    required this.progressFraction,
    required this.isCurrentEpisode,
    required this.sourceEpisodes,
  });

  final double number;
  final String displayTitle;
  final String secondaryText;
  final List<SourceAvailability> playableSources;
  final double? progressFraction;
  final bool isCurrentEpisode;

  /// Map of source plugin ID → SourceEpisode for this episode number.
  final Map<String, SourceEpisode> sourceEpisodes;
}

/// Source plugin ID for Anime Nexus — excluded from downloads per user request.
const _excludedDownloadSource = 'kumoriya.source.anime_nexus';

// ─── Download helper ─────────────────────────────────────────────────────────

/// Resolves server links for [sourceEpisode] via [sourcePluginId], picks the
/// best stream, and enqueues a download task. Returns true on success.
Future<bool> _enqueueEpisodeDownload({
  required WidgetRef ref,
  required int anilistId,
  required String sourcePluginId,
  required SourceEpisode sourceEpisode,
  String? animeTitle,
  String? coverImageUrl,
}) async {
  try {
    final sourcePlugin = ref.read(sourcePluginByIdProvider(sourcePluginId));
    final registry = ref.read(resolverRegistryProvider);

    final linksResult = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: sourcePlugin,
      registry: registry,
    ).call(sourceEpisode);

    final links = linksResult.fold(
      onSuccess: (l) => l,
      onFailure: (_) => <SourceServerLink>[],
    );
    if (links.isEmpty) return false;

    final enqueueUseCase = ref.read(enqueueDownloadUseCaseProvider);
    final result = await enqueueUseCase.call(
      anilistId: anilistId,
      episodeNumber: sourceEpisode.number,
      serverLink: links.first,
      sourcePluginId: sourcePluginId,
      animeTitle: animeTitle,
      coverImageUrl: coverImageUrl,
    );

    return result.fold(onSuccess: (_) => true, onFailure: (_) => false);
  } catch (_) {
    return false;
  }
}

/// Resolves the anime cover image URL from the cached detail provider.
String? _resolveCoverUrl(WidgetRef ref, int anilistId) {
  return ref
      .read(animeDetailProvider(anilistId))
      .maybeWhen(
        data: (r) => r.fold(
          onFailure: (_) => null,
          onSuccess: (d) => d.anime.coverImageUrl,
        ),
        orElse: () => null,
      );
}
