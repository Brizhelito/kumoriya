import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_auth/kumoriya_auth.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/auth/auth_providers.dart';
import '../../../../shared/storage_providers.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/party_exit_dialog.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../anime_catalog/application/models/resolved_server_link_result.dart';
import '../../../anime_catalog/application/models/source_availability.dart';
import '../../../anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../../anime_catalog/presentation/support/plugin_icon_helpers.dart';
import '../../../anime_catalog/presentation/support/playback_launch_flow.dart';
import '../../../anime_catalog/presentation/widgets/source_badge.dart';
import '../../../downloads/presentation/download_providers.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../application/models/models.dart';
import '../../application/providers/party_providers.dart';
import '../../infrastructure/party_debug_logger.dart';
import '../party_route_mode.dart';
import 'party_episode_list_page.dart';

class PartyAnimePage extends ConsumerStatefulWidget {
  const PartyAnimePage({super.key, this.anilistId, this.autoJoinCode});

  final int? anilistId;
  final String? autoJoinCode;

  @override
  ConsumerState<PartyAnimePage> createState() => _PartyAnimePageState();
}

class _PartyAnimePageState extends ConsumerState<PartyAnimePage> {
  final _inviteController = TextEditingController();
  bool _isLaunching = false;
  bool _navCallbackSet = false;
  bool _showAnimeSearch = false;
  PartySessionNotifier? _partyNotifier;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(partySessionProvider.notifier);
    _partyNotifier = notifier;
    notifier.onMediaChangeNavigation =
        (int anilistId, String animeTitle, double episodeNumber) {
          if (!mounted) return;
          // When the anime stays the same and only the episode changes,
          // the lobby already reacts via ref.watch(partySessionProvider)
          // — skip the disruptive pop+push navigation.
          // Compare against widget.anilistId (fixed at construction) since
          // session state has already been updated when this callback fires.
          if (widget.anilistId != null && widget.anilistId == anilistId) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final navigator = Navigator.of(context, rootNavigator: true);
            navigator.popUntil((route) => route.isFirst);
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => PartyAnimePage(anilistId: anilistId),
              ),
            );
          });
        };
    notifier.onKickedOut = (String byUserId, String? reason) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            reason == null || reason.isEmpty
                ? context.l10n.partyRemovedByHost
                : context.l10n.partyRemovedWithReason(reason),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    };
    _navCallbackSet = true;

    final autoCode = widget.autoJoinCode;
    if (autoCode != null && autoCode.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final session = ref.read(partySessionProvider);
        final normalizedCode = autoCode.trim().toUpperCase().replaceAll(
          RegExp(r'[^A-Z0-9]'),
          '',
        );
        if (normalizedCode.isEmpty) return;
        if (session.status != PartySessionStatus.idle) return;
        _inviteController.text = normalizedCode;
        ref.read(partySessionProvider.notifier).joinRoom(normalizedCode);
      });
    }
  }

  @override
  void dispose() {
    if (_navCallbackSet) {
      final notifier = _partyNotifier;
      if (notifier != null) {
        notifier.onMediaChangeNavigation = null;
        notifier.onKickedOut = null;
      }
      _navCallbackSet = false;
    }
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(partySessionProvider);
    final effectiveAnilistId = session.room?.anilistId ?? widget.anilistId ?? 0;
    final isConnected = session.status == PartySessionStatus.connected;

    // Refresh source availability when the session connects (join or create)
    ref.listen(partySessionProvider, (
      PartySessionState? previous,
      PartySessionState next,
    ) {
      if (previous?.status != PartySessionStatus.connected &&
          next.status == PartySessionStatus.connected) {
        final roomId = next.room?.anilistId;
        if (roomId != null && roomId > 0) {
          ref.invalidate(sourceAvailabilitySummaryProvider(roomId));
        }
      }
    });

    return PopScope(
      canPop: !session.isActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !session.isActive || !mounted) return;
        final action = await showPartyExitDialog(context);
        if (action == PartyExitAction.leave && mounted) {
          await ref.read(partySessionProvider.notifier).leaveRoom();
          if (context.mounted) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).popUntil((route) => route.isFirst);
          }
        }
      },
      child: Scaffold(
        backgroundColor: KumoriyaColors.background,
        appBar: isConnected
            ? AppBar(
                backgroundColor: KumoriyaColors.surface,
                title: Text(context.l10n.partyTitle),
                actions: [
                  if (session.room != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: session.room!.inviteCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.partyInviteCodeCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: KumoriyaColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            session.room!.inviteCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: KumoriyaColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.bug_report),
                    onPressed: () => _showDebugLogs(context),
                    tooltip: context.l10n.partyViewDebugLogsTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app),
                    onPressed: () => _leaveParty(context),
                  ),
                ],
              )
            : null,
        body: _buildBody(session, effectiveAnilistId),
      ),
    );
  }

  /// Leave the party from the lobby AppBar exit button.
  ///
  /// Shows a confirmation dialog first. On confirm, displays a brief loading
  /// overlay while [leaveRoom] completes, then pops to the root route.
  Future<void> _leaveParty(BuildContext context) async {
    final action = await showPartyExitDialog(context);
    if (action != PartyExitAction.leave || !mounted) return;
    showBlockingLoader(context, context.l10n.partyLeavingRoom);
    try {
      await ref.read(partySessionProvider.notifier).leaveRoom();
    } finally {
      if (mounted) {
        hideBlockingLoader(context);
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _showDebugLogs(BuildContext context) async {
    final logs = await PartyDebugLogger.readAll();
    if (!mounted || !context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.partyDebugLogsTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              logs,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.partyClose),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logs));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.partyLogsCopied)),
              );
            },
            child: Text(context.l10n.partyCopy),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(PartySessionState session, int anilistId) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading || auth.value == null) {
      return _PartyPageShell(
        child: LoadingStateView(label: context.l10n.loadingGeneric),
      );
    }
    if (auth.value is! AuthenticatedAuthState) {
      return const _PartyPageShell(child: _UnauthenticatedView());
    }

    if (session.status == PartySessionStatus.idle) {
      if (anilistId == 0) {
        return _PartyPageShell(
          child: _IdleView(
            inviteController: _inviteController,
            onCreate: null,
            onJoin: _joinParty,
          ),
        );
      }
      return _PartyPageShell(
        child: _IdleView(
          inviteController: _inviteController,
          onCreate: _createParty,
          onJoin: _joinParty,
        ),
      );
    }
    if (session.status == PartySessionStatus.creating ||
        session.status == PartySessionStatus.joining ||
        session.status == PartySessionStatus.connecting) {
      return _PartyPageShell(
        child: LoadingStateView(label: context.l10n.partyPreparingStage),
      );
    }
    if (session.status == PartySessionStatus.error) {
      return _PartyPageShell(
        child: _ErrorView(
          message: session.error ?? context.l10n.partyUnknownError,
          onRetry: () => ref.read(partySessionProvider.notifier).leaveRoom(),
        ),
      );
    }

    if (anilistId == 0) {
      return _PartyPageShell(
        child: LoadingStateView(label: context.l10n.partyPreparingStage),
      );
    }

    return _buildContent(session, anilistId);
  }

  Widget _buildContent(PartySessionState session, int anilistId) {
    final detailState = ref.watch(animeDetailProvider(anilistId));
    final availabilityState = ref.watch(
      sourceAvailabilitySummaryProvider(anilistId),
    );

    return detailState.when(
      loading: () => _PartyPageShell(
        child: LoadingStateView(label: context.l10n.partyPreparingStage),
      ),
      error: (_, _) => _PartyPageShell(
        child: ErrorStateView(
          message: context.l10n.partyCouldNotLoadAnime,
          onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
        ),
      ),
      data: (result) => result.fold(
        onFailure: (error) => _PartyPageShell(
          child: ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () => ref.invalidate(animeDetailProvider(anilistId)),
          ),
        ),
        onSuccess: (detail) => _PartyPageShell(
          child: _PartyAnimeContent(
            detail: detail,
            availabilityState: availabilityState,
            session: session,
            isLaunching: _isLaunching,
            showAnimeSearch: _showAnimeSearch,
            onCloseAnimeSearch: () => setState(() => _showAnimeSearch = false),
            onOpenEpisodes: () => _openEpisodes(detail),
            onStartWatching: () => _startWatching(detail),
            onChangeAnime: () => _changeAnime(context, ref),
            onChangeEpisode: () => _changeEpisode(context, ref),
            onShareInviteLink: (room) => _shareInviteLink(context, room),
          ),
        ),
      ),
    );
  }

  void _joinParty() {
    final code = _inviteController.text.trim();
    if (code.isEmpty) return;
    dev.log('_joinParty: code=$code', name: 'Party');
    ref.read(partySessionProvider.notifier).joinRoom(code);
  }

  Future<void> _createParty() async {
    final targetAnilistId = widget.anilistId;
    if (targetAnilistId == null) return;

    final detailResult = await ref.read(
      animeDetailProvider(targetAnilistId).future,
    );
    final animeTitle = detailResult.fold(
      onFailure: (_) => '',
      onSuccess: (detail) => detail.anime.title.romaji,
    );

    final latestResult = await ref.read(
      latestEpisodeProgressProvider(targetAnilistId).future,
    );
    final latestEpisode = latestResult.fold(
      onFailure: (_) => null,
      onSuccess: (progress) => progress?.episodeNumber,
    );
    final startEpisode = latestEpisode ?? 1;

    dev.log(
      '_createParty: anilistId=$targetAnilistId '
      'startEpisode=$startEpisode (latest=$latestEpisode)',
      name: 'Party',
    );
    if (!mounted) return;
    ref
        .read(partySessionProvider.notifier)
        .createRoom(
          anilistId: targetAnilistId,
          animeTitle: animeTitle,
          episodeNumber: startEpisode.toDouble(),
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

  Future<void> _startWatching(AnimeDetail detail) async {
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
        final notifier = ref.read(partySessionProvider.notifier);
        if (notifier.isLocalHost) {
          notifier.startWatching();
        }
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
    try {
      final decision = await ref
          .read(startEpisodePlaybackUseCaseProvider)
          .call(
            anilistId: detail.anime.anilistId,
            episodeNumber: episodeNumber,
            availabilitySummary: summary,
          );
      if (!mounted) return;
      hideBlockingLoader(context);
      final notifier = ref.read(partySessionProvider.notifier);
      if (notifier.isLocalHost) {
        notifier.startWatching();
      }
      await handlePlaybackDecision(
        context: context,
        ref: ref,
        anilistId: detail.anime.anilistId,
        animeTitle: detail.anime.title.romaji,
        routeMode: PartyRouteMode.party,
        decision: decision,
        totalEpisodes: detail.anime.totalEpisodes,
        nextAiringEpisodeNumber: detail.anime.nextAiringEpisodeNumber
            ?.toDouble(),
      );
    } catch (e, st) {
      dev.log('_startWatching error: $e $st', name: 'Party');
      if (mounted) {
        hideBlockingLoader(context);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.partyPlaybackLaunchFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  Future<void> _changeAnime(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(partySessionProvider.notifier);
    if (!notifier.isLocalHost) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.partyOnlyHostCanSwitchAnime)),
      );
      return;
    }
    // Toggle the inline search section instead of navigating away.
    setState(() => _showAnimeSearch = !_showAnimeSearch);
  }

  /// Opens the full episode list page so the host can pick an episode
  /// visually instead of typing a number. The episode list page handles
  /// `changeMedia()` internally when the host selects a different episode.
  void _changeEpisode(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(partySessionProvider.notifier);
    if (!notifier.isLocalHost) return;
    final session = ref.read(partySessionProvider);
    final room = session.room;
    if (room == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PartyEpisodeListPage(
          anilistId: room.anilistId,
          animeTitle: room.animeTitle,
          focusedEpisodeNumber: room.episodeNumber,
        ),
      ),
    );
  }

  Future<void> _shareInviteLink(BuildContext context, PartyRoom room) async {
    const baseUrl = 'https://join.kumoriya.online';
    final link = '$baseUrl/${room.inviteCode}';
    await Share.share(
      'Únete a mi Watch Party de "${room.animeTitle}" en Kumoriya\n$link',
      subject: context.l10n.partyShareInviteSubject,
    );
  }
}

