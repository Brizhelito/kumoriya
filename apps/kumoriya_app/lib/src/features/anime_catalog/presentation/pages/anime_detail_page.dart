import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../shared/utils/error_messaging.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/widgets/translated_dynamic_text.dart';
import '../../application/models/source_availability.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../../application/services/mal_metadata_bridge_service.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import '../../application/models/resolved_server_link_result.dart';
import '../../application/models/server_quality_registry.dart';
import '../../../downloads/application/probe_audio_kinds.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../manga_catalog/presentation/pages/manga_detail_page.dart';
import '../../../player/presentation/pages/player_page.dart';
import 'episode_list_page.dart';
import '../../../watch_party/application/party_session_guard.dart';
import '../../../watch_party/application/providers/party_providers.dart';
import '../../../watch_party/presentation/pages/party_anime_page.dart';
import '../../../watch_party/presentation/pages/party_episode_list_page.dart';
import '../../../watch_party/presentation/party_route_mode.dart';
import '../support/episode_display_title.dart';
import '../support/playback_launch_flow.dart';
import '../support/plugin_icon_helpers.dart';
import '../support/translated_episode_title.dart';
import '../widgets/source_quality_picker_sheet.dart';

class AnimeDetailPage extends StatelessWidget {
  const AnimeDetailPage({super.key, required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context) {
    return AnimeDetailScene(
      anilistId: anilistId,
      routeMode: PartyRouteMode.standard,
      enableDebugShortcuts: true,
    );
  }
}

class AnimeDetailScene extends ConsumerStatefulWidget {
  const AnimeDetailScene({
    super.key,
    required this.anilistId,
    required this.routeMode,
    this.enableDebugShortcuts = false,
  });

  final int anilistId;
  final PartyRouteMode routeMode;
  final bool enableDebugShortcuts;

  @override
  ConsumerState<AnimeDetailScene> createState() => _AnimeDetailSceneState();
}

class _AnimeDetailSceneState extends ConsumerState<AnimeDetailScene> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showDebugPlaybackPreferenceTools() async {
    if (!kDebugMode) {
      return;
    }

    final preferenceResult = await ref.read(
      playbackPreferenceProvider(widget.anilistId).future,
    );
    if (!mounted) {
      return;
    }

    final preference = preferenceResult.fold(
      onFailure: (_) => null,
      onSuccess: (value) => value,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = FormFactorProvider.colorsOf(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Debug playback preference',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preference == null
                      ? 'No persisted preferred player is stored for this anime.'
                      : _debugPreferenceSummary(preference),
                  style: TextStyle(fontSize: 14, color: colors.text),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: preference != null,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Clear persisted preferred player'),
                  subtitle: const Text(
                    'Removes the saved source/server/resolver preference for this anime.',
                  ),
                  onTap: preference == null
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          final result = await ref
                              .read(clearPlaybackPreferenceUseCaseProvider)
                              .call(widget.anilistId);
                          if (!mounted) {
                            return;
                          }

                          result.fold(
                            onFailure: (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to clear preferred player: ${error.message}',
                                  ),
                                ),
                              );
                            },
                            onSuccess: (_) {
                              ref.invalidate(
                                playbackPreferenceProvider(widget.anilistId),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Persisted preferred player cleared.',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(widget.anilistId),
    );
    final latestProgressState = ref.watch(
      latestEpisodeProgressProvider(widget.anilistId),
    );

    final content = Scaffold(
      body: detailState.when(
        loading: () => LoadingStateView(label: context.l10n.animeDetailLoading),
        error: (_, _) => ErrorStateView(
          message: context.l10n.genericLoadFailure,
          onRetry: () => ref.invalidate(animeDetailProvider(widget.anilistId)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () =>
                ref.invalidate(animeDetailProvider(widget.anilistId)),
          ),
          onSuccess: (detail) => AnimeDetailContent(
            detail: detail,
            availabilityState: availabilityState,
            latestProgressState: latestProgressState,
            routeMode: widget.routeMode,
          ),
        ),
      ),
    );

    if (!kDebugMode || !widget.enableDebugShortcuts) {
      return content;
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD):
            _showDebugPlaybackPreferenceTools,
      },
      child: Focus(autofocus: true, child: content),
    );
  }
}

