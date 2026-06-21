import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Status pill for anime status (airing, finished, upcoming, etc.).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final CloudAnimeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final bgColor = _resolveBg(colors);
    final fgColor = _resolveFg(colors);
    final label = _resolveLabel();

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
        label,
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
      CloudAnimeStatus.airing => colors.primary.withValues(alpha: 0.14),
      CloudAnimeStatus.finished => colors.success.withValues(alpha: 0.12),
      CloudAnimeStatus.upcoming => colors.surface2,
      CloudAnimeStatus.cancelled => colors.error.withValues(alpha: 0.12),
      CloudAnimeStatus.hiatus => colors.warning.withValues(alpha: 0.12),
    };
  }

  Color _resolveFg(CloudColors colors) {
    return switch (status) {
      CloudAnimeStatus.airing => colors.primary,
      CloudAnimeStatus.finished => colors.success,
      CloudAnimeStatus.upcoming => colors.textMuted,
      CloudAnimeStatus.cancelled => colors.error,
      CloudAnimeStatus.hiatus => colors.warning,
    };
  }

  String _resolveLabel() {
    return switch (status) {
      CloudAnimeStatus.airing => 'AIRING',
      CloudAnimeStatus.finished => 'FINISHED',
      CloudAnimeStatus.upcoming => 'UPCOMING',
      CloudAnimeStatus.cancelled => 'CANCELLED',
      CloudAnimeStatus.hiatus => 'ON HIATUS',
    };
  }
}

enum CloudAnimeStatus { airing, finished, upcoming, cancelled, hiatus }
