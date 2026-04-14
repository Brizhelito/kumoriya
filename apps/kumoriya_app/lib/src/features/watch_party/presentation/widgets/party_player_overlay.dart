import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../application/providers/party_providers.dart';

/// Overlay placed on top of the player when in a watch party.
/// Shows connected peers, reactions, and a mini chat.
class PartyPlayerOverlay extends ConsumerStatefulWidget {
  const PartyPlayerOverlay({super.key});

  @override
  ConsumerState<PartyPlayerOverlay> createState() =>
      _PartyPlayerOverlayState();
}

class _PartyPlayerOverlayState extends ConsumerState<PartyPlayerOverlay> {
  bool _chatExpanded = false;
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(partySessionProvider);
    if (!session.isActive) return const SizedBox.shrink();

    return Stack(
      children: [
        // Reaction bubbles float up from bottom
        _ReactionBubbles(reactions: session.reactions),

        // Top-right: peer indicators
        Positioned(
          top: 8,
          right: 8,
          child: _PeerIndicators(session: session),
        ),

        // Bottom: reaction bar + chat toggle
        Positioned(
          bottom: 80, // Above player controls
          left: 8,
          right: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_chatExpanded) _buildChat(session),
              const SizedBox(height: 8),
              _buildReactionBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReactionBar() {
    const emojis = ['❤️', '😂', '😮', '👏', '🔥', '😢', '💀', '🎉'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: KumoriyaColors.playerControlBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Chat toggle
          IconButton(
            icon: Icon(
              _chatExpanded ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: KumoriyaColors.textPrimary,
              size: 20,
            ),
            onPressed: () => setState(() => _chatExpanded = !_chatExpanded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Emoji buttons
          ...emojis.map(
            (emoji) => GestureDetector(
              onTap: () =>
                  ref.read(partySessionProvider.notifier).sendReaction(emoji),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(PartySessionState session) {
    // Auto-scroll to bottom when new messages arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: KumoriyaColors.playerControlBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(8),
              itemCount: session.chatMessages.length,
              itemBuilder: (context, index) {
                final msg = session.chatMessages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${msg.senderName}: ',
                          style: const TextStyle(
                            color: KumoriyaColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: msg.text,
                          style: const TextStyle(
                            color: KumoriyaColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              controller: _chatController,
              style: const TextStyle(
                color: KumoriyaColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Say something...',
                hintStyle: const TextStyle(
                  color: KumoriyaColors.textMuted,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: KumoriyaColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: KumoriyaColors.primary,
                    size: 18,
                  ),
                  onPressed: _sendChat,
                ),
              ),
              onSubmitted: (_) => _sendChat(),
            ),
          ),
        ],
      ),
    );
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ref.read(partySessionProvider.notifier).sendChat(text);
    _chatController.clear();
  }
}

// ── Peer connection indicators (top-right) ──

class _PeerIndicators extends StatelessWidget {
  const _PeerIndicators({required this.session});

  final PartySessionState session;

  @override
  Widget build(BuildContext context) {
    final room = session.room;
    if (room == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: KumoriyaColors.playerControlBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups, color: KumoriyaColors.textPrimary, size: 16),
          const SizedBox(width: 4),
          Text(
            '${session.connectedPeerIds.length + 1}/${room.maxMembers}',
            style: const TextStyle(
              color: KumoriyaColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating reaction bubbles ──

class _ReactionBubbles extends StatelessWidget {
  const _ReactionBubbles({required this.reactions});

  final List<PartyReaction> reactions;

  @override
  Widget build(BuildContext context) {
    // Show last 5 reactions as floating bubbles.
    final recent = reactions.length > 5
        ? reactions.sublist(reactions.length - 5)
        : reactions;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (int i = 0; i < recent.length; i++)
              _AnimatedReaction(
                key: ValueKey(recent[i].timestamp),
                reaction: recent[i],
                index: i,
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedReaction extends StatefulWidget {
  const _AnimatedReaction({
    super.key,
    required this.reaction,
    required this.index,
  });

  final PartyReaction reaction;
  final int index;

  @override
  State<_AnimatedReaction> createState() => _AnimatedReactionState();
}

class _AnimatedReactionState extends State<_AnimatedReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    final startX = 0.7 + (widget.index * 0.06);
    _position = Tween<Offset>(
      begin: Offset(startX, 0.8),
      end: Offset(startX - 0.1, 0.3),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        return Positioned(
          left: _position.value.dx * size.width,
          top: _position.value.dy * size.height,
          child: Opacity(
            opacity: _opacity.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.reaction.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                Text(
                  widget.reaction.senderName,
                  style: const TextStyle(
                    color: KumoriyaColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
