import 'package:kumoriya_core/kumoriya_core.dart';

import '../client/mangaupdates_http_client.dart';
import '../contracts/mangaupdates_metadata_gateway.dart';
import '../errors/mangaupdates_error.dart';
import '../mappers/mangaupdates_group_mapper.dart';
import '../mappers/mangaupdates_release_mapper.dart';
import '../mappers/mangaupdates_series_mapper.dart';
import '../models/mangaupdates_group.dart';
import '../models/mangaupdates_release.dart';
import '../models/mangaupdates_series.dart';

/// HTTP-backed implementation of [MangaUpdatesMetadataGateway].
final class HttpMangaUpdatesMetadataGateway
    implements MangaUpdatesMetadataGateway {
  HttpMangaUpdatesMetadataGateway({required MangaUpdatesHttpClient client})
    : _client = client;

  final MangaUpdatesHttpClient _client;

  @override
  Future<Result<List<MangaUpdatesSeries>, KumoriyaError>> searchSeries({
    required String query,
    int page = 1,
    int perPage = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Success(<MangaUpdatesSeries>[]);
    }

    final response = await _client.postJson(
      path: 'series/search',
      body: <String, dynamic>{
        'search': trimmed,
        'page': page,
        'perpage': perPage,
      },
    );

    return response.fold(
      onSuccess: (envelope) {
        final results = envelope['results'];
        if (results is! List) {
          return const Failure(
            MangaUpdatesMappingError(
              message:
                  'MangaUpdates search payload does not contain a `results` array.',
            ),
          );
        }
        try {
          final out = <MangaUpdatesSeries>[];
          for (final entry in results) {
            if (entry is! Map<String, dynamic>) continue;
            final record = entry['record'];
            if (record is! Map<String, dynamic>) continue;
            out.add(MangaUpdatesSeriesMapper.map(record));
          }
          return Success(List<MangaUpdatesSeries>.unmodifiable(out));
        } on FormatException catch (error) {
          return Failure(
            MangaUpdatesMappingError(
              message: 'Failed to map MangaUpdates search results: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<MangaUpdatesSeries, KumoriyaError>> fetchSeriesById(
    int id,
  ) async {
    final response = await _client.getJson(path: 'series/$id');
    return response.fold(
      onSuccess: (envelope) {
        try {
          return Success(MangaUpdatesSeriesMapper.map(envelope));
        } on FormatException catch (error) {
          return Failure(
            MangaUpdatesMappingError(
              message: 'Failed to map MangaUpdates series payload: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<MangaUpdatesGroup, KumoriyaError>> fetchGroupById(
    int id,
  ) async {
    final response = await _client.getJson(path: 'groups/$id');
    return response.fold(
      onSuccess: (envelope) {
        try {
          return Success(MangaUpdatesGroupMapper.map(envelope));
        } on FormatException catch (error) {
          return Failure(
            MangaUpdatesMappingError(
              message: 'Failed to map MangaUpdates group payload: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<List<MangaUpdatesRelease>, KumoriyaError>> searchReleases({
    int? seriesId,
    int? groupId,
    int page = 1,
    int perPage = 25,
  }) async {
    if (seriesId == null && groupId == null) {
      return const Failure(
        MangaUpdatesMappingError(
          message:
              'searchReleases requires at least one of seriesId or groupId.',
        ),
      );
    }

    final body = <String, dynamic>{'page': page, 'perpage': perPage};
    // The releases search endpoint accepts `search` + `search_type`
    // for series-scoped queries, and `groups` for group-scoped ones.
    if (seriesId != null) {
      body['search'] = seriesId.toString();
      body['search_type'] = 'series';
    }
    if (groupId != null) {
      body['groups'] = <int>[groupId];
    }

    final response = await _client.postJson(
      path: 'releases/search',
      body: body,
    );
    return response.fold(
      onSuccess: (envelope) {
        final results = envelope['results'];
        if (results is! List) {
          return const Failure(
            MangaUpdatesMappingError(
              message:
                  'MangaUpdates releases payload does not contain a `results` array.',
            ),
          );
        }
        try {
          final out = <MangaUpdatesRelease>[];
          for (final entry in results) {
            if (entry is! Map<String, dynamic>) continue;
            final record = entry['record'];
            if (record is! Map<String, dynamic>) continue;
            out.add(MangaUpdatesReleaseMapper.map(record));
          }
          return Success(List<MangaUpdatesRelease>.unmodifiable(out));
        } on FormatException catch (error) {
          return Failure(
            MangaUpdatesMappingError(
              message: 'Failed to map MangaUpdates release results: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }
}
