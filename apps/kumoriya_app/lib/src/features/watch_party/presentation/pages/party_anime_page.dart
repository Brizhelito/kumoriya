import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../anime_catalog/application/models/resolved_server_link_result.dart';
import '../../../anime_catalog/application/models/source_availability.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../anime_catalog/presentation/support/plugin_icon_helpers.dart';
import '../../../anime_catalog/presentation/support/playback_launch_flow.dart';
import '../../../anime_catalog/presentation/widgets/source_badge.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../application/party_session_guard.dart';
import '../../application/models/models.dart';
import '../../application/providers/party_providers.dart';
import '../party_route_mode.dart';
import 'party_episode_list_page.dart';
import 'party_lobby_page.dart';

class PartyAnimePage extends ConsumerStatefulWidget {
  const PartyAnimePage({super.key, required this.anilistId});

  final int anilistId;

  @override
  ConsumerState<PartyAnimePage> createState() => _PartyAnimePageState();
}

class _PartyAnimePageState extends ConsumerState<PartyAnimePage> {
  bool _isLaunching = false;
  bool _partySourceCallbackSet = false;
  int? _lastPartyAutoResolveAtMs;
  PartySessionNotifier? _partyNotifier;

  /// Max staleness accepted when replaying a `source_selected` event that
  /// arrived before this page mounted. Anything older is assumed to refer to
  /// a previous episode/selection and gets ignored to avoid spurious jumps.
  static const Duration _latestSourceReplayMaxAge = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(partySessionProvider.notifier);
    _partyNotifier = notifier;
    notifier.onPartySourceSelected =
        (
          String sourcePluginId,
          String serverName,
          String? resolverPluginId,
          double episodeNumber,
        ) {
          unawaited(
            _handlePartySourceSelected(
              sourcePluginId: sourcePluginId,
              serverName: serverName,
              resolverPluginId: resolverPluginId,
              episodeNumber: episodeNumber,
            ),
          );
        };
    _partySourceCallbackSet = true;

