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
import '../../../downloads/application/probe_audio_kinds.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../downloads/presentation/widgets/download_path_dialog.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../watch_party/application/party_session_guard.dart';
import '../../../watch_party/application/providers/party_providers.dart';
import '../../../watch_party/presentation/party_route_mode.dart';
import '../../../watch_party/presentation/pages/party_lobby_page.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../support/episode_display_title.dart';
import '../support/playback_launch_flow.dart';
import '../support/plugin_icon_helpers.dart';
import '../support/translated_episode_title.dart';
import '../widgets/source_badge.dart';
import '../widgets/source_quality_picker_sheet.dart';
import '../../../../shared/theme/kumoriya_theme.dart';

class EpisodeListPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return EpisodeListScene(
      anilistId: anilistId,
      animeTitle: animeTitle,
      focusedEpisodeNumber: focusedEpisodeNumber,
      routeMode: PartyRouteMode.standard,
    );
  }
}

class EpisodeListScene extends ConsumerStatefulWidget {
  const EpisodeListScene({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    this.focusedEpisodeNumber,
    required this.routeMode,
  });

  final int anilistId;
  final String animeTitle;
  final double? focusedEpisodeNumber;
  final PartyRouteMode routeMode;

  @override
  ConsumerState<EpisodeListScene> createState() => _EpisodeListSceneState();
}

class _EpisodeListSceneState extends ConsumerState<EpisodeListScene> {
  static const int _aniSkipPrefetchWindowBefore = 10;
  static const int _aniSkipPrefetchWindowAfter = 50;
  static const int _aniSkipPrefetchLargeSeries = 150;
  static const int _pageSize = 50;

  bool _isLaunching = false;
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToFocus = false;
  bool _didAutoDownloadCheck = false;
  bool _didAniSkipPrefetch = false;

  int _currentPage = 0;
  bool _didAutoSelectPage = false;

