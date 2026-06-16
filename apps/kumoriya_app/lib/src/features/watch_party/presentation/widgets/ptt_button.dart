import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/party_providers.dart';
import '../../application/providers/voice_providers.dart';

/// Push-to-Talk button. Minimalist, Discord-style.
///
/// Interaction:
///  - Mobile/Touch: long-press to speak, release to mute.
///  - Desktop/Windows/Linux/macOS: hold V to speak, release V to mute.
///  - First use: activates voice (requests mic permission) before speaking.
///
/// Visual states:
///  - Ready (no permission): mic_off icon — tap to activate voice.
///  - Ready (has permission, not speaking): mic_none icon.
///  - Speaking: red, pulsing glow, mic icon.
///  - Activating: circular progress.
///
/// On desktop platforms the visual button is hidden — only the "V" keyboard
/// shortcut is active. A tiny speaking indicator dot is still shown when
/// the user is broadcasting voice.
class PttButton extends ConsumerStatefulWidget {
  const PttButton({super.key, this.isOverlayMode = false});

  final bool isOverlayMode;

  /// Whether the current platform is a desktop OS (no touch PTT needed).
  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  ConsumerState<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends ConsumerState<PttButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;
  bool _isDimmed = false;
  bool _activating = false;
  Timer? _dimTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    HardwareKeyboard.instance.addHandler(_onKey);
    _resetDimTimer();
  }

  void _resetDimTimer() {
    if (!widget.isOverlayMode) return;
    setState(() => _isDimmed = false);
    _dimTimer?.cancel();
    if (!_pressed) {
      _dimTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _isDimmed = true);
      });
    }
  }

  bool _onKey(KeyEvent e) {
    if (e.logicalKey != LogicalKeyboardKey.keyV) return false;
    _resetDimTimer();
    if (e is KeyDownEvent && !_pressed) {
      _start();
      return true;
    }
    if (e is KeyUpEvent && _pressed) {
      _stop();
      return true;
    }
    return false;
  }

  Future<void> _start() async {
    _resetDimTimer();
    final voice = ref.read(voiceSessionProvider);

    // First use: activate voice lazily (requests permission + acquires mic).
    if (!voice.isInitialized) {
      if (_activating) return;
      final localUserId = ref.read(partySessionProvider.notifier).localUserId;
      if (localUserId == null) return;

      setState(() => _activating = true);
      final ok = await ref
          .read(voiceSessionProvider.notifier)
          .activate(localUserId);
      if (!mounted) return;
      setState(() => _activating = false);
      if (!ok) return; // permission denied or mic error
    }

    setState(() => _pressed = true);
    _pulse.repeat(reverse: true);
    HapticFeedback.mediumImpact();
    ref.read(voiceSessionProvider.notifier).setMicEnabled(true);
  }

  void _stop() {
    setState(() => _pressed = false);
    _pulse.stop();
    _pulse.reset();
    HapticFeedback.lightImpact();
    ref.read(voiceSessionProvider.notifier).setMicEnabled(false);
    _resetDimTimer();
  }

  @override
  void dispose() {
    _dimTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceSessionProvider);
    final active = _pressed && voice.hasPermission;
    final glow = active ? 0.25 + (_pulse.value) * 0.35 : 0.0;
    final desktop = PttButton.isDesktopPlatform;

    // On desktop: no tappable button — keyboard "V" handles everything.
    // Show a tiny glowing dot only when actively speaking so the user
    // gets visual confirmation without a full button chrome.
    if (desktop) {
      if (!active) return const SizedBox.shrink();
      return Tooltip(
        message: 'Speaking (release V to mute)',
        child: Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: glow),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onTapDown: (_) => _resetDimTimer(),
      child: AnimatedOpacity(
        opacity: _isDimmed ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final bgColor = active
                ? Colors.red.shade700.withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.12);

            final Widget icon;
            if (_activating) {
              icon = const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white60,
                ),
              );
            } else if (!voice.hasPermission) {
              icon = const Icon(Icons.mic_off, color: Colors.white60, size: 22);
            } else if (active) {
              icon = const Icon(Icons.mic, color: Colors.white, size: 22);
            } else {
              icon = const Icon(
                Icons.mic_none,
                color: Colors.white60,
                size: 22,
              );
            }

            return Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: glow),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: icon),
            );
          },
        ),
      ),
    );
  }
}
