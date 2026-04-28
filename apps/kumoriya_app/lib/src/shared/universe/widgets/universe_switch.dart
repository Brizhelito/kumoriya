import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../../../app/l10n.dart';
import '../../theme/kumoriya_theme.dart';
import '../active_universe_providers.dart';

/// Two-segment pill that toggles the active universe between
/// [MediaKind.anime] and [MediaKind.manga].
///
/// Reads and writes the [activeUniverseProvider] directly. The widget is
/// intentionally compact so it can sit at the top of a Home page header
/// without taking visual precedence over the page's primary content.
class UniverseSwitch extends ConsumerWidget {
  const UniverseSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeUniverseProvider);
    final notifier = ref.read(activeUniverseProvider.notifier);

    return Semantics(
      container: true,
      label: context.l10n.universeSwitchLabel,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: KumoriyaColors.surface,
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          border: Border.all(color: KumoriyaColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Segment(
              label: context.l10n.universeAnime,
              icon: Icons.movie_outlined,
              activeIcon: Icons.movie_rounded,
              selected: active == MediaKind.anime,
              onTap: () => notifier.set(MediaKind.anime),
            ),
            _Segment(
              label: context.l10n.universeManga,
              icon: Icons.menu_book_outlined,
              activeIcon: Icons.menu_book_rounded,
              selected: active == MediaKind.manga,
              onTap: () => notifier.set(MediaKind.manga),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fg = selected ? KumoriyaColors.textPrimary : KumoriyaColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(KumoriyaRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(KumoriyaRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(selected ? activeIcon : icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
