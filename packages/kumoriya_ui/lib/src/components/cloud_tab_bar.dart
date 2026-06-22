import 'package:flutter/material.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_motion.dart';
import '../tokens/cloud_radius.dart';
import '../tokens/cloud_spacing.dart';

/// Cloud-styled segmented tab bar with ink-wash underline animation.
///
/// Used for Library tabs (Watchlist | Downloads | History),
/// Search filters, and any segmented selection.
class CloudTabBar extends StatefulWidget {
  const CloudTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
  });

  /// Tab labels.
  final List<String> tabs;

  /// Currently selected tab index.
  final int currentIndex;

  /// Called when a tab is tapped.
  final ValueChanged<int> onChanged;

  @override
  State<CloudTabBar> createState() => _CloudTabBarState();
}

class _CloudTabBarState extends State<CloudTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: CloudMotion.base);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: CloudMotion.easeCloud,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CloudTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    final factor = FormFactorProvider.formFactorOf(context);

    return Container(
      padding: EdgeInsets.all(CloudSpacing.s1),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CloudRadius.pill),
        boxShadow: colors.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < widget.tabs.length; i++)
            _CloudTab(
              label: widget.tabs[i],
              isActive: i == widget.currentIndex,
              colors: colors,
              isDesktop: factor.isDesktop,
              onTap: () => widget.onChanged(i),
              showInkUnderline: i == widget.currentIndex,
              animation: _animation,
            ),
        ],
      ),
    );
  }
}

class _CloudTab extends StatelessWidget {
  const _CloudTab({
    required this.label,
    required this.isActive,
    required this.colors,
    required this.isDesktop,
    required this.onTap,
    required this.showInkUnderline,
    required this.animation,
  });

  final String label;
  final bool isActive;
  final CloudColors colors;
  final bool isDesktop;
  final VoidCallback onTap;
  final bool showInkUnderline;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: isDesktop ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CloudMotion.fast,
          curve: CloudMotion.easeCloud,
          padding: EdgeInsets.symmetric(
            horizontal: CloudSpacing.s4,
            vertical: CloudSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: isActive ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(CloudRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: isActive ? colors.text : colors.textMuted,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.02,
                ),
              ),
              if (showInkUnderline)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Container(
                      margin: EdgeInsets.only(top: 2),
                      height: 3,
                      width: 24 * animation.value,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
