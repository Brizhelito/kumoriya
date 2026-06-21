import 'package:flutter/material.dart';

import '../platform/form_factor.dart';
import '../platform/form_factor_provider.dart';
import 'cloud_bottom_nav.dart';
import 'cloud_sidebar.dart';

/// Navigation shell that adapts to form factor.
///
/// Renders [CloudBottomNav] for mobile/tablet and [CloudSidebar] for desktop.
/// Manages per-tab navigators with offstage lazy loading.
class CloudNavShell extends StatefulWidget {
  const CloudNavShell({
    super.key,
    required this.animeTabBuilders,
    this.mangaTabBuilders,
    this.brandName = 'Kumoriya',
  });

  /// Tab builders for the anime universe.
  final Map<String, WidgetBuilder> animeTabBuilders;

  /// Tab builders for the manga universe (optional).
  final Map<String, WidgetBuilder>? mangaTabBuilders;

  final String brandName;

  @override
  State<CloudNavShell> createState() => _CloudNavShellState();
}

class _CloudNavShellState extends State<CloudNavShell> {
  int _currentIndex = 0;
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {};

  @override
  Widget build(BuildContext context) {
    final factor = FormFactorProvider.formFactorOf(context);
    final tabs = widget.animeTabBuilders.keys.toList();

    // Ensure navigator keys exist for all tabs.
    for (var i = 0; i < tabs.length; i++) {
      _navigatorKeys.putIfAbsent(i, () => GlobalKey<NavigatorState>());
    }

    final body = IndexedStack(
      index: _currentIndex,
      children: <Widget>[
        for (var i = 0; i < tabs.length; i++)
          Navigator(
            key: _navigatorKeys[i],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (ctx) => widget.animeTabBuilders[tabs[i]]!(ctx),
            ),
          ),
      ],
    );

    if (factor.isDesktop) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            CloudSidebar(
              items: <SidebarItem>[
                for (final tab in tabs)
                  SidebarItem(
                    icon: _defaultIconFor(tab),
                    activeIcon: _defaultActiveIconFor(tab),
                    label: _capitalize(tab),
                  ),
              ],
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              brandName: widget.brandName,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Mobile + tablet: bottom nav overlay.
    return Scaffold(
      body: Stack(
        children: <Widget>[
          body,
          CloudBottomNav(
            items: <BottomNavItem>[
              for (final tab in tabs)
                BottomNavItem(
                  icon: _defaultIconFor(tab),
                  activeIcon: _defaultActiveIconFor(tab),
                  label: _capitalize(tab),
                ),
            ],
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index]?.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _currentIndex = index);
  }

  static IconData _defaultIconFor(String tab) {
    return switch (tab) {
      'home' => Icons.home_outlined,
      'search' => Icons.search_rounded,
      'party' => Icons.groups_outlined,
      'library' => Icons.bookmark_outline_rounded,
      'profile' => Icons.person_outline_rounded,
      _ => Icons.circle_outlined,
    };
  }

  static IconData _defaultActiveIconFor(String tab) {
    return switch (tab) {
      'home' => Icons.home_rounded,
      'search' => Icons.search_rounded,
      'party' => Icons.groups_rounded,
      'library' => Icons.bookmark_rounded,
      'profile' => Icons.person_rounded,
      _ => Icons.circle_rounded,
    };
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
}
