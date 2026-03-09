import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/source_availability.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../widgets/source_badge.dart';
import '../../../player/presentation/pages/player_page.dart';

class EpisodeListPage extends ConsumerStatefulWidget {
  const EpisodeListPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
  });

  final int anilistId;
  final String animeTitle;

  @override
  ConsumerState<EpisodeListPage> createState() => _EpisodeListPageState();
}

class _EpisodeListPageState extends ConsumerState<EpisodeListPage> {
  bool _isLaunching = false;

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
      fallbackTitleBuilder: (episodeNumber) => context.l10n
          .continueWatchingEpisode(episodeNumber.toInt().toString()),
      upcomingLabel: context.l10n.episodeStatusUpcoming,
      readyLabel: context.l10n.episodePlayNowLabel,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.episodeListTitle(widget.animeTitle)),
      ),
      body: rows.isEmpty
          ? EmptyStateView(message: context.l10n.episodeListEmpty)
          : ListView(
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
    _showBlockingLoader(context, context.l10n.playbackPreparing);
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
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _isLaunching = false);

    switch (decision.type) {
      case EpisodePlaybackDecisionType.direct:
        await _openPlayer(decision.launch!);
      case EpisodePlaybackDecisionType.selection:
        final option = await _showServerPicker(
          context,
          options: decision.options,
          autoSelectionFailed: decision.autoSelectionFailed,
        );
        if (option != null && mounted) {
          await _resolveSelectedOption(
            option,
            remaining: decision.options
                .where((item) => item.optionKey != option.optionKey)
                .toList(growable: false),
          );
        }
      case EpisodePlaybackDecisionType.unavailable:
        _showUserMessage(
          decision.autoSelectionFailed
              ? context.l10n.episodeAutoplayFailed
              : context.l10n.episodePlaybackUnavailable,
        );
    }
  }

  Future<void> _resolveSelectedOption(
    EpisodePlaybackOption option, {
    required List<EpisodePlaybackOption> remaining,
  }) async {
    _showBlockingLoader(context, context.l10n.playbackOpeningSelectedServer);
    final result = await ref
        .read(resolveSourceServerLinkUseCaseProvider)
        .call(option.serverLink);
    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    result.fold(
      onFailure: (_) async {
        _showUserMessage(context.l10n.episodeSelectedServerFailed);
        if (remaining.isNotEmpty) {
          final next = await _showServerPicker(
            context,
            options: remaining,
            autoSelectionFailed: true,
          );
          if (next != null && mounted) {
            await _resolveSelectedOption(
              next,
              remaining: remaining
                  .where((item) => item.optionKey != next.optionKey)
                  .toList(growable: false),
            );
          }
        }
      },
      onSuccess: (resolved) async {
        await _openPlayer(
          EpisodePlayerLaunch(option: option, resolved: resolved),
        );
      },
    );
  }

  Future<void> _openPlayer(EpisodePlayerLaunch launch) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          anilistId: widget.anilistId,
          animeTitle: widget.animeTitle,
          episodeNumber: launch.option.sourceEpisode.number.toInt().toString(),
          sourcePluginId: launch.option.sourcePluginId,
          serverName: launch.option.serverLink.serverName,
          preferredAudioPreference: switch (launch.option.audioKind) {
            SourceAudioKind.sub => PlaybackAudioPreference.sub,
            SourceAudioKind.dub => PlaybackAudioPreference.dub,
            null => null,
          },
          resolved: launch.resolved,
        ),
      ),
    );
  }

  Future<EpisodePlaybackOption?> _showServerPicker(
    BuildContext context, {
    required List<EpisodePlaybackOption> options,
    required bool autoSelectionFailed,
  }) {
    return showModalBottomSheet<EpisodePlaybackOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  autoSelectionFailed
                      ? context.l10n.episodeAutoplayFailed
                      : context.l10n.serverPickerTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.serverPickerSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          leading: const Icon(
                            Icons.play_circle_outline_rounded,
                          ),
                          title: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  option.serverLink.serverName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (option.isPreferred)
                                _ContextChip(
                                  label: context.l10n.serverOptionLastUsed,
                                )
                              else if (option.isRecommended)
                                _ContextChip(
                                  label: context.l10n.serverOptionRecommended,
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SourceBadge(
                                  name: option.sourceName,
                                  iconUrl: option.sourceIconUrl,
                                  audioKinds: option.audioKind == null
                                      ? const <SourceAudioKind>{}
                                      : <SourceAudioKind>{option.audioKind!},
                                  compact: true,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  option.serverLink.detectedHost ??
                                      option.resolverName,
                                ),
                              ],
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(option),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlockingLoader(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUserMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          isCurrentEpisode: latestProgress?.episodeNumber == number,
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
  if (manifest.baseUrls.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(manifest.baseUrls.first);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  return uri.resolve('/favicon.ico').toString();
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
