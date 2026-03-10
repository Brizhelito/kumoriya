import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/kumoriya_theme.dart';

enum KumoriyaTab { home, search, calendar, myList }

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key, required this.tabBuilders});

  final Map<KumoriyaTab, WidgetBuilder> tabBuilders;

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  KumoriyaTab _currentTab = KumoriyaTab.home;

  final Map<KumoriyaTab, GlobalKey<NavigatorState>> _navigatorKeys = {
    KumoriyaTab.home: GlobalKey<NavigatorState>(),
    KumoriyaTab.search: GlobalKey<NavigatorState>(),
    KumoriyaTab.calendar: GlobalKey<NavigatorState>(),
    KumoriyaTab.myList: GlobalKey<NavigatorState>(),
  };

  static bool get _isDesktop {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  void _onTabSelected(int index) {
    final tab = KumoriyaTab.values[index];
    if (tab == _currentTab) {
      _navigatorKeys[tab]?.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _currentTab = tab);
  }

  Future<bool> _handlePopScope() async {
    final nav = _navigatorKeys[_currentTab]?.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_currentTab != KumoriyaTab.home) {
      setState(() => _currentTab = KumoriyaTab.home);
      return false;
    }
    return true;
  }

  Widget _buildTabNavigator(KumoriyaTab tab) {
    return Navigator(
      key: _navigatorKeys[tab],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: widget.tabBuilders[tab]!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentTab.index;

    final body = IndexedStack(
      index: currentIndex,
      children: KumoriyaTab.values
          .map((tab) => _buildTabNavigator(tab))
          .toList(growable: false),
    );

    if (_isDesktop) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await _handlePopScope();
        },
        child: Scaffold(
          backgroundColor: KumoriyaColors.background,
          body: Row(
            children: <Widget>[
              _DesktopRail(currentIndex: currentIndex, onTap: _onTabSelected),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handlePopScope();
      },
      child: Scaffold(
        backgroundColor: KumoriyaColors.background,
        body: body,
        bottomNavigationBar: _MobileBottomNav(
          currentIndex: currentIndex,
          onTap: _onTabSelected,
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KumoriyaColors.borderSubtle)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: KumoriyaColors.navBackground,
        selectedItemColor: KumoriyaColors.primary,
        unselectedItemColor: KumoriyaColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        iconSize: 22,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            activeIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline_rounded),
            activeIcon: Icon(Icons.bookmark_rounded),
            label: 'My List',
          ),
        ],
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: KumoriyaColors.navBackground,
        border: Border(right: BorderSide(color: KumoriyaColors.borderSubtle)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 28),
          _KumoriyaLogoMark(),
          const SizedBox(height: 16),
          const Divider(
            indent: 16,
            endIndent: 16,
            color: KumoriyaColors.borderSubtle,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: <_RailItem>[
                  _RailItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    index: 0,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.search_rounded,
                    activeIcon: Icons.search_rounded,
                    label: 'Search',
                    index: 1,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.calendar_month_outlined,
                    activeIcon: Icons.calendar_month_rounded,
                    label: 'Calendar',
                    index: 2,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.bookmark_outline_rounded,
                    activeIcon: Icons.bookmark_rounded,
                    label: 'My List',
                    index: 3,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _KumoriyaLogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: KumoriyaColors.primary,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: KumoriyaColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'K',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive
        ? KumoriyaColors.primary
        : KumoriyaColors.textDisabled;

    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          width: 88,
          height: 56,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? KumoriyaColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(isActive ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