class AnimeDetailContent extends ConsumerWidget {
  const AnimeDetailContent({
    super.key,
    required this.detail,
    required this.availabilityState,
    required this.latestProgressState,
    required this.routeMode,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final AsyncValue<Result<EpisodeProgress?, KumoriyaError>> latestProgressState;
  final PartyRouteMode routeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(animeDetailProvider(detail.anime.anilistId));
        ref.invalidate(
          sourceAvailabilitySummaryProvider(detail.anime.anilistId),
        );
        ref.invalidate(latestEpisodeProgressProvider(detail.anime.anilistId));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: colors.bg,
            elevation: 0,
            leading: routeMode.isParty
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: context.l10n.partyBackToLobbyTooltip,
                    onPressed: () => Navigator.of(context, rootNavigator: true)
                        .pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => PartyAnimePage(
                              anilistId: detail.anime.anilistId,
                            ),
                          ),
                        ),
                  )
                : null,
            title: routeMode.isParty ? Text(context.l10n.partyTitle) : null,
            actions: [
              _PartyActionButton(
                anilistId: detail.anime.anilistId,
                animeTitle: detail.anime.title.romaji,
                routeMode: routeMode,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DetailHero(detail: detail),
              stretchModes: const <StretchMode>[StretchMode.fadeTitle],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                if (routeMode.isParty) ...<Widget>[
                  const _PartyBrowseBanner(),
                  const SizedBox(height: 14),
                ],
                _TitleBlock(detail: detail),
                const SizedBox(height: 14),
                _PlayResumeCta(
                  anilistId: detail.anime.anilistId,
                  animeTitle: detail.anime.title.romaji,
                  availabilityState: availabilityState,
                  latestProgressState: latestProgressState,
                  routeMode: routeMode,
                ),
                if (!routeMode.isParty) ...<Widget>[
                  const SizedBox(height: 12),
                  _WatchPartySpotlightCard(
                    anilistId: detail.anime.anilistId,
                    animeTitle: detail.anime.title.romaji,
                    routeMode: routeMode,
                  ),
                ],
                const SizedBox(height: 12),
                _LibraryActions(anilistId: detail.anime.anilistId),
                if (detail.synopsis != null &&
                    detail.synopsis!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _CollapsibleSynopsis(synopsis: detail.synopsis!),
                ],
                if (detail.genres.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detail.genres
                        .map(
                          (genre) => MetaChip(
                            label: displayGenreLabel(context, genre),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 22),
                _EpisodeDetailSection(
                  detail: detail,
                  availabilityState: availabilityState,
                  latestProgressState: latestProgressState,
                  routeMode: routeMode,
                ),
                if (detail.relations.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  _AnimeRelationsSection(
                    relations: detail.relations,
                    routeMode: routeMode,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayResumeCta extends ConsumerStatefulWidget {
  const _PlayResumeCta({
    required this.anilistId,
    required this.animeTitle,
    required this.availabilityState,
    required this.latestProgressState,
    required this.routeMode,
  });

  final int anilistId;
  final String animeTitle;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final AsyncValue<Result<EpisodeProgress?, KumoriyaError>> latestProgressState;
  final PartyRouteMode routeMode;

  @override
  ConsumerState<_PlayResumeCta> createState() => _PlayResumeCtaState();
}

class _PlayResumeCtaState extends ConsumerState<_PlayResumeCta> {
  bool _isLaunching = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final partySession = ref.watch(partySessionProvider);
    final partyLockedEpisode = partyLockedEpisodeNumberForAnime(
      session: partySession,
      isLocalHost: ref.read(partySessionProvider.notifier).isLocalHost,
      anilistId: widget.anilistId,
    );
    final summary = widget.availabilityState.maybeWhen(
      data: (result) =>
          result.fold(onFailure: (_) => null, onSuccess: (s) => s),
      orElse: () => null,
    );

    final latestProgress = widget.latestProgressState.maybeWhen(
      data: (result) =>
          result.fold(onFailure: (_) => null, onSuccess: (p) => p),
      orElse: () => null,
    );

    final targetEpisodeNumber =
        partyLockedEpisode ?? latestProgress?.episodeNumber ?? 1.0;
    final isAvailable = summary != null
        ? summary.playableSources.any(
            (source) => source.episodes.any(
              (episode) => (episode.number - targetEpisodeNumber).abs() < 0.001,
            ),
          )
        : false;
    final hasProgress = latestProgress != null;
    final isCheckingSources = widget.availabilityState.isLoading;
    final checkingLabel = summary == null
        ? context.l10n.detailCheckingSources
        : '${context.l10n.detailCheckingSources} (${summary.playableSources.length})';

    final label = isCheckingSources
        ? checkingLabel
        : partyLockedEpisode != null
        ? context.l10n.partyEpisodeCta(partyLockedEpisode.toInt())
        : widget.routeMode.isParty
        ? context.l10n.partyStartWithParty
        : hasProgress
        ? context.l10n.detailResumeEpisode(latestProgress.episodeNumber.toInt())
        : context.l10n.detailPlay;
    const icon = Icons.play_arrow_rounded;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isAvailable && !_isLaunching && !isCheckingSources
            // ignore: unnecessary_non_null_assertion
            ? () => _handleTap(summary!, targetEpisodeNumber)
            : null,
        icon: _isLaunching || isCheckingSources
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.text,
                ),
              )
            : const Icon(icon, size: 22),
        label: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: colors.text,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.text,
          disabledBackgroundColor: colors.surface,
          disabledForegroundColor: colors.textSoft,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CloudRadius.md),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    SourceAvailabilitySummary summary,
    double episodeNumber,
  ) async {
    // Check for completed offline download first.
    final dlTasksState = ref.read(
      downloadTasksByAnimeProvider(widget.anilistId),
    );
    final offlineTask = dlTasksState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (tasks) {
          for (final t in tasks) {
            if ((t.episodeNumber - episodeNumber).abs() < 0.001 &&
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
              episodeNumber: episodeNumber.toInt().toString(),
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

    if (!mounted) return;
    setState(() => _isLaunching = true);
    showBlockingLoader(context, context.l10n.playbackPreparing);

    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: widget.anilistId,
          episodeNumber: episodeNumber,
          availabilitySummary: summary,
        );
    if (!mounted) return;
    hideBlockingLoader(context);
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
      context: context,
      ref: ref,
      anilistId: widget.anilistId,
      animeTitle: widget.animeTitle,
      episodeTitle: null,
      routeMode: widget.routeMode,
      decision: decision,
      totalEpisodes: totalEpisodes,
    );
  }
}

class _PartyBrowseBanner extends StatelessWidget {
  const _PartyBrowseBanner();

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primarySoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(CloudRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.groups_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.partyBrowseModeBanner,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleSynopsis extends StatefulWidget {
  const _CollapsibleSynopsis({required this.synopsis});
  final String synopsis;
  @override
  State<_CollapsibleSynopsis> createState() => _CollapsibleSynopsisState();
}

class _CollapsibleSynopsisState extends State<_CollapsibleSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: <Widget>[
              Text(
                context.l10n.detailSynopsisTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: colors.textSoft,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: TranslatedDynamicText(
            widget.synopsis,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colors.textMuted,
            ),
          ),
          secondChild: TranslatedDynamicText(
            widget.synopsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colors.textMuted,
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: CloudMotion.fast,
        ),
      ],
    );
  }
}

class _AnimeRelationsSection extends StatefulWidget {
  const _AnimeRelationsSection({
    required this.relations,
    required this.routeMode,
  });

  final List<AnimeRelation> relations;
  final PartyRouteMode routeMode;

  @override
  State<_AnimeRelationsSection> createState() => _AnimeRelationsSectionState();
}

class _AnimeRelationsSectionState extends State<_AnimeRelationsSection> {
  static const int _collapsedCount = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final visible = _expanded
        ? widget.relations
        : widget.relations.take(_collapsedCount);
    final canToggle = widget.relations.length > _collapsedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.relationsTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        ...visible.map(
          (relation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AnimeRelationCard(
              relation: relation,
              routeMode: widget.routeMode,
            ),
          ),
        ),
        if (canToggle)
          _RelationsToggleButton(
            expanded: _expanded,
            hiddenCount: widget.relations.length - _collapsedCount,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}

class _AnimeRelationCard extends StatelessWidget {
  const _AnimeRelationCard({required this.relation, required this.routeMode});

  final AnimeRelation relation;
  final PartyRouteMode routeMode;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final target = relation.target;
    return InkWell(
      borderRadius: BorderRadius.circular(CloudRadius.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => switch (target.kind) {
            MediaKind.anime =>
              routeMode.isParty
                  ? PartyAnimePage(anilistId: target.anilistId)
                  : AnimeDetailPage(anilistId: target.anilistId),
            MediaKind.manga => MangaDetailPage(anilistId: target.anilistId),
          },
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(CloudRadius.lg),
          border: Border.all(color: colors.surface2),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    target.titleRomaji,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _RelationTypeBadge(type: relation.type),
                      MetaChip(
                        label: _animeRelationTargetFormatLabel(
                          context,
                          relation,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: colors.textSoft),
          ],
        ),
      ),
    );
  }
}

class _RelationsToggleButton extends StatelessWidget {
  const _RelationsToggleButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onPressed,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 18,
        ),
        label: Text(
          expanded
              ? _relationsShowLessLabel(context)
              : _relationsShowMoreLabel(context, hiddenCount),
        ),
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

class _PartyActionButton extends ConsumerWidget {
  const _PartyActionButton({
    required this.anilistId,
    required this.animeTitle,
    required this.routeMode,
  });

  final int anilistId;
  final String animeTitle;
  final PartyRouteMode routeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    final session = ref.watch(partySessionProvider);
    final isActive = session.isActive;

    // `isLocalHost` works under both v1 (P2P) and v2 (brokered realtime);
    // the old `syncEngine.localUserId` path returned null in v2 and caused
    // host UI to never render.
    final isHost =
        isActive && ref.read(partySessionProvider.notifier).isLocalHost;

    if (isActive && isHost) {
      // Host is viewing a different anime — offer to change the party's media.
      final isSameAnime = session.room!.anilistId == anilistId;
      return IconButton(
        icon: Icon(
          isSameAnime ? Icons.group : Icons.swap_horiz,
          color: isSameAnime ? colors.primary : Colors.orangeAccent,
        ),
        tooltip: isSameAnime
            ? context.l10n.partyActiveTooltip
            : context.l10n.partySetForPartyTooltip,
        onPressed: isSameAnime
            ? () {
                final navigator = Navigator.of(context, rootNavigator: true);
                final route = MaterialPageRoute<void>(
                  builder: (_) => PartyAnimePage(anilistId: anilistId),
                );
                if (routeMode.isParty) {
                  navigator.pushReplacement(route);
                } else {
                  navigator.push(route);
                }
              }
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.l10n.partyChangeAnimeTitle),
                    content: Text(
                      context.l10n.partyChangeAnimeBody(animeTitle),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(context.l10n.profileCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.l10n.partySwitch),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref
                      .read(partySessionProvider.notifier)
                      .changeMedia(
                        anilistId: anilistId,
                        animeTitle: animeTitle,
                        episodeNumber: 1,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.partySwitchedToAnime(animeTitle),
                        ),
                      ),
                    );
                  }
                }
              },
      );
    }

    // Default: open party lobby.
    return IconButton(
      icon: Icon(
        isActive ? Icons.group : Icons.group_add_outlined,
        color: isActive ? colors.primary : null,
      ),
      tooltip: isActive
          ? context.l10n.partyLobbyTooltip
          : context.l10n.partyTitle,
      onPressed: () {
        final navigator = Navigator.of(context, rootNavigator: true);
        final route = MaterialPageRoute<void>(
          builder: (_) => PartyAnimePage(anilistId: anilistId),
        );
        navigator.push(route);
      },
    );
  }
}

