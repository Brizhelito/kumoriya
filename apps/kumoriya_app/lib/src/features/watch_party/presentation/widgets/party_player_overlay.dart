import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../application/party_session_guard.dart';
import '../../application/providers/party_providers.dart';
import '../../application/models/models.dart';

// ── Tunables ──────────────────────────────────────────────────────────────
const List<String> _kPartyEmojis = [
  '❤️',
  '😂',
  '😮',
  '👏',
  '🔥',
  '😢',
  '💀',
  '🎉',
];
const double _kWheelRadius = 108; // distance from center to slot centers
const double _kSlotRadius = 30;
const double _kWheelOuterPad = 18; // backdrop padding around wheel
const double _kDeadzoneRadius = 42;
const double _kButtonSize = 56;

/// Overlay placed on top of the player when in a watch party.
///
/// Provides:
/// - Top-right peer indicator.
/// - A draggable floating trigger button (double-tap to enter reposition mode).
/// - A Wild Rift-style radial emoji wheel opened by pressing-and-dragging the
///   button. Release on a slot to send, release in the center/outside to
///   cancel. Works on Android (touch + haptics) and Windows (mouse).
/// - Floating reaction bubbles with an improved arc-path animation.
class PartyPlayerOverlay extends ConsumerStatefulWidget {
  const PartyPlayerOverlay({super.key});

  @override
  ConsumerState<PartyPlayerOverlay> createState() => _PartyPlayerOverlayState();
}

class _PartyPlayerOverlayState extends ConsumerState<PartyPlayerOverlay> {
  Offset? _buttonPosition; // null → default bottom-right
  bool _editMode = false;
  Timer? _editTimer;

  // Wheel state
  bool _wheelOpen = false;
  Offset _wheelCenter = Offset.zero;
  Offset _fingerPos = Offset.zero;
  int? _hoveredSlot;

  @override
  void dispose() {
    _editTimer?.cancel();
    super.dispose();
  }

