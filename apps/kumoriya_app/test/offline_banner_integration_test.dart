import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/shared/cache/fallback_reason.dart';
import 'package:kumoriya_app/src/shared/navigation/app_navigation_shell.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_providers.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_store.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

/// Integration test for the offline / AniList-down banner shown by
/// `AppNavigationShell`. We don't drive the real composite repository
/// here — the unit test in composite_manga_catalog_repository_test.dart
/// already covers the data path. This test pins the *visual* contract
/// the banner exposes when the shared `FallbackReason` notifier flips.
class _InMemoryUniverseStore implements ActiveUniverseStore {
  @override
  Future<MediaKind?> read() async => null;

  @override
  Future<void> write(MediaKind kind) async {}
}

Widget _buildShell(ValueNotifier<FallbackReason> reason) {
  Widget tab(String tag) => Scaffold(
    body: Center(child: Text('tab:$tag', key: Key('content:$tag'))),
  );

  return ProviderScope(
    overrides: [
      activeUniverseStoreProvider.overrideWithValue(_InMemoryUniverseStore()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppNavigationShell(
        fallbackReasonNotifier: reason,
        animeTabBuilders: <KumoriyaAnimeTab, WidgetBuilder>{
          KumoriyaAnimeTab.home: (_) => tab('anime-home'),
          KumoriyaAnimeTab.search: (_) => tab('anime-search'),
          KumoriyaAnimeTab.party: (_) => tab('anime-party'),
          KumoriyaAnimeTab.library: (_) => tab('anime-library'),
          KumoriyaAnimeTab.profile: (_) => tab('anime-profile'),
        },
        mangaTabBuilders: <KumoriyaMangaTab, WidgetBuilder>{
          KumoriyaMangaTab.home: (_) => tab('manga-home'),
          KumoriyaMangaTab.search: (_) => tab('manga-search'),
          KumoriyaMangaTab.library: (_) => tab('manga-library'),
          KumoriyaMangaTab.profile: (_) => tab('manga-profile'),
        },
      ),
    ),
  );
}

void main() {
  group('AppNavigationShell offline banner', () {
    testWidgets('is hidden when fallbackReason is none', (tester) async {
      final reason = ValueNotifier(FallbackReason.none);
      await tester.pumpWidget(_buildShell(reason));
      await tester.pump();

      expect(find.text('Offline'), findsNothing);
      expect(find.text('AniList is down'), findsNothing);
    });

    testWidgets(
      'shows the offline banner when fallbackReason flips to offline',
      (tester) async {
        final reason = ValueNotifier(FallbackReason.none);
        await tester.pumpWidget(_buildShell(reason));
        await tester.pump();
        expect(find.text('Offline'), findsNothing);

        reason.value = FallbackReason.offline;
        await tester.pump();

        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('AniList is down'), findsNothing);
      },
    );

    testWidgets(
      'shows the AniList-down banner when fallbackReason flips to anilistDown',
      (tester) async {
        final reason = ValueNotifier(FallbackReason.none);
        await tester.pumpWidget(_buildShell(reason));
        await tester.pump();

        reason.value = FallbackReason.anilistDown;
        await tester.pump();

        expect(find.text('AniList is down'), findsOneWidget);
        expect(find.text('Offline'), findsNothing);
      },
    );

    testWidgets('banner disappears when fallbackReason returns to none', (
      tester,
    ) async {
      final reason = ValueNotifier(FallbackReason.offline);
      await tester.pumpWidget(_buildShell(reason));
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);

      reason.value = FallbackReason.none;
      await tester.pump();

      expect(find.text('Offline'), findsNothing);
      expect(find.text('AniList is down'), findsNothing);
    });

    testWidgets('banner stays visible across tab switches', (tester) async {
      final reason = ValueNotifier(FallbackReason.anilistDown);
      await tester.pumpWidget(_buildShell(reason));
      await tester.pump();

      expect(find.text('AniList is down'), findsOneWidget);
      expect(find.byKey(const Key('content:anime-home')), findsOneWidget);

      // Tap into the search tab. The exact tap target depends on
      // shell layout; finding the tab by label is more robust.
      final searchTab = find.text('Search').first;
      if (searchTab.evaluate().isNotEmpty) {
        await tester.tap(searchTab);
        await tester.pumpAndSettle();
        // Banner must still be there on a different tab.
        expect(find.text('AniList is down'), findsOneWidget);
      }
    });
  });
}
