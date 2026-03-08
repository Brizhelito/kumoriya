import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import 'package:kumoriya_app/src/app/kumoriya_app.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';

void main() {
  testWidgets('home -> search -> detail -> episodes flow is navigable', (
    tester,
  ) async {
    final fakeRepository = _FakeAnimeCatalogRepository.success();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Kumoriya'), findsOneWidget);
    expect(find.text('Frieren'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Search AniList'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'frieren');
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    expect(find.text('Frieren'), findsWidgets);

    await tester.tap(find.text('Frieren').first);
    await tester.pumpAndSettle();

    expect(find.text('Anime detail'), findsOneWidget);
    expect(find.text('View episode list'), findsOneWidget);

    await tester.tap(find.text('View episode list'));
    await tester.pumpAndSettle();

    expect(find.textContaining('episodes'), findsOneWidget);
    expect(find.textContaining('Episode 1'), findsOneWidget);
  });

  testWidgets('home page shows typed error with retry button', (tester) async {
    final fakeRepository = _FakeAnimeCatalogRepository.transportFailure();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const KumoriyaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach AniList. Check your connection and retry.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

final class _FakeAnimeCatalogRepository implements AnimeCatalogRepository {
  _FakeAnimeCatalogRepository({required this.fail});

  final bool fail;

  factory _FakeAnimeCatalogRepository.success() {
    return _FakeAnimeCatalogRepository(fail: false);
  }

  factory _FakeAnimeCatalogRepository.transportFailure() {
    return _FakeAnimeCatalogRepository(fail: true);
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
    if (fail) {
      return const Failure(
        SimpleError(
          code: 'anilist.transport',
          message: 'network down',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

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
    if (fail) {
      return const Failure(
        SimpleError(
          code: 'anilist.transport',
          message: 'network down',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    return Success(<Anime>[_anime]);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
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