  List<_EpisodeRowData>? _cachedRows;
  List<AnimeEpisode>? _prevEpisodes;
  SourceAvailabilitySummary? _prevSummary;
  List<EpisodeProgress>? _prevProgress;
  Map<int, MalEpisodeMetadata>? _prevMalMetadata;

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
    final partySession = ref.watch(partySessionProvider);
    final isLocalHost = ref.read(partySessionProvider.notifier).isLocalHost;
    final partyLockedEpisode = partyLockedEpisodeNumberForAnime(
      session: partySession,
      isLocalHost: isLocalHost,
      anilistId: widget.anilistId,
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
          leading: widget.routeMode.isParty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.l10n.partyBackToLobbyTooltip,
                  onPressed: () => Navigator.of(context, rootNavigator: true)
                      .pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => PartyLobbyPage(
                            anilistId: widget.anilistId,
                            animeTitle: widget.animeTitle,
                          ),
                        ),
                      ),
                )
              : null,
          title: Text(
            widget.routeMode.isParty
                ? context.l10n.partyEpisodesTitle
                : context.l10n.episodeListTitle(widget.animeTitle),
          ),
        ),
        body: LoadingStateView(label: context.l10n.episodeListLoading),
      );
    }

    final bool inputsChanged =
        !identical(_prevEpisodes, animeEpisodes) ||
        !identical(_prevSummary, sourceSummary) ||
        !identical(_prevProgress, progressList) ||
        !identical(_prevMalMetadata, malEpisodeMetadata);

    if (inputsChanged || _cachedRows == null) {
      _cachedRows = _buildEpisodeRows(
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
      _prevEpisodes = animeEpisodes;
      _prevSummary = sourceSummary;
      _prevProgress = progressList;
      _prevMalMetadata = malEpisodeMetadata;
    }
    final rows = _cachedRows!;

    // Auto-select the page that contains the focused episode (runs once).
    if (!_didAutoSelectPage &&
        widget.focusedEpisodeNumber != null &&
        rows.isNotEmpty) {
      _didAutoSelectPage = true;
      final focusIndex = rows.indexWhere(
        (row) => (row.number - widget.focusedEpisodeNumber!).abs() < 0.001,
      );
      if (focusIndex >= 0) {
        _currentPage = focusIndex ~/ _pageSize;
      }
    }

    final pageCount = rows.isEmpty ? 0 : ((rows.length - 1) ~/ _pageSize) + 1;
    final pageStart = _currentPage * _pageSize;
    final visibleRows = rows
        .skip(pageStart)
        .take(_pageSize)
        .toList(growable: false);

    _scheduleScrollToFocus(visibleRows);
    _scheduleAutoDownloadCheck(rows);
    _scheduleAniSkipPrefetch(animeEpisodes);

    // Lift download-tasks watch here so individual _EpisodeCard widgets don't
    // each independently watch the same provider (N cards → N rebuilds).
    final dlTasksState = ref.watch(
      downloadTasksByAnimeProvider(widget.anilistId),
    );
    final dlTaskMap = <int, DownloadTask>{};
    dlTasksState.whenData((result) {
      result.fold(
        onSuccess: (tasks) {
          for (final t in tasks) {
            dlTaskMap[(t.episodeNumber * 1000).round()] = t;
          }
        },
        onFailure: (_) {},
      );
    });

    return Scaffold(
      appBar: AppBar(
        leading: widget.routeMode.isParty
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: context.l10n.partyBackToLobbyTooltip,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PartyLobbyPage(
                          anilistId: widget.anilistId,
                          animeTitle: widget.animeTitle,
                        ),
                      ),
                    ),
              )
            : null,
        title: Text(
          widget.routeMode.isParty
              ? context.l10n.partyEpisodesTitle
              : context.l10n.episodeListTitle(widget.animeTitle),
        ),
      ),
      body: rows.isEmpty
          ? EmptyStateView(message: context.l10n.episodeListEmpty)
          : CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _EpisodeListHeader(
                      summary: sourceSummary,
                      preference: preference,
                      anilistId: widget.anilistId,
                      animeTitle: widget.animeTitle,
                      rows: rows,
                      lockedEpisodeNumber: partyLockedEpisode,
                      routeMode: widget.routeMode,
                    ),
                  ),
                ),
                if (pageCount > 1) ...<Widget>[
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: _PageSelector(
                      pageCount: pageCount,
                      currentPage: _currentPage,
                      pageSize: _pageSize,
                      totalRows: rows.length,
                      onPageSelected: (page) {
                        setState(() {
                          _currentPage = page;
                          _didScrollToFocus = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _scrollController.hasClients) {
                            _scrollController.jumpTo(0);
                          }
                        });
                      },
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.builder(
                    itemCount: visibleRows.length,
                    itemBuilder: (context, index) {
                      final row = visibleRows[index];
                      final dlTask = dlTaskMap[(row.number * 1000).round()];
                      return _EpisodeCard(
                        key: ValueKey('ep-${row.number}'),
                        row: row,
                        anilistId: widget.anilistId,
                        animeTitle: widget.animeTitle,
                        downloadTask: dlTask,
                        routeMode: widget.routeMode,
                        onTap:
                            row.playableSources.isEmpty ||
                                sourceSummary == null ||
                                _isLaunching
                            ? null
                            : isPartyEpisodeLocked(
                                session: partySession,
                                isLocalHost: isLocalHost,
                                anilistId: widget.anilistId,
                                episodeNumber: row.number,
                              )
                            ? () => _showPartyEpisodeLockedMessage(
                                context,
                                partyLockedEpisode ?? row.number,
                              )
                            : () => _handleEpisodeTap(row, sourceSummary),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _scheduleAniSkipPrefetch(List<AnimeEpisode> animeEpisodes) {
    if (_didAniSkipPrefetch || animeEpisodes.isEmpty) {
      return;
    }
    var episodeNumbers = animeEpisodes
        .where((episode) => episode.isAired)
        .map((episode) => episode.number.toInt())
        .where((episodeNumber) => episodeNumber > 0)
        .toSet()
        .toList(growable: false);
    if (episodeNumbers.isEmpty) {
      return;
    }

    if (episodeNumbers.length > _aniSkipPrefetchLargeSeries) {
      final focus = widget.focusedEpisodeNumber?.toInt() ?? episodeNumbers.last;
      final rangeStart = (focus - _aniSkipPrefetchWindowBefore).clamp(
        episodeNumbers.first,
        episodeNumbers.last,
      );
      final rangeEnd = (focus + _aniSkipPrefetchWindowAfter).clamp(
        episodeNumbers.first,
        episodeNumbers.last,
      );
      episodeNumbers = episodeNumbers
          .where((n) => n >= rangeStart && n <= rangeEnd)
          .toList(growable: false);
    }

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
    final partySession = ref.read(partySessionProvider);
    final isLocked = isPartyEpisodeLocked(
      session: partySession,
      isLocalHost: ref.read(partySessionProvider.notifier).isLocalHost,
      anilistId: widget.anilistId,
      episodeNumber: row.number,
    );
    if (isLocked) {
      _showPartyEpisodeLockedMessage(
        context,
        partySession.room?.episodeNumber ?? row.number,
      );
      return;
    }
    final playbackPreparingLabel = context.l10n.playbackPreparing;
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final translatedEpisodeTitle = await resolveTranslatedEpisodeTitle(
      ref: ref,
      title: row.displayTitle,
      languageCode: languageCode,
    );
    if (!mounted) return;

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

        final detailResult = await ref.read(
          animeDetailProvider(widget.anilistId).future,
        );
        if (!mounted) return;
        final totalEpisodes = detailResult.fold(
          onFailure: (_) => null,
          onSuccess: (detail) => detail.anime.totalEpisodes,
        );

        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerPage(
              anilistId: widget.anilistId,
              animeTitle: widget.animeTitle,
              episodeNumber: row.number.toInt().toString(),
              episodeTitle: translatedEpisodeTitle,
              persistSelection: false,
              sourcePluginId: offlineTask.sourcePluginId ?? 'offline',
              serverName: offlineTask.serverName ?? 'Downloaded',
              routeMode: widget.routeMode,
              resolved: ResolvedServerLinkResult(
                resolverId: 'offline',
                resolverName: 'Downloaded',
                streams: <ResolvedStream>[ResolvedStream(url: file.uri)],
              ),
              totalEpisodes: totalEpisodes,
            ),
          ),
        );
        return;
      }
      // File was deleted outside the app — clean up the orphan record so the
      // provider reflects reality and the streaming path can proceed.
      unawaited(
        ref.read(downloadManagerProvider).deleteCompleted(offlineTask.id),
      );
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

    final detailResult = await ref.read(
      animeDetailProvider(widget.anilistId).future,
    );
    if (!mounted) return;
    final totalEpisodes = detailResult.fold(
      onFailure: (_) => null,
      onSuccess: (detail) => detail.anime.totalEpisodes,
    );

    // ignore: use_build_context_synchronously
    await handlePlaybackDecision(
      context: rootNavigator.context,
      ref: ref,
      anilistId: widget.anilistId,
      animeTitle: widget.animeTitle,
      episodeTitle: translatedEpisodeTitle,
      routeMode: widget.routeMode,
      decision: decision,
      totalEpisodes: totalEpisodes,
    );
  }

  T? _extractSuccessValue<T>(AsyncValue<Result<T, KumoriyaError>> asyncValue) {
    return asyncValue.maybeWhen(
      data: (result) =>
          result.fold(onSuccess: (value) => value, onFailure: (_) => null),
      orElse: () => null,
    );
  }

  void _showPartyEpisodeLockedMessage(
    BuildContext context,
    double episodeNumber,
  ) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.partyLockedToEpisode(episodeNumber.toInt())),
        duration: const Duration(seconds: 2),
      ),
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
      final languageCode =
          Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

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
        if (!mounted) return;
        final translatedEpisodeTitle = await resolveTranslatedEpisodeTitle(
          ref: ref,
          title: row.displayTitle,
          languageCode: languageCode,
        );
        if (!mounted) return;
        await _enqueueEpisodeDownload(
          context: context,
          ref: ref,
          anilistId: widget.anilistId,
          sourcePluginId: entry.key,
          sourceEpisode: entry.value,
          animeTitle: widget.animeTitle,
          coverImageUrl: _resolveCoverUrl(ref, widget.anilistId),
          episodeTitle: translatedEpisodeTitle,
        );
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
    required this.lockedEpisodeNumber,
    required this.routeMode,
  });

  final SourceAvailabilitySummary? summary;
  final PlaybackPreference? preference;
  final int anilistId;
  final String animeTitle;
  final List<_EpisodeRowData> rows;
  final double? lockedEpisodeNumber;
  final PartyRouteMode routeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playableSources =
        summary?.playableSources ?? const <SourceAvailability>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (routeMode.isParty) ...<Widget>[
          const _PartyEpisodeBanner(),
          const SizedBox(height: 8),
        ],
        if (lockedEpisodeNumber != null) ...<Widget>[
          _InfoBanner(
            message:
                'Watch party active: only episode ${lockedEpisodeNumber!.toInt()} can be opened until the host changes it.',
          ),
          const SizedBox(height: 8),
        ],
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
                    iconUrl: effectiveSourceIconUrl(source.manifest),
                    audioKinds: source.availableAudioKinds,
                    compact: true,
                    highlighted:
                        summary?.recommended?.manifest.id == source.manifest.id,
                  ),
                )
                .toList(growable: false),
          ),
        if (!routeMode.isParty && playableSources.isNotEmpty) ...<Widget>[
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
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final downloadable = rows
        .where((r) => r.sourceEpisodes.isNotEmpty)
        .toList();
    if (downloadable.isEmpty) return;

    final sourceId = await _pickSourceForBulkDownload(context, ref);
    if (sourceId == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    // Detect available audio kinds for the chosen source. Prefer the cached
    // [SourceAvailability.availableAudioKinds] when populated; otherwise probe
    // the first downloadable episode's server links just-in-time.
    final selectedSource = summary?.playableSources
        .where((s) => s.manifest.id == sourceId)
        .firstOrNull;
    var audioKinds =
        selectedSource?.availableAudioKinds ?? const <SourceAudioKind>{};
    if (audioKinds.length <= 1) {
      final sampleEpisode = downloadable
          .map((row) => row.sourceEpisodes[sourceId])
          .whereType<SourceEpisode>()
          .firstOrNull;
      if (sampleEpisode != null) {
        final probed = await probeAudioKindsForSource(
          ref: ref,
          sourcePluginId: sourceId,
          sampleEpisode: sampleEpisode,
        );
        if (probed.isNotEmpty) audioKinds = probed;
      }
      if (!context.mounted) return;
    }

    SourceAudioKind? audioPreference;
    if (audioKinds.length > 1) {
      audioPreference = await _pickAudioKind(context);
      if (audioPreference == null || !context.mounted) return;
    }

    // Enqueue in parallel batches of 4 with deterministic timestamps
    // so episode ordering is preserved.
    final baseTime = DateTime.now();
    var queued = 0;

    for (var i = 0; i < downloadable.length; i += 4) {
      final batch = downloadable.sublist(
        i,
        (i + 4).clamp(0, downloadable.length),
      );
      if (!context.mounted) return;

      final futures = <Future<bool>>[];
      for (var j = 0; j < batch.length; j++) {
        final row = batch[j];
        final entry = row.sourceEpisodes.entries
            .where((e) => e.key == sourceId)
            .firstOrNull;
        if (entry == null) continue;
        final translatedEpisodeTitle = await resolveTranslatedEpisodeTitle(
          ref: ref,
          title: row.displayTitle,
          languageCode: languageCode,
        );
        if (!context.mounted) return;

        futures.add(
          _enqueueEpisodeDownload(
            context: context,
            ref: ref,
            anilistId: anilistId,
            sourcePluginId: entry.key,
            sourceEpisode: entry.value,
            audioPreference: audioPreference,
            animeTitle: animeTitle,
            coverImageUrl: _resolveCoverUrl(ref, anilistId),
            episodeTitle: translatedEpisodeTitle,
            createdAt: baseTime.add(Duration(milliseconds: i + j)),
          ),
        );
      }
      final results = await Future.wait(futures);
      queued += results.where((r) => r).length;
    }

    if (context.mounted && queued > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadAllQueued)));
    }
  }

  Future<SourceAudioKind?> _pickAudioKind(BuildContext context) {
    return showModalBottomSheet<SourceAudioKind>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  context.l10n.downloadAllChooseAudio,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_rounded),
                title: const Text('SUB'),
                onTap: () => Navigator.of(context).pop(SourceAudioKind.sub),
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_rounded),
                title: const Text('DUB'),
                onTap: () => Navigator.of(context).pop(SourceAudioKind.dub),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _pickSourceForBulkDownload(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

    // Build a sample-episode map so the sheet can probe each source.
    final sampleEpisodes = <String, SourceEpisode>{};
    for (final source in playableSources) {
      final sampleRow = rows
          .where((row) => row.sourceEpisodes.containsKey(source.manifest.id))
          .firstOrNull;
      final episode = sampleRow?.sourceEpisodes[source.manifest.id];
      if (episode == null) {
        continue;
      }
      sampleEpisodes[source.manifest.id] = episode;
    }

    if (!context.mounted) return null;

    // Show the sheet immediately — quality probes run inside the widget.
    return showSourceQualityPickerSheet(
      context: context,
      sources: playableSources,
      sampleEpisodes: sampleEpisodes,
    );
  }
}

