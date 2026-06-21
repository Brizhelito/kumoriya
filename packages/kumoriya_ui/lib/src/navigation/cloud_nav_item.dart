import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Shared nav item spec used by both bottom nav and sidebar.
class CloudNavItem extends StatelessWidget {
  const CloudNavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);

    return MouseRegion(
      cursor: factor.isDesktop
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CloudMotion.fast,
          curve: CloudMotion.easeCloud,
          decoration: BoxDecoration(
            color: isActive ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(
              compact ? CloudRadius.sm : CloudRadius.pill,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? CloudSpacing.s3 : CloudSpacing.s4,
            vertical: compact ? CloudSpacing.s2 : CloudSpacing.s2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? colors.text : colors.textSoft,
                size: compact ? 20 : 22,
              ),
              if (!compact) ...[
                SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? colors.text : colors.textSoft,
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
