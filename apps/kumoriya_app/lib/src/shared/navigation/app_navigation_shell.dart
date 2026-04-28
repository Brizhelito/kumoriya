import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../../app/l10n.dart';
import '../../features/anime_catalog/application/services/cached_anime_catalog_repository.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../icons/kumoriya_icons.dart';
import '../theme/kumoriya_theme.dart';
import '../universe/active_universe_providers.dart';

/// Tabs available in the anime universe. Order is the canonical
/// bottom-nav / rail order.
enum KumoriyaAnimeTab { home, search, calendar, library, downloads }

/// Tabs available in the manga universe. Order is the canonical
/// bottom-nav / rail order. No Calendar (anime-only) and no dedicated
/// Latest tab — Latest lives inside Manga Home (see plan §8).
enum KumoriyaMangaTab { home, search, library, downloads }

class AppNavigationShell extends ConsumerStatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.animeTabBuilders,
    required this.mangaTabBuilders,
    this.fallbackReasonNotifier,
    this.onTapRetry,
  });

  final Map<KumoriyaAnimeTab, WidgetBuilder> animeTabBuilders;
  final Map<KumoriyaMangaTab, WidgetBuilder> mangaTabBuilders;

  /// When non-null, a persistent banner is shown to indicate the fallback
  /// reason ([FallbackReason.offline] or [FallbackReason.anilistDown]).
  final ValueNotifier<FallbackReason>? fallbackReasonNotifier;

  /// When non-null, the offline banner becomes tappable and invokes
  /// this callback. Wired to a "retry now" gesture that invalidates the
  /// catalog providers so the user can manually trigger a refresh
  /// without waiting for the background recovery poller.
  final VoidCallback? onTapRetry;

  @override
  ConsumerState<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends ConsumerState<AppNavigationShell> {
  /// Current tab index per universe. Each universe keeps its own
  /// selection so switching back lands on the last-viewed tab.
  final Map<MediaKind, int> _currentTabIndex = <MediaKind, int>{
    MediaKind.anime: 0,
    MediaKind.manga: 0,
  };

  /// Tabs that have been visited at least once per universe. Drives the
  /// lazy `Offstage` build of inactive tabs.
  final Map<MediaKind, Set<int>> _visitedTabs = <MediaKind, Set<int>>{
    MediaKind.anime: <int>{0},
    MediaKind.manga: <int>{0},
  };

  /// Per-(universe, tab) navigator keys so each tab keeps its own
  /// navigation stack across universe switches.
  final Map<MediaKind, Map<int, GlobalKey<NavigatorState>>> _navigatorKeys =
      <MediaKind, Map<int, GlobalKey<NavigatorState>>>{
        MediaKind.anime: <int, GlobalKey<NavigatorState>>{
          for (var i = 0; i < KumoriyaAnimeTab.values.length; i++)
            i: GlobalKey<NavigatorState>(),
        },
        MediaKind.manga: <int, GlobalKey<NavigatorState>>{
          for (var i = 0; i < KumoriyaMangaTab.values.length; i++)
            i: GlobalKey<NavigatorState>(),
        },
      };

  static bool get _isDesktop {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  int _tabCountFor(MediaKind universe) => switch (universe) {
    MediaKind.anime => KumoriyaAnimeTab.values.length,
    MediaKind.manga => KumoriyaMangaTab.values.length,
  };

  void _onTabSelected(MediaKind universe, int index) {
    if (index == _currentTabIndex[universe]) {
      _navigatorKeys[universe]?[index]?.currentState?.popUntil(
        (route) => route.isFirst,
      );
      return;
    }
    setState(() {
      _visitedTabs[universe]!.add(index);
      _currentTabIndex[universe] = index;
    });
  }

  Future<bool> _handlePopScope(MediaKind universe) async {
    final currentIndex = _currentTabIndex[universe]!;
    final nav = _navigatorKeys[universe]?[currentIndex]?.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (currentIndex != 0) {
      setState(() => _currentTabIndex[universe] = 0);
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

  Widget _buildTabNavigator(MediaKind universe, int index) {
    return Navigator(
      key: _navigatorKeys[universe]![index],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (ctx) => _builderFor(universe, index)(ctx),
      ),
    );
  }

  WidgetBuilder _builderFor(MediaKind universe, int index) {
    return switch (universe) {
      MediaKind.anime =>
        widget.animeTabBuilders[KumoriyaAnimeTab.values[index]]!,
      MediaKind.manga =>
        widget.mangaTabBuilders[KumoriyaMangaTab.values[index]]!,
    };
  }

  Widget _buildOfflineBanner(Widget body) {
    final notifier = widget.fallbackReasonNotifier;
    if (notifier == null) return body;
    return ValueListenableBuilder<FallbackReason>(
      valueListenable: notifier,
      builder: (context, reason, child) {
        return Column(
          children: <Widget>[
            if (reason != FallbackReason.none)
              SafeArea(
                bottom: false,
                child: Material(
                  color: reason == FallbackReason.offline
                      ? KumoriyaColors.statusWarning
                      : KumoriyaColors.statusDanger,
                  child: InkWell(
                    onTap: widget.onTapRetry,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              reason == FallbackReason.offline
                                  ? context.l10n.offlineBanner
                                  : context.l10n.anilistDownBanner,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (widget.onTapRetry != null) ...<Widget>[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.refresh,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(child: child!),
          ],
        );
      },
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final universe = ref.watch(activeUniverseProvider);
    final currentIndex = _currentTabIndex[universe]!;
    final tabCount = _tabCountFor(universe);

    // Build navigators only for visited tabs of the active universe;
    // tabs of the inactive universe are not built at all so the inactive
    // tree stays cheap. When the user switches back, the visited-set is
    // preserved and the navigator keys keep the stacks alive.
    final body = Stack(
      children: <Widget>[
        for (var i = 0; i < tabCount; i++)
          if (_visitedTabs[universe]!.contains(i))
            Offstage(
              offstage: i != currentIndex,
              child: _buildTabNavigator(universe, i),
            ),
      ],
    );

    final bodyWithBanner = _buildOfflineBanner(body);

    if (_isDesktop) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await _handlePopScope(universe);
        },
        child: Scaffold(
          backgroundColor: KumoriyaColors.background,
          body: Row(
            children: <Widget>[
              _DesktopRail(
                universe: universe,
                currentIndex: currentIndex,
                onTap: (i) => _onTabSelected(universe, i),
                onOpenSettings: () => _openSettings(context),
              ),
              Expanded(child: bodyWithBanner),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handlePopScope(universe);
      },
      child: Scaffold(
        backgroundColor: KumoriyaColors.background,
        body: bodyWithBanner,
        bottomNavigationBar: _MobileBottomNav(
          universe: universe,
          currentIndex: currentIndex,
          onTap: (i) => _onTabSelected(universe, i),
          onSettingsTap: () => _openSettings(context),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

List<_TabSpec> _tabSpecsFor(MediaKind universe, AppL10nProxy l10n) {
  return switch (universe) {
    MediaKind.anime => <_TabSpec>[
      _TabSpec(
        icon: KumoriyaIcons.navHome,
        activeIcon: KumoriyaIcons.navHomeActive,
        label: l10n.navHome,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navSearch,
        activeIcon: KumoriyaIcons.navSearchActive,
        label: l10n.navSearch,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navCalendar,
        activeIcon: KumoriyaIcons.navCalendarActive,
        label: l10n.navCalendar,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navLibrary,
        activeIcon: KumoriyaIcons.navLibraryActive,
        label: l10n.navLibrary,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navDownloads,
        activeIcon: KumoriyaIcons.navDownloadsActive,
        label: l10n.navDownloads,
      ),
    ],
    MediaKind.manga => <_TabSpec>[
      _TabSpec(
        icon: KumoriyaIcons.navHome,
        activeIcon: KumoriyaIcons.navHomeActive,
        label: l10n.navHome,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navSearch,
        activeIcon: KumoriyaIcons.navSearchActive,
        label: l10n.navSearch,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navLibrary,
        activeIcon: KumoriyaIcons.navLibraryActive,
        label: l10n.navLibrary,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navDownloads,
        activeIcon: KumoriyaIcons.navDownloadsActive,
        label: l10n.navDownloads,
      ),
    ],
  };
}

/// Adapter so [_tabSpecsFor] does not have to take a `BuildContext`. The
/// intent is just to keep the spec list build side-effect-free and easy
/// to unit-test.
class AppL10nProxy {
  const AppL10nProxy({
    required this.navHome,
    required this.navSearch,
    required this.navCalendar,
    required this.navLibrary,
    required this.navDownloads,
  });

  factory AppL10nProxy.of(BuildContext context) {
    final l10n = context.l10n;
    return AppL10nProxy(
      navHome: l10n.navHome,
      navSearch: l10n.navSearch,
      navCalendar: l10n.navCalendar,
      navLibrary: l10n.navLibrary,
      navDownloads: l10n.navDownloads,
    );
  }

  final String navHome;
  final String navSearch;
  final String navCalendar;
  final String navLibrary;
  final String navDownloads;
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.universe,
    required this.currentIndex,
    required this.onTap,
    required this.onSettingsTap,
  });

  final MediaKind universe;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final specs = _tabSpecsFor(universe, AppL10nProxy.of(context));
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KumoriyaColors.borderSubtle)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == specs.length) {
            onSettingsTap();
            return;
          }
          onTap(index);
        },
        backgroundColor: KumoriyaColors.navBackground,
        selectedItemColor: KumoriyaColors.textPrimary,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedItemColor: KumoriyaColors.navInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        iconSize: 24,
        items: <BottomNavigationBarItem>[
          for (final spec in specs)
            BottomNavigationBarItem(
              icon: Icon(spec.icon),
              activeIcon: Icon(spec.activeIcon),
              label: spec.label,
            ),
          BottomNavigationBarItem(
            icon: const Icon(KumoriyaIcons.navSettings),
            activeIcon: const Icon(KumoriyaIcons.navSettingsActive),
            label: context.l10n.settingsTitle,
          ),
        ],
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.universe,
    required this.currentIndex,
    required this.onTap,
    required this.onOpenSettings,
  });

  final MediaKind universe;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final specs = _tabSpecsFor(universe, AppL10nProxy.of(context));
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
                children: <Widget>[
                  for (var i = 0; i < specs.length; i++)
                    _RailItem(
                      icon: specs[i].icon,
                      activeIcon: specs[i].activeIcon,
                      label: specs[i].label,
                      index: i,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                ],
              ),
            ),
          ),
          _RailUtilityButton(
            icon: KumoriyaIcons.navSettings,
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
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          onTap: widget.onTap,
          splashColor: primary.withValues(alpha: 0.10),
          child: Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? primary.withValues(alpha: 0.20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: KumoriyaColors.navInactive,
                size: 24,
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
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'K',
        style: TextStyle(
          color: KumoriyaColors.textPrimary,
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
    final primary = Theme.of(context).colorScheme.primary;
    final isActive = index == currentIndex;
    final color = isActive ? primary : KumoriyaColors.navInactive;

    return Tooltip(
      message: label,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          onTap: () => onTap(index),
          splashColor: primary.withValues(alpha: 0.10),
          child: Container(
            width: 88,
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? primary.withValues(alpha: 0.20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(isActive ? activeIcon : icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
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