class _EpisodeCard extends ConsumerStatefulWidget {
  const _EpisodeCard({
    super.key,
    required this.row,
    required this.anilistId,
    required this.animeTitle,
    required this.routeMode,
    this.downloadTask,
    this.onTap,
  });

  final _EpisodeRowData row;
  final int anilistId;
  final String animeTitle;
  final PartyRouteMode routeMode;
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                children: <Widget>[
                  if (!widget.routeMode.isParty)
                    _buildDownloadButton(context, dlTask),
                  FilledButton.tonalIcon(
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      row.playableSources.isEmpty
                          ? context.l10n.playEpisode
                          : widget.routeMode.isParty
                          ? 'Propose to Party'
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
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      icon: const Icon(Icons.download_rounded, size: 28),
      tooltip: context.l10n.downloadEpisode,
      onPressed: () => _handleDownload(context),
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isEnqueuing) return;
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    setState(() => _isEnqueuing = true);

    // Pick the first non-excluded source for download.
    final entry = widget.row.sourceEpisodes.entries
        .where((e) => e.key != _excludedDownloadSource)
        .firstOrNull;

    final success = entry != null
        ? await () async {
            final translatedEpisodeTitle = await resolveTranslatedEpisodeTitle(
              ref: ref,
              title: widget.row.displayTitle,
              languageCode: languageCode,
            );
            if (!context.mounted) return false;
            return _enqueueEpisodeDownload(
              context: context,
              ref: ref,
              anilistId: widget.anilistId,
              sourcePluginId: entry.key,
              sourceEpisode: entry.value,
              animeTitle: widget.animeTitle,
              coverImageUrl: _resolveCoverUrl(ref, widget.anilistId),
              episodeTitle: translatedEpisodeTitle,
            );
          }()
        : false;

    if (!context.mounted) return;
    setState(() => _isEnqueuing = false);
    final messenger = ScaffoldMessenger.of(context);
    if (success) {
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

class _PartyEpisodeBanner extends StatelessWidget {
  const _PartyEpisodeBanner();

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(message: context.l10n.partyEpisodeModeBanner);
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
      DownloadStatus.disconnected => (
        Icons.cloud_off_rounded,
        KumoriyaColors.textMuted,
        // TODO(i18n): localize.
        'Sin conexi\u00f3n',
      ),
      DownloadStatus.remuxing => (
        Icons.auto_fix_high_rounded,
        Theme.of(context).colorScheme.primary,
        // TODO(i18n): localize.
        'Procesando\u2026',
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
        color: KumoriyaColors.primary.withValues(alpha: 0.85),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: KumoriyaColors.textPrimary,
        ),
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
          displayTitle: resolveEpisodeDisplayTitle(
            episodeNumber: number,
            animeTitle: animeTitle,
            metadata: metadata,
            sourceEpisodes:
                sourceEpisodesByNumber[number] ??
                const <String, SourceEpisode>{},
            fallbackTitle:
                (jikanMetadata?.title != null &&
                    jikanMetadata!.title!.trim().isNotEmpty)
                ? jikanMetadata.title!.trim()
                : fallbackTitleBuilder(number),
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

// ─── Page selector ───────────────────────────────────────────────────────────

class _PageSelector extends StatefulWidget {
  const _PageSelector({
    required this.pageCount,
    required this.currentPage,
    required this.pageSize,
    required this.totalRows,
    required this.onPageSelected,
  });

  final int pageCount;
  final int currentPage;
  final int pageSize;
  final int totalRows;
  final void Function(int page) onPageSelected;

  @override
  State<_PageSelector> createState() => _PageSelectorState();
}

class _PageSelectorState extends State<_PageSelector> {
  final ScrollController _chipScroll = ScrollController();

  @override
  void didUpdateWidget(_PageSelector old) {
    super.didUpdateWidget(old);
    if (old.currentPage != widget.currentPage) {
      _scrollToCurrentChip();
    }
  }

  void _scrollToCurrentChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chipScroll.hasClients) return;
      const chipWidth = 80.0;
      const chipSpacing = 8.0;
      final target = widget.currentPage * (chipWidth + chipSpacing);
      _chipScroll.animateTo(
        target.clamp(0.0, _chipScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _chipScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        controller: _chipScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.pageCount,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final start = index * widget.pageSize + 1;
          final end = ((index + 1) * widget.pageSize).clamp(
            0,
            widget.totalRows,
          );
          final isSelected = index == widget.currentPage;
          return ChoiceChip(
            label: Text('$start–$end', style: const TextStyle(fontSize: 12)),
            selected: isSelected,
            onSelected: (_) => widget.onPageSelected(index),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

// ─── Episode row data ─────────────────────────────────────────────────────────

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
  required BuildContext context,
  required WidgetRef ref,
  required int anilistId,
  required String sourcePluginId,
  required SourceEpisode sourceEpisode,
  SourceAudioKind? audioPreference,
  String? animeTitle,
  String? coverImageUrl,
  String? episodeTitle,
  DateTime? createdAt,
}) async {
  try {
    final configured = await _ensureDownloadDirectoryConfigured(
      context: context,
      ref: ref,
    );
    if (!configured) {
      return false;
    }

    await _prefetchAniSkipForDownload(
      ref: ref,
      anilistId: anilistId,
      episodeNumber: sourceEpisode.number,
    );

    final sourcePlugin = ref.read(sourcePluginByIdProvider(sourcePluginId));
    final registry = ref.read(resolverRegistryProvider);

    final linksResult = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: sourcePlugin,
      registry: registry,
      includeDownloadLinks: true,
    ).call(sourceEpisode);

    var links = linksResult.fold(
      onSuccess: (l) => l,
      onFailure: (_) => <SourceServerLink>[],
    );
    if (links.isEmpty) return false;

    // Filter by audio preference when provided.
    if (audioPreference != null) {
      final filtered = links
          .where((link) {
            final kind = sourceAudioKindFromCode(link.language);
            return kind == audioPreference;
          })
          .toList(growable: false);
      if (filtered.isNotEmpty) links = filtered;
    }

    // Rank servers by historical success rate — best first.
    final scorer = ref.read(downloadServerScorerProvider);
    links = scorer.rankByScore(links, (l) => l.serverName);

    final enqueueUseCase = ref.read(enqueueDownloadUseCaseProvider);
    for (final link in links) {
      final result = await enqueueUseCase.call(
        anilistId: anilistId,
        episodeNumber: sourceEpisode.number,
        serverLink: link,
        sourcePluginId: sourcePluginId,
        animeTitle: animeTitle,
        coverImageUrl: coverImageUrl,
        episodeTitle: episodeTitle ?? sourceEpisode.title,
        createdAt: createdAt,
      );
      final enqueued = result.fold(
        onSuccess: (_) => true,
        onFailure: (_) => false,
      );
      if (enqueued) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

Future<bool> _ensureDownloadDirectoryConfigured({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final directoryService = ref.read(downloadDirectoryServiceProvider);
  if (await directoryService.hasConfiguredDownloadDirectory()) {
    return true;
  }

  final suggestion = await directoryService.getDefaultSuggestionPath();
  if (!context.mounted) {
    return false;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DownloadPathDialog(
      suggestedPath: suggestion,
      onUseDefault: () async {
        final result = await directoryService.selectDirectoryPath(suggestion);
        if (result is Success && ctx.mounted) {
          Navigator.of(ctx).pop();
        }
      },
      onBrowse: () async {
        final outcome = await directoryService
            .selectAndPersistCustomDirectory();
        outcome.fold(
          onFailure: (_) {},
          onSuccess: (value) {
            if (value.changed && ctx.mounted) {
              Navigator.of(ctx).pop();
            }
          },
        );
      },
    ),
  );

  return directoryService.hasConfiguredDownloadDirectory();
}

Future<void> _prefetchAniSkipForDownload({
  required WidgetRef ref,
  required int anilistId,
  required double episodeNumber,
}) async {
  final normalizedEpisode = episodeNumber.toInt();
  if (normalizedEpisode <= 0) {
    return;
  }

  try {
    await ref
        .read(malMetadataBridgeProvider)
        .getAniSkipSegments(
          anilistId: anilistId,
          episodeNumber: normalizedEpisode,
          episodeLengthSeconds: 1440,
        )
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // Soft-fail: allow download to proceed if AniSkip prefetch fails.
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