// ── Idle: create or join ──

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.inviteController,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController inviteController;
  final VoidCallback? onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_rounded,
              size: 64,
              color: KumoriyaColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.partyTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: KumoriyaColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.partyIdleSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KumoriyaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_circle_rounded),
                label: Text(context.l10n.partyCreateRoom),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.l10n.partyOrDivider,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KumoriyaColors.textMuted,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inviteController,
              decoration: InputDecoration(
                hintText: context.l10n.partyInviteCodeLabel,
                filled: true,
                fillColor: KumoriyaColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.login_rounded),
                label: Text(context.l10n.partyJoin),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: KumoriyaColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ──

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: KumoriyaColors.statusDanger,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KumoriyaColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: KumoriyaColors.primary,
              ),
              child: Text(context.l10n.partyTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Unauthenticated ──

class _UnauthenticatedView extends StatelessWidget {
  const _UnauthenticatedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 56,
              color: KumoriyaColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.partyRequiresAccount,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: KumoriyaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.partyRequiresAccountDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KumoriyaColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: KumoriyaColors.primary,
              ),
              child: Text(context.l10n.partyGoToLogin),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shell ──

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

// ── Content (connected) ──

class _PartyAnimeContent extends ConsumerWidget {
  const _PartyAnimeContent({
    required this.detail,
    required this.availabilityState,
    required this.session,
    required this.isLaunching,
    required this.showAnimeSearch,
    required this.onCloseAnimeSearch,
    required this.onOpenEpisodes,
    required this.onStartWatching,
    required this.onChangeAnime,
    required this.onChangeEpisode,
    required this.onShareInviteLink,
  });

  final AnimeDetail detail;
  final AsyncValue<Result<SourceAvailabilitySummary, KumoriyaError>>
  availabilityState;
  final PartySessionState session;
  final bool isLaunching;
  final bool showAnimeSearch;
  final VoidCallback onCloseAnimeSearch;
  final VoidCallback onOpenEpisodes;
  final VoidCallback onStartWatching;
  final VoidCallback onChangeAnime;
  final VoidCallback onChangeEpisode;
  final void Function(PartyRoom) onShareInviteLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = session.room;
    final notifier = ref.read(partySessionProvider.notifier);
    final isHost = notifier.isLocalHost;
    final isCurrentPartyAnime =
        room != null && room.anilistId == detail.anime.anilistId;
    final summary = availabilityState.maybeWhen(
      data: (result) =>
          result.fold(onFailure: (_) => null, onSuccess: (value) => value),
      orElse: () => null,
    );
    final memberCount = room?.members.length ?? 0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PartyHeroCard(
                  detail: detail,
                  memberCount: memberCount,
                  currentEpisode: room?.episodeNumber,
                  isPlaying: session.playback.isPlaying,
                ),
                const SizedBox(height: 16),
                if (room != null)
                  _PartyStatusCard(
                    room: room,
                    onShareInviteLink: onShareInviteLink,
                  ),
                const SizedBox(height: 16),
                if (room != null && isHost)
                  _PartyHostControlsCard(
                    onChangeAnime: onChangeAnime,
                    onChangeEpisode: onChangeEpisode,
                  ),
                if (room != null && isHost) const SizedBox(height: 16),
                if (showAnimeSearch && isHost && room != null)
                  _PartyAnimeSearchSection(
                    currentAnilistId: room.anilistId,
                    onClose: onCloseAnimeSearch,
                  ),
                if (showAnimeSearch && isHost && room != null)
                  const SizedBox(height: 16),
                // Members see a waiting indicator when host is searching.
                if (showAnimeSearch && !isHost && room != null)
                  _PartyWaitingForHostBanner(),
                _PartySourceStrip(summary: summary),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isCurrentPartyAnime ? onOpenEpisodes : null,
                        icon: const Icon(Icons.queue_play_next_rounded),
                        label: Text(
                          isHost
                              ? context.l10n.partyChooseEpisode
                              : context.l10n.partyPreviewEpisodes,
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isCurrentPartyAnime
                            ? (isLaunching ? null : onStartWatching)
                            : null,
                        icon: Icon(
                          isHost
                              ? Icons.play_circle_fill_rounded
                              : Icons.videocam_rounded,
                        ),
                        label: Text(
                          isLaunching
                              ? context.l10n.partyOpening
                              : (isHost
                                    ? context.l10n.partyStartWatching
                                    : context.l10n.partyEnterPlayer),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: KumoriyaColors.primary,
                          foregroundColor: KumoriyaColors.textPrimary,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _PartyMembersStrip(
                  room: room,
                  memberStatuses: session.memberStatuses,
                  currentUserId: notifier.localUserId,
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

// ── Hero card ──

class _PartyHeroCard extends StatelessWidget {
  const _PartyHeroCard({
    required this.detail,
    required this.memberCount,
    required this.currentEpisode,
    required this.isPlaying,
  });

  final AnimeDetail detail;
  final int memberCount;
  final double? currentEpisode;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
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
              height: 200,
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
                    Row(
                      children: [
                        _PartyStatPill(
                          icon: Icons.group_rounded,
                          label: context.l10n.partyInRoomCount(memberCount),
                        ),
                        const SizedBox(width: 8),
                        // Live playback state indicator.
                        _PlaybackStatePill(isPlaying: isPlaying),
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
                            if (currentEpisode != null)
                              _PartyInfoChip(
                                label: context.l10n.partyRoomOnEpisode(
                                  currentEpisode!.toInt(),
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

// ── Source strip ──

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

// ── Members strip (status only, no ready) ──

class _PartyMembersStrip extends StatelessWidget {
  const _PartyMembersStrip({
    required this.room,
    required this.memberStatuses,
    required this.currentUserId,
  });

  final PartyRoom? room;
  final Map<String, PartyMemberStatus> memberStatuses;
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
              final status = memberStatuses[member.userId] ?? member.status;
              final isYou = member.userId == currentUserId;
              return _MemberTile(member: member, status: status, isYou: isYou);
            },
          ),
        ),
      ],
    );
  }
}

Color _statusColor(PartyMemberStatus status) {
  return switch (status) {
    PartyMemberStatus.watching => KumoriyaColors.statusSuccess,
    PartyMemberStatus.inPlayer => Colors.lightBlue,
    PartyMemberStatus.loading => Colors.orange,
    PartyMemberStatus.paused => Colors.amber,
    PartyMemberStatus.inLobby => KumoriyaColors.textMuted,
  };
}

// ── Animated member tile ──

/// Individual member tile with animated border transitions.
///
/// The border color smoothly interpolates when a member's status changes
/// (e.g. from `inLobby` to `watching`), giving the lobby a sense of
/// liveness without being distracting.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.status,
    required this.isYou,
  });

  final PartyMember member;
  final PartyMemberStatus status;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final borderColor = status == PartyMemberStatus.watching
        ? KumoriyaColors.statusSuccess.withValues(alpha: 0.5)
        : status == PartyMemberStatus.loading
        ? Colors.orange.withValues(alpha: 0.4)
        : KumoriyaColors.borderSubtle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: 116,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A24),
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(color: borderColor),
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
                      ? context.l10n.partyAvatarFallback
                      : member.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                status.label,
                style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
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
  }
}