  void _enterEditMode() {
    _editTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _editMode = true);
    _editTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _editMode = false);
    });
  }

  void _bumpEditTimer() {
    _editTimer?.cancel();
    _editTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _editMode = false);
    });
  }

  void _openWheel(Offset globalPos, Size overlaySize) {
    const pad = _kWheelRadius + _kSlotRadius + _kWheelOuterPad;
    final cx = globalPos.dx.clamp(pad, overlaySize.width - pad);
    final cy = globalPos.dy.clamp(pad, overlaySize.height - pad);
    HapticFeedback.mediumImpact();
    setState(() {
      _wheelOpen = true;
      _wheelCenter = Offset(cx.toDouble(), cy.toDouble());
      _fingerPos = globalPos;
      _hoveredSlot = null;
    });
  }

  void _updateWheel(Offset globalPos) {
    final delta = globalPos - _wheelCenter;
    int? next;
    if (delta.distance >= _kDeadzoneRadius) {
      final angle = math.atan2(delta.dy, delta.dx);
      const twoPi = 2 * math.pi;
      // Slot 0 at top (angle -pi/2). Add pi/2, normalise to [0, 2π).
      final normalized = ((angle + math.pi / 2) % twoPi + twoPi) % twoPi;
      next =
          (normalized / (twoPi / _kPartyEmojis.length)).floor() %
          _kPartyEmojis.length;
    }
    if (next != _hoveredSlot) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _fingerPos = globalPos;
      _hoveredSlot = next;
    });
  }

  void _closeWheel({required bool commit}) {
    final slot = _hoveredSlot;
    final sending = commit && slot != null;
    if (sending) {
      HapticFeedback.heavyImpact();
      ref.read(partySessionProvider.notifier).sendReaction(_kPartyEmojis[slot]);
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _wheelOpen = false;
      _hoveredSlot = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(
      partySessionProvider.select((session) => session.isActive),
    );
    if (!isActive) return const SizedBox.shrink();
    final reactions = ref.watch(
      partySessionProvider.select((session) => session.reactions),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final defaultPos = Offset(
          overlaySize.width - _kButtonSize - 24,
          overlaySize.height - _kButtonSize - 120,
        );
        final rawPos = _buttonPosition ?? defaultPos;
        final buttonPos = Offset(
          rawPos.dx.clamp(
            8.0,
            math.max(8.0, overlaySize.width - _kButtonSize - 8),
          ),
          rawPos.dy.clamp(
            8.0,
            math.max(8.0, overlaySize.height - _kButtonSize - 8),
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _ReactionBubbles(reactions: reactions),
                ),
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: RepaintBoundary(child: _PartyPlayerHud()),
            ),
            Positioned(
              left: buttonPos.dx,
              top: buttonPos.dy,
              child: _FloatingReactionButton(
                editMode: _editMode,
                dimmed: _wheelOpen,
                onDoubleTap: _enterEditMode,
                onPanStart: (pos) {
                  if (_editMode) {
                    _bumpEditTimer();
                    return;
                  }
                  _openWheel(pos, overlaySize);
                },
                onPanUpdate: (globalPos, delta) {
                  if (_editMode) {
                    setState(() {
                      _buttonPosition = Offset(
                        (buttonPos.dx + delta.dx).clamp(
                          8.0,
                          math.max(8.0, overlaySize.width - _kButtonSize - 8),
                        ),
                        (buttonPos.dy + delta.dy).clamp(
                          8.0,
                          math.max(8.0, overlaySize.height - _kButtonSize - 8),
                        ),
                      );
                    });
                    return;
                  }
                  if (_wheelOpen) _updateWheel(globalPos);
                },
                onPanEnd: () {
                  if (_editMode) {
                    _bumpEditTimer();
                    return;
                  }
                  if (_wheelOpen) _closeWheel(commit: true);
                },
                onPanCancel: () {
                  if (_wheelOpen) _closeWheel(commit: false);
                },
              ),
            ),
            if (_wheelOpen)
              Positioned.fill(
                child: IgnorePointer(
                  child: _ReactionWheel(
                    center: _wheelCenter,
                    finger: _fingerPos,
                    hoveredSlot: _hoveredSlot,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Floating draggable trigger button ─────────────────────────────────────

class _FloatingReactionButton extends StatefulWidget {
  const _FloatingReactionButton({
    required this.editMode,
    required this.dimmed,
    required this.onDoubleTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  final bool editMode;
  final bool dimmed;
  final VoidCallback onDoubleTap;
  final void Function(Offset globalPos) onPanStart;
  final void Function(Offset globalPos, Offset delta) onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onPanCancel;

  @override
  State<_FloatingReactionButton> createState() =>
      _FloatingReactionButtonState();
}

class _FloatingReactionButtonState extends State<_FloatingReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTap,
      onPanStart: (d) => widget.onPanStart(d.globalPosition),
      onPanUpdate: (d) => widget.onPanUpdate(d.globalPosition, d.delta),
      onPanEnd: (_) => widget.onPanEnd(),
      onPanCancel: widget.onPanCancel,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulseT = widget.editMode
              ? Curves.easeInOut.transform(_pulse.value)
              : 0.0;
          final ringOpacity = widget.editMode ? 0.4 + pulseT * 0.4 : 0.0;
          final ringScale = 1.0 + pulseT * 0.18;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: widget.dimmed ? 0.25 : 1.0,
            child: SizedBox(
              width: _kButtonSize,
              height: _kButtonSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.editMode)
                    Transform.scale(
                      scale: ringScale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: KumoriyaColors.primaryLight.withValues(
                              alpha: ringOpacity,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: KumoriyaColors.primary.withValues(
                                alpha: 0.35 * ringOpacity,
                              ),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    width: _kButtonSize - 6,
                    height: _kButtonSize - 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          KumoriyaColors.primaryLight,
                          KumoriyaColors.primary,
                          KumoriyaColors.primaryDark,
                        ],
                        stops: [0, 0.6, 1],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: KumoriyaColors.primary.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.editMode
                            ? Icons.open_with_rounded
                            : Icons.emoji_emotions_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
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

// ── Radial reaction wheel ─────────────────────────────────────────────────

class _ReactionWheel extends StatefulWidget {
  const _ReactionWheel({
    required this.center,
    required this.finger,
    required this.hoveredSlot,
  });

  final Offset center;
  final Offset finger;
  final int? hoveredSlot;

  @override
  State<_ReactionWheel> createState() => _ReactionWheelState();
}

class _ReactionWheelState extends State<_ReactionWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_intro.value.clamp(0.0, 1.0));
        final scale = 0.4 + 0.6 * t;
        final opacity = _intro.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: CustomPaint(
            painter: _WheelPainter(
              center: widget.center,
              finger: widget.finger,
              hoveredSlot: widget.hoveredSlot,
              scale: scale,
              introT: _intro.value.clamp(0.0, 1.0),
            ),
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.center,
    required this.finger,
    required this.hoveredSlot,
    required this.scale,
    required this.introT,
  });

  final Offset center;
  final Offset finger;
  final int? hoveredSlot;
  final double scale;
  final double introT;

  @override
  void paint(Canvas canvas, Size size) {
    final outerR = (_kWheelRadius + _kSlotRadius + _kWheelOuterPad) * scale;

    // 1. Scrim behind the wheel (radial fade).
    final scrimPaint = Paint()
      ..shader = ui.Gradient.radial(center, outerR * 1.6, [
        Colors.black.withValues(alpha: 0.55 * introT),
        Colors.black.withValues(alpha: 0),
      ]);
    canvas.drawRect(Offset.zero & size, scrimPaint);

    // 2. Outer backdrop disk.
    canvas.drawCircle(
      center,
      outerR,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          center - Offset(0, outerR),
          center + Offset(0, outerR),
          [
            KumoriyaColors.primaryLight.withValues(alpha: 0.55),
            KumoriyaColors.primary.withValues(alpha: 0.15),
          ],
        ),
    );

    // 3. Deadzone center disk.
    final inDeadzone = hoveredSlot == null;
    final deadR = _kDeadzoneRadius * scale;
    canvas.drawCircle(
      center,
      deadR,
      Paint()
        ..color =
            (inDeadzone ? KumoriyaColors.statusDanger : KumoriyaColors.primary)
                .withValues(alpha: inDeadzone ? 0.22 : 0.12),
    );
    canvas.drawCircle(
      center,
      deadR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (inDeadzone ? KumoriyaColors.statusDanger : Colors.white)
            .withValues(alpha: inDeadzone ? 0.7 : 0.25),
    );
    // Cancel icon (X) if inside deadzone.
    if (inDeadzone) {
      final iconPaint = Paint()
        ..color = KumoriyaColors.statusDanger.withValues(alpha: 0.9)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final k = deadR * 0.35;
      canvas.drawLine(
        center + Offset(-k, -k),
        center + Offset(k, k),
        iconPaint,
      );
      canvas.drawLine(
        center + Offset(k, -k),
        center + Offset(-k, k),
        iconPaint,
      );
    }

    // 4. Finger trail line from center toward finger (subtle guide).
    if (!inDeadzone) {
      final dir = finger - center;
      final unit = dir / dir.distance;
      final from = center + unit * deadR;
      final to = center + unit * (_kWheelRadius * scale);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = KumoriyaColors.primaryLight.withValues(alpha: 0.45)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // 5. Slots.
    final slotCount = _kPartyEmojis.length;
    for (var i = 0; i < slotCount; i++) {
      final angle = -math.pi / 2 + (2 * math.pi / slotCount) * i;
      final slotCenter =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (_kWheelRadius * scale);
      final hovered = i == hoveredSlot;
      final slotR = _kSlotRadius * scale * (hovered ? 1.22 : 1.0);

      // Glow ring when hovered.
      if (hovered) {
        canvas.drawCircle(
          slotCenter,
          slotR + 10,
          Paint()
            ..color = KumoriyaColors.primary.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      // Slot bg.
      final bgPaint = Paint();
      if (hovered) {
        bgPaint.shader = ui.Gradient.radial(slotCenter, slotR, [
          KumoriyaColors.primaryLight,
          KumoriyaColors.primaryDark,
        ]);
      } else {
        bgPaint.color = Colors.white.withValues(alpha: 0.06);
      }
      canvas.drawCircle(slotCenter, slotR, bgPaint);
      // Slot border.
      canvas.drawCircle(
        slotCenter,
        slotR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hovered ? 2.0 : 1.0
          ..color = (hovered ? Colors.white : KumoriyaColors.textPrimary)
              .withValues(alpha: hovered ? 0.9 : 0.18),
      );

      // Emoji glyph.
      final tp = TextPainter(
        text: TextSpan(
          text: _kPartyEmojis[i],
          style: TextStyle(fontSize: 26 * scale * (hovered ? 1.18 : 1.0)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, slotCenter - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.center != center ||
      old.finger != finger ||
      old.hoveredSlot != hoveredSlot ||
      old.scale != scale ||
      old.introT != introT;
}

// ── Expandable peer HUD (top-right) ──

class _PartyPlayerHud extends ConsumerStatefulWidget {
  const _PartyPlayerHud();

  @override
  ConsumerState<_PartyPlayerHud> createState() => _PartyPlayerHudState();
}

class _PartyPlayerHudState extends ConsumerState<_PartyPlayerHud> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(partySessionProvider);
    final room = session.room;
    if (room == null) return const SizedBox.shrink();
    final localUserId = ref.read(partySessionProvider.notifier).localUserId;
    final connectedCount = partyConnectedMemberCount(
      session,
      localUserId: localUserId,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Trigger pill (always visible)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KumoriyaColors.playerControlBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$connectedCount/${room.maxMembers}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 2),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        // Expanded panel
        if (_expanded)
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: KumoriyaColors.playerControlBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final member in room.members) ...[
                      if (member != room.members.first)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Divider(height: 1, color: Colors.white12),
                        ),
                      _MemberRow(
                        member: member,
                        isConnected: session.connectedPeerIds.contains(
                          member.userId,
                        ),
                        isReady: session.readyStates[member.userId] ?? false,
                        isSelf: member.userId == localUserId,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isConnected,
    required this.isReady,
    required this.isSelf,
  });

  final PartyMember member;
  final bool isConnected;
  final bool isReady;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: KumoriyaColors.primaryContainer,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isSelf ? '${member.displayName} (You)' : member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 12,
            color: isReady ? Colors.green : Colors.white38,
          ),
          const SizedBox(width: 4),
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            size: 12,
            color: isConnected ? Colors.green : Colors.white24,
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

    return Stack(
      children: [
        for (int i = 0; i < recent.length; i++)
          _AnimatedReaction(
            key: ValueKey(recent[i].timestamp),
            reaction: recent[i],
            index: i,
          ),
      ],
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
  late final double _seed; // deterministic per reaction
  late final double _startX; // 0..1 of overlay width
  late final double _swayAmp; // horizontal sway amplitude
  late final double _tilt; // base rotation in radians
  late final double _swaySign;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    // Seed from timestamp so a given reaction always renders identically.
    final hash = widget.reaction.timestamp.microsecondsSinceEpoch;
    _seed = ((hash & 0xFFFF) / 0xFFFF); // 0..1
    // Stagger horizontally across the lower band, biased right of center.
    _startX = 0.55 + _seed * 0.35 + (widget.index % 3) * 0.03;
    _swayAmp = 0.025 + _seed * 0.035;
    _swaySign = (hash & 1) == 0 ? 1.0 : -1.0;
    _tilt = (_seed - 0.5) * 0.18; // ±~0.09 rad
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
        final t = _controller.value;

        // Phase-based easing: pop in, float up, fade out.
        final entry = Curves.elasticOut.transform(t.clamp(0.0, 0.35) / 0.35);
        final float = Curves.easeOutCubic.transform(t);
        final fade = t < 0.65
            ? 1.0
            : (1.0 - ((t - 0.65) / 0.35)).clamp(0.0, 1.0);

        final scaleIn = 0.4 + 0.6 * entry.clamp(0.0, 1.0);
        final scalePulse = 1.0 + math.sin(t * math.pi) * 0.06;
        final scale = scaleIn * scalePulse;

        final riseY = 0.78 - 0.55 * float;
        final sway =
            math.sin(t * math.pi * 2 + _seed * math.pi * 2) *
            _swayAmp *
            _swaySign;
        final x = (_startX + sway).clamp(0.02, 0.95);

        return Positioned(
          left: x * size.width - 28,
          top: riseY * size.height,
          child: Opacity(
            opacity: fade,
            child: Transform.rotate(
              angle: _tilt + math.sin(t * math.pi * 3) * 0.04,
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.reaction.emoji,
                      style: TextStyle(
                        fontSize: 38,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          Shadow(
                            color: KumoriyaColors.primary.withValues(
                              alpha: 0.35 * fade,
                            ),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: KumoriyaColors.primaryLight.withValues(
                            alpha: 0.25,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.reaction.senderName,
                        style: const TextStyle(
                          color: KumoriyaColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
