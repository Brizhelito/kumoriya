import 'dart:developer' as developer;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../client/anilist_graphql_client.dart';
import '../client/anilist_queries.dart';
import '../contracts/anilist_metadata_gateway.dart';
import '../errors/anilist_error.dart';

final class GraphqlAnilistMetadataGateway implements AnilistMetadataGateway {
  GraphqlAnilistMetadataGateway({required AnilistGraphqlClient client})
    : _client = client;

  final AnilistGraphqlClient _client;

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final seasonWindow = _currentSeasonWindow();
    final result = await _client.execute(
      query: trendingAnimeQuery,
      variables: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'season': seasonWindow.season,
        'seasonYear': seasonWindow.year,
        'statusIn': const <String>['RELEASING', 'NOT_YET_RELEASED'],
      },
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Trending payload does not contain Page.media list.',
            ),
          );
        }

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchHomeCatalog error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> fetchSeasonCatalog(
    SeasonalCatalogRequest request,
  ) async {
    final currentSeason = await _fetchSeasonMedia(
      query: seasonalAnimeQuery,
      request: request,
      status: 'RELEASING',
      logLabel: 'fetchSeasonCatalog.current',
    );
    if (currentSeason.isFailure) {
      return currentSeason;
    }

    final merged = <int, Map<String, dynamic>>{};
    final currentSeasonMedia = currentSeason.fold(
      onSuccess: (value) => value,
      onFailure: (_) => const <Map<String, dynamic>>[],
    );
    for (final item in currentSeasonMedia) {
      final animeId = item['id'];
      if (animeId is int) {
        merged[animeId] = item;
      }
    }

    if (request.includeCarryovers) {
      final previousRequest = _previousSeasonRequest(request);
      final carryovers = await _fetchSeasonMedia(
        query: seasonalAnimeQuery,
        request: previousRequest,
        status: 'RELEASING',
        logLabel: 'fetchSeasonCatalog.carryovers',
      );
      if (carryovers.isFailure) {
        return carryovers;
      }

      final carryoverMedia = carryovers.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <Map<String, dynamic>>[],
      );
      for (final item in carryoverMedia) {
        final animeId = item['id'];
        if (animeId is int) {
          merged.putIfAbsent(animeId, () => item);
        }
      }
    }

    final sorted = merged.values.toList(growable: false)
      ..sort(
        (left, right) => _trendingScore(right).compareTo(_trendingScore(left)),
      );
    return Success(sorted);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchUpcomingSeasonCatalog(SeasonalCatalogRequest request) {
    return _fetchSeasonMedia(
      query: upcomingSeasonAnimeQuery,
      request: request,
      logLabel: 'fetchUpcomingSeasonCatalog',
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchSeasonRecommendations(SeasonalCatalogRequest request) {
    return _fetchSeasonMedia(
      query: seasonRecommendationsQuery,
      request: request,
      logLabel: 'fetchSeasonRecommendations',
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final fromDate = (from ?? DateTime.now()).toUtc();
    final toDate = (to ?? fromDate.add(const Duration(days: 7))).toUtc();

    final dedupedById = <int, Map<String, dynamic>>{};
    var currentPage = page;
    var hasNextPage = true;

    while (hasNextPage) {
      final result = await _client.execute(
        query: airingCalendarQuery,
        variables: <String, dynamic>{
          'page': currentPage,
          'perPage': perPage,
          'airingAtGreater': fromDate.millisecondsSinceEpoch ~/ 1000,
          'airingAtLesser': toDate.millisecondsSinceEpoch ~/ 1000,
        },
      );

      final folded = result
          .fold<
            Result<
              ({List<Map<String, dynamic>> media, bool hasNext}),
              KumoriyaError
            >
          >(
            onSuccess: (data) {
              final media = _extractAiringScheduleMediaList(data);
              if (media == null) {
                return const Failure(
                  AnilistMappingError(
                    message:
                        'Airing calendar payload does not contain Page.airingSchedules list.',
                  ),
                );
              }

              final next = _extractHasNextPage(data) ?? false;
              return Success((media: media, hasNext: next));
            },
            onFailure: (err) {
              developer.log(
                'fetchAiringCalendar error [${err.code}/${err.kind.name}]: ${err.message}',
                name: 'GraphqlAnilistMetadataGateway',
              );
              return Failure(err);
            },
          );

      if (folded.isFailure) {
        return folded.fold(
          onSuccess: (_) => throw StateError('unreachable'),
          onFailure: Failure.new,
        );
      }

      final pageData = folded.fold(
        onSuccess: (value) => value,
        onFailure: (_) => throw StateError('unreachable'),
      );

      for (final media in pageData.media) {
        final animeId = media['id'];
        if (animeId is! int) {
          continue;
        }

        final existing = dedupedById[animeId];
        if (existing == null ||
            _nextAiringTimestamp(media) < _nextAiringTimestamp(existing)) {
          dedupedById[animeId] = media;
        }
      }

      hasNextPage = pageData.hasNext;
      currentPage += 1;
    }

    final merged = dedupedById.values.toList(growable: false)
      ..sort(
        (left, right) =>
            _nextAiringTimestamp(left).compareTo(_nextAiringTimestamp(right)),
      );
    return Success(merged);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendarSlots({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final fromDate = (from ?? DateTime.now()).toUtc();
    final toDate = (to ?? fromDate.add(const Duration(days: 7))).toUtc();

    final allEntries = <Map<String, dynamic>>[];
    var currentPage = page;
    var hasNextPage = true;

    while (hasNextPage) {
      final result = await _client.execute(
        query: airingCalendarQuery,
        variables: <String, dynamic>{
          'page': currentPage,
          'perPage': perPage,
          'airingAtGreater': fromDate.millisecondsSinceEpoch ~/ 1000,
          'airingAtLesser': toDate.millisecondsSinceEpoch ~/ 1000,
        },
      );

      final folded = result
          .fold<
            Result<
              ({List<Map<String, dynamic>> media, bool hasNext}),
              KumoriyaError
            >
          >(
            onSuccess: (data) {
              final media = _extractAiringScheduleEntries(data);
              if (media == null) {
                return const Failure(
                  AnilistMappingError(
                    message:
                        'Airing calendar payload does not contain Page.airingSchedules list.',
                  ),
                );
              }

              final next = _extractHasNextPage(data) ?? false;
              return Success((media: media, hasNext: next));
            },
            onFailure: (err) {
              developer.log(
                'fetchAiringCalendarSlots error [${err.code}/${err.kind.name}]: ${err.message}',
                name: 'GraphqlAnilistMetadataGateway',
              );
              return Failure(err);
            },
          );

      if (folded.isFailure) {
        return folded.fold(
          onSuccess: (_) => throw StateError('unreachable'),
          onFailure: Failure.new,
        );
      }

      final pageData = folded.fold(
        onSuccess: (value) => value,
        onFailure: (_) => throw StateError('unreachable'),
      );

      allEntries.addAll(pageData.media);
      hasNextPage = pageData.hasNext;
      currentPage += 1;
    }

    allEntries.sort(
      (left, right) =>
          _nextAiringTimestamp(left).compareTo(_nextAiringTimestamp(right)),
    );
    return Success(allEntries);
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchAnime({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _client.execute(
      query: searchAnimeQuery,
      variables: <String, dynamic>{
        'query': query,
        'page': page,
        'perPage': perPage,
      },
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Search payload does not contain Page.media list.',
            ),
          );
        }

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'searchAnime(query=$query) error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchAnimeDetail(
    int anilistId,
  ) async {
    final result = await _client.execute(
      query: animeDetailQuery,
      variables: <String, dynamic>{'id': anilistId},
    );

    return result.fold(
      onSuccess: (data) {
        final media = data['Media'];
        if (media == null) {
          return Failure(
            AnilistNotFoundError(
              message: 'No anime found for AniList id $anilistId.',
            ),
          );
        }

        if (media is! Map<String, dynamic>) {
          return const Failure(
            AnilistMappingError(message: 'Media payload is not a JSON object.'),
          );
        }

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchAnimeDetail(id=$anilistId) error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<Map<String, List<Map<String, dynamic>>>, KumoriyaError>>
  fetchSeasonDiscovery(SeasonalCatalogRequest request) async {
    final previous = _previousSeasonRequest(request);
    final result = await _client.execute(
      query: seasonDiscoveryQuery,
      variables: <String, dynamic>{
        'page': request.page,
        'perPage': request.perPage,
        'season': _mapSeason(request.season),
        'seasonYear': request.year,
        'prevSeason': _mapSeason(previous.season),
        'prevSeasonYear': previous.year,
        'includeCarryover': request.includeCarryovers,
      },
    );

    return result.fold(
      onSuccess: (data) {
        final sections = <String, List<Map<String, dynamic>>>{};
        for (final alias in const <String>[
          'current',
          'upcoming',
          'recommended',
          'carryover',
        ]) {
          final page = data[alias];
          if (page is! Map<String, dynamic>) continue;
          final media = page['media'];
          if (media is! List) continue;
          final mapped = <Map<String, dynamic>>[
            for (final item in media)
              if (item is Map<String, dynamic>) item,
          ];
          sections[alias] = mapped;
        }

        if (!sections.containsKey('current')) {
          return const Failure(
            AnilistMappingError(
              message:
                  'Season discovery payload does not contain current Page.media list.',
            ),
          );
        }

        return Success(sections);
      },
      onFailure: (err) {
        developer.log(
          'fetchSeasonDiscovery error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchAnimeByIds(List<int> ids, {int page = 1, int perPage = 50}) async {
    if (ids.isEmpty) {
      return const Success(<Map<String, dynamic>>[]);
    }

    final result = await _client.execute(
      query: batchAnimeByIdsQuery,
      variables: <String, dynamic>{
        'ids': ids,
        'page': page,
        'perPage': perPage,
      },
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Batch anime payload does not contain Page.media list.',
            ),
          );
        }

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchBatchAnimeByIds error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> _fetchSeasonMedia({
    required String query,
    required SeasonalCatalogRequest request,
    String? status,
    required String logLabel,
  }) async {
    final result = await _client.execute(
      query: query,
      variables: <String, dynamic>{
        'page': request.page,
        'perPage': request.perPage,
        'season': _mapSeason(request.season),
        'seasonYear': request.year,
        ...?status == null ? null : <String, dynamic>{'status': status},
      },
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return Failure(
            AnilistMappingError(
              message: '$logLabel payload does not contain Page.media list.',
            ),
          );
        }

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          '$logLabel error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  SeasonalCatalogRequest _previousSeasonRequest(
    SeasonalCatalogRequest request,
  ) {
    return switch (request.season) {
      AnimeSeason.winter => SeasonalCatalogRequest(
        season: AnimeSeason.fall,
        year: request.year - 1,
        page: request.page,
        perPage: request.perPage,
        includeCarryovers: false,
      ),
      AnimeSeason.spring => SeasonalCatalogRequest(
        season: AnimeSeason.winter,
        year: request.year,
        page: request.page,
        perPage: request.perPage,
        includeCarryovers: false,
      ),
      AnimeSeason.summer => SeasonalCatalogRequest(
        season: AnimeSeason.spring,
        year: request.year,
        page: request.page,
        perPage: request.perPage,
        includeCarryovers: false,
      ),
      AnimeSeason.fall => SeasonalCatalogRequest(
        season: AnimeSeason.summer,
        year: request.year,
        page: request.page,
        perPage: request.perPage,
        includeCarryovers: false,
      ),
    };
  }

  String _mapSeason(AnimeSeason season) {
    return switch (season) {
      AnimeSeason.winter => 'WINTER',
      AnimeSeason.spring => 'SPRING',
      AnimeSeason.summer => 'SUMMER',
      AnimeSeason.fall => 'FALL',
    };
  }

  ({String season, int year}) _currentSeasonWindow() {
    final now = DateTime.now().toUtc();
    return switch (now.month) {
      12 || 1 || 2 => (season: 'WINTER', year: now.year),
      3 || 4 || 5 => (season: 'SPRING', year: now.year),
      6 || 7 || 8 => (season: 'SUMMER', year: now.year),
      _ => (season: 'FALL', year: now.year),
    };
  }

  List<Map<String, dynamic>>? _extractMediaList(Map<String, dynamic> data) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) {
      return null;
    }

    final media = page['media'];
    if (media is! List) {
      return null;
    }

    final mapped = <Map<String, dynamic>>[];
    for (final item in media) {
      if (item is Map<String, dynamic>) {
        mapped.add(item);
      }
    }

    return mapped;
  }

  List<Map<String, dynamic>>? _extractAiringScheduleMediaList(
    Map<String, dynamic> data,
  ) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) {
      return null;
    }

    final schedules = page['airingSchedules'];
    if (schedules is! List) {
      return null;
    }

    final deduped = <int, Map<String, dynamic>>{};
    for (final item in schedules) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final media = item['media'];
      final animeId = media is Map<String, dynamic> ? media['id'] : null;
      if (media is! Map<String, dynamic> || animeId is! int) {
        continue;
      }

      if (media['isAdult'] == true) {
        continue;
      }

      final enrichedMedia = Map<String, dynamic>.from(media);
      enrichedMedia['nextAiringEpisode'] = <String, dynamic>{
        'episode': item['episode'],
        'airingAt': item['airingAt'],
      };

      final existing = deduped[animeId];
      if (existing == null ||
          _nextAiringTimestamp(enrichedMedia) <
              _nextAiringTimestamp(existing)) {
        deduped[animeId] = enrichedMedia;
      }
    }

    final result = deduped.values.toList(growable: false)
      ..sort(
        (left, right) =>
            _nextAiringTimestamp(left).compareTo(_nextAiringTimestamp(right)),
      );
    return result;
  }

  /// Like [_extractAiringScheduleMediaList] but returns every entry
  /// without deduplicating by anime ID.
  List<Map<String, dynamic>>? _extractAiringScheduleEntries(
    Map<String, dynamic> data,
  ) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) {
      return null;
    }

    final schedules = page['airingSchedules'];
    if (schedules is! List) {
      return null;
    }

    final entries = <Map<String, dynamic>>[];
    for (final item in schedules) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final media = item['media'];
      if (media is! Map<String, dynamic>) {
        continue;
      }

      final animeId = media['id'];
      if (animeId is! int) {
        continue;
      }

      if (media['isAdult'] == true) {
        continue;
      }

      final enrichedMedia = Map<String, dynamic>.from(media);
      enrichedMedia['nextAiringEpisode'] = <String, dynamic>{
        'episode': item['episode'],
        'airingAt': item['airingAt'],
      };
      entries.add(enrichedMedia);
    }

    return entries;
  }

  bool? _extractHasNextPage(Map<String, dynamic> data) {
    final page = data['Page'];
    if (page is! Map<String, dynamic>) {
      return null;
    }

    final pageInfo = page['pageInfo'];
    if (pageInfo is! Map<String, dynamic>) {
      return null;
    }

    final hasNextPage = pageInfo['hasNextPage'];
    return hasNextPage is bool ? hasNextPage : null;
  }

  int _nextAiringTimestamp(Map<String, dynamic> media) {
    final nextAiring = media['nextAiringEpisode'];
    if (nextAiring is! Map<String, dynamic>) {
      return 1 << 31;
    }

    final airingAt = nextAiring['airingAt'];
    return airingAt is int ? airingAt : 1 << 31;
  }

  int _trendingScore(Map<String, dynamic> media) {
    final trending = media['trending'];
    return trending is int ? trending : -1;
  }

  // -------------------------------------------------------------------------
  // Browse / Discover
  // -------------------------------------------------------------------------

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> browseAnime({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<String>? formats,
    String? season,
    int? seasonYear,
    List<String>? statuses,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'search': ?search,
      'genres': ?genres,
      'tags': ?tags,
      'formatIn': ?formats,
      'season': ?season,
      'seasonYear': ?seasonYear,
      'statusIn': ?statuses,
      'sort': ?sort,
    };

    final result = await _client.execute(
      query: browseAnimeQuery,
      variables: variables,
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Browse payload does not contain Page.media list.',
            ),
          );
        }

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'browseAnime error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() async {
    final result = await _client.execute(
      query: genreCollectionQuery,
      variables: const <String, dynamic>{},
    );

    return result.fold(
      onSuccess: (data) {
        final raw = data['GenreCollection'];
        if (raw is! List) {
          return const Failure(
            AnilistMappingError(
              message: 'GenreCollection payload is not a list.',
            ),
          );
        }

        final genres = <String>[
          for (final item in raw)
            if (item is String) item,
        ];
        return Success(genres);
      },
      onFailure: (err) {
        developer.log(
          'fetchGenreCollection error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  // -------------------------------------------------------------------------
  // Manga
  // -------------------------------------------------------------------------

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchMangaHomeCatalog({int page = 1, int perPage = 20}) async {
    final result = await _client.execute(
      query: trendingMangaQuery,
      variables: <String, dynamic>{'page': page, 'perPage': perPage},
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message:
                  'Trending manga payload does not contain Page.media list.',
            ),
          );
        }
        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchMangaHomeCatalog error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> searchManga({
    required String query,
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _client.execute(
      query: searchMangaQuery,
      variables: <String, dynamic>{
        'query': query,
        'page': page,
        'perPage': perPage,
      },
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Manga search payload does not contain Page.media list.',
            ),
          );
        }
        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'searchManga(query=$query) error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) async {
    final result = await _client.execute(
      query: mangaDetailQuery,
      variables: <String, dynamic>{'id': anilistId},
    );

    return result.fold(
      onSuccess: (data) {
        final media = data['Media'];
        if (media == null) {
          return Failure(
            AnilistNotFoundError(
              message: 'No manga found for AniList id $anilistId.',
            ),
          );
        }
        if (media is! Map<String, dynamic>) {
          return const Failure(
            AnilistMappingError(message: 'Manga payload is not a JSON object.'),
          );
        }
        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchMangaDetail(id=$anilistId) error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchBatchMangaByIds(List<int> ids, {int page = 1, int perPage = 50}) async {
    if (ids.isEmpty) {
      return const Success(<Map<String, dynamic>>[]);
    }

    final result = await _client.execute(
      query: batchMangaByIdsQuery,
      variables: <String, dynamic>{
        'ids': ids,
        'page': page,
        'perPage': perPage,
      },
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Batch manga payload does not contain Page.media list.',
            ),
          );
        }
        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchBatchMangaByIds error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>> browseManga({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<String>? formats,
    List<String>? statuses,
    String? countryOfOrigin,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'search': ?search,
      'genres': ?genres,
      'tags': ?tags,
      'formatIn': ?formats,
      'statusIn': ?statuses,
      'countryOfOrigin': ?countryOfOrigin,
      'sort': ?sort,
    };

    final result = await _client.execute(
      query: browseMangaQuery,
      variables: variables,
    );

    return result.fold(
      onSuccess: (data) {
        final media = _extractMediaList(data);
        if (media == null) {
          return const Failure(
            AnilistMappingError(
              message: 'Browse manga payload does not contain Page.media list.',
            ),
          );
        }
        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'browseManga error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchTagCollection() async {
    final result = await _client.execute(
      query: tagCollectionQuery,
      variables: const <String, dynamic>{},
    );

    return result.fold(
      onSuccess: (data) {
        final raw = data['MediaTagCollection'];
        if (raw is! List) {
          return const Failure(
            AnilistMappingError(
              message: 'MediaTagCollection payload is not a list.',
            ),
          );
        }

        final tags = <Map<String, dynamic>>[
          for (final item in raw)
            if (item is Map<String, dynamic>) item,
        ];
        return Success(tags);
      },
      onFailure: (err) {
        developer.log(
          'fetchTagCollection error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
    );
  }
}
