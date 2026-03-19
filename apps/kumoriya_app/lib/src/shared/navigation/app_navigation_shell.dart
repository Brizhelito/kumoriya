import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/settings/presentation/pages/settings_page.dart';
import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';

enum KumoriyaTab { home, search, calendar, library, downloads }

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
    KumoriyaTab.library: GlobalKey<NavigatorState>(),
    KumoriyaTab.downloads: GlobalKey<NavigatorState>(),
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

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
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
              _DesktopRail(
                currentIndex: currentIndex,
                onTap: _onTabSelected,
                onOpenSettings: () => _openSettings(context),
              ),
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
          onSettingsTap: () => _openSettings(context),
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onSettingsTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KumoriyaColors.borderSubtle)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == KumoriyaTab.values.length) {
            onSettingsTap();
            return;
          }
          onTap(index);
        },
        backgroundColor: KumoriyaColors.navBackground,
        selectedItemColor: KumoriyaColors.primary,
        unselectedItemColor: KumoriyaColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        iconSize: 22,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: context.l10n.navHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_rounded),
            activeIcon: const Icon(Icons.search_rounded),
            label: context.l10n.navSearch,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today_outlined),
            activeIcon: const Icon(Icons.calendar_today_rounded),
            label: context.l10n.navCalendar,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.video_library_outlined),
            activeIcon: const Icon(Icons.video_library_rounded),
            label: context.l10n.navLibrary,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.download_outlined),
            activeIcon: const Icon(Icons.download_rounded),
            label: context.l10n.navDownloads,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings_rounded),
            label: context.l10n.settingsTitle,
          ),
        ],
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.currentIndex,
    required this.onTap,
    required this.onOpenSettings,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onOpenSettings;

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
                    label: context.l10n.navHome,
                    index: 0,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.search_rounded,
                    activeIcon: Icons.search_rounded,
                    label: context.l10n.navSearch,
                    index: 1,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_today_rounded,
                    label: context.l10n.navCalendar,
                    index: 2,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.video_library_outlined,
                    activeIcon: Icons.video_library_rounded,
                    label: context.l10n.navLibrary,
                    index: 3,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                  _RailItem(
                    icon: Icons.download_outlined,
                    activeIcon: Icons.download_rounded,
                    label: context.l10n.navDownloads,
                    index: 4,
                    currentIndex: currentIndex,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ),
          _RailUtilityButton(
            icon: Icons.settings_outlined,
            tooltip: context.l10n.settingsTitle,
            onTap: onOpenSettings,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RailUtilityButton extends StatefulWidget {
  const _RailUtilityButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_RailUtilityButton> createState() => _RailUtilityButtonState();
}

class _RailUtilityButtonState extends State<_RailUtilityButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? KumoriyaColors.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
            ),
            child: const Center(
              child: Icon(
                Icons.settings_outlined,
                color: KumoriyaColors.textMuted,
                size: 22,
              ),
            ),
          ),
        ),
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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
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
      ),
    );
  }
}
