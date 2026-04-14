import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../anime_catalog/presentation/pages/anime_detail_page.dart';
import '../../application/models/models.dart';
import '../../application/providers/party_providers.dart';

/// Pre-playback lobby for watch party. Shows room members, invite code,
/// ready states, and peer connection status.
class PartyLobbyPage extends ConsumerStatefulWidget {
  const PartyLobbyPage({super.key, this.anilistId, this.animeTitle});

  final int? anilistId;
  final String? animeTitle;

  @override
  ConsumerState<PartyLobbyPage> createState() => _PartyLobbyPageState();
}

class _PartyLobbyPageState extends ConsumerState<PartyLobbyPage> {
  final _inviteController = TextEditingController();
  bool _navCallbackSet = false;

  @override
  void initState() {
    super.initState();
    // Set the navigation callback ONCE — not on every rebuild.
    // This handles media change events for non-host members in the lobby.
    ref.read(partySessionProvider.notifier).onMediaChangeNavigation = (
      int anilistId,
      String animeTitle,
      double episodeNumber,
    ) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AnimeDetailPage(anilistId: anilistId),
        ),
      );
    };
    _navCallbackSet = true;
  }

  @override
  void dispose() {
    // Clear the callback when leaving the lobby to prevent stale references.
    if (_navCallbackSet) {
      ref.read(partySessionProvider.notifier).onMediaChangeNavigation = null;
      _navCallbackSet = false;
    }
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(partySessionProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        backgroundColor: KumoriyaColors.surface,
        title: const Text('Watch Party'),
        actions: [
          if (session.isActive)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => _leaveParty(context),
            ),
        ],
      ),
      body: switch (session.status) {
        PartySessionStatus.idle => _IdleView(
            inviteController: _inviteController,
            onJoin: _joinParty,
            onCreate: (widget.anilistId != null && widget.animeTitle != null)
                ? _createParty
                : null,
            animeTitle: widget.animeTitle,
          ),
        PartySessionStatus.creating ||
        PartySessionStatus.joining ||
        PartySessionStatus.connecting =>
          const _LoadingView(),
        PartySessionStatus.connected => _ConnectedView(session: session),
        PartySessionStatus.error => _ErrorView(
            message: session.error ?? 'Unknown error',
            onRetry: () =>
                ref.read(partySessionProvider.notifier).leaveRoom(),
          ),
      },
    );
  }

  void _joinParty() {
    final code = _inviteController.text.trim();
    if (code.isEmpty) return;
    dev.log('_joinParty: code=$code', name: 'Party');
    ref.read(partySessionProvider.notifier).joinRoom(code);
  }

  void _createParty() {
    dev.log('_createParty: anilistId=${widget.anilistId} title=${widget.animeTitle}', name: 'Party');
    ref.read(partySessionProvider.notifier).createRoom(
      anilistId: widget.anilistId!,
      animeTitle: widget.animeTitle!,
      episodeNumber: 1,
    );
  }

  void _leaveParty(BuildContext context) {
    ref.read(partySessionProvider.notifier).leaveRoom();
  }
}

// ── Idle: create or join ──

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.inviteController,
    required this.onJoin,
    this.onCreate,
    this.animeTitle,
  });

  final TextEditingController inviteController;
  final VoidCallback onJoin;
  final VoidCallback? onCreate;
  final String? animeTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.groups_outlined,
            size: 64,
            color: KumoriyaColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Watch together with friends',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: KumoriyaColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a room or join with an invite code. Up to 4 people can watch in sync via P2P.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KumoriyaColors.textSecondary,
                ),
          ),
          const SizedBox(height: 48),
          // Join section
          TextField(
            controller: inviteController,
            style: const TextStyle(color: KumoriyaColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Invite Code',
              labelStyle: const TextStyle(color: KumoriyaColors.textMuted),
              filled: true,
              fillColor: KumoriyaColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: KumoriyaColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: KumoriyaColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KumoriyaColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.login),
            label: const Text('Join Party'),
            style: FilledButton.styleFrom(
              backgroundColor: KumoriyaColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (onCreate != null) ...[  
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Or start a room for ${animeTitle ?? 'this anime'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KumoriyaColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Room'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KumoriyaColors.primary,
                side: const BorderSide(color: KumoriyaColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else
            Text(
              'Open an anime page to create a room',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KumoriyaColors.textMuted,
                  ),
            ),
        ],
      ),
    );
  }
}

