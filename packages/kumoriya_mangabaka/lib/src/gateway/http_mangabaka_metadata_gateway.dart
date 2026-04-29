import 'package:kumoriya_core/kumoriya_core.dart';

import '../client/mangabaka_http_client.dart';
import '../contracts/mangabaka_metadata_gateway.dart';
import '../errors/mangabaka_error.dart';
import '../mappers/mangabaka_series_mapper.dart';
import '../models/mangabaka_series.dart';

/// HTTP-backed implementation of [MangaBakaMetadataGateway].
final class HttpMangaBakaMetadataGateway implements MangaBakaMetadataGateway {
  HttpMangaBakaMetadataGateway({required MangaBakaHttpClient client})
    : _client = client;

  final MangaBakaHttpClient _client;

  @override
  Future<Result<List<MangaBakaSeries>, KumoriyaError>> searchSeries({
    required String query,
    int limit = 20,
    int page = 1,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Success(<MangaBakaSeries>[]);
    }

    final response = await _client.getJson(
      path: 'series/search',
      queryParameters: <String, dynamic>{
        'q': trimmed,
        'limit': limit,
        'page': page,
      },
    );

    return response.fold(
      onSuccess: (envelope) {
        final data = envelope['data'];
        if (data is! List) {
          return const Failure(
            MangaBakaMappingError(
              message:
                  'MangaBaka search payload does not contain a `data` array.',
            ),
          );
        }
        try {
          final mapped = <MangaBakaSeries>[];
          for (final entry in data) {
            if (entry is! Map<String, dynamic>) continue;
            mapped.add(MangaBakaSeriesMapper.map(entry));
          }
          return Success(List<MangaBakaSeries>.unmodifiable(mapped));
        } on FormatException catch (error) {
          return Failure(
            MangaBakaMappingError(
              message: 'Failed to map MangaBaka search results: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<MangaBakaSeries, KumoriyaError>> fetchSeriesById(
    int id, {
    bool followMerges = true,
  }) async {
    final initial = await _fetchOne(id);
    if (!followMerges) return initial;

    return initial.fold(
      onSuccess: (series) async {
        if (series.state != MangaBakaSeriesState.merged ||
            series.mergedWith == null ||
            series.mergedWith == series.id) {
          return Success(series);
        }
        // Single-hop merge follow to keep latency bounded.
        return _fetchOne(series.mergedWith!);
      },
      onFailure: (err) async => Failure(err),
    );
  }

  Future<Result<MangaBakaSeries, KumoriyaError>> _fetchOne(int id) async {
    final response = await _client.getJson(path: 'series/$id');
    return response.fold(
      onSuccess: (envelope) {
        final data = envelope['data'];
        if (data is! Map<String, dynamic>) {
          return const Failure(
            MangaBakaMappingError(
              message:
                  'MangaBaka series payload does not contain a `data` object.',
            ),
          );
        }
        try {
          return Success(MangaBakaSeriesMapper.map(data));
        } on FormatException catch (error) {
          return Failure(
            MangaBakaMappingError(
              message: 'Failed to map MangaBaka series payload: $error',
            ),
          );
        }
      },
      onFailure: Failure.new,
    );
  }
}
