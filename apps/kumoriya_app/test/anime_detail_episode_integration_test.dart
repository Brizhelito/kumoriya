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

  testWidgets(
    'episode tap opens the minimal selector when autoplay is ambiguous',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animeProgressStoreProvider.overrideWithValue(
              _FakeAnimeProgressStore(),
            ),
            animeDetailProvider.overrideWith(
              (ref, anilistId) async => Success(_detail(anilistId)),
            ),
            sourceAvailabilitySummaryProvider.overrideWith(
              (ref, anilistId) async => Success(_summary),
            ),
            latestEpisodeProgressProvider.overrideWith(
              (ref, anilistId) async =>
                  const Success<EpisodeProgress?, KumoriyaError>(null),
            ),
            animeEpisodeProgressListProvider.overrideWith(
              (ref, anilistId) async =>
                  const Success<List<EpisodeProgress>, KumoriyaError>(
                    <EpisodeProgress>[],
                  ),
            ),
            playbackPreferenceProvider.overrideWith(
              (ref, anilistId) async =>
                  const Success<PlaybackPreference?, KumoriyaError>(null),
            ),
            sourcePluginsProvider.overrideWithValue(const <SourcePlugin>[
              _FakeMultiServerSourcePlugin(),
            ]),
            resolverPluginsProvider.overrideWithValue(const <ResolverPlugin>[
              _FakeResolverPlugin(),
            ]),
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
        find.byKey(const Key('anime-detail-episode-2')),
        400,
        scrollable: verticalScrollable,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('anime-detail-episode-2')));
      await tester.pumpAndSettle();

      expect(find.text('Choose a server'), findsOneWidget);
      expect(find.text('AlphaServer'), findsOneWidget);
      expect(find.text('BetaServer'), findsOneWidget);
    },
  );
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

final class _FakeMultiServerSourcePlugin implements SourcePlugin {
  const _FakeMultiServerSourcePlugin();

  @override
  PluginManifest get manifest => PluginManifest(
    id: 'kumoriya.source.fake',
    displayName: 'Fake Source',
    type: PluginType.source,
    capabilities: const <PluginCapability>{
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
      SourceAnimeDetail(sourceId: 'inline', title: 'Inline Episodes Anime'),
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(_summary.sources.single.episodes);
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
      SourceAnimeMatch(sourceId: 'inline', title: 'Inline Episodes Anime'),
    ]);
  }
}

final class _FakeResolverPlugin implements ResolverPlugin {
  const _FakeResolverPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.fake',
    displayName: 'Fake Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  int get priority => 100;

  @override
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    return Success(<ResolvedStream>[
      ResolvedStream(url: Uri.parse('https://cdn.example${url.path}.m3u8')),
    ]);
  }

  @override
  bool supports(Uri url) => url.host == 'video.example';
}

final class _FakeAnimeProgressStore implements AnimeProgressStore {
  @override
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(
    int anilistId,
  ) async {
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
    return const Success(null);
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
    PlaybackPreference preference,
  ) async {
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertWatchHistory({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    int? totalDurationSeconds,
    String? lastSourcePluginId,
  }) async {
    return const Success(null);
  }
}