// ── Loading ──

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: KumoriyaColors.primary),
          SizedBox(height: 16),
          Text(
            'Connecting...',
            style: TextStyle(color: KumoriyaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Connected: room info + members ──

class _ConnectedView extends ConsumerWidget {
  const _ConnectedView({required this.session});

  final PartySessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = session.room!;
    final localUserId = ref.read(partySessionProvider.notifier).syncEngine?.localUserId;
    final isHost = localUserId == room.hostId;

    dev.log(
      '_ConnectedView: room=${room.id} isHost=$isHost localUserId=$localUserId '
      'members=${room.members.length} connected=${session.connectedPeerIds.length} '
      'ready=${session.readyStates.length}',
      name: 'Party',
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KumoriyaColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KumoriyaColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.live_tv, size: 20, color: KumoriyaColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Now Watching',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: KumoriyaColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  room.animeTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: KumoriyaColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Episode ${room.episodeNumber.toInt()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KumoriyaColors.textSecondary,
                      ),
                ),

                // ── Host controls ──
                if (isHost) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _changeAnime(context, ref),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Change Anime'),
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
                          onPressed: () => _changeEpisode(context, ref, room),
                          icon: const Icon(Icons.skip_next, size: 18),
                          label: const Text('Change Ep.'),
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

                const SizedBox(height: 12),
                // Invite code
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: KumoriyaColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          room.inviteCode,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
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
                        Clipboard.setData(
                          ClipboardData(text: room.inviteCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invite code copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: KumoriyaColors.primary),
                      tooltip: 'Share invite link',
                      onPressed: () {
                        final link =
                            'kumoriya://party/join?code=${room.inviteCode}';
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invite link copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Members list
          Text(
            'Members (${room.members.length}/${room.maxMembers})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: KumoriyaColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: room.members.length,
              itemBuilder: (context, index) {
                final member = room.members[index];
                final isConnected =
                    session.connectedPeerIds.contains(member.userId);
                final isReady =
                    session.readyStates[member.userId] ?? false;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: KumoriyaColors.primaryContainer,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: KumoriyaColors.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    member.displayName,
                    style: const TextStyle(
                      color: KumoriyaColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    member.role.name,
                    style: const TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // P2P connection indicator
                      Icon(
                        isConnected ? Icons.wifi : Icons.wifi_off,
                        size: 16,
                        color: isConnected
                            ? KumoriyaColors.statusSuccess
                            : KumoriyaColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      // Ready indicator
                      Icon(
                        isReady
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isReady
                            ? KumoriyaColors.statusSuccess
                            : KumoriyaColors.textMuted,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Ready + Start controls
          _BottomControls(session: session, room: room, isHost: isHost),
        ],
      ),
    );
  }

  /// Host picks a different anime — just pop back to browse.
  /// The party icon on AnimeDetailPage will offer "Set for Party"
  /// when the user is already in an active room as host.
  void _changeAnime(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Browse an anime and tap the party icon to switch.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Host picks a different episode number.
  void _changeEpisode(BuildContext context, WidgetRef ref, PartyRoom room) {
    final controller = TextEditingController(
      text: room.episodeNumber.toInt().toString(),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KumoriyaColors.surface,
        title: const Text('Change Episode', style: TextStyle(color: KumoriyaColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: KumoriyaColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Episode number',
            labelStyle: const TextStyle(color: KumoriyaColors.textMuted),
            filled: true,
            fillColor: KumoriyaColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final ep = double.tryParse(controller.text.trim());
              if (ep == null || ep <= 0) return;
              Navigator.of(ctx).pop();
              ref.read(partySessionProvider.notifier).changeMedia(
                anilistId: room.anilistId,
                animeTitle: room.animeTitle,
                episodeNumber: ep,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: KumoriyaColors.primary),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// ── Bottom controls: Ready toggle + Start Watching ──

class _BottomControls extends ConsumerWidget {
  const _BottomControls({
    required this.session,
    required this.room,
    required this.isHost,
  });

  final PartySessionState session;
  final PartyRoom room;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localUserId =
        ref.read(partySessionProvider.notifier).syncEngine?.localUserId;
    final localReady = session.readyStates[localUserId] ?? false;
    final allReady = room.members.isNotEmpty &&
        room.members.every(
          (m) => session.readyStates[m.userId] == true,
        );

    dev.log(
      '_BottomControls: localUserId=$localUserId localReady=$localReady allReady=$allReady members=${room.members.length}',
      name: 'Party',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ready toggle
        FilledButton.icon(
          onPressed: () {
            dev.log('toggleReady: $localReady -> ${!localReady}', name: 'Party');
            ref.read(partySessionProvider.notifier).toggleReady(!localReady);
          },
          icon: Icon(localReady ? Icons.check_circle : Icons.radio_button_unchecked),
          label: Text(localReady ? 'Ready!' : 'Ready'),
          style: FilledButton.styleFrom(
            backgroundColor:
                localReady ? KumoriyaColors.statusSuccess : KumoriyaColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Host: Start Watching button / Members: waiting label
        if (isHost)
          FilledButton.icon(
            onPressed: allReady ? () => _startWatching(context) : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              allReady ? 'Start Watching' : 'Waiting for everyone...',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: KumoriyaColors.primary,
              disabledBackgroundColor: KumoriyaColors.surface,
              disabledForegroundColor: KumoriyaColors.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else if (localReady)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Waiting for the host to start...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KumoriyaColors.textMuted,
                  ),
            ),
          ),
      ],
    );
  }

  void _startWatching(BuildContext context) {
    // Navigate to the anime detail page where the host selects
    // an episode and the normal resolve → player flow kicks in.
    // The party session stays active (it's a global Riverpod provider).
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: room.anilistId),
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
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
