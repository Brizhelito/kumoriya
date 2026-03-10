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
  testWidgets('home shows continue watching when one entry exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogProvider.overrideWith((ref) async => Success(_catalog)),
          continueWatchingProvider.overrideWith(
            (ref) async => Success(<AnimeWatchHistory>[_history]),
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

    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.byKey(const Key('continue-watching-card-1')), findsOneWidget);
    expect(
      find.byKey(const Key('continue-watching-scroll-left')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('continue-watching-scroll-right')),
      findsNothing,
    );
  });

  testWidgets('home hides continue watching when history is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogProvider.overrideWith((ref) async => Success(_catalog)),
          continueWatchingProvider.overrideWith(
            (ref) async => const Success(<AnimeWatchHistory>[]),
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

    expect(find.text('Continue Watching'), findsNothing);
    expect(find.byKey(const Key('continue-watching-list')), findsNothing);
  });
}

final List<Anime> _catalog = <Anime>[
  Anime(
    anilistId: 1,
    title: const AnimeTitle(romaji: 'Solo Leveling'),
    format: AnimeFormat.tv,
  ),
];

final AnimeWatchHistory _history = AnimeWatchHistory(
  anilistId: 1,
  lastEpisodeNumber: 3.0,
  lastAccessedAt: DateTime(2026, 3, 9, 12),
  lastPositionSeconds: 480,
  lastTotalDurationSeconds: 1440,
);
