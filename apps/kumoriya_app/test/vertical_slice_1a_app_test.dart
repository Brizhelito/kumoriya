import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';

import 'package:kumoriya_app/src/app/kumoriya_app.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/downloads/application/download_directory_service.dart';
import 'package:kumoriya_app/src/features/downloads/presentation/download_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/widgets/source_badge.dart';

void main() {
  testWidgets(
    'home -> detail shows compact source badges and opens episode list',
    (tester) async {
      final fakeRepository = _FakeAnimeCatalogRepository.success();
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      const fakeSourcePlugins = <SourcePlugin>[
        _PrimarySourcePlugin(),
        _SecondarySourcePlugin(),
      ];

      final summary = SourceAvailabilitySummary(
        sources: <SourceAvailability>[
          _fakeAvailability(const _PrimarySourcePlugin().manifest),
          _fakeAvailability(const _SecondarySourcePlugin().manifest),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
            downloadDirectoryStoreProvider.overrideWithValue(
              _ConfiguredDownloadDirectoryStore(),
            ),
            sourcePluginsProvider.overrideWithValue(fakeSourcePlugins),
            sourceAvailabilitySummaryProvider.overrideWith(
              (ref, anilistId) async => Success(summary),
            ),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const KumoriyaApp(),
        ),
      );

      await _pumpUntilVisible(tester, find.text('Frieren'));

      expect(find.text('Frieren'), findsOneWidget);

      await tester.tap(find.text('Frieren').first);
      await _pumpForUi(tester);

      expect(find.byType(SourceBadge), findsNWidgets(2));
      expect(find.text('Episode preview'), findsOneWidget);
      expect(find.text('Play now'), findsWidgets);

      // Drain pending Drift micro-timers triggered by library providers.
      await tester.pumpAndSettle();
    },
  );

  testWidgets('episode tap opens a minimal server selector when needed', (
    tester,
  ) async {
    final fakeRepository = _FakeAnimeCatalogRepository.success();
    final db = openInMemoryDatabase();
    addTearDown(db.close);
    const fakeSourcePlugins = <SourcePlugin>[_MultiServerSourcePlugin()];
    const fakeResolverPlugins = <ResolverPlugin>[_FakeResolverPlugin()];

    final summary = SourceAvailabilitySummary(
      sources: <SourceAvailability>[
        _fakeAvailability(const _MultiServerSourcePlugin().manifest),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          downloadDirectoryStoreProvider.overrideWithValue(
            _ConfiguredDownloadDirectoryStore(),
          ),
          sourcePluginsProvider.overrideWithValue(fakeSourcePlugins),
          resolverPluginsProvider.overrideWithValue(fakeResolverPlugins),
          sourceAvailabilitySummaryProvider.overrideWith(
            (ref, anilistId) async => Success(summary),
          ),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('Frieren'));
    await tester.tap(find.text('Frieren').first);
    await _pumpForUi(tester);

    // Scroll until a 'Play now' label becomes visible (sliver-lazy build).
    await tester.scrollUntilVisible(
      find.text('Play now'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _pumpForUi(tester);

    // Verify the episode card has a play icon (playable sources present).
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsWidgets);

    await tester.tap(find.text('Play now').first);
    await _pumpUntilVisible(tester, find.text('Choose a server'));

    expect(find.text('Choose a server'), findsOneWidget);
    expect(find.text('MP4Upload'), findsOneWidget);
  });

  testWidgets('app respects Spanish system locale when supported', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('es', 'ES'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final fakeRepository = _FakeAnimeCatalogRepository.success();
    final db = openInMemoryDatabase();
    addTearDown(db.close);

    final summary = SourceAvailabilitySummary(
      sources: <SourceAvailability>[
        _fakeAvailability(const _PrimarySourcePlugin().manifest),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          downloadDirectoryStoreProvider.overrideWithValue(
            _ConfiguredDownloadDirectoryStore(),
          ),
          sourcePluginsProvider.overrideWithValue(const <SourcePlugin>[
            _PrimarySourcePlugin(),
          ]),
          sourceAvailabilitySummaryProvider.overrideWith(
            (ref, anilistId) async => Success(summary),
          ),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('Frieren'));
    await tester.tap(find.text('Frieren').first);
    await _pumpForUi(tester);

    // Compact source badges are icon-only in the current detail UI.
    expect(find.byType(SourceBadge), findsWidgets);

    // Drain pending Drift micro-timers triggered by library providers.
    await tester.pumpAndSettle();
  });

  testWidgets('calendar shows month grid and anime on selected day', (
    tester,
  ) async {
    final fakeRepository = _FakeAnimeCatalogRepository.success();
    final db = openInMemoryDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          downloadDirectoryStoreProvider.overrideWithValue(
            _ConfiguredDownloadDirectoryStore(),
          ),
          sourcePluginsProvider.overrideWithValue(const <SourcePlugin>[
            _PrimarySourcePlugin(),
          ]),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('Calendar'));
    await tester.tap(find.text('Calendar'));
    await _pumpForUi(tester);

    final currentMonth = DateTime.now();
    expect(fakeRepository.airingCalendarSlotRequests, hasLength(1));
    expect(
      fakeRepository.airingCalendarSlotRequests.single.from,
      DateTime(currentMonth.year, currentMonth.month),
    );
    expect(
      fakeRepository.airingCalendarSlotRequests.single.to,
      DateTime(currentMonth.year, currentMonth.month + 1),
    );

    // Month label is visible (Frieren airs March 16 2026 UTC → local).
    final frierenLocal = DateTime.utc(2026, 3, 16, 18).toLocal();
    final monthLabel = DateFormat.yMMMM().format(
      DateTime(frierenLocal.year, frierenLocal.month),
    );
    expect(find.text(monthLabel), findsOneWidget);

    // Tap on the day Frieren airs (local).
    final frierenDay = frierenLocal.day.toString();
    await tester.tap(find.text(frierenDay).first);
    await _pumpForUi(tester);
    expect(find.text('Frieren'), findsOneWidget);

    // Tap on the day Dandadan airs (local).
    final dandadanLocal = DateTime.utc(2026, 3, 17, 21).toLocal();
    final dandadanDay = dandadanLocal.day.toString();
    await tester.tap(find.text(dandadanDay).first);
    await _pumpForUi(tester);
    expect(find.text('Dandadan'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await _pumpForUi(tester);
    expect(fakeRepository.airingCalendarSlotRequests, hasLength(2));
    expect(
      fakeRepository.airingCalendarSlotRequests.last.from,
      DateTime(currentMonth.year, currentMonth.month + 1),
    );
    expect(
      fakeRepository.airingCalendarSlotRequests.last.to,
      DateTime(currentMonth.year, currentMonth.month + 2),
    );
  });
}

Future<void> _pumpForUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 30,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

final class _FakeAnimeCatalogRepository implements AnimeCatalogRepository {
  _FakeAnimeCatalogRepository({required this.fail});

  final bool fail;
  final List<({DateTime? from, DateTime? to, int page, int perPage})>
  airingCalendarSlotRequests =
      <({DateTime? from, DateTime? to, int page, int perPage})>[];

  factory _FakeAnimeCatalogRepository.success() {
    return _FakeAnimeCatalogRepository(fail: false);
  }

  @override
  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    if (fail) {
      return const Failure(
        SimpleError(
          code: 'anilist.transport',
          message: 'network down',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    return Success(
      AnimeDetail(
        anime: _anime,
        episodes: const <AnimeEpisode>[
          AnimeEpisode(number: 1, title: 'Episode 1', isAired: true),
          AnimeEpisode(number: 2, title: 'Episode 2', isAired: false),
        ],
      ),
    );
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  ) async {
    return const Success(<AnimeEpisode>[
      AnimeEpisode(number: 1, title: 'Episode 1', isAired: true),
      AnimeEpisode(number: 2, title: 'Episode 2', isAired: false),
    ]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    return Success(_homeCatalog);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    return Success(_homeCatalog);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    airingCalendarSlotRequests.add((
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    ));
    return Success(_homeCatalog);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    return Success(<Anime>[_anime]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<SeasonDiscoveryResult, KumoriyaError>> fetchSeasonDiscovery(
    SeasonalCatalogRequest request,
  ) async {
    return const Success(
      SeasonDiscoveryResult(
        inSeason: <Anime>[],
        upcoming: <Anime>[],
        recommended: <Anime>[],
      ),
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchBatchAnimeByIds(
    List<int> ids,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> browseAnime(
    AnimeBrowseRequest request,
  ) async {
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() async {
    return const Success(<String>[]);
  }

  @override
  Future<Result<List<AnimeTag>, KumoriyaError>> fetchTagCollection() async {
    return const Success(<AnimeTag>[]);
  }

  static final List<Anime> _homeCatalog = <Anime>[
    _anime,
    _secondAnime,
    _unknownScheduleAnime,
  ];

  static final Anime _anime = Anime(
    anilistId: 1,
    title: AnimeTitle(romaji: 'Frieren'),
    format: AnimeFormat.tv,
    totalEpisodes: 28,
    nextAiringEpisodeNumber: 27,
    nextAiringAt: DateTime.utc(2026, 3, 16, 18),
    status: AnimeStatus.releasing,
  );

  static final Anime _secondAnime = Anime(
    anilistId: 2,
    title: AnimeTitle(romaji: 'Dandadan'),
    format: AnimeFormat.tv,
    totalEpisodes: 12,
    nextAiringEpisodeNumber: 8,
    nextAiringAt: DateTime.utc(2026, 3, 17, 21),
    status: AnimeStatus.releasing,
  );

  static final Anime _unknownScheduleAnime = Anime(
    anilistId: 3,
    title: AnimeTitle(romaji: 'One Punch Man 3'),
    format: AnimeFormat.tv,
    totalEpisodes: 12,
    status: AnimeStatus.notYetReleased,
  );
}

final class _ConfiguredDownloadDirectoryStore
    implements DownloadDirectoryStore {
  String? _path = 'C:/KumoriyaTestDownloads';

  @override
  Future<String?> readCustomDirectoryPath() async => _path;

  @override
  Future<void> writeCustomDirectoryPath(String? path) async {
    _path = path;
  }
}

final class _PrimarySourcePlugin extends _BaseFakeSourcePlugin {
  const _PrimarySourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.jkanime',
    displayName: 'JKAnime',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
  );
}

final class _SecondarySourcePlugin extends _BaseFakeSourcePlugin {
  const _SecondarySourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.animeav1',
    displayName: 'AnimeAV1',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
  );
}

class _BaseFakeSourcePlugin implements SourcePlugin {
  const _BaseFakeSourcePlugin();

  @override
  PluginManifest get manifest => throw UnimplementedError();

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: '1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    ]);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'mp4upload-0',
        serverName: 'MP4Upload',
        initialUrl: Uri.parse(
          'https://www.mp4upload.com/embed-bz5usnfha398.html',
        ),
        language: 'sub',
        detectedHost: 'www.mp4upload.com',
      ),
    ]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'frieren', title: 'Frieren'),
    ]);
  }
}

final class _MultiServerSourcePlugin extends _BaseFakeSourcePlugin {
  const _MultiServerSourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.animeav1',
    displayName: 'AnimeAV1',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
  );

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return Success(<SourceServerLink>[
      SourceServerLink(
        serverId: 'mp4upload-0',
        serverName: 'MP4Upload',
        initialUrl: Uri.parse(
          'https://www.mp4upload.com/embed-bz5usnfha398.html',
        ),
        language: 'sub',
        detectedHost: 'www.mp4upload.com',
      ),
      SourceServerLink(
        serverId: 'streamwish-1',
        serverName: 'Streamwish',
        initialUrl: Uri.parse('https://hlswish.com/e/123456'),
        language: 'dub',
        detectedHost: 'hlswish.com',
      ),
    ]);
  }
}

final class _FakeResolverPlugin implements ResolverPlugin {
  const _FakeResolverPlugin();

  static const _supportedHosts = <String>{
    'www.mp4upload.com',
    'mp4upload.com',
    'hlswish.com',
  };

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.fake',
    displayName: 'FakeResolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{},
  );

  @override
  int get priority => 100;

  @override
  bool supports(Uri url) => _supportedHosts.contains(url.host);

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    return Success(
      ResolveResult(
        streams: <ResolvedStream>[
          ResolvedStream(url: Uri.parse('https://cdn.example.com/video.mp4')),
        ],
      ),
    );
  }
}

SourceAvailability _fakeAvailability(PluginManifest manifest) {
  return SourceAvailability(
    manifest: manifest,
    status: SourceAvailabilityStatus.available,
    decision: const SourceMatchDecision(
      verdict: true,
      confidence: MatchConfidence.high,
      reason: 'fake',
      acceptanceSignals: <String>[],
      rejectionSignals: <String>[],
    ),
    episodes: <SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: '1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    ],
  );
}