// ── Playback state pill (hero card) ──

/// Small pill showing the room's live playback state (playing / paused).
///
/// Uses a pulsing green dot when playing and a static amber dot when
/// paused, giving the lobby an at-a-glance indicator of whether content
/// is actively streaming.
class _PlaybackStatePill extends StatelessWidget {
  const _PlaybackStatePill({required this.isPlaying});

  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final dotColor = isPlaying ? KumoriyaColors.statusSuccess : Colors.amber;
    final label = isPlaying
        ? context.l10n.partyPlaybackPlaying
        : context.l10n.partyPlaybackPaused;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.6),
                  blurRadius: isPlaying ? 6 : 0,
                  spreadRadius: isPlaying ? 1 : 0,
                ),
              ],
            ),
          ),
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

// ── Waiting for host banner ──

/// Shown to non-host members when the host is in anime-search mode.
///
/// Gives members context that the host is actively choosing the next
/// anime, so they understand why nothing is happening.
class _PartyWaitingForHostBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: KumoriyaColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          border: Border.all(
            color: KumoriyaColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.partyHostIsChoosing,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KumoriyaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Relation card ──

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

// ── Stat pill ──

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

// ── Party status card (invite code + copy/share + connected) ──

class _PartyStatusCard extends StatelessWidget {
  const _PartyStatusCard({required this.room, required this.onShareInviteLink});

  final PartyRoom room;
  final void Function(PartyRoom) onShareInviteLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: KumoriyaColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                room.inviteCode,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: KumoriyaColors.primary,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, color: KumoriyaColors.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: room.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.partyInviteCodeCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: KumoriyaColors.primary),
            tooltip: context.l10n.partyShareInviteLinkTooltip,
            onPressed: () => onShareInviteLink(room),
          ),
        ],
      ),
    );
  }
}

