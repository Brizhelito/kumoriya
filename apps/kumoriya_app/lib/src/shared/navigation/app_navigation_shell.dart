import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';

import '../../app/l10n.dart';
import '../../features/anime_catalog/application/services/cached_anime_catalog_repository.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../icons/kumoriya_icons.dart';
import '../theme/kumoriya_theme.dart';
import '../universe/active_universe_providers.dart';

/// Tabs available in the anime universe. Order is the canonical
/// bottom-nav / rail order.
enum KumoriyaAnimeTab { home, search, party, library, profile }

/// Tabs available in the manga universe. Order is the canonical
/// bottom-nav / rail order. No Calendar (anime-only) and no Party tab.
enum KumoriyaMangaTab { home, search, library, profile }

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
              CloudSidebar(
                items: <SidebarItem>[
                  for (final spec in _tabSpecsFor(universe, AppL10nProxy.of(context)))
                    SidebarItem(
                      icon: spec.icon,
                      activeIcon: spec.activeIcon,
                      label: spec.label,
                    ),
                ],
                currentIndex: currentIndex,
                onTap: (i) => _onTabSelected(universe, i),
                brandName: 'Kumoriya',
                onSettingsTap: () => _openSettings(context),
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
        body: Stack(
          children: <Widget>[
            bodyWithBanner,
            CloudBottomNav(
              items: <BottomNavItem>[
                for (final spec in _tabSpecsFor(universe, AppL10nProxy.of(context)))
                  BottomNavItem(
                    icon: spec.icon,
                    activeIcon: spec.activeIcon,
                    label: spec.label,
                  ),
              ],
              currentIndex: currentIndex,
              onTap: (i) => _onTabSelected(universe, i),
            ),
          ],
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
        icon: KumoriyaIcons.navParty,
        activeIcon: KumoriyaIcons.navPartyActive,
        label: l10n.navParty,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navLibrary,
        activeIcon: KumoriyaIcons.navLibraryActive,
        label: l10n.navLibrary,
      ),
      _TabSpec(
        icon: KumoriyaIcons.navProfile,
        activeIcon: KumoriyaIcons.navProfileActive,
        label: l10n.navProfile,
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
        icon: KumoriyaIcons.navProfile,
        activeIcon: KumoriyaIcons.navProfileActive,
        label: l10n.navProfile,
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
    required this.navParty,
    required this.navLibrary,
    required this.navProfile,
  });

  factory AppL10nProxy.of(BuildContext context) {
    final l10n = context.l10n;
    return AppL10nProxy(
      navHome: l10n.navHome,
      navSearch: l10n.navSearch,
      navParty: l10n.navParty,
      navLibrary: l10n.navLibrary,
      navProfile: l10n.navProfile,
    );
  }

  final String navHome;
  final String navSearch;
  final String navParty;
  final String navLibrary;
  final String navProfile;
}