class _WatchPartySpotlightCard extends ConsumerWidget {
  const _WatchPartySpotlightCard({
    required this.anilistId,
    required this.animeTitle,
    required this.routeMode,
  });

  final int anilistId;
  final String animeTitle;
  final PartyRouteMode routeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    final isActive = ref.watch(partySessionProvider).isActive;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          final navigator = Navigator.of(context, rootNavigator: true);
          final route = MaterialPageRoute<void>(
            builder: (_) => PartyAnimePage(anilistId: anilistId),
          );
          navigator.push(route);
        },
        icon: Icon(
          isActive ? Icons.groups_rounded : Icons.group_add_rounded,
          size: 20,
        ),
        label: Text(
          isActive ? context.l10n.partyLobbyTooltip : context.l10n.partyTitle,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
          backgroundColor: colors.primarySoft.withValues(alpha: 0.28),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CloudRadius.md),
          ),
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          image: true,
          label: detail.anime.title.romaji,
          child: GestureDetector(
            onTap: () => _showArtworkPreview(
              context,
              detail.bannerImageUrl ?? detail.anime.coverImageUrl,
              detail.anime.title.romaji,
            ),
            child: CloudCachedImage(
              url: detail.bannerImageUrl ?? detail.anime.coverImageUrl,
              bucket: CloudImageCacheBucket.artwork,
              fit: BoxFit.cover,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                colors.bg.withValues(alpha: 0.0),
                colors.bg.withValues(alpha: 0.85),
              ],
              stops: const <double>[0.3, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Semantics(
                    image: true,
                    label: '${detail.anime.title.romaji} cover',
                    child: GestureDetector(
                      onTap: () => _showArtworkPreview(
                        context,
                        detail.anime.coverImageUrl,
                        detail.anime.title.romaji,
                      ),
                      child: CloudCachedImage(
                        url: detail.anime.coverImageUrl,
                        bucket: CloudImageCacheBucket.artwork,
                        width: 120,
                        height: 170,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        borderRadius: BorderRadius.circular(CloudRadius.lg),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          detail.anime.title.romaji,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _HeroMetaPill(
                              label: _formatLabel(context, detail.anime.format),
                            ),
                            _HeroMetaPill(
                              label: _statusLabel(context, detail.anime.status),
                            ),
                            if (detail.anime.releaseYear != null)
                              _HeroMetaPill(
                                label: detail.anime.releaseYear.toString(),
                              ),
                            if (detail.anime.totalEpisodes != null)
                              _HeroMetaPill(
                                label:
                                    '${detail.anime.totalEpisodes} ${context.l10n.episodesWord}',
                              ),
                            if (detail.anime.averageScore != null)
                              _HeroMetaPill(
                                label: '★ ${detail.anime.averageScore}/100',
                                textColor: colors.star,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showArtworkPreview(
  BuildContext context,
  String? imageUrl,
  String title,
) async {
  if (imageUrl == null || imageUrl.trim().isEmpty) {
    return;
  }

  final colors = FormFactorProvider.colorsOf(context);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: <Widget>[
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CloudCachedImage(
                  url: imageUrl,
                  bucket: CloudImageCacheBucket.artwork,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.text),
                  tooltip: title,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.detail});

  final AnimeDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final secondaryTitle =
        detail.anime.title.english ??
        detail.anime.title.native ??
        detail.anime.title.romaji;
    final hasDistinctSecondaryTitle =
        secondaryTitle.trim() != detail.anime.title.romaji.trim();

    if (!hasDistinctSecondaryTitle) {
      return const SizedBox.shrink();
    }

    return Text(
      secondaryTitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
      ),
    );
  }
}

class _EpisodeDetailSection extends ConsumerStatefulWidget {
  const _EpisodeDetailSection({
    required this.detail,
    required this.availabilityState,
    required this.latestProgressState,
    required this.routeMode,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final AsyncValue<Result<EpisodeProgress?, KumoriyaError>> latestProgressState;
  final PartyRouteMode routeMode;

  @override
  ConsumerState<_EpisodeDetailSection> createState() =>
      _EpisodeDetailSectionState();
}

class _EpisodeDetailSectionState extends ConsumerState<_EpisodeDetailSection> {
  static const int _collapsedEpisodeCount = 12;
  static const int _longSeriesThreshold = 80;
  static const int _pageSize = 50;

  bool _isLaunching = false;
  bool _isRefreshingSources = false;
  bool _showAllEpisodes = false;
  bool _didAniSkipPrefetch = false;
  int _currentPage = 0;
  bool _didAutoSelectPage = false;

  void _scheduleAniSkipPrefetch(
    List<AnimeEpisode> episodes, {
    int? focusedEpisodeNumber,
  }) {
    if (_didAniSkipPrefetch || episodes.isEmpty) {
      return;
    }
    var episodeNumbers = episodes
        .where((episode) => episode.isAired)
        .map((episode) => episode.number.toInt())
        .where((episodeNumber) => episodeNumber > 0)
        .toSet()
        .toList(growable: false);
    if (episodeNumbers.isEmpty) {
      return;
    }

    if (episodeNumbers.length > _collapsedEpisodeCount) {
      final focus = focusedEpisodeNumber ?? episodeNumbers.last;
      final startIndex = (episodeNumbers.indexOf(focus) - 2).clamp(
        0,
        episodeNumbers.length - 1,
      );
      episodeNumbers = episodeNumbers
          .skip(startIndex)
          .take(_collapsedEpisodeCount)
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
              anilistId: widget.detail.anime.anilistId,
              episodeNumbers: episodeNumbers,
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final latestProgress = widget.latestProgressState.maybeWhen(
      data: (result) => result.fold(
        onFailure: (_) => null,
        onSuccess: (progress) => progress,
      ),
      orElse: () => null,
    );
    final progressListState = ref.watch(
      animeEpisodeProgressListProvider(widget.detail.anime.anilistId),
    );
    final progressList =
        _extractSuccessValue<List<EpisodeProgress>>(progressListState) ??
        const <EpisodeProgress>[];
    final partySession = ref.watch(partySessionProvider);
    final partyLockedEpisode = partyLockedEpisodeNumberForAnime(
      session: partySession,
      isLocalHost: ref.read(partySessionProvider.notifier).isLocalHost,
      anilistId: widget.detail.anime.anilistId,
    );
    final summary = _extractSuccessValue<SourceAvailabilitySummary>(
      widget.availabilityState,
    );
    final malEpisodeMetadata = ref
        .watch(malEpisodeMetadataProvider(widget.detail.anime.anilistId))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <int, MalEpisodeMetadata>{},
        );
    final totalEpisodeEstimate = math.max(
      widget.detail.episodes.length,
      summary?.playableSources.fold<int>(
            0,
            (maxCount, source) => math.max(maxCount, source.episodes.length),
          ) ??
          0,
    );
    _scheduleAniSkipPrefetch(
      widget.detail.episodes,
      focusedEpisodeNumber: latestProgress?.episodeNumber.toInt(),
    );
    final isLongSeries = totalEpisodeEstimate >= _longSeriesThreshold;
    // For long series, build ALL rows (no previewLimit) so pagination works.
    final rowsResult = _buildDetailEpisodeRows(
      animeEpisodes: widget.detail.episodes,
      availabilitySummary: summary,
      progressList: progressList,
      malEpisodeMetadata: malEpisodeMetadata,
      focusedEpisodeNumber: latestProgress?.episodeNumber,
      animeTitle: widget.detail.anime.title.romaji,
      fallbackTitleBuilder: (episodeNumber) => context.l10n
          .continueWatchingEpisode(episodeNumber.toInt().toString()),
      upcomingLabel: context.l10n.episodeStatusUpcoming,
      readyLabel: context.l10n.episodePlayNowLabel,
      previewLimit: null,
    );
    final allRows = rowsResult.rows;

    // Auto-select page containing latest progress (runs once).
    if (!_didAutoSelectPage && latestProgress != null && allRows.isNotEmpty) {
      _didAutoSelectPage = true;
      final focusIndex = allRows.indexWhere(
        (row) => (row.number - latestProgress.episodeNumber).abs() < 0.001,
      );
      if (focusIndex >= 0) {
        _currentPage = focusIndex ~/ _pageSize;
      }
    }

    final pageCount = allRows.isEmpty
        ? 0
        : ((allRows.length - 1) ~/ _pageSize) + 1;
    final pageStart = _currentPage * _pageSize;
    final pagedRows = allRows
        .skip(pageStart)
        .take(_pageSize)
        .toList(growable: false);

    // For short series without pagination, use collapsed preview logic.
    final List<_DetailEpisodeRowData> visibleRows;
    if (isLongSeries || pageCount > 1) {
      visibleRows = pagedRows;
    } else if (_showAllEpisodes || allRows.length <= _collapsedEpisodeCount) {
      visibleRows = allRows;
    } else {
      visibleRows = allRows
          .take(_collapsedEpisodeCount)
          .toList(growable: false);
    }
    final hiddenEpisodeCount = rowsResult.totalCount - visibleRows.length;
    final sourceBadges =
        summary?.playableSources
            .map(
              (source) => SourceBadge(
                sourceName: source.manifest.displayName,
                iconUrl: effectiveSourceIconUrl(source.manifest),
                audioKinds: source.availableAudioKinds,
                compact: true,
                iconOnly: true,
                isHighlighted:
                    summary.recommended?.manifest.id == source.manifest.id,
              ),
            )
            .toList(growable: false) ??
        const <Widget>[];
    final contentChildren = <Widget>[
      SectionHeader(
        title: context.l10n.episodePreviewTitle,
        onSeeAll: isLongSeries
            ? () => _openEpisodeListPage(latestProgress)
            : null,
        seeAllLabel: isLongSeries ? context.l10n.viewEpisodeList : null,
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          if (widget.availabilityState.isLoading) ...<Widget>[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              rowsResult.totalCount == 0
                  ? context.l10n.episodeListEmpty
                  : '${rowsResult.totalCount} ${context.l10n.episodesWord}',
              style: TextStyle(fontSize: 12, color: colors.textSoft),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: _isRefreshingSources ? null : _refreshSources,
            icon: _isRefreshingSources
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(_refreshSourcesLabel(context)),
          ),
        ],
      ),
      if (!widget.routeMode.isParty &&
          !isLongSeries &&
          allRows.any(
            (row) => row.sourceEpisodes.keys.any(
              (id) => id != _excludedDetailDownloadSource,
            ),
          )) ...<Widget>[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _DetailDownloadAllButton(
            rows: allRows,
            anilistId: widget.detail.anime.anilistId,
            animeTitle: widget.detail.anime.title.romaji,
            coverImageUrl: widget.detail.anime.coverImageUrl,
            availableSources:
                summary?.playableSources ?? const <SourceAvailability>[],
          ),
        ),
      ],
      const SizedBox(height: 10),
      if (sourceBadges.isEmpty)
        Text(
          context.l10n.detailPlaybackNotReady,
          style: TextStyle(fontSize: 12, color: colors.textSoft),
        )
      else
        Wrap(spacing: 4, runSpacing: 4, children: sourceBadges),
      if (partyLockedEpisode != null) ...<Widget>[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primarySoft.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(CloudRadius.md),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: Text(
            'Watch party active: only episode ${partyLockedEpisode.toInt()} is available while the host controls playback.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
    ];

    // Add page selector for long series with multiple pages.
    if (pageCount > 1) {
      contentChildren.addAll(<Widget>[
        const SizedBox(height: 6),
        _DetailPageSelector(
          pageCount: pageCount,
          currentPage: _currentPage,
          pageSize: _pageSize,
          totalRows: allRows.length,
          onPageSelected: (page) => setState(() => _currentPage = page),
        ),
        const SizedBox(height: 6),
      ]);
    }

    if (allRows.isEmpty) {
      contentChildren.add(
        Text(
          context.l10n.episodeListEmpty,
          style: TextStyle(fontSize: 14, color: colors.text),
        ),
      );
    } else {
      // Lift download-tasks watch here (1 watch) instead of N per card.
      final dlTasksState = ref.watch(
        downloadTasksByAnimeProvider(widget.detail.anime.anilistId),
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

      contentChildren.addAll(
        visibleRows.map((row) {
          // Direct map lookup by rounded key to avoid float comparison issues.
          final dlKey = (row.number * 1000).round();
          final dlTask = dlTaskMap[dlKey];
          return _DetailEpisodeCard(
            row: row,
            anilistId: widget.detail.anime.anilistId,
            animeTitle: widget.detail.anime.title.romaji,
            coverImageUrl: widget.detail.anime.coverImageUrl,
            downloadTask: dlTask,
            onTap:
                row.playableSources.isEmpty || summary == null || _isLaunching
                ? null
                : isPartyEpisodeLocked(
                    session: partySession,
                    isLocalHost: ref
                        .read(partySessionProvider.notifier)
                        .isLocalHost,
                    anilistId: widget.detail.anime.anilistId,
                    episodeNumber: row.number,
                  )
                ? () => _showPartyEpisodeLockedMessage(
                    context,
                    partyLockedEpisode ?? row.number,
                  )
                : () => _handleEpisodeTap(row, summary),
          );
        }),
      );

      if (hiddenEpisodeCount > 0 && isLongSeries) {
        contentChildren.add(const SizedBox(height: 6));
      } else if (hiddenEpisodeCount > 0) {
        contentChildren.addAll(<Widget>[
          const SizedBox(height: 6),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _showAllEpisodes = true);
              },
              icon: const Icon(Icons.expand_more_rounded),
              label: Text('+$hiddenEpisodeCount ${context.l10n.episodesWord}'),
            ),
          ),
        ]);
      } else if (!isLongSeries &&
          _showAllEpisodes &&
          allRows.length > _collapsedEpisodeCount) {
        contentChildren.addAll(<Widget>[
          const SizedBox(height: 6),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _showAllEpisodes = false);
              },
              icon: const Icon(Icons.expand_less_rounded),
              label: Text(context.l10n.episodePreviewTitle),
            ),
          ),
        ]);
      }
    }

    return Container(
      key: const Key('anime-detail-episodes-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CloudRadius.lg),
        border: Border.all(color: colors.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentChildren,
      ),
    );
  }

  Future<void> _refreshSources() async {
    if (_isRefreshingSources) {
      return;
    }
    setState(() => _isRefreshingSources = true);

    final result = await ref
        .read(loadSourceAvailabilitySummaryUseCaseProvider)
        .refresh(widget.detail);

    if (!mounted) {
      return;
    }

    setState(() => _isRefreshingSources = false);
    ref.invalidate(
      sourceAvailabilitySummaryProvider(widget.detail.anime.anilistId),
    );

    result.fold(
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorMessage(context, error))),
        );
      },
      onSuccess: (_) {},
    );
  }

  String _refreshSourcesLabel(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'es'
        ? 'Refrescar fuentes'
        : 'Refresh sources';
  }

  Future<void> _handleEpisodeTap(
    _DetailEpisodeRowData row,
    SourceAvailabilitySummary summary,
  ) async {
    final partySession = ref.read(partySessionProvider);
    final isLocked = isPartyEpisodeLocked(
      session: partySession,
      isLocalHost: ref.read(partySessionProvider.notifier).isLocalHost,
      anilistId: widget.detail.anime.anilistId,
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
      downloadTasksByAnimeProvider(widget.detail.anime.anilistId),
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
              anilistId: widget.detail.anime.anilistId,
              animeTitle: widget.detail.anime.title.romaji,
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
              totalEpisodes: widget.detail.anime.totalEpisodes,
              nextAiringEpisodeNumber: widget
                  .detail
                  .anime
                  .nextAiringEpisodeNumber
                  ?.toDouble(),
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
          anilistId: widget.detail.anime.anilistId,
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
      anilistId: widget.detail.anime.anilistId,
      animeTitle: widget.detail.anime.title.romaji,
      episodeTitle: translatedEpisodeTitle,
      routeMode: widget.routeMode,
      decision: decision,
      totalEpisodes: widget.detail.anime.totalEpisodes,
      nextAiringEpisodeNumber: widget.detail.anime.nextAiringEpisodeNumber
          ?.toDouble(),
    );
  }

  Future<void> _openEpisodeListPage(EpisodeProgress? latestProgress) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.routeMode.isParty
            ? PartyEpisodeListPage(
                anilistId: widget.detail.anime.anilistId,
                animeTitle: widget.detail.anime.title.romaji,
                focusedEpisodeNumber: latestProgress?.episodeNumber,
              )
            : EpisodeListPage(
                anilistId: widget.detail.anime.anilistId,
                animeTitle: widget.detail.anime.title.romaji,
                focusedEpisodeNumber: latestProgress?.episodeNumber,
              ),
      ),
    );
  }
}

