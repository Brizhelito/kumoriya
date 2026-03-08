import 'package:kumoriya_core/kumoriya_core.dart';

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
    final result = await _client.execute(
      query: trendingAnimeQuery,
      variables: <String, dynamic>{'page': page, 'perPage': perPage},
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
      onFailure: Failure.new,
    );
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
      onFailure: Failure.new,
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
      onFailure: Failure.new,
    );
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
}
