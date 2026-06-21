import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Corner badge for cards — backdrop blur, mono font.
///
/// Positioned at top-left of a [Stack] or image overlay.
class CloudBadge extends StatelessWidget {
  const CloudBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(CloudRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: CloudSpacing.s3,
            vertical: CloudSpacing.s1,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(CloudRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, size: 12, color: colors.text),
                SizedBox(width: CloudSpacing.s1),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