class _DetailEpisodeCard extends ConsumerStatefulWidget {
  const _DetailEpisodeCard({
    required this.row,
    required this.anilistId,
    required this.animeTitle,
    this.coverImageUrl,
    this.downloadTask,
    this.onTap,
  });

  final _DetailEpisodeRowData row;
  final int anilistId;
  final String animeTitle;
  final String? coverImageUrl;
  final DownloadTask? downloadTask;
  final VoidCallback? onTap;

  @override
  ConsumerState<_DetailEpisodeCard> createState() => _DetailEpisodeCardState();
}

class _DetailEpisodeCardState extends ConsumerState<_DetailEpisodeCard> {
  bool _isEnqueuing = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isPlayable = row.playableSources.isNotEmpty;

    final dlTask = widget.downloadTask;

    return KeyedSubtree(
      key: Key('anime-detail-episode-${row.number.toInt()}'),
      child: EpisodeRow(
        episodeNumber: row.number.toString(),
        title: row.displayTitle,
        subtitle: row.secondaryText,
        sourceBadges: const <Widget>[],
        state: row.isCurrentEpisode
            ? EpisodeRowState.active
            : !isPlayable
            ? EpisodeRowState.notPlayable
            : EpisodeRowState.defaultState,
        progress: row.progressFraction,
        onTap: widget.onTap,
        activeLabel: context.l10n.detailContinueBadge,
        trailingAccessory: _buildDownloadWidget(context, dlTask),
      ),
    );
  }

  Widget _buildDownloadWidget(BuildContext context, DownloadTask? dlTask) {
    final colors = FormFactorProvider.colorsOf(context);
    if (_isEnqueuing) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (dlTask != null) {
      return _DetailDownloadStatusIcon(task: dlTask);
    }

    // Only show download if there's a downloadable (non-excluded) source.
    final hasDownloadableSource = widget.row.sourceEpisodes.keys.any(
      (id) => id != _excludedDetailDownloadSource,
    );
    if (!hasDownloadableSource) return const SizedBox.shrink();

    return IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: () => _handleDownload(context),
      icon: Icon(Icons.download_rounded, size: 22, color: colors.textSoft),
      tooltip: context.l10n.downloadEpisode,
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    if (_isEnqueuing) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    // Get downloadable sources (excluding Anime Nexus).
    final entries = widget.row.sourceEpisodes.entries
        .where((e) => e.key != _excludedDetailDownloadSource)
        .toList();
    if (entries.isEmpty) return;

    setState(() => _isEnqueuing = true);

    try {
      final registry = ref.read(resolverRegistryProvider);

      // Aggregate server links from ALL available source plugins so the user
      // sees every downloadable server, not just those from the first source.
      final allOptions = <_DownloadServerOption>[];
      final optionSourceMap =
          <_DownloadServerOption, MapEntry<String, SourceEpisode>>{};
      final scorer = ref.read(downloadServerScorerProvider);

      for (final entry in entries) {
        final sourcePlugin = ref.read(sourcePluginByIdProvider(entry.key));
        final linksResult = await GetSourceEpisodeServerLinksUseCase(
          sourcePlugin: sourcePlugin,
          registry: registry,
          includeDownloadLinks: true,
        ).call(entry.value);

        linksResult.fold(
          onSuccess: (links) {
            for (final link in _filterDetailDownloadLinks(links)) {
              final tier = ServerQualityRegistry.tierFor(
                detectedHost: link.detectedHost,
                serverName: link.serverName,
              );
              final rankingScore = ServerQualityRegistry.combinedScore(
                tier: tier,
                sessionScore: scorer.score(link.serverName),
              );
              final opt = _DownloadServerOption(
                link: link,
                sourcePluginId: entry.key,
                sourceName: sourcePlugin.manifest.displayName,
                qualityTier: tier,
                rankingScore: rankingScore,
                sourceIconUrl: sourcePlugin.manifest.iconUrl,
                sourceEpisode: entry.value,
              );
              allOptions.add(opt);
              optionSourceMap[opt] = entry;
            }
          },
          onFailure: (_) {},
        );
      }

      if (!context.mounted) return;

      if (allOptions.isEmpty) {
        setState(() => _isEnqueuing = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.downloadSourceUnavailable)),
        );
        return;
      }

      allOptions.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      // If multiple servers, let user choose.
      _DownloadServerOption chosenOption;
      if (allOptions.length > 1) {
        setState(() => _isEnqueuing = false);
        final picked = await _showDownloadServerPicker(context, allOptions);
        if (picked == null || !mounted) return;
        chosenOption = picked;
        setState(() => _isEnqueuing = true);
      } else {
        chosenOption = allOptions.first;
      }

      final chosenLink = chosenOption.link;
      final chosenEntry = optionSourceMap[chosenOption] ?? entries.first;
      final translatedEpisodeTitle = await resolveTranslatedEpisodeTitle(
        ref: ref,
        title: widget.row.displayTitle,
        languageCode: languageCode,
      );
      if (!mounted) return;

      final enqueueUseCase = ref.read(enqueueDownloadUseCaseProvider);
      final result = await enqueueUseCase.call(
        anilistId: widget.anilistId,
        episodeNumber: chosenEntry.value.number,
        serverLink: chosenLink,
        sourcePluginId: chosenEntry.key,
        animeTitle: widget.animeTitle,
        coverImageUrl: widget.coverImageUrl,
        episodeTitle: translatedEpisodeTitle,
      );

      if (!mounted) return;
      setState(() => _isEnqueuing = false);

      final success = result.fold(
        onSuccess: (_) => true,
        onFailure: (_) => false,
      );

      if (success) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadQueued)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isEnqueuing = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
      }
    }
  }
}

