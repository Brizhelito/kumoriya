import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/pages/home_page.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

void main() {
  test(
    'filterAiringTodayAnime keeps only same local-day entries in time order',
    () {
      final now = DateTime(2026, 3, 18, 10, 30);
      final result = filterAiringTodayAnime(<Anime>[
        _anime(
          1,
          'Late Tonight',
          DateTime(2026, 3, 18, 23, 45),
          AnimeStatus.releasing,
        ),
        _anime(
          2,
          'Already Aired Today',
          DateTime(2026, 3, 18, 8, 0),
          AnimeStatus.releasing,
        ),
        _anime(
          3,
          'Tomorrow Show',
          DateTime(2026, 3, 19, 0, 15),
          AnimeStatus.releasing,
        ),
        _anime(
          4,
          'Finished Show',
          DateTime(2026, 3, 18, 13, 0),
          AnimeStatus.finished,
        ),
      ], now);

      expect(
        result.map((anime) => anime.title.romaji).toList(growable: false),
        <String>['Already Aired Today', 'Late Tonight'],
      );
    },
  );

  test(
    'calendarCatalogProvider requests the calendar from local week start',
    () async {
      final repository = _CapturingAnimeCatalogRepository();
      final container = ProviderContainer(
        overrides: [
          animeCatalogRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(calendarCatalogProvider.future);

      final expectedStart = startOfLocalCalendarWeek(DateTime.now());
      expect(repository.lastFrom, expectedStart);
      expect(repository.lastTo, expectedStart.add(const Duration(days: 7)));
      expect(repository.lastPerPage, 100);
    },
  );
}

Anime _anime(int id, String title, DateTime nextAiringAt, AnimeStatus status) {
  return Anime(
    anilistId: id,
    title: AnimeTitle(romaji: title),
    status: status,
    format: AnimeFormat.tv,
    nextAiringAt: nextAiringAt,
  );
}

final class _CapturingAnimeCatalogRepository implements AnimeCatalogRepository {
  DateTime? lastFrom;
  DateTime? lastTo;
  int? lastPerPage;

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    lastFrom = from;
    lastTo = to;
    lastPerPage = perPage;
    return const Success(<Anime>[]);
  }

  @override
  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(int anilistId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) {
    throw UnimplementedError();
  }
}