    // Drain any `source_selected` that arrived before this page mounted.
    // Without this replay, a fast host whose `source_selected` beats the
    // member's pop+push navigation leaves the member stranded on this page
    // with no auto-open. The notifier keeps the last event in
    // `latestSourceSelection`; we consume it post-frame so the provider
    // tree and route are fully wired.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeReplayLatestSourceSelection();
    });
  }

  void _maybeReplayLatestSourceSelection() {
    final notifier = _partyNotifier;
    if (notifier == null) return;
    final pending = notifier.latestSourceSelection;
    if (pending == null) return;
    final ageMs = DateTime.now().millisecondsSinceEpoch - pending.receivedAtMs;
    if (ageMs < 0 || ageMs > _latestSourceReplayMaxAge.inMilliseconds) {
      return;
    }
    unawaited(
      _handlePartySourceSelected(
        sourcePluginId: pending.sourcePluginId,
        serverName: pending.serverName,
        resolverPluginId: pending.resolverPluginId,
        episodeNumber: pending.episodeNumber,
      ),
    );
  }

  @override
  void dispose() {
    if (_partySourceCallbackSet) {
      _partyNotifier?.onPartySourceSelected = null;
      _partySourceCallbackSet = false;
    }
    super.dispose();
  }

  Future<void> _handlePartySourceSelected({
    required String sourcePluginId,
    required String serverName,
    required String? resolverPluginId,
    required double episodeNumber,
  }) async {
    if (!mounted) return;
    final notifier = ref.read(partySessionProvider.notifier);
    if (notifier.isLocalHost) return;

    final session = ref.read(partySessionProvider);
    final room = session.room;
    if (room == null || room.anilistId != widget.anilistId) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastPartyAutoResolveAtMs != null &&
        now - _lastPartyAutoResolveAtMs! < 1500) {
      return;
    }
    _lastPartyAutoResolveAtMs = now;

    final outcome = await openPartySelectedSource(
      context: context,
      ref: ref,
      anilistId: widget.anilistId,
      animeTitle: room.animeTitle,
      episodeNumber: episodeNumber,
      sourcePluginId: sourcePluginId,
      serverName: serverName,
      resolverPluginId: resolverPluginId,
      routeMode: PartyRouteMode.party,
    );
    if (!mounted) return;

    final hint = switch (outcome) {
      PartyAutoResolveOutcome.sourceUnavailable =>
        context.l10n.partyHostSourceMissing,
      PartyAutoResolveOutcome.episodeUnavailable =>
        context.l10n.partyHostEpisodeUnavailable,
      PartyAutoResolveOutcome.serverUnavailable =>
        context.l10n.partyHostServerUnavailable,
      PartyAutoResolveOutcome.resolverFailed =>
        context.l10n.partyHostResolverFailed,
      _ => null,
    };
    if (hint != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(hint), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(animeDetailProvider(widget.anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(widget.anilistId),
    );
    final session = ref.watch(partySessionProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: detailState.when(
        loading: () => _PartyPageShell(
          child: LoadingStateView(label: context.l10n.partyPreparingStage),
        ),
        error: (_, _) => _PartyPageShell(
          child: ErrorStateView(
            message: context.l10n.partyCouldNotLoadAnime,
            onRetry: () =>
                ref.invalidate(animeDetailProvider(widget.anilistId)),
          ),
        ),
        data: (result) => result.fold(
          onFailure: (error) => _PartyPageShell(
            child: ErrorStateView(
              message: mapErrorMessage(context, error),
              onRetry: () =>
                  ref.invalidate(animeDetailProvider(widget.anilistId)),
            ),
          ),
          onSuccess: (detail) => _PartyPageShell(
            child: _PartyAnimeContent(
              detail: detail,
              availabilityState: availabilityState,
              session: session,
              isLaunching: _isLaunching,
              onOpenLobby: _openLobby,
              onOpenEpisodes: () => _openEpisodes(detail),
              onSwitchAnime: () => _switchPartyAnime(detail),
              onOpenCurrentEpisode: () => _openCurrentEpisode(detail),
            ),
          ),
        ),
      ),
    );
  }

  void _openLobby() {
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PartyLobbyPage(anilistId: widget.anilistId),
      ),
    );
  }

  void _openEpisodes(AnimeDetail detail) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PartyEpisodeListPage(
          anilistId: detail.anime.anilistId,
          animeTitle: detail.anime.title.romaji,
        ),
      ),
    );
  }

  Future<void> _switchPartyAnime(AnimeDetail detail) async {
    final notifier = ref.read(partySessionProvider.notifier);
    if (!notifier.isLocalHost) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.partyOnlyHostCanSwitchAnime)),
      );
      return;
    }
    await notifier.changeMedia(
      anilistId: detail.anime.anilistId,
      animeTitle: detail.anime.title.romaji,
      episodeNumber: 1,
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.partySwitchedToAnime(detail.anime.title.romaji),
        ),
      ),
    );
  }

  Future<void> _openCurrentEpisode(AnimeDetail detail) async {
    if (_isLaunching) return;
    final session = ref.read(partySessionProvider);
    final room = session.room;
    final episodeNumber =
        room != null && room.anilistId == detail.anime.anilistId
        ? room.episodeNumber
        : 1.0;

    final summaryResult = await ref.read(
      sourceAvailabilitySummaryProvider(detail.anime.anilistId).future,
    );
    final summary = summaryResult.fold(
      onFailure: (_) => null,
      onSuccess: (value) => value,
    );
    if (summary == null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.partyNoPlayableSourcesReady)),
      );
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
            if ((task.episodeNumber - episodeNumber).abs() < 0.001 &&
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
              episodeNumber: episodeNumber.toInt().toString(),
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
    showBlockingLoader(context, context.l10n.partyGettingRoomStreamReady);
    final decision = await ref
        .read(startEpisodePlaybackUseCaseProvider)
        .call(
          anilistId: detail.anime.anilistId,
          episodeNumber: episodeNumber,
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
      routeMode: PartyRouteMode.party,
      decision: decision,
      totalEpisodes: detail.anime.totalEpisodes,
      nextAiringEpisodeNumber: detail.anime.nextAiringEpisodeNumber?.toDouble(),
    );
  }
}

