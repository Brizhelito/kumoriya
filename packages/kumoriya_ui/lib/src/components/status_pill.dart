import 'package:flutter/widgets.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Status pill for anime status (releasing, finished, upcoming, etc.).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label});

  final AnimeStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final bgColor = _resolveBg(colors);
    final fgColor = _resolveFg(colors);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: CloudSpacing.s2 + 1,
        vertical: CloudSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
      ),
      child: Text(
        label ?? _defaultLabel(),
        style: TextStyle(
          color: fgColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Color _resolveBg(CloudColors colors) {
    return switch (status) {
      AnimeStatus.releasing => colors.primary.withValues(alpha: 0.14),
      AnimeStatus.finished => colors.success.withValues(alpha: 0.12),
      AnimeStatus.notYetReleased => colors.surface2,
      AnimeStatus.cancelled => colors.error.withValues(alpha: 0.12),
      AnimeStatus.hiatus => colors.warning.withValues(alpha: 0.12),
      AnimeStatus.unknown => colors.surface2,
    };
  }

  Color _resolveFg(CloudColors colors) {
    return switch (status) {
      AnimeStatus.releasing => colors.primary,
      AnimeStatus.finished => colors.success,
      AnimeStatus.notYetReleased => colors.textMuted,
      AnimeStatus.cancelled => colors.error,
      AnimeStatus.hiatus => colors.warning,
      AnimeStatus.unknown => colors.textMuted,
    };
  }

  String _defaultLabel() {
    return switch (status) {
      AnimeStatus.releasing => 'AIRING',
      AnimeStatus.finished => 'FINISHED',
      AnimeStatus.notYetReleased => 'UPCOMING',
      AnimeStatus.cancelled => 'CANCELLED',
      AnimeStatus.hiatus => 'ON HIATUS',
      AnimeStatus.unknown => 'UNKNOWN',
    };
  }
}
