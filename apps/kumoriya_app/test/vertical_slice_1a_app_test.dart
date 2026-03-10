import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage_flutter.dart';

import 'package:kumoriya_app/src/app/kumoriya_app.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';

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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
            sourcePluginsProvider.overrideWithValue(fakeSourcePlugins),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const KumoriyaApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Frieren'), findsOneWidget);

      await tester.tap(find.text('Frieren').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ready in'), findsOneWidget);
      expect(find.text('JKAnime'), findsOneWidget);
      expect(find.text('AnimeAV1'), findsOneWidget);

      // Episodes are inline on the detail page (no separate tab).
      // Scroll down to reach the episode section.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Episode preview'), findsOneWidget);
      expect(find.text('Play now'), findsWidgets);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          sourcePluginsProvider.overrideWithValue(fakeSourcePlugins),
          resolverPluginsProvider.overrideWithValue(fakeResolverPlugins),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Frieren').first);
    await tester.pumpAndSettle();

    // Source availability should have resolved with playable sources.
    expect(find.textContaining('Ready in'), findsOneWidget);

    // Scroll until a 'Play now' label becomes visible (sliver-lazy build).
    await tester.scrollUntilVisible(
      find.text('Play now'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify the episode card has a play icon (playable sources present).
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsWidgets);

    await tester.tap(find.text('Play now').first);
    await tester.pumpAndSettle();

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          sourcePluginsProvider.overrideWithValue(const <SourcePlugin>[
            _PrimarySourcePlugin(),
          ]),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Frieren').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Disponible en'), findsOneWidget);
  });
}

final class _FakeAnimeCatalogRepository implements AnimeCatalogRepository {
  _FakeAnimeCatalogRepository({required this.fail});

  final bool fail;

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
        synopsis: 'A fantasy story.',
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
    return Success(<Anime>[_anime]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    return Success(<Anime>[_anime]);
  }

  static const Anime _anime = Anime(
    anilistId: 1,
    title: AnimeTitle(romaji: 'Frieren'),
    format: AnimeFormat.tv,
    totalEpisodes: 28,
    status: AnimeStatus.releasing,
  );
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
  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url) async {
    return Success(<ResolvedStream>[
      ResolvedStream(url: Uri.parse('https://cdn.example.com/video.mp4')),
    ]);
  }
}
