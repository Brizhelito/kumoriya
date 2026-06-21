import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Cloud-styled pill chip for status, tags, and metadata.
class CloudChip extends StatelessWidget {
  const CloudChip({
    super.key,
    required this.label,
    this.icon,
    this.variant = CloudChipVariant.tag,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final CloudChipVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final bgColor = _resolveBg(colors);
    final fgColor = _resolveFg(colors);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: CloudSpacing.s3,
          vertical: CloudSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(CloudRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...[
              Icon(icon, size: 14, color: fgColor),
              SizedBox(width: CloudSpacing.s1),
            ],
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveBg(CloudColors colors) {
    return switch (variant) {
      CloudChipVariant.tag => colors.surface2,
      CloudChipVariant.airing => colors.success,
      CloudChipVariant.finished => colors.textSoft,
      CloudChipVariant.upcoming => colors.warning,
      CloudChipVariant.rating => colors.accentSoft,
    };
  }

  Color _resolveFg(CloudColors colors) {
    return switch (variant) {
      CloudChipVariant.tag => colors.text,
      CloudChipVariant.airing => const Color(0xFFFFFFFF),
      CloudChipVariant.finished => const Color(0xFFFFFFFF),
      CloudChipVariant.upcoming => const Color(0xFFFFFFFF),
      CloudChipVariant.rating => colors.text,
    };
  }
}

enum CloudChipVariant { tag, airing, finished, upcoming, rating }
