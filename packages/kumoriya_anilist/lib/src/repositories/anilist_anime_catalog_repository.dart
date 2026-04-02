import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../contracts/anilist_metadata_gateway.dart';
import '../errors/anilist_error.dart';
import '../mappers/anilist_anime_mapper.dart';

final class AnilistAnimeCatalogRepository implements AnimeCatalogRepository {
  AnilistAnimeCatalogRepository({required AnilistMetadataGateway gateway})
    : _gateway = gateway;

  final AnilistMetadataGateway _gateway;

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _gateway.fetchHomeCatalog(
      page: page,
      perPage: perPage,
    );
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _gateway.fetchSeasonCatalog(request);
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchUpcomingSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _gateway.fetchUpcomingSeasonCatalog(request);
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchSeasonRecommendations(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _gateway.fetchSeasonRecommendations(request);
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final result = await _gateway.fetchAiringCalendar(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    );
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final result = await _gateway.fetchAiringCalendarSlots(
      from: from,
      to: to,
      page: page,
      perPage: perPage,
    );
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(
    AnimeSearchRequest request,
  ) async {
    final result = await _gateway.searchAnime(
      query: request.query,
      page: request.page,
      perPage: request.perPage,
    );

    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<AnimeDetail, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    final result = await _gateway.fetchAnimeDetail(anilistId);
    return result.fold(
      onSuccess: (media) {
        try {
          return Success(AnilistAnimeMapper.mapDetail(media));
        } on FormatException catch (error) {
          return Failure(
            AnilistMappingError(message: 'Failed to map anime detail: $error'),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<List<AnimeEpisode>, KumoriyaError>> fetchAnimeEpisodes(
    int anilistId,
  ) async {
    final result = await _gateway.fetchAnimeDetail(anilistId);

    return result.fold(
      onSuccess: (media) {
        try {
          return Success(AnilistAnimeMapper.mapEpisodes(media));
        } on FormatException catch (error) {
          return Failure(
            AnilistMappingError(message: 'Failed to map episodes: $error'),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<SeasonDiscoveryResult, KumoriyaError>> fetchSeasonDiscovery(
    SeasonalCatalogRequest request,
  ) async {
    final result = await _gateway.fetchSeasonDiscovery(request);
    return result.fold(
      onSuccess: (sections) {
        try {
          final currentMedia =
              sections['current'] ?? const <Map<String, dynamic>>[];
          final carryoverMedia =
              sections['carryover'] ?? const <Map<String, dynamic>>[];

          // Merge current + carryover, dedup by ID, sort by trending.
          final merged = <int, Map<String, dynamic>>{};
          for (final item in currentMedia) {
            final animeId = item['id'];
            if (animeId is int) {
              merged[animeId] = item;
            }
          }
          for (final item in carryoverMedia) {
            final animeId = item['id'];
            if (animeId is int) {
              merged.putIfAbsent(animeId, () => item);
            }
          }
          final sortedCurrent = merged.values.toList(growable: false)
            ..sort(
              (left, right) =>
                  _trendingScore(right).compareTo(_trendingScore(left)),
            );

          final upcomingMedia =
              sections['upcoming'] ?? const <Map<String, dynamic>>[];
          final recommendedMedia =
              sections['recommended'] ?? const <Map<String, dynamic>>[];

          return Success(
            SeasonDiscoveryResult(
              inSeason: sortedCurrent
                  .map(AnilistAnimeMapper.mapAnime)
                  .toList(growable: false),
              upcoming: upcomingMedia
                  .map(AnilistAnimeMapper.mapAnime)
                  .toList(growable: false),
              recommended: recommendedMedia
                  .map(AnilistAnimeMapper.mapAnime)
                  .toList(growable: false),
            ),
          );
        } on FormatException catch (error) {
          return Failure(
            AnilistMappingError(
              message: 'Failed to map season discovery payload: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<List<Anime>, KumoriyaError>> fetchBatchAnimeByIds(
    List<int> ids,
  ) async {
    final result = await _gateway.fetchBatchAnimeByIds(ids);
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  static int _trendingScore(Map<String, dynamic> media) {
    final trending = media['trending'];
    return trending is int ? trending : -1;
  }

  Result<List<Anime>, KumoriyaError> _mapAnimeList(
    List<Map<String, dynamic>> data,
  ) {
    try {
      final anime = data
          .map(AnilistAnimeMapper.mapAnime)
          .toList(growable: false);
      return Success(anime);
    } on FormatException catch (error) {
      return Failure(
        AnilistMappingError(
          message: 'Failed to map anime catalog payload: $error',
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Browse / Discover
  // -------------------------------------------------------------------------

  @override
  Future<Result<List<Anime>, KumoriyaError>> browseAnime(
    AnimeBrowseRequest request,
  ) async {
    final result = await _gateway.browseAnime(
      search: request.search,
      genres: request.genres,
      tags: request.tags,
      formats: request.formats?.map(_mapFormat).toList(growable: false),
      season: request.season != null ? _mapSeason(request.season!) : null,
      seasonYear: request.seasonYear,
      statuses: request.statuses?.map(_mapStatus).toList(growable: false),
      sort: _mapSortType(request.sort),
      page: request.page,
      perPage: request.perPage,
    );
    return result.fold(onSuccess: _mapAnimeList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() {
    return _gateway.fetchGenreCollection();
  }

  @override
  Future<Result<List<AnimeTag>, KumoriyaError>> fetchTagCollection() async {
    final result = await _gateway.fetchTagCollection();
    return result.fold(
      onSuccess: (data) {
        final tags = data
            .where((t) => t['isAdult'] != true)
            .map(
              (t) => AnimeTag(
                name: t['name'] as String? ?? '',
                description: t['description'] as String?,
                category: t['category'] as String?,
                isAdult: t['isAdult'] as bool? ?? false,
              ),
            )
            .where((t) => t.name.isNotEmpty)
            .toList(growable: false);
        return Success(tags);
      },
      onFailure: Failure.new,
    );
  }

  static String _mapFormat(AnimeFormat format) {
    return switch (format) {
      AnimeFormat.tv => 'TV',
      AnimeFormat.movie => 'MOVIE',
      AnimeFormat.ova => 'OVA',
      AnimeFormat.ona => 'ONA',
      AnimeFormat.special => 'SPECIAL',
      AnimeFormat.unknown => 'TV',
    };
  }

  static String _mapSeason(AnimeSeason season) {
    return switch (season) {
      AnimeSeason.winter => 'WINTER',
      AnimeSeason.spring => 'SPRING',
      AnimeSeason.summer => 'SUMMER',
      AnimeSeason.fall => 'FALL',
    };
  }

  static String _mapStatus(AnimeStatus status) {
    return switch (status) {
      AnimeStatus.finished => 'FINISHED',
      AnimeStatus.releasing => 'RELEASING',
      AnimeStatus.notYetReleased => 'NOT_YET_RELEASED',
      AnimeStatus.cancelled => 'CANCELLED',
      AnimeStatus.hiatus => 'HIATUS',
      AnimeStatus.unknown => 'FINISHED',
    };
  }

  static List<String> _mapSortType(AnimeSortType sort) {
    return switch (sort) {
      AnimeSortType.trending => const ['TRENDING_DESC'],
      AnimeSortType.score => const ['SCORE_DESC'],
      AnimeSortType.popularity => const ['POPULARITY_DESC'],
      AnimeSortType.favourites => const ['FAVOURITES_DESC'],
      AnimeSortType.startDate => const ['START_DATE_DESC'],
      AnimeSortType.titleRomaji => const ['TITLE_ROMAJI'],
    };
  }
}