// ── Host controls card (change anime/episode, host only) ──

class _PartyHostControlsCard extends StatelessWidget {
  const _PartyHostControlsCard({
    required this.onChangeAnime,
    required this.onChangeEpisode,
  });

  final VoidCallback onChangeAnime;
  final VoidCallback onChangeEpisode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: KumoriyaColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.partyHostControls,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: KumoriyaColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChangeAnime,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(context.l10n.partyChangeAnime),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KumoriyaColors.primary,
                    side: const BorderSide(color: KumoriyaColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChangeEpisode,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: Text(context.l10n.partyChangeEpisode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KumoriyaColors.primary,
                    side: const BorderSide(color: KumoriyaColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info chip ──

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

// ── Inline anime search section (host only) ──

/// Expandable search section rendered inline in the party lobby.
///
/// The host types a query, sees live results from the AniList catalog,
/// and taps an anime to confirm a `changeMedia` for the whole room.
/// Uses the existing [searchCatalogProvider] for queries and
/// [browseAnimeCatalogProvider] for trending suggestions when the
/// search box is empty.
class _PartyAnimeSearchSection extends ConsumerStatefulWidget {
  const _PartyAnimeSearchSection({
    required this.currentAnilistId,
    required this.onClose,
  });

  final int currentAnilistId;
  final VoidCallback onClose;

  @override
  ConsumerState<_PartyAnimeSearchSection> createState() =>
      _PartyAnimeSearchSectionState();
}

class _PartyAnimeSearchSectionState
    extends ConsumerState<_PartyAnimeSearchSection> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _activeQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _activeQuery = value.trim());
    });
  }

  Future<void> _selectAnime(
    BuildContext context,
    WidgetRef ref,
    Anime anime,
  ) async {
    if (anime.anilistId == widget.currentAnilistId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        ),
        title: Text(
          context.l10n.partyChangeAnimeTitle,
          style: TextStyle(color: KumoriyaColors.textPrimary),
        ),
        content: Text(
          context.l10n.partyChangeAnimeBody(anime.title.romaji),
          style: TextStyle(color: KumoriyaColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              context.l10n.cancelAction,
              style: TextStyle(color: KumoriyaColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KumoriyaColors.primary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.partySwitch),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(partySessionProvider.notifier);
    await notifier.changeMedia(
      anilistId: anime.anilistId,
      animeTitle: anime.title.romaji,
      episodeNumber: 1.0,
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
        border: Border.all(
          color: KumoriyaColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.search, color: KumoriyaColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.partySearchAnime,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: KumoriyaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: KumoriyaColors.textMuted,
                  size: 20,
                ),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search input
          TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: context.l10n.partySearchPlaceholder,
              filled: true,
              fillColor: KumoriyaColors.background,
              prefixIcon: Icon(
                Icons.search,
                color: KumoriyaColors.textMuted,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              isDense: true,
            ),
            style: TextStyle(color: KumoriyaColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          // Results or trending
          if (_activeQuery.isNotEmpty)
            _SearchResultsList(
              query: _activeQuery,
              onSelect: (anime) => _selectAnime(context, ref, anime),
            )
          else
            _TrendingAnimeList(
              onSelect: (anime) => _selectAnime(context, ref, anime),
            ),
        ],
      ),
    );
  }
}

