import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/pages/anime_detail_page.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  testWidgets('AnimeDetail renders episode rows inline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeDetailProvider.overrideWith(
            (ref, anilistId) async => Success(_detail(anilistId)),
          ),
          sourceAvailabilitySummaryProvider.overrideWith(
            (ref, anilistId) async => Success(_summary),
          ),
          latestEpisodeProgressProvider.overrideWith(
            (ref, anilistId) async =>
                Success<EpisodeProgress?, KumoriyaError>(_progress.last),
          ),
          animeEpisodeProgressListProvider.overrideWith(
            (ref, anilistId) async =>
                Success<List<EpisodeProgress>, KumoriyaError>(_progress),
          ),
          playbackPreferenceProvider.overrideWith(
            (ref, anilistId) async =>
                const Success<PlaybackPreference?, KumoriyaError>(null),
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
          home: AnimeDetailPage(anilistId: 404),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('anime-detail-episodes-section')),
      400,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('anime-detail-episodes-section')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('anime-detail-episode-1')), findsOneWidget);
    expect(find.byKey(const Key('anime-detail-episode-2')), findsOneWidget);
    expect(find.byKey(const Key('anime-detail-episode-3')), findsOneWidget);
    expect(find.text('Episode 1'), findsOneWidget);
    expect(find.text('Episode 2'), findsOneWidget);
    expect(find.text('Episode 3'), findsOneWidget);
    expect(find.text('View episode list'), findsNothing);
  });
}

AnimeDetail _detail(int anilistId) {
  return AnimeDetail(
    anime: Anime(
      anilistId: anilistId,
      title: const AnimeTitle(romaji: 'Inline Episodes Anime'),
      format: AnimeFormat.tv,
      status: AnimeStatus.releasing,
      totalEpisodes: 3,
    ),
    synopsis: 'Integrated episode flow.',
    episodes: const <AnimeEpisode>[
      AnimeEpisode(number: 1, title: 'Episode 1'),
      AnimeEpisode(number: 2, title: 'Episode 2'),
      AnimeEpisode(number: 3, title: 'Episode 3'),
    ],
  );
}

final SourceAvailabilitySummary _summary = SourceAvailabilitySummary(
  sources: <SourceAvailability>[
    SourceAvailability(
      manifest: PluginManifest(
        id: 'kumoriya.source.fake',
        displayName: 'Fake Source',
        type: PluginType.source,
        capabilities: <PluginCapability>{PluginCapability.search},
      ),
      status: SourceAvailabilityStatus.available,
      decision: const SourceMatchDecision(
        verdict: true,
        confidence: MatchConfidence.high,
        reason: 'Exact title',
        acceptanceSignals: <String>['exact-title'],
        rejectionSignals: <String>[],
      ),
      episodes: <SourceEpisode>[
        SourceEpisode(
          sourceEpisodeId: 'ep1',
          number: 1,
          title: 'Episode 1',
          episodeUrl: Uri.parse('https://example.com/1'),
        ),
        SourceEpisode(
          sourceEpisodeId: 'ep2',
          number: 2,
          title: 'Episode 2',
          episodeUrl: Uri.parse('https://example.com/2'),
        ),
        SourceEpisode(
          sourceEpisodeId: 'ep3',
          number: 3,
          title: 'Episode 3',
          episodeUrl: Uri.parse('https://example.com/3'),
        ),
      ],
      availableAudioKinds: const <SourceAudioKind>{SourceAudioKind.sub},
    ),
  ],
);

final List<EpisodeProgress> _progress = <EpisodeProgress>[
  EpisodeProgress(
    anilistId: 404,
    episodeNumber: 2,
    position: const Duration(minutes: 7),
    totalDuration: const Duration(minutes: 24),
    updatedAt: DateTime(2026, 3, 9, 12),
  ),
];