class _PartyPageShell extends StatelessWidget {
  const _PartyPageShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF101823),
            KumoriyaColors.background,
            Color(0xFF090D13),
          ],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _PartyAnimeContent extends ConsumerWidget {
  const _PartyAnimeContent({
    required this.detail,
    required this.availabilityState,
    required this.session,
    required this.isLaunching,
    required this.onOpenLobby,
    required this.onOpenEpisodes,
    required this.onSwitchAnime,
    required this.onOpenCurrentEpisode,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final PartySessionState session;
  final bool isLaunching;
  final VoidCallback onOpenLobby;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onSwitchAnime;
  final VoidCallback onOpenCurrentEpisode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = session.room;
    final isHost = ref.read(partySessionProvider.notifier).isLocalHost;
    final isCurrentPartyAnime =
        room != null && room.anilistId == detail.anime.anilistId;
    final summary = availabilityState.maybeWhen(
      data: (result) =>
          result.fold(onFailure: (_) => null, onSuccess: (value) => value),
      orElse: () => null,
    );
    final readyCount = session.readyStates.values.where((v) => v).length;
    final memberCount = room?.members.length ?? 0;
    final connectedCount = partyConnectedMemberCount(
      session,
      localUserId: ref.read(partySessionProvider.notifier).localUserId,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PartyTopBar(
                  onBack: onOpenLobby,
                  roomTitle: room?.animeTitle,
                  inviteCode: room?.inviteCode,
                ),
                const SizedBox(height: 18),
                _PartyHeroCard(
                  detail: detail,
                  memberCount: memberCount,
                  readyCount: readyCount,
                  connectedCount: connectedCount,
                  currentEpisode: room?.episodeNumber,
                ),
                const SizedBox(height: 16),
                _PartyIntentCard(
                  isHost: isHost,
                  isCurrentPartyAnime: isCurrentPartyAnime,
                  animeTitle: detail.anime.title.romaji,
                ),
                const SizedBox(height: 16),
                _PartySourceStrip(summary: summary),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenEpisodes,
                        icon: const Icon(Icons.queue_play_next_rounded),
                        label: Text(
                          isCurrentPartyAnime
                              ? context.l10n.partyChooseEpisode
                              : context.l10n.partyPreviewEpisodes,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: KumoriyaColors.primary,
                          foregroundColor: KumoriyaColors.textPrimary,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isCurrentPartyAnime
                            ? (isLaunching ? null : onOpenCurrentEpisode)
                            : (isHost ? onSwitchAnime : null),
                        icon: Icon(
                          isCurrentPartyAnime
                              ? Icons.play_circle_fill_rounded
                              : Icons.swap_horiz_rounded,
                        ),
                        label: Text(
                          isCurrentPartyAnime
                              ? (isLaunching
                                    ? context.l10n.partyOpening
                                    : context.l10n.partyWatchCurrentEpisode)
                              : (isHost
                                    ? context.l10n.partySetForPartyTooltip
                                    : context.l10n.partyHostChoosesAnime),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KumoriyaColors.textPrimary,
                          side: BorderSide(
                            color: isCurrentPartyAnime
                                ? KumoriyaColors.primary
                                : KumoriyaColors.borderSubtle,
                          ),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PartyMembersStrip(
                  room: room,
                  readyStates: session.readyStates,
                  currentUserId: ref
                      .read(partySessionProvider.notifier)
                      .localUserId,
                ),
                if (detail.relations.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  Text(
                    context.l10n.partyMaybeNext,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 212,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: detail.relations
                          .where(
                            (relation) =>
                                relation.targetKind == MediaKind.anime,
                          )
                          .take(8)
                          .length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final relation = detail.relations
                            .where(
                              (relation) =>
                                  relation.targetKind == MediaKind.anime,
                            )
                            .take(8)
                            .elementAt(index);
                        return _PartyRelationCard(anime: relation.anime);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PartyTopBar extends StatelessWidget {
  const _PartyTopBar({
    required this.onBack,
    required this.roomTitle,
    required this.inviteCode,
  });

  final VoidCallback onBack;
  final String? roomTitle;
  final String? inviteCode;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                context.l10n.partyTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: KumoriyaColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                roomTitle == null
                    ? context.l10n.partyChooseRoomNext
                    : context.l10n.partyRoomCode(inviteCode ?? '------'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KumoriyaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartyHeroCard extends StatelessWidget {
  const _PartyHeroCard({
    required this.detail,
    required this.memberCount,
    required this.readyCount,
    required this.connectedCount,
    required this.currentEpisode,
  });

  final AnimeDetail detail;
  final int memberCount;
  final int readyCount;
  final int connectedCount;
  final double? currentEpisode;

  @override
  Widget build(BuildContext context) {
    final currentEpisodeValue = currentEpisode;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        child: Stack(
          children: <Widget>[
            SizedBox(
              height: 270,
              width: double.infinity,
              child: KumoriyaCachedImage(
                url: detail.bannerImageUrl ?? detail.anime.coverImageUrl,
                bucket: KumoriyaImageCacheBucket.artwork,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.35),
                      const Color(0xFF0A1018),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _PartyStatPill(
                          icon: Icons.group_rounded,
                          label: context.l10n.partyInRoomCount(memberCount),
                        ),
                        _PartyStatPill(
                          icon: Icons.check_circle_rounded,
                          label: context.l10n.partyReadyCount(readyCount),
                        ),
                        _PartyStatPill(
                          icon: Icons.wifi_tethering_rounded,
                          label: context.l10n.partyConnectedCount(
                            connectedCount,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          detail.anime.title.romaji,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (detail.anime.format.name.isNotEmpty)
                              _PartyInfoChip(label: detail.anime.format.name),
                            if (detail.anime.releaseYear != null)
                              _PartyInfoChip(
                                label: detail.anime.releaseYear.toString(),
                              ),
                            if (detail.anime.totalEpisodes != null)
                              _PartyInfoChip(
                                label: context.l10n.partyEpisodeCount(
                                  detail.anime.totalEpisodes!,
                                ),
                              ),
                            if (currentEpisodeValue != null)
                              _PartyInfoChip(
                                label: context.l10n.partyRoomOnEpisode(
                                  currentEpisodeValue.toInt(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyIntentCard extends StatelessWidget {
  const _PartyIntentCard({
    required this.isHost,
    required this.isCurrentPartyAnime,
    required this.animeTitle,
  });

  final bool isHost;
  final bool isCurrentPartyAnime;
  final String animeTitle;

  @override
  Widget build(BuildContext context) {
    final title = isCurrentPartyAnime
        ? context.l10n.partyIntentCurrentTitle
        : context.l10n.partyIntentOtherTitle;
    final description = isCurrentPartyAnime
        ? (isHost
              ? context.l10n.partyIntentCurrentHost
              : context.l10n.partyIntentCurrentMember)
        : (isHost
              ? context.l10n.partyIntentOtherHost(animeTitle)
              : context.l10n.partyIntentOtherMember);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A24),
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: KumoriyaColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: KumoriyaColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartySourceStrip extends StatelessWidget {
  const _PartySourceStrip({required this.summary});

  final SourceAvailabilitySummary? summary;

  @override
  Widget build(BuildContext context) {
    final sources = summary?.playableSources ?? const <SourceAvailability>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.partyRoomReadySources,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: KumoriyaColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (sources.isEmpty)
            Text(
              context.l10n.partyNeedPlayableSource,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KumoriyaColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sources
                  .map(
                    (source) => SourceBadge(
                      name: source.manifest.displayName,
                      iconUrl: effectiveSourceIconUrl(source.manifest),
                      audioKinds: source.availableAudioKinds,
                      compact: true,
                      highlighted:
                          summary?.recommended?.manifest.id ==
                          source.manifest.id,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _PartyMembersStrip extends StatelessWidget {
  const _PartyMembersStrip({
    required this.room,
    required this.readyStates,
    required this.currentUserId,
  });

  final PartyRoom? room;
  final Map<String, bool> readyStates;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final members = room?.members ?? const <PartyMember>[];
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.partyWhoIsHere,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: KumoriyaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final member = members[index];
              final isReady = readyStates[member.userId] ?? false;
              final isYou = member.userId == currentUserId;
              return Container(
                width: 116,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A24),
                  borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
                  border: Border.all(
                    color: isReady
                        ? KumoriyaColors.statusSuccess.withValues(alpha: 0.5)
                        : KumoriyaColors.borderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: KumoriyaColors.primaryContainer,
                          child: Text(
                            member.displayName.isEmpty
                                ? '?'
                                : member.displayName
                                      .substring(0, 1)
                                      .toUpperCase(),
                            style: const TextStyle(
                              color: KumoriyaColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          isReady
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isReady
                              ? KumoriyaColors.statusSuccess
                              : KumoriyaColors.textMuted,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      isYou
                          ? '${member.displayName} · ${context.l10n.partyYouSuffix}'
                          : member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KumoriyaColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PartyRelationCard extends StatelessWidget {
  const _PartyRelationCard({required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => PartyAnimePage(anilistId: anime.anilistId),
        ),
      ),
      child: SizedBox(
        width: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 144,
              width: 124,
              child: KumoriyaCachedImage(
                url: anime.coverImageUrl,
                bucket: KumoriyaImageCacheBucket.artwork,
                borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              anime.title.romaji,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KumoriyaColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyStatPill extends StatelessWidget {
  const _PartyStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyInfoChip extends StatelessWidget {
  const _PartyInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
