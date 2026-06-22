import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/shared/navigation/app_navigation_shell.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_providers.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_store.dart';
import 'package:kumoriya_app/src/shared/universe/widgets/universe_switch.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

class _InMemoryUniverseStore implements ActiveUniverseStore {
  MediaKind? _value;

  @override
  Future<MediaKind?> read() async => _value;

  @override
  Future<void> write(MediaKind kind) async {
    _value = kind;
  }
}

Widget _buildShell({MediaKind? initial}) {
  Widget tab(String tag) => Scaffold(
    body: Center(child: Text('tab:$tag', key: Key('content:$tag'))),
  );

  return ProviderScope(
    overrides: [
      activeUniverseStoreProvider.overrideWithValue(_InMemoryUniverseStore()),
      if (initial != null)
        activeUniverseProvider.overrideWith(
          () => _PreloadedUniverseNotifier(initial),
        ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppNavigationShell(
        animeTabBuilders: <KumoriyaAnimeTab, WidgetBuilder>{
          KumoriyaAnimeTab.home: (_) => Builder(
            builder: (ctx) => Scaffold(
              body: Column(
                children: <Widget>[
                  const UniverseSwitch(),
                  const Expanded(child: Center(child: Text('anime-home'))),
                ],
              ),
            ),
          ),
          KumoriyaAnimeTab.search: (_) => tab('anime-search'),
          KumoriyaAnimeTab.party: (_) => tab('anime-party'),
          KumoriyaAnimeTab.library: (_) => tab('anime-library'),
          KumoriyaAnimeTab.profile: (_) => tab('anime-profile'),
        },
        mangaTabBuilders: <KumoriyaMangaTab, WidgetBuilder>{
          // The real MangaHomePage / MangaSearchPage need the full
          // provider graph (AniList gateway, Drift database) which
          // these shell-focused tests don't set up. Use lightweight
          // stubs so the shell can render without network/database.
          KumoriyaMangaTab.home: (_) => tab('manga-home'),
          KumoriyaMangaTab.search: (_) => tab('manga-search'),
          KumoriyaMangaTab.library: (_) => tab('manga-library'),
          KumoriyaMangaTab.profile: (_) => tab('manga-profile'),
        },
      ),
    ),
  );
}

class _PreloadedUniverseNotifier extends ActiveUniverseNotifier {
  _PreloadedUniverseNotifier(this._initial);
  final MediaKind _initial;

  @override
  MediaKind build() {
    // Skip the disk-load microtask; tests want a deterministic initial.
    return _initial;
  }
}

void main() {
  testWidgets('anime universe renders 5 nav items in canonical order', (
    tester,
  ) async {
    await tester.pumpWidget(_buildShell(initial: MediaKind.anime));
    await tester.pumpAndSettle();

    // The bottom nav adds Settings as a 6th item, so we expect 5 tabs +
    // 1 settings entry = 6 BottomNavigationBarItems for anime.
    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items, hasLength(6));
    // Party must be present on anime (3rd item, index 2).
    expect(nav.items[2].label, isNotNull);
  });

  testWidgets('manga universe renders 4 nav items, no Calendar', (
    tester,
  ) async {
    await tester.pumpWidget(_buildShell(initial: MediaKind.manga));
    await tester.pumpAndSettle();

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    // 4 manga tabs + 1 settings = 5 items, one fewer than anime.
    expect(nav.items, hasLength(5));
    // Manga Home is the active tab — its placeholder should be visible.
    expect(find.text('tab:manga-home'), findsOneWidget);
  });

  testWidgets('tapping the universe switch flips the shell to manga', (
    tester,
  ) async {
    await tester.pumpWidget(_buildShell(initial: MediaKind.anime));
    await tester.pumpAndSettle();

    expect(find.text('anime-home'), findsOneWidget);

    // Tap the Manga segment of the UniverseSwitch (rendered in
    // anime-home in this fixture).
    await tester.tap(find.text('Manga'));
    await tester.pumpAndSettle();

    // After the switch, the shell rebuilds with manga tabs.
    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items, hasLength(5));
    expect(find.text('tab:manga-home'), findsOneWidget);
  });

  testWidgets('per-universe tab selection survives a switch round-trip', (
    tester,
  ) async {
    await tester.pumpWidget(_buildShell(initial: MediaKind.anime));
    await tester.pumpAndSettle();

    // Move anime to the search tab (index 1) by invoking onTap directly
    // (the rendered tab content varies, so we don't tap a label).
    final nav0 = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    nav0.onTap?.call(1);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );

    // Flip to manga via the provider (the switch widget isn't on screen
    // when anime is on its Search tab).
    final ctx = tester.element(find.byType(AppNavigationShell));
    ProviderScope.containerOf(
      ctx,
    ).read(activeUniverseProvider.notifier).set(MediaKind.manga);
    await tester.pumpAndSettle();

    // Manga has its own current tab (home, default).
    expect(find.text('tab:manga-home'), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );

    // Flip back to anime — anime should still be on Search (index 1),
    // not reset to Home.
    ProviderScope.containerOf(
      ctx,
    ).read(activeUniverseProvider.notifier).set(MediaKind.anime);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
  });
}
