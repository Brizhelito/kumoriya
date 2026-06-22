import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'package:kumoriya_ui/kumoriya_ui.dart';
import '../../../../app/l10n.dart';
import '../../../../shared/utils/error_messaging.dart';
import '../../../anime_catalog/application/models/resolved_server_link_result.dart';
import '../../../anime_catalog/application/models/source_availability.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../anime_catalog/presentation/support/episode_display_title.dart';
import '../../../anime_catalog/presentation/support/playback_launch_flow.dart';
import '../../../anime_catalog/presentation/support/plugin_icon_helpers.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../anime_catalog/presentation/providers/storage_providers.dart';
import '../../application/party_session_guard.dart';
import '../../application/providers/party_providers.dart';
import '../party_route_mode.dart';

class PartyEpisodeListPage extends ConsumerStatefulWidget {
  const PartyEpisodeListPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    this.focusedEpisodeNumber,
  });

  final int anilistId;
  final String animeTitle;
  final double? focusedEpisodeNumber;

  @override
  ConsumerState<PartyEpisodeListPage> createState() =>
      _PartyEpisodeListPageState();
}

class _PartyEpisodeListPageState extends ConsumerState<PartyEpisodeListPage> {
  bool _isLaunching = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(widget.anilistId),
    );
    final progressState = ref.watch(
      animeEpisodeProgressListProvider(widget.anilistId),
    );
    final session = ref.watch(partySessionProvider);
    final isActive = session.isActive;

    return PopScope(
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) _openLobby();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: detailState.when(
            loading: () =>
                LoadingStateView(label: context.l10n.partyLoadingEpisodeBoard),
            error: (_, _) => ErrorStateView(
              message: context.l10n.partyCouldNotLoadEpisodes,
              onRetry: () =>
                  ref.invalidate(animeDetailProvider(widget.anilistId)),
            ),
            data: (detailResult) => detailResult.fold(
              onFailure: (error) => ErrorStateView(
                message: mapErrorMessage(context, error),
                onRetry: () =>
                    ref.invalidate(animeDetailProvider(widget.anilistId)),
              ),
              onSuccess: (detail) {
                final summary = availabilityState.maybeWhen(
                  data: (result) => result.fold(
                    onFailure: (_) => null,
                    onSuccess: (value) => value,
                  ),
                  orElse: () => null,
                );
                final progressList = progressState.maybeWhen(
                  data: (result) => result.fold(
                    onFailure: (_) => const <EpisodeProgress>[],
                    onSuccess: (value) => value,
                  ),
                  orElse: () => const <EpisodeProgress>[],
                );
                return _PartyEpisodeContent(
                  detail: detail,
                  summary: summary,
                  progressList: progressList,
                  session: session,
                  focusedEpisodeNumber: widget.focusedEpisodeNumber,
                  isLaunching: _isLaunching,
                  onBack: _openLobby,
                  onEpisodeSelected: (episode) => _handleEpisodeTap(
                    detail: detail,
                    episode: episode,
                    summary: summary,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openLobby() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _handleEpisodeTap({
    required AnimeDetail detail,
    required AnimeEpisode episode,
    required SourceAvailabilitySummary? summary,
  }) async {
    final session = ref.read(partySessionProvider);
    final room = session.room;
    final notifier = ref.read(partySessionProvider.notifier);
    final isHost = notifier.isLocalHost;
    final isCurrentPartyEpisode =
        room != null &&
        room.anilistId == detail.anime.anilistId &&
        (room.episodeNumber - episode.number).abs() < 0.001;

    if (!isHost && !isCurrentPartyEpisode) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.partyHostChoosesNextEpisode)),
      );
      return;
    }

    if (isHost && !isCurrentPartyEpisode) {
      await notifier.changeMedia(
        anilistId: detail.anime.anilistId,
        animeTitle: detail.anime.title.romaji,
        episodeNumber: episode.number,
      );
    }

    if (summary == null || _isLaunching) {
      return;
    }

    final dlTasksState = ref.read(
      downloadTasksByAnimeProvider(detail.anime.anilistId),
    );
    final offlineTask = dlTasksState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (tasks) {
          for (final task in tasks) {
            if ((task.episodeNumber - episode.number).abs() < 0.001 &&
                task.status == DownloadStatus.completed &&
                task.filePath != null) {
              return task;
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
              anilistId: detail.anime.anilistId,
              animeTitle: detail.anime.title.romaji,
              episodeNumber: episode.number.toInt().toString(),
              episodeTitle: _displayEpisodeTitle(episode),
              persistSelection: false,
              sourcePluginId: offlineTask.sourcePluginId ?? 'offline',
              serverName: offlineTask.serverName ?? 'Downloaded',
              routeMode: PartyRouteMode.party,
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
      unawaited(
        ref.read(downloadManagerProvider).deleteCompleted(offlineTask.id),
      );
    }

    if (!mounted) return;
    setState(() => _isLaunching = true);
    showBlockingLoader(context, context.l10n.partyOpeningEpisode);
    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: detail.anime.anilistId,
          episodeNumber: episode.number,
          availabilitySummary: summary,
        );
    if (!mounted) return;
    hideBlockingLoader(context);
    setState(() => _isLaunching = false);
    await handlePlaybackDecision(
      context: context,
      ref: ref,
      anilistId: detail.anime.anilistId,
      animeTitle: detail.anime.title.romaji,
      episodeTitle: _displayEpisodeTitle(episode),
      routeMode: PartyRouteMode.party,
      decision: decision,
      totalEpisodes: detail.anime.totalEpisodes,
      nextAiringEpisodeNumber: detail.anime.nextAiringEpisodeNumber?.toDouble(),
    );
  }

  String _displayEpisodeTitle(AnimeEpisode episode) {
    return episode.title.trim().isNotEmpty
        ? episode.title
        : context.l10n.partyEpisodeLabel(episode.number.toInt());
  }
}

class _PartyEpisodeContent extends ConsumerWidget {
  const _PartyEpisodeContent({
    required this.detail,
    required this.summary,
    required this.progressList,
    required this.session,
    required this.focusedEpisodeNumber,
    required this.isLaunching,
    required this.onBack,
    required this.onEpisodeSelected,
  });

  final AnimeDetail detail;
  final SourceAvailabilitySummary? summary;
  final List<EpisodeProgress> progressList;
  final PartySessionState session;
  final double? focusedEpisodeNumber;
  final bool isLaunching;
  final VoidCallback onBack;
  final ValueChanged<AnimeEpisode> onEpisodeSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    final notifier = ref.read(partySessionProvider.notifier);
    final isHost = notifier.isLocalHost;
    final room = session.room;
    final currentEpisode = room?.episodeNumber ?? focusedEpisodeNumber ?? 1.0;
    final connectedCount = partyConnectedMemberCount(
      session,
      localUserId: notifier.localUserId,
    );

    final episodes = List<AnimeEpisode>.of(detail.episodes)
      ..sort((a, b) => a.number.compareTo(b.number));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.partyEpisodesTitle,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isHost
                                ? context.l10n.partyEpisodesHostSubtitle
                                : context.l10n.partyEpisodesMemberSubtitle,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CloudRadius.lg),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFF152131), Color(0xFF0D131C)],
                    ),
                    border: Border.all(color: colors.surface2),
                  ),
                  child: Row(
                    children: <Widget>[
                      CloudCachedImage(
                        url: detail.anime.coverImageUrl,
                        bucket: CloudImageCacheBucket.artwork,
                        width: 68,
                        height: 96,
                        borderRadius: BorderRadius.circular(CloudRadius.md),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              detail.anime.title.romaji,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _PartyMiniChip(
                                  label: context.l10n.partyRoomOnEpisode(
                                    currentEpisode.toInt(),
                                  ),
                                ),
                                _PartyMiniChip(
                                  label: context.l10n.partyOnlineCount(
                                    connectedCount,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (summary != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: summary!.playableSources
                        .map(
                          (source) => SourceBadge(
                            sourceName: source.manifest.displayName,
                            iconUrl: effectiveSourceIconUrl(source.manifest),
                            audioKinds: source.availableAudioKinds,
                            compact: true,
                            isHighlighted:
                                summary!.recommended?.manifest.id ==
                                source.manifest.id,
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
        if (episodes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateView(message: context.l10n.partyNoEpisodesYet),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final sources = _playableSourcesForEpisode(
                  summary,
                  episode.number,
                );
                final isCurrentPartyEpisode =
                    (currentEpisode - episode.number).abs() < 0.001;
                final progress = progressList
                    .where(
                      (item) =>
                          (item.episodeNumber - episode.number).abs() < 0.001,
                    )
                    .firstOrNull;
                if (!isHost) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrentPartyEpisode
                            ? colors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(CloudRadius.md),
                        border: isCurrentPartyEpisode
                            ? Border.all(
                                color: colors.primary.withValues(alpha: 0.20),
                              )
                            : null,
                      ),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 36,
                            child: Text(
                              episode.number.toInt().toString(),
                              style: TextStyle(
                                color: isCurrentPartyEpisode
                                    ? colors.primary
                                    : colors.textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _displayEpisodeTitle(episode, context: context),
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentPartyEpisode)
                            Text(
                              context.l10n.partyRoomPick,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return EpisodeRow(
                  episodeNumber: episode.number.toString(),
                  title: _displayEpisodeTitle(episode, context: context),
                  subtitle: _secondaryLabel(
                    context: context,
                    isHost: isHost,
                    isCurrentPartyEpisode: isCurrentPartyEpisode,
                    sourceCount: sources.length,
                    episode: episode,
                  ),
                  state: isCurrentPartyEpisode
                      ? EpisodeRowState.active
                      : isLaunching || sources.isEmpty
                      ? EpisodeRowState.notPlayable
                      : EpisodeRowState.defaultState,
                  sourceBadges: sources
                      .map(
                        (source) => SourceBadge(
                          sourceName: source.manifest.displayName,
                          iconUrl: effectiveSourceIconUrl(source.manifest),
                          audioKinds: source.availableAudioKinds,
                          compact: true,
                          iconOnly: true,
                        ),
                      )
                      .toList(growable: false),
                  progress: _progressFraction(progress),
                  activeLabel: isCurrentPartyEpisode
                      ? context.l10n.partyRoomPick
                      : context.l10n.partyTapToQueue,
                  trailingAccessory: _EpisodeActionChip(
                    label: isCurrentPartyEpisode
                        ? (sources.isNotEmpty
                              ? context.l10n.partyWatchTogether
                              : context.l10n.partyWaitingOnSource)
                        : context.l10n.partySetForPartyTooltip,
                    highlighted: isCurrentPartyEpisode,
                  ),
                  onTap: () => onEpisodeSelected(episode),
                );
              },
            ),
          ),
      ],
    );
  }

  List<SourceAvailability> _playableSourcesForEpisode(
    SourceAvailabilitySummary? summary,
    double episodeNumber,
  ) {
    final sources = summary?.playableSources ?? const <SourceAvailability>[];
    return sources
        .where(
          (source) => source.episodes.any(
            (episode) => (episode.number - episodeNumber).abs() < 0.001,
          ),
        )
        .toList(growable: false);
  }

  String _displayEpisodeTitle(
    AnimeEpisode episode, {
    required BuildContext context,
  }) {
    return resolveEpisodeDisplayTitle(
      episodeNumber: episode.number,
      fallbackTitle: context.l10n.partyEpisodeLabel(episode.number.toInt()),
      animeTitle: detail.anime.title.romaji,
      metadata: episode,
    );
  }

  String _secondaryLabel({
    required BuildContext context,
    required bool isHost,
    required bool isCurrentPartyEpisode,
    required int sourceCount,
    required AnimeEpisode episode,
  }) {
    if (isCurrentPartyEpisode && sourceCount > 0) {
      return context.l10n.partyRoomEpisodeReady;
    }
    if (isCurrentPartyEpisode) {
      return context.l10n.partyRoomEpisodeNoSource;
    }
    if (isHost) {
      return context.l10n.partyTapToMoveEpisode(episode.number.toInt());
    }
    return context.l10n.partyOnlyHostChangesEpisode;
  }

  double? _progressFraction(EpisodeProgress? progress) {
    if (progress == null) {
      return null;
    }
    final total = progress.totalDuration;
    if (total == null || total <= Duration.zero) {
      return null;
    }
    return (progress.position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }
}

class _EpisodeActionChip extends StatelessWidget {
  const _EpisodeActionChip({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withValues(alpha: 0.18)
            : colors.surface,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: 0.35)
              : colors.surface2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PartyMiniChip extends StatelessWidget {
  const _PartyMiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CloudRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
