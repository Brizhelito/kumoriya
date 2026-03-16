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
}