/// Compact search results list driven by [searchCatalogProvider].
class _SearchResultsList extends ConsumerWidget {
  const _SearchResultsList({required this.query, required this.onSelect});

  final String query;
  final ValueChanged<Anime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchCatalogProvider(query));
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.l10n.partyCouldNotLoadAnime,
          style: TextStyle(color: KumoriyaColors.textMuted, fontSize: 12),
        ),
      ),
      data: (result) {
        final anime = result.fold(
          onFailure: (_) => <Anime>[],
          onSuccess: (list) => list,
        );
        if (anime.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.l10n.partyNeedPlayableSource,
              style: TextStyle(color: KumoriyaColors.textMuted, fontSize: 12),
            ),
          );
        }
        return _AnimeCompactList(items: anime, onSelect: onSelect);
      },
    );
  }
}

/// Compact trending anime list driven by [browseAnimeCatalogProvider].
class _TrendingAnimeList extends ConsumerWidget {
  const _TrendingAnimeList({required this.onSelect});

  final ValueChanged<Anime> onSelect;

  static const _trendingRequest = AnimeBrowseRequest(
    sort: AnimeSortType.trending,
    perPage: 12,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browseAnimeCatalogProvider(_trendingRequest));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.partyTrendingNow,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: KumoriyaColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        state.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (result) {
            final anime = result.fold(
              onFailure: (_) => <Anime>[],
              onSuccess: (list) => list,
            );
            return _AnimeCompactList(items: anime, onSelect: onSelect);
          },
        ),
      ],
    );
  }
}

/// Compact vertical list of anime tiles used inside the search section.
class _AnimeCompactList extends StatelessWidget {
  const _AnimeCompactList({required this.items, required this.onSelect});

  final List<Anime> items;
  final ValueChanged<Anime> onSelect;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: KumoriyaColors.borderSubtle),
        itemBuilder: (context, index) {
          final anime = items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelect(anime),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: KumoriyaCachedImage(
                      url: anime.coverImageUrl,
                      bucket: KumoriyaImageCacheBucket.artwork,
                      width: 40,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.title.romaji,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: KumoriyaColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (anime.releaseYear != null)
                          Text(
                            '${anime.format.name} \u00b7 ${anime.releaseYear}',
                            style: TextStyle(
                              color: KumoriyaColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: KumoriyaColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
