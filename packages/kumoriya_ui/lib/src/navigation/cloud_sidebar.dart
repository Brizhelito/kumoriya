import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';
import 'cloud_nav_item.dart';

/// Collapsible sidebar for desktop — 220px expanded / 72px collapsed.
class CloudSidebar extends StatefulWidget {
  const CloudSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.brandName = 'Kumoriya',
    this.onSettingsTap,
  });

  final List<SidebarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String brandName;
  final VoidCallback? onSettingsTap;

  @override
  State<CloudSidebar> createState() => _CloudSidebarState();
}

class _CloudSidebarState extends State<CloudSidebar> {
  bool _collapsed = false;

  void _toggle() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final width = _collapsed ? 72.0 : 220.0;

    return AnimatedContainer(
      duration: CloudMotion.base,
      curve: CloudMotion.easeCloud,
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.surface2)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: CloudSpacing.s3,
        vertical: CloudSpacing.s5,
      ),
      child: Column(
        children: <Widget>[
          // Brand
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'K',
                  style: TextStyle(
                    color: colors.isDark ? colors.bg : const Color(0xFFFFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!_collapsed) ...[
                SizedBox(width: CloudSpacing.s2),
                Expanded(
                  child: Text(
                    widget.brandName,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: CloudSpacing.s5),
          // Collapse toggle
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(CloudRadius.sm),
              ),
              child: Icon(
                _collapsed
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: colors.textMuted,
                size: 18,
              ),
            ),
          ),
          SizedBox(height: CloudSpacing.s4),
          // Nav items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (var i = 0; i < widget.items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: CloudSpacing.s1),
                    child: CloudNavItem(
                      icon: widget.items[i].icon,
                      activeIcon: widget.items[i].activeIcon,
                      label: widget.items[i].label,
                      isActive: i == widget.currentIndex,
                      onTap: () => widget.onTap(i),
                      compact: _collapsed,
                    ),
                  ),
              ],
            ),
          ),
          // Settings
          if (widget.onSettingsTap != null)
            CloudNavItem(
              icon: Icons.settings_rounded,
              activeIcon: Icons.settings_rounded,
              label: 'Settings',
              isActive: false,
              onTap: widget.onSettingsTap!,
              compact: _collapsed,
            ),
        ],
      ),
    );
  }
}

/// Spec for a sidebar item.
class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
