import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';

class KumoriyaStatusPill extends StatelessWidget {
  const KumoriyaStatusPill({super.key, required this.status});

  final AnimeStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text, String label) = switch (status) {
      AnimeStatus.releasing => (
        KumoriyaColors.primary.withValues(alpha: 0.14),
        KumoriyaColors.primaryLight,
        context.l10n.statusAiring,
      ),
      AnimeStatus.notYetReleased => (
        KumoriyaColors.borderSubtle,
        KumoriyaColors.textMuted,
        context.l10n.statusUpcoming,
      ),
      AnimeStatus.finished => (
        KumoriyaColors.statusSuccess.withValues(alpha: 0.12),
        KumoriyaColors.statusSuccess,
        context.l10n.statusFinished,
      ),
      AnimeStatus.cancelled => (
        KumoriyaColors.statusDanger.withValues(alpha: 0.12),
        KumoriyaColors.statusDanger,
        context.l10n.statusCancelled,
      ),
      AnimeStatus.hiatus => (
        KumoriyaColors.statusWarning.withValues(alpha: 0.12),
        KumoriyaColors.statusWarning,
        context.l10n.statusOnHiatus,
      ),
      AnimeStatus.unknown || _ => (
        KumoriyaColors.borderSubtle,
        KumoriyaColors.textDisabled,
        context.l10n.statusUnknown,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
