import 'dart:developer' as developer;
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
  Future<Result<List<Map<String, dynamic>>, KumoriyaError>>
  fetchAiringCalendar({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    final fromDate = (from ?? DateTime.now()).toUtc();
    final toDate = (to ?? fromDate.add(const Duration(days: 7))).toUtc();

    final result = await _client.execute(
      query: airingCalendarQuery,
      variables: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'airingAtGreater': fromDate.millisecondsSinceEpoch ~/ 1000,
        'airingAtLesser': toDate.millisecondsSinceEpoch ~/ 1000,
      },
    );

    return result.fold(
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

        return Success(media);
      },
      onFailure: (err) {
        developer.log(
          'fetchAiringCalendar error [${err.code}/${err.kind.name}]: ${err.message}',
          name: 'GraphqlAnilistMetadataGateway',
        );
        return Failure(err);
      },
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

  int _nextAiringTimestamp(Map<String, dynamic> media) {
    final nextAiring = media['nextAiringEpisode'];
    if (nextAiring is! Map<String, dynamic>) {
      return 1 << 31;
    }

    final airingAt = nextAiring['airingAt'];
    return airingAt is int ? airingAt : 1 << 31;
  }
}
