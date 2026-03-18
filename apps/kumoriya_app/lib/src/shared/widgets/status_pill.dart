import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
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
        'AIRING',
      ),
      AnimeStatus.notYetReleased => (
        KumoriyaColors.borderSubtle,
        KumoriyaColors.textMuted,
        'UPCOMING',
      ),
      AnimeStatus.finished => (
        KumoriyaColors.statusSuccess.withValues(alpha: 0.12),
        KumoriyaColors.statusSuccess,
        'FINISHED',
      ),
      AnimeStatus.cancelled => (
        KumoriyaColors.statusDanger.withValues(alpha: 0.12),
        KumoriyaColors.statusDanger,
        'CANCELLED',
      ),
      AnimeStatus.hiatus => (
        KumoriyaColors.statusWarning.withValues(alpha: 0.12),
        KumoriyaColors.statusWarning,
        'ON HIATUS',
      ),
      AnimeStatus.unknown || _ => (
        KumoriyaColors.borderSubtle,
        KumoriyaColors.textDisabled,
        'UNKNOWN',
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
