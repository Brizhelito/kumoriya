import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/pages/home_page.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/pages/episode_list_page.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('home shows continue watching when one entry exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          homeCatalogProvider.overrideWith((ref) async => Success(_catalog)),
          continueWatchingProvider.overrideWith(
            (ref) async => Success(<AnimeWatchHistory>[_history]),
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

    expect(find.text('Continue Watching'), findsNothing);
    expect(find.byKey(const Key('continue-watching-list')), findsNothing);
  });

  testWidgets(
    'continue watching opens the selector when autoplay has no clear winner',
    (tester) async {
      final store = _FakeAnimeProgressStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            animeProgressStoreProvider.overrideWithValue(store),
            homeCatalogProvider.overrideWith((ref) async => Success(_catalog)),
            continueWatchingProvider.overrideWith(
              (ref) async => Success(<AnimeWatchHistory>[_history]),
            ),
            calendarCatalogProvider.overrideWith(
              (ref) async => const Success(<Anime>[]),
            ),
            sourcePluginsProvider.overrideWithValue(const <SourcePlugin>[
              _ResumeMultiServerSourcePlugin(),
            ]),
            resolverPluginsProvider.overrideWithValue(const <ResolverPlugin>[
              _ResumeFakeResolverPlugin(),
            ]),
            sourceAvailabilitySummaryProvider.overrideWith(
              (ref, anilistId) async =>
                  Success<SourceAvailabilitySummary, KumoriyaError>(
                    _ambiguousResumeSummary,
                  ),
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
      await tester.tap(find.byKey(const Key('continue-watching-card-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Choose a server'), findsOneWidget);
      expect(find.text('AlphaServer'), findsOneWidget);
      expect(find.text('BetaServer'), findsOneWidget);
    },
  );

  testWidgets(
    'continue watching falls back to the episode list when autoplay is unavailable',
    (tester) async {
      final store = _FakeAnimeProgressStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            animeProgressStoreProvider.overrideWithValue(store),
            homeCatalogProvider.overrideWith((ref) async => Success(_catalog)),
            continueWatchingProvider.overrideWith(
              (ref) async => Success(<AnimeWatchHistory>[_history]),
            ),
            calendarCatalogProvider.overrideWith(
              (ref) async => const Success(<Anime>[]),
            ),
            sourceAvailabilitySummaryProvider.overrideWith(
              (ref, anilistId) async =>
                  const Success<SourceAvailabilitySummary, KumoriyaError>(
                    SourceAvailabilitySummary(sources: <SourceAvailability>[]),
                  ),
            ),
            animeEpisodesProvider.overrideWith(
              (ref, anilistId) async =>
                  Success<List<AnimeEpisode>, KumoriyaError>(_episodes),
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
      await tester.tap(find.byKey(const Key('continue-watching-card-1')));
      await tester.pumpAndSettle();

      expect(find.byType(EpisodeListPage), findsOneWidget);
    },
  );
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

const List<AnimeEpisode> _episodes = <AnimeEpisode>[
  AnimeEpisode(number: 1, title: 'Episode 1'),
  AnimeEpisode(number: 2, title: 'Episode 2'),
  AnimeEpisode(number: 3, title: 'Episode 3'),
];

final SourceAvailabilitySummary _ambiguousResumeSummary =
    SourceAvailabilitySummary(
      sources: <SourceAvailability>[
        SourceAvailability(
          manifest: const PluginManifest(
            id: 'kumoriya.source.resume',
            displayName: 'Resume Source',
            type: PluginType.source,
            capabilities: <PluginCapability>{
              PluginCapability.search,
              PluginCapability.episodeList,
              PluginCapability.linkExtraction,
            },
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
              sourceEpisodeId: 'resume-3',
              number: 3,
              title: 'Episode 3',
              episodeUrl: Uri.parse('https://example.com/resume/3'),
            ),
          ],
          availableAudioKinds: const <SourceAudioKind>{SourceAudioKind.sub},
        ),
      ],
    );

final class _ResumeMultiServerSourcePlugin implements SourcePlugin {
  const _ResumeMultiServerSourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.resume',
    displayName: 'Resume Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    return const Success(
      SourceAnimeDetail(sourceId: 'resume', title: 'Solo Leveling'),
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: 'resume-3',
        number: 3,
        title: 'Episode 3',
        episodeUrl: Uri.parse('https://example.com/resume/3'),
      ),
    ]);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'alpha',
        serverName: 'AlphaServer',
        initialUrl: Uri.parse('https://video.example/alpha'),
        language: 'sub',
      ),
      SourceServerLink(
        serverId: 'beta',
        serverName: 'BetaServer',
        initialUrl: Uri.parse('https://video.example/beta'),
        language: 'sub',
      ),
    ]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'resume', title: 'Solo Leveling'),
    ]);
  }
}

final class _ResumeFakeResolverPlugin implements ResolverPlugin {
  const _ResumeFakeResolverPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.resume',
    displayName: 'Resume Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  int get priority => 100;

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(url: Uri.parse('https://cdn.example${url.path}.m3u8')),
        ],
      ),
    );
  }

  @override
  bool supports(Uri url) => url.host == 'video.example';
}

final class _FakeAnimeProgressStore implements AnimeProgressStore {
  _FakeAnimeProgressStore();

  PlaybackPreference? preference;

  @override
  Future<Result<void, KumoriyaError>> clearAllPlaybackPreferences() async {
    preference = null;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(
    int anilistId,
  ) async {
    preference = null;
    return const Success(null);
  }

  @override
  Future<Result<List<EpisodeProgress>, KumoriyaError>> getAllProgress(
    int anilistId,
  ) async {
    return const Success(<EpisodeProgress>[]);
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getLatestProgress(
    int anilistId,
  ) async {
    return const Success(null);
  }

  @override
  Future<Result<PlaybackPreference?, KumoriyaError>> getPlaybackPreference(
    int anilistId,
  ) async {
    return Success(preference);
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  ) async {
    return const Success(null);
  }

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) async {
    return const Success(<AnimeWatchHistory>[]);
  }

  @override
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress) async {
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference nextPreference,
  ) async {
    preference = nextPreference;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertWatchHistory({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    int? totalDurationSeconds,
    String? lastSourcePluginId,
    DateTime? lastAccessedAt,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getAllHistory() async {
    return const Success(<AnimeWatchHistory>[]);
  }

  @override
  Future<Result<void, KumoriyaError>> deleteHistoryEntry(int anilistId) async {
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> clearAllHistory() async {
    return const Success(null);
  }
}
