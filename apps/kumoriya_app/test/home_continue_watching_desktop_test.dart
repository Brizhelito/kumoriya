import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/pages/home_page.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  testWidgets('desktop continue watching shows controls and scrolls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeCatalogProvider.overrideWith((ref) async => Success(_catalog)),
            continueWatchingProvider.overrideWith(
              (ref) async => Success(_history),
            ),
            calendarCatalogProvider.overrideWith(
              (ref) async => const Success(<Anime>[]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('continue-watching-scroll-left')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('continue-watching-scroll-right')),
        findsOneWidget,
      );

      final horizontalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      );
      final scrollableState = tester.state<ScrollableState>(
        horizontalScrollable,
      );
      final initialOffset = scrollableState.position.pixels;

      await tester.tap(find.byKey(const Key('continue-watching-scroll-right')));
      await tester.pumpAndSettle();

      final afterRightOffset = scrollableState.position.pixels;
      expect(afterRightOffset, greaterThan(initialOffset));

      await tester.tap(find.byKey(const Key('continue-watching-scroll-left')));
      await tester.pumpAndSettle();

      final afterLeftOffset = scrollableState.position.pixels;
      expect(afterLeftOffset, lessThan(afterRightOffset));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

final List<Anime> _catalog = List<Anime>.generate(
  8,
  (index) => Anime(
    anilistId: index + 1,
    title: AnimeTitle(romaji: 'Anime ${index + 1}'),
    format: AnimeFormat.tv,
  ),
);

final List<AnimeWatchHistory> _history = List<AnimeWatchHistory>.generate(
  8,
  (index) => AnimeWatchHistory(
    anilistId: index + 1,
    lastEpisodeNumber: index + 1,
    lastAccessedAt: DateTime(2026, 3, 9, 12).subtract(Duration(hours: index)),
  ),
);
