import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'package:kumoriya_app/src/app/kumoriya_app.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';

void main() {
  testWidgets(
    'home -> detail shows multi-source section and navigates to source episodes',
    (tester) async {
      final fakeRepository = _FakeAnimeCatalogRepository.success();
      const fakeSourcePlugins = <SourcePlugin>[
        _PrimarySourcePlugin(),
        _SecondarySourcePlugin(),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
            sourcePluginsProvider.overrideWithValue(fakeSourcePlugins),
          ],
          child: const KumoriyaApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Frieren'), findsOneWidget);

      await tester.tap(find.text('Frieren').first);
      await tester.pumpAndSettle();

      expect(find.text('Source availability'), findsOneWidget);
      expect(find.textContaining('Open recommended source'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);

      await tester.tap(find.text('Episodes').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('episodes | Frieren'), findsOneWidget);
      expect(find.text('View servers'), findsWidgets);
    },
  );

  testWidgets('source server links route resolves from a secondary source', (
    tester,
  ) async {
    final fakeRepository = _FakeAnimeCatalogRepository.success();
    const fakeSourcePlugins = <SourcePlugin>[
      _UnavailableSourcePlugin(),
      _SecondarySourcePlugin(),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          sourcePluginsProvider.overrideWithValue(fakeSourcePlugins),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Frieren').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Episodes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View servers').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('servers'), findsOneWidget);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
          sourcePluginsProvider.overrideWithValue(const <SourcePlugin>[
            _PrimarySourcePlugin(),
          ]),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Frieren').first);
    await tester.pumpAndSettle();

    expect(find.text('Disponibilidad de fuentes'), findsOneWidget);
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

final class _UnavailableSourcePlugin extends _BaseFakeSourcePlugin {
  const _UnavailableSourcePlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.jkanime',
    displayName: 'JKAnime',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'other', title: 'Other Show'),
    ]);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return const Success(<SourceEpisode>[]);
  }
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