class _LibraryActions extends ConsumerWidget {
  const _LibraryActions({required this.anilistId});

  final int anilistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    final isFavAsync = ref.watch(isFavoriteProvider(anilistId));
    final isSubAsync = ref.watch(isSubscribedProvider(anilistId));
    final isAutoDownloadAsync = ref.watch(isAutoDownloadProvider(anilistId));
    final audioPreferenceAsync = ref.watch(
      autoDownloadAudioPreferenceProvider(anilistId),
    );

    final isFav = isFavAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final isSub = isSubAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final isAutoDl = isAutoDownloadAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final currentAudioPreference = audioPreferenceAsync.maybeWhen(
      data: (value) => value,
      orElse: () => 'none',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            _ActionButton(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: context.l10n.libraryActionSave,
              active: isFav,
              onTap: () async {
                await ref
                    .read(libraryStoreProvider)
                    .setFavorite(anilistId, isFavorite: !isFav);
                ref.invalidate(favoriteAnimeIdsProvider);
              },
            ),
            const SizedBox(width: 20),
            _ActionButton(
              icon: isSub
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              label: context.l10n.libraryActionNotify,
              active: isSub,
              onTap: () async {
                if (!isSub && Platform.isAndroid) {
                  final status = await Permission.notification.request();
                  if (!status.isGranted) return;
                }
                await ref
                    .read(libraryStoreProvider)
                    .setSubscription(anilistId, notify: !isSub);
                ref.invalidate(subscribedAnimeIdsProvider);
                ref.invalidate(isSubscribedProvider(anilistId));
              },
            ),
            const SizedBox(width: 20),
            _ActionButton(
              icon: isAutoDl
                  ? Icons.download_done_rounded
                  : Icons.download_rounded,
              label: context.l10n.libraryActionAutoDownload,
              active: isAutoDl,
              onTap: isSub
                  ? () async {
                      await ref
                          .read(libraryStoreProvider)
                          .setAutoDownload(anilistId, autoDownload: !isAutoDl);
                      ref.invalidate(autoDownloadAnimeIdsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAutoDl
                                  ? context.l10n.autoDownloadDisabled
                                  : context.l10n.autoDownloadEnabled,
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
        if (isAutoDl) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            context.l10n.autoDownloadAudioPreference,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: 'none',
                label: Text(context.l10n.autoDownloadAudioAny),
              ),
              ButtonSegment<String>(
                value: 'sub',
                label: Text(context.l10n.autoDownloadAudioSub),
              ),
              ButtonSegment<String>(
                value: 'dub',
                label: Text(context.l10n.autoDownloadAudioDub),
              ),
            ],
            selected: <String>{currentAudioPreference},
            onSelectionChanged: (values) async {
              if (values.isEmpty) {
                return;
              }
              final selected = values.first;
              await ref
                  .read(libraryStoreProvider)
                  .setAutoDownloadAudioPreference(anilistId, selected);
              ref.invalidate(autoDownloadAudioPreferenceProvider(anilistId));
            },
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final disabled = onTap == null;
    final color = disabled
        ? colors.textSoft
        : active
        ? colors.primary
        : colors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? colors.primary.withValues(alpha: 0.12)
                    : colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? colors.primary.withValues(alpha: 0.35)
                      : colors.surface2,
                ),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page selector for detail section ────────────────────────────────────────

class _DetailPageSelector extends StatelessWidget {
  const _DetailPageSelector({
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pageCount,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final start = index * pageSize + 1;
          final end = ((index + 1) * pageSize).clamp(0, totalRows);
          final isSelected = index == currentPage;
          return ChoiceChip(
            label: Text('$start–$end', style: const TextStyle(fontSize: 11)),
            selected: isSelected,
            onSelected: (_) => onPageSelected(index),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
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

void _showPartyEpisodeLockedMessage(
  BuildContext context,
  double episodeNumber,
) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        'The host locked the party to episode ${episodeNumber.toInt()}.',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

_DetailEpisodeRowsResult _buildDetailEpisodeRows({
  required List<AnimeEpisode> animeEpisodes,
  required SourceAvailabilitySummary? availabilitySummary,
  required List<EpisodeProgress> progressList,
  required Map<int, MalEpisodeMetadata> malEpisodeMetadata,
  required double? focusedEpisodeNumber,
  required String animeTitle,
  required String Function(double episodeNumber) fallbackTitleBuilder,
  required String upcomingLabel,
  required String readyLabel,
  int? previewLimit,
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
  final visibleNumbers =
      previewLimit != null && allNumbers.length > previewLimit
      ? _selectDetailEpisodePreviewNumbers(
          allNumbers: allNumbers,
          previewLimit: previewLimit,
          focusedEpisodeNumber: focusedEpisodeNumber,
        )
      : allNumbers;

  EpisodeProgress? latestProgress;
  for (final progress in progressList) {
    if (latestProgress == null ||
        progress.updatedAt.isAfter(latestProgress.updatedAt)) {
      latestProgress = progress;
    }
  }

  return _DetailEpisodeRowsResult(
    totalCount: allNumbers.length,
    rows: visibleNumbers
        .map((number) {
          final metadata = metadataByNumber[number];
          final jikanMetadata = malEpisodeMetadata[number.toInt()];
          final sources =
              sourcesByEpisode[number] ?? const <SourceAvailability>[];
          final progress = progressByNumber[number];

          return _DetailEpisodeRowData(
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
                ? _formatEpisodeDate(metadata!.airDate!)
                : metadata?.isAired == false
                ? upcomingLabel
                : jikanMetadata?.airedAt != null
                ? _formatEpisodeDate(jikanMetadata!.airedAt!)
                : readyLabel,
            playableSources: sources,
            progressFraction: _progressFraction(progress),
            isCurrentEpisode:
                latestProgress?.episodeNumber == number ||
                focusedEpisodeNumber == number,
            sourceEpisodes:
                sourceEpisodesByNumber[number] ??
                const <String, SourceEpisode>{},
          );
        })
        .toList(growable: false),
  );
}

List<double> _selectDetailEpisodePreviewNumbers({
  required List<double> allNumbers,
  required int previewLimit,
  required double? focusedEpisodeNumber,
}) {
  if (allNumbers.length <= previewLimit) {
    return allNumbers;
  }

  final focusIndex = focusedEpisodeNumber == null
      ? -1
      : allNumbers.indexWhere(
          (number) => (number - focusedEpisodeNumber).abs() < 0.001,
        );

  if (focusIndex >= 0) {
    final halfWindow = previewLimit ~/ 2;
    final start = math.max(
      0,
      math.min(focusIndex - halfWindow, allNumbers.length - previewLimit),
    );
    return allNumbers.sublist(start, start + previewLimit);
  }

  return allNumbers.sublist(allNumbers.length - previewLimit);
}

final class _DetailEpisodeRowsResult {
  const _DetailEpisodeRowsResult({
    required this.rows,
    required this.totalCount,
  });

  final List<_DetailEpisodeRowData> rows;
  final int totalCount;
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

String _formatEpisodeDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

final class _DetailEpisodeRowData {
  const _DetailEpisodeRowData({
    required this.number,
    required this.displayTitle,
    required this.secondaryText,
    required this.playableSources,
    required this.progressFraction,
    required this.isCurrentEpisode,
    this.sourceEpisodes = const <String, SourceEpisode>{},
  });

  final double number;
  final String displayTitle;
  final String secondaryText;
  final List<SourceAvailability> playableSources;
  final double? progressFraction;
  final bool isCurrentEpisode;

  /// Map of source plugin ID → SourceEpisode for download support.
  final Map<String, SourceEpisode> sourceEpisodes;
}

class _HeroMetaPill extends StatelessWidget {
  const _HeroMetaPill({required this.label, this.textColor = Colors.white});

  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CloudRadius.pill),
          color: Colors.black.withValues(alpha: 0.55),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

String _formatLabel(BuildContext context, AnimeFormat format) {
  return displayFormatLabel(context, format);
}

String _animeRelationTargetFormatLabel(
  BuildContext context,
  AnimeRelation relation,
) {
  return switch (relation.targetKind) {
    MediaKind.anime => _formatLabel(context, relation.anime.format),
    MediaKind.manga => relation.target.formatLabel ?? 'Manga',
  };
}

String _relationsShowMoreLabel(BuildContext context, int hiddenCount) {
  final spanish = Localizations.localeOf(context).languageCode == 'es';
  return spanish
      ? 'Ver $hiddenCount relaciones más'
      : 'Show $hiddenCount more relations';
}

String _relationsShowLessLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'es'
      ? 'Ver menos relaciones'
      : 'Show fewer relations';
}

String _statusLabel(BuildContext context, AnimeStatus status) {
  return switch (status) {
    AnimeStatus.releasing => context.l10n.statusAiring,
    AnimeStatus.notYetReleased => context.l10n.statusUpcoming,
    AnimeStatus.finished => context.l10n.statusFinished,
    AnimeStatus.cancelled => context.l10n.statusCancelled,
    AnimeStatus.hiatus => context.l10n.statusOnHiatus,
    AnimeStatus.unknown => context.l10n.statusUnknown,
  };
}

String _debugPreferenceSummary(PlaybackPreference preference) {
  final parts = <String>[
    if (preference.preferredSourcePluginId != null)
      'Source: ${preference.preferredSourcePluginId}',
    if (preference.preferredServerName != null)
      'Server: ${preference.preferredServerName}',
    if (preference.preferredResolverPluginId != null)
      'Resolver: ${preference.preferredResolverPluginId}',
    if (preference.preferredAudioPreference != null)
      'Audio: ${preference.preferredAudioPreference!.name}',
  ];

  if (parts.isEmpty) {
    return 'A playback preference row exists, but it has no persisted source, server, resolver, or audio signal.';
  }

  return parts.join('\n');
}

// ─── Download helpers for detail page ────────────────────────────────────────

/// Source plugin excluded from downloads.
const _excludedDetailDownloadSource = 'kumoriya.source.anime_nexus';

const Set<String> _excludedDetailDownloadHosts = <String>{'hgplaycdn.com'};

bool _isExcludedDetailDownloadLink(SourceServerLink link) {
  final detectedHost = link.detectedHost?.trim().toLowerCase();
  final initialHost = link.initialUrl.host.trim().toLowerCase();

  bool matchesExcludedHost(String? host) {
    if (host == null || host.isEmpty) {
      return false;
    }

    return _excludedDetailDownloadHosts.any(
      (excluded) => host == excluded || host.endsWith('.$excluded'),
    );
  }

  return matchesExcludedHost(detectedHost) || matchesExcludedHost(initialHost);
}

List<SourceServerLink> _filterDetailDownloadLinks(
  Iterable<SourceServerLink> links,
) {
  return links.where((link) => !_isExcludedDetailDownloadLink(link)).toList();
}

/// Resolves server links for [sourceEpisode] via [sourcePluginId], picks the
/// best stream, and enqueues a download task. Returns true on success.
Future<bool> _enqueueDetailEpisodeDownload({
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
    final sourcePlugin = ref.read(sourcePluginByIdProvider(sourcePluginId));
    final registry = ref.read(resolverRegistryProvider);

    final linksResult = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: sourcePlugin,
      registry: registry,
      includeDownloadLinks: true,
    ).call(sourceEpisode);

    var links = linksResult.fold(
      onSuccess: _filterDetailDownloadLinks,
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

    // Rank servers by static quality + historical success rate.
    final scorer = ref.read(downloadServerScorerProvider);
    final rankedLinks = List<SourceServerLink>.of(links);
    rankedLinks.sort((a, b) {
      final aTier = ServerQualityRegistry.tierFor(
        detectedHost: a.detectedHost,
        serverName: a.serverName,
      );
      final bTier = ServerQualityRegistry.tierFor(
        detectedHost: b.detectedHost,
        serverName: b.serverName,
      );
      final aScore = ServerQualityRegistry.combinedScore(
        tier: aTier,
        sessionScore: scorer.score(a.serverName),
      );
      final bScore = ServerQualityRegistry.combinedScore(
        tier: bTier,
        sessionScore: scorer.score(b.serverName),
      );
      return bScore.compareTo(aScore);
    });
    links = rankedLinks;

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

class _DetailDownloadStatusIcon extends ConsumerWidget {
  const _DetailDownloadStatusIcon({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = FormFactorProvider.colorsOf(context);
    // Listen to live progress events for this task only.
    final liveEvent = ref
        .watch(downloadProgressByTaskProvider(task.id))
        .maybeWhen(data: (event) => event, orElse: () => null);

    final (icon, color) = switch (task.status) {
      DownloadStatus.pending => (Icons.hourglass_top_rounded, colors.textSoft),
      DownloadStatus.downloading => (Icons.downloading_rounded, colors.primary),
      DownloadStatus.paused => (
        Icons.pause_circle_outline_rounded,
        colors.warning,
      ),
      DownloadStatus.remuxing => (Icons.auto_fix_high_rounded, colors.primary),
      DownloadStatus.disconnected => (
        Icons.cloud_off_rounded,
        colors.textMuted,
      ),
      DownloadStatus.completed => (Icons.download_done_rounded, colors.success),
      DownloadStatus.cancelled => (Icons.cancel_outlined, colors.textSoft),
      DownloadStatus.failed => (Icons.error_outline_rounded, colors.error),
    };

    // Show circular progress around the icon when downloading.
    if (task.status == DownloadStatus.downloading) {
      final fraction = liveEvent?.fraction ?? _storedFraction(task);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2.5,
                backgroundColor: colors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, size: 22, color: color),
    );
  }

  double? _storedFraction(DownloadTask task) {
    if (task.totalBytes == null ||
        task.totalBytes == 0 ||
        task.downloadedBytes == null) {
      return null;
    }
    return (task.downloadedBytes! / task.totalBytes!).clamp(0.0, 1.0);
  }
}

class _DetailDownloadAllButton extends ConsumerStatefulWidget {
  const _DetailDownloadAllButton({
    required this.rows,
    required this.anilistId,
    required this.animeTitle,
    required this.availableSources,
    this.coverImageUrl,
  });

  final List<_DetailEpisodeRowData> rows;
  final int anilistId;
  final String animeTitle;
  final List<SourceAvailability> availableSources;
  final String? coverImageUrl;

  @override
  ConsumerState<_DetailDownloadAllButton> createState() =>
      _DetailDownloadAllButtonState();
}

class _DetailDownloadAllButtonState
    extends ConsumerState<_DetailDownloadAllButton> {
  bool _isEnqueuing = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return _isEnqueuing
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : GestureDetector(
            onTap: () => _downloadAll(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.download_rounded, size: 17, color: colors.primary),
                const SizedBox(width: 5),
                Text(
                  context.l10n.downloadAll,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          );
  }

  Future<void> _downloadAll(BuildContext context) async {
    if (_isEnqueuing) return;
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    final downloadable = widget.rows
        .where((r) => r.sourceEpisodes.isNotEmpty)
        .toList();
    if (downloadable.isEmpty) return;

    final sourceId = await _pickSourceForBulkDownload(context);
    if (sourceId == null) {
      return;
    }

    if (!context.mounted) return;

    // Detect available audio kinds for the chosen source. Prefer the cached
    // [SourceAvailability.availableAudioKinds] when populated; otherwise probe
    // the first downloadable episode's server links just-in-time.
    final selectedSource = widget.availableSources
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

    setState(() => _isEnqueuing = true);
    var queued = 0;

    // Use a deterministic base timestamp so episode ordering is preserved
    // even when enqueuing in parallel batches.
    final baseTime = DateTime.now();

    // Process in parallel batches of 4 to speed up enqueue.
    for (var i = 0; i < downloadable.length; i += 4) {
      final batch = downloadable.sublist(
        i,
        (i + 4).clamp(0, downloadable.length),
      );
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
        if (!mounted) return;

        futures.add(
          _enqueueDetailEpisodeDownload(
            ref: ref,
            anilistId: widget.anilistId,
            sourcePluginId: entry.key,
            sourceEpisode: entry.value,
            audioPreference: audioPreference,
            animeTitle: widget.animeTitle,
            coverImageUrl: widget.coverImageUrl,
            episodeTitle: translatedEpisodeTitle,
            createdAt: baseTime.add(Duration(milliseconds: i + j)),
          ),
        );
      }
      final results = await Future.wait(futures);
      queued += results.where((r) => r).length;
    }

    if (!context.mounted) return;
    setState(() => _isEnqueuing = false);

    if (queued > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadAllQueued)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.downloadSourceUnavailable)),
      );
    }
  }

  Future<SourceAudioKind?> _pickAudioKind(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
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
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 15,
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

  Future<String?> _pickSourceForBulkDownload(BuildContext context) async {
    final availableSources = widget.availableSources
        .where((source) => source.manifest.id != _excludedDetailDownloadSource)
        .where(
          (source) => widget.rows.any(
            (row) => row.sourceEpisodes.containsKey(source.manifest.id),
          ),
        )
        .toList(growable: false);

    if (availableSources.isEmpty) {
      return null;
    }
    if (availableSources.length == 1) {
      return availableSources.first.manifest.id;
    }

    // Build a sample-episode map so the sheet can probe each source.
    final sampleEpisodes = <String, SourceEpisode>{};
    for (final source in availableSources) {
      final sampleRow = widget.rows
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
      sources: availableSources,
      sampleEpisodes: sampleEpisodes,
      filterLinks: _filterDetailDownloadLinks,
    );
  }
}

// ─── Download server picker ──────────────────────────────────────────────────

/// A server link bundled with its source plugin metadata for display in the
/// download server picker.
final class _DownloadServerOption {
  const _DownloadServerOption({
    required this.link,
    required this.sourcePluginId,
    required this.sourceName,
    required this.qualityTier,
    required this.rankingScore,
    this.sourceIconUrl,
    this.sourceEpisode,
  });

  final SourceServerLink link;
  final String sourcePluginId;
  final String sourceName;
  final ServerQualityTier qualityTier;
  final double rankingScore;
  final String? sourceIconUrl;
  final SourceEpisode? sourceEpisode;
}

Future<_DownloadServerOption?> _showDownloadServerPicker(
  BuildContext context,
  List<_DownloadServerOption> options,
) {
  return showModalBottomSheet<_DownloadServerOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _DownloadServerPickerSheet(options: options),
  );
}

class _DownloadServerPickerSheet extends StatefulWidget {
  const _DownloadServerPickerSheet({required this.options});

  final List<_DownloadServerOption> options;

  @override
  State<_DownloadServerPickerSheet> createState() =>
      _DownloadServerPickerSheetState();
}

class _DownloadServerPickerSheetState
    extends State<_DownloadServerPickerSheet> {
  static const String _allSources = '__all__';
  String _selectedSourceId = _allSources;

  IconData _iconForQuality(ServerQualityTier tier) => switch (tier) {
    ServerQualityTier.premium => Icons.verified_rounded,
    ServerQualityTier.good => Icons.thumb_up_alt_outlined,
    ServerQualityTier.average => Icons.dns_outlined,
    ServerQualityTier.low => Icons.warning_amber_rounded,
    ServerQualityTier.unknown => Icons.help_outline_rounded,
    ServerQualityTier.unavailable => Icons.block_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final grouped = <String, List<_DownloadServerOption>>{};
    for (final opt in widget.options) {
      grouped.putIfAbsent(opt.sourcePluginId, () => []).add(opt);
    }
    final sourceEntries = grouped.entries.toList(growable: false);
    final filteredEntries = _selectedSourceId == _allSources
        ? sourceEntries
        : sourceEntries
              .where((e) => e.key == _selectedSourceId)
              .toList(growable: false);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.download_rounded, size: 22, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.downloadSelectServer,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (sourceEntries.length > 1) ...<Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(context.l10n.serverPickerAllSources),
                          selected: _selectedSourceId == _allSources,
                          onSelected: (_) {
                            setState(() => _selectedSourceId = _allSources);
                          },
                        ),
                      ),
                      ...sourceEntries.map((entry) {
                        final rep = entry.value.first;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: _selectedSourceId == entry.key,
                            onSelected: (_) {
                              setState(() => _selectedSourceId = entry.key);
                            },
                            label: Text(
                              '${rep.sourceName} (${entry.value.length})',
                            ),
                            avatar: _DownloadSourceAvatar(
                              sourceName: rep.sourceName,
                              iconUrl: rep.sourceIconUrl,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: filteredEntries.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    final sourceOptions = entry.value;
                    final rep = sourceOptions.first;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.bgElev,
                        borderRadius: BorderRadius.circular(CloudRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              SourceBadge(
                                sourceName: rep.sourceName,
                                iconUrl: rep.sourceIconUrl,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${sourceOptions.length} server${sourceOptions.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...sourceOptions.map(
                            (opt) => Padding(
                              padding: EdgeInsets.only(
                                top: opt == sourceOptions.first ? 0 : 10,
                              ),
                              child: Material(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(
                                  CloudRadius.lg,
                                ),
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(opt),
                                  borderRadius: BorderRadius.circular(
                                    CloudRadius.lg,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          _iconForQuality(opt.qualityTier),
                                          size: 22,
                                          color: opt.qualityTier.color,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Flexible(
                                                    child: Text(
                                                      opt.link.serverName,
                                                      style: TextStyle(
                                                        color: colors.text,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  _QualityTierChip(
                                                    tier: opt.qualityTier,
                                                  ),
                                                  if (opt.link.language != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 6,
                                                          ),
                                                      child: _AudioCodeChip(
                                                        code:
                                                            opt.link.language!,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (opt.link.detectedHost !=
                                                  null) ...<Widget>[
                                                const SizedBox(height: 4),
                                                Text(
                                                  opt.link.detectedHost!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityTierChip extends StatelessWidget {
  const _QualityTierChip({required this.tier});

  final ServerQualityTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tier.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        tier.label,
        style: TextStyle(
          color: tier.color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AudioCodeChip extends StatelessWidget {
  const _AudioCodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.35)),
      ),
      child: Text(
        code.trim().toUpperCase(),
        style: TextStyle(
          color: Colors.blueAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DownloadSourceAvatar extends StatelessWidget {
  const _DownloadSourceAvatar({required this.sourceName, this.iconUrl});

  final String sourceName;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    if (iconUrl != null && iconUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(iconUrl!),
        backgroundColor: Colors.transparent,
      );
    }
    return CircleAvatar(
      radius: 12,
      child: Text(sourceName.characters.first.toUpperCase()),
    );
  }
}

class _RelationTypeBadge extends StatelessWidget {
  const _RelationTypeBadge({required this.type});

  final AnimeRelationType type;

  @override
  Widget build(BuildContext context) {
    return MetaChip(
      label: displayRelationTypeLabel(context, type),
      isActive: true,
    );
  }
}
