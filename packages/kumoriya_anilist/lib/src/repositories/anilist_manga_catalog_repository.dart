import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../contracts/anilist_metadata_gateway.dart';
import '../errors/anilist_error.dart';
import '../mappers/anilist_manga_mapper.dart';

/// AniList-backed implementation of [MangaCatalogRepository].
///
/// `fetchMangaChapters` returns an empty list: AniList does not expose
/// per-chapter metadata. The application layer composes this repository
/// with a `MangaSourcePlugin` to populate the chapter list.
final class AnilistMangaCatalogRepository implements MangaCatalogRepository {
  AnilistMangaCatalogRepository({required AnilistMetadataGateway gateway})
    : _gateway = gateway;

  final AnilistMetadataGateway _gateway;

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchHomeCatalog({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _gateway.fetchMangaHomeCatalog(
      page: page,
      perPage: perPage,
    );
    return result.fold(onSuccess: _mapMangaList, onFailure: Failure.new);
  }

  @override
  Future<Result<MangaHomeSections, KumoriyaError>> fetchHomeSections({
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _gateway.fetchMangaHomeSections(
      page: page,
      perPage: perPage,
    );
    return result.fold(
      onSuccess: (sections) {
        try {
          return Success(
            MangaHomeSections(
              trending: _mapShelf(sections['trending']),
              popular: _mapShelf(sections['popular']),
              latest: _mapShelf(sections['latest']),
              topRated: _mapShelf(sections['topRated']),
            ),
          );
        } on FormatException catch (error) {
          return Failure(
            AnilistMappingError(
              message: 'Failed to map manga home sections: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  static List<Manga> _mapShelf(List<Map<String, dynamic>>? shelf) {
    if (shelf == null || shelf.isEmpty) return const <Manga>[];
    return shelf.map(AnilistMangaMapper.mapManga).toList(growable: false);
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> searchManga(
    MangaSearchRequest request,
  ) async {
    final result = await _gateway.searchManga(
      query: request.query,
      page: request.page,
      perPage: request.perPage,
    );
    return result.fold(onSuccess: _mapMangaList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> browseManga(
    MangaBrowseRequest request,
  ) async {
    final result = await _gateway.browseManga(
      search: request.search,
      genres: request.genres,
      tags: request.tags,
      formats: request.formats?.map(_mapFormat).toList(growable: false),
      statuses: request.statuses?.map(_mapStatus).toList(growable: false),
      countryOfOrigin: request.countriesOfOrigin?.isNotEmpty == true
          ? request.countriesOfOrigin!.first.code
          : null,
      sort: _mapSortType(request.sort),
      page: request.page,
      perPage: request.perPage,
    );
    return result.fold(onSuccess: _mapMangaList, onFailure: Failure.new);
  }

  @override
  Future<Result<MangaDetail, KumoriyaError>> fetchMangaDetail(
    int anilistId,
  ) async {
    final result = await _gateway.fetchMangaDetail(anilistId);
    return result.fold(
      onSuccess: (media) {
        try {
          return Success(AnilistMangaMapper.mapDetail(media));
        } on FormatException catch (error) {
          return Failure(
            AnilistMappingError(message: 'Failed to map manga detail: $error'),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  /// AniList does not expose per-chapter metadata. The chapter list is
  /// authoritative on the source plugin, not on AniList. This default
  /// returns an empty list; the application-layer repository that
  /// composes AniList with a `MangaSourcePlugin` overrides this with
  /// real data.
  @override
  Future<Result<List<MangaChapter>, KumoriyaError>> fetchMangaChapters(
    int anilistId,
  ) async {
    return const Success(<MangaChapter>[]);
  }

  @override
  Future<Result<List<Manga>, KumoriyaError>> fetchBatchMangaByIds(
    List<int> ids,
  ) async {
    final result = await _gateway.fetchBatchMangaByIds(ids);
    return result.fold(onSuccess: _mapMangaList, onFailure: Failure.new);
  }

  @override
  Future<Result<List<String>, KumoriyaError>> fetchGenreCollection() {
    return _gateway.fetchGenreCollection();
  }

  @override
  Future<Result<List<MangaTag>, KumoriyaError>> fetchTagCollection() async {
    final result = await _gateway.fetchTagCollection();
    return result.fold(
      onSuccess: (data) {
        final tags = data
            .where((t) => t['isAdult'] != true)
            .map(
              (t) => MangaTag(
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

  Result<List<Manga>, KumoriyaError> _mapMangaList(
    List<Map<String, dynamic>> data,
  ) {
    try {
      final manga = data
          .map(AnilistMangaMapper.mapManga)
          .toList(growable: false);
      return Success(manga);
    } on FormatException catch (error) {
      return Failure(
        AnilistMappingError(
          message: 'Failed to map manga catalog payload: $error',
        ),
      );
    }
  }

  static String _mapFormat(MangaFormat format) {
    return switch (format) {
      MangaFormat.manga => 'MANGA',
      MangaFormat.manhwa => 'MANHWA',
      MangaFormat.manhua => 'MANHUA',
      MangaFormat.oneShot => 'ONE_SHOT',
      MangaFormat.doujinshi => 'DOUJINSHI',
      // Unknown maps to MANGA as a defensive default — AniList rejects
      // bogus enum values with a 400 and we'd rather surface "all" than
      // an empty page.
      MangaFormat.unknown => 'MANGA',
    };
  }

  static String _mapStatus(MangaStatus status) {
    return switch (status) {
      MangaStatus.finished => 'FINISHED',
      MangaStatus.releasing => 'RELEASING',
      MangaStatus.notYetReleased => 'NOT_YET_RELEASED',
      MangaStatus.cancelled => 'CANCELLED',
      MangaStatus.hiatus => 'HIATUS',
      MangaStatus.unknown => 'FINISHED',
    };
  }

  static List<String> _mapSortType(MangaSortType sort) {
    return switch (sort) {
      MangaSortType.trending => const ['TRENDING_DESC'],
      MangaSortType.score => const ['SCORE_DESC'],
      MangaSortType.popularity => const ['POPULARITY_DESC'],
      MangaSortType.favourites => const ['FAVOURITES_DESC'],
      MangaSortType.startDate => const ['START_DATE_DESC'],
      MangaSortType.titleRomaji => const ['TITLE_ROMAJI'],
      MangaSortType.chaptersDesc => const ['CHAPTERS_DESC'],
    };
  }
}
