import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';
import 'cloud_nav_item.dart';

/// Floating pill bottom nav for mobile + tablet.
class CloudBottomNav extends StatelessWidget {
  const CloudBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Positioned(
      left: CloudSpacing.s3,
      right: CloudSpacing.s3,
      bottom: CloudSpacing.s3 + MediaQuery.viewPaddingOf(context).bottom,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CloudRadius.pill),
          boxShadow: colors.shadow,
        ),
        padding: EdgeInsets.all(CloudSpacing.s2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            for (var i = 0; i < items.length; i++)
              Flexible(
                child: CloudNavItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: items[i].label,
                  isActive: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Spec for a bottom nav item.
class BottomNavItem {
  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
