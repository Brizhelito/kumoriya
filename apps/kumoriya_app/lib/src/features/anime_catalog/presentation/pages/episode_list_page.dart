import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/source_availability.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../support/playback_launch_flow.dart';
import '../widgets/source_badge.dart';

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
      focusedEpisodeNumber: widget.focusedEpisodeNumber,
      fallbackTitleBuilder: (episodeNumber) => context.l10n
          .continueWatchingEpisode(episodeNumber.toInt().toString()),
      upcomingLabel: context.l10n.episodeStatusUpcoming,
      readyLabel: context.l10n.episodePlayNowLabel,
    );
    _scheduleScrollToFocus(rows);

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
                ),
                const SizedBox(height: 12),
                ...rows.map(
                  (row) => _EpisodeCard(
                    row: row,
                    onTap:
                        row.playableSources.isEmpty ||
                            sourceSummary == null ||
                            _isLaunching
                        ? null
                        : () => _handleEpisodeTap(row, sourceSummary),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleEpisodeTap(
    _EpisodeRowData row,
    SourceAvailabilitySummary summary,
  ) async {
    setState(() => _isLaunching = true);
    showBlockingLoader(context, context.l10n.playbackPreparing);
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
    hideBlockingLoader(context);
    setState(() => _isLaunching = false);
    await handlePlaybackDecision(
      context: context,
      ref: ref,
      anilistId: widget.anilistId,
      animeTitle: widget.animeTitle,
      decision: decision,
    );
  }

  T? _extractSuccessValue<T>(AsyncValue asyncValue) {
    return asyncValue.maybeWhen(
      data: (result) {
        try {
          final dynamic typedResult = result;
          return typedResult.value as T?;
        } catch (_) {
          return null;
        }
      },
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
}

class _EpisodeListHeader extends StatelessWidget {
  const _EpisodeListHeader({required this.summary, required this.preference});

  final SourceAvailabilitySummary? summary;
  final PlaybackPreference? preference;

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.row, this.onTap});

  final _EpisodeRowData row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = row.progressFraction;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: row.isCurrentEpisode
          ? colorScheme.primaryContainer.withValues(alpha: 0.6)
          : colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
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
              if (row.playableSources.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: row.playableSources
                      .map(
                        (source) => SourceBadge(
                          name: source.manifest.displayName,
                          iconUrl: _sourceIcon(source.manifest),
                          audioKinds: source.availableAudioKinds,
                          compact: true,
                        ),
                      )
                      .toList(growable: false),
                )
              else
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
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    row.playableSources.isEmpty
                        ? context.l10n.episodeLockedLabel
                        : context.l10n.episodePlayNowLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
  required double? focusedEpisodeNumber,
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

  for (final source
      in availabilitySummary?.playableSources ?? const <SourceAvailability>[]) {
    for (final episode in source.episodes) {
      sourcesByEpisode
          .putIfAbsent(episode.number, () => <SourceAvailability>[])
          .add(source);
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
        final sources =
            sourcesByEpisode[number] ?? const <SourceAvailability>[];
        final progress = progressByNumber[number];

        return _EpisodeRowData(
          number: number,
          displayTitle: metadata?.title.trim().isNotEmpty == true
              ? metadata!.title
              : fallbackTitleBuilder(number),
          secondaryText: metadata?.isAired == false
              ? upcomingLabel
              : metadata?.airDate != null
              ? _formatDate(metadata!.airDate!)
              : readyLabel,
          playableSources: sources,
          progressFraction: _progressFraction(progress),
          isCurrentEpisode:
              latestProgress?.episodeNumber == number ||
              focusedEpisodeNumber == number,
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
  });

  final double number;
  final String displayTitle;
  final String secondaryText;
  final List<SourceAvailability> playableSources;
  final double? progressFraction;
  final bool isCurrentEpisode;
}
