import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_mangabaka/kumoriya_mangabaka.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMangaBakaMetadataGateway.searchSeries', () {
    test(
      'returns Success([]) without hitting the network on empty query',
      () async {
        final client = _RecordingClient();
        final gateway = HttpMangaBakaMetadataGateway(client: client);

        final result = await gateway.searchSeries(query: '   ');

        expect(client.calls, isEmpty);
        result.fold(
          onSuccess: (entries) => expect(entries, isEmpty),
          onFailure: (e) => fail('expected success, got $e'),
        );
      },
    );

    test('maps live search fixture into MangaBakaSeries entries', () async {
      final fixture = File(
        'test/fixtures/search_solo_leveling.json',
      ).readAsStringSync();
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.success(jsonDecode(fixture) as Map<String, dynamic>),
        ],
      );
      final gateway = HttpMangaBakaMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'solo leveling');

      expect(client.calls.single.path, 'series/search');
      expect(client.calls.single.queryParameters!['q'], 'solo leveling');
      result.fold(
        onSuccess: (entries) {
          expect(entries, isNotEmpty);
          expect(entries.first.id, 3397);
          expect(entries.first.title, 'Solo Leveling');
          expect(entries.first.crossIds.anilistId, 105398);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test('returns MappingError when the envelope is malformed', () async {
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.success(<String, dynamic>{'status': 200}),
        ],
      );
      final gateway = HttpMangaBakaMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'x');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<MangaBakaMappingError>()),
      );
    });

    test(
      'lifts FormatException from a single bad row into MappingError',
      () async {
        final client = _RecordingClient(
          responses: <_Stub>[
            _Stub.success(<String, dynamic>{
              'status': 200,
              'data': <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'title': 'OK'},
                // missing id triggers FormatException in the mapper.
                <String, dynamic>{'title': 'broken'},
              ],
            }),
          ],
        );
        final gateway = HttpMangaBakaMetadataGateway(client: client);

        final result = await gateway.searchSeries(query: 'x');

        result.fold(
          onSuccess: (_) => fail('expected failure'),
          onFailure: (e) => expect(e, isA<MangaBakaMappingError>()),
        );
      },
    );

    test('propagates client failures unchanged', () async {
      const failure = MangaBakaRateLimitError(message: 'too many requests');
      final client = _RecordingClient(
        responses: <_Stub>[_Stub.failure(failure)],
      );
      final gateway = HttpMangaBakaMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'x');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, same(failure)),
      );
    });
  });

  group('HttpMangaBakaMetadataGateway.fetchSeriesById', () {
    test('returns the mapped series on success', () async {
      final fixture = File(
        'test/fixtures/series_3397_solo_leveling.json',
      ).readAsStringSync();
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.success(jsonDecode(fixture) as Map<String, dynamic>),
        ],
      );
      final gateway = HttpMangaBakaMetadataGateway(client: client);

      final result = await gateway.fetchSeriesById(3397);

      expect(client.calls.single.path, 'series/3397');
      result.fold(
        onSuccess: (series) {
          expect(series.id, 3397);
          expect(series.title, 'Solo Leveling');
          expect(series.state, MangaBakaSeriesState.active);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test(
      'follows the merge once when state=merged and followMerges=true',
      () async {
        final mergedFixture = File(
          'test/fixtures/series_10023_merged.json',
        ).readAsStringSync();
        final mergedJson = jsonDecode(mergedFixture) as Map<String, dynamic>;
        final canonicalId =
            (mergedJson['data'] as Map<String, dynamic>)['merged_with'] as int;

        final canonicalEnvelope = <String, dynamic>{
          'status': 200,
          'data': <String, dynamic>{
            'id': canonicalId,
            'title': 'Bleach (canonical)',
            'state': 'active',
            'type': 'manga',
          },
        };

        final client = _RecordingClient(
          responses: <_Stub>[
            _Stub.success(mergedJson),
            _Stub.success(canonicalEnvelope),
          ],
        );
        final gateway = HttpMangaBakaMetadataGateway(client: client);

        final result = await gateway.fetchSeriesById(10023);

        expect(client.calls.length, 2);
        expect(client.calls[0].path, 'series/10023');
        expect(client.calls[1].path, 'series/$canonicalId');
        result.fold(
          onSuccess: (series) {
            expect(series.id, canonicalId);
            expect(series.state, MangaBakaSeriesState.active);
          },
          onFailure: (e) => fail('expected success, got $e'),
        );
      },
    );

    test('does not follow the merge when followMerges=false', () async {
      final mergedFixture = File(
        'test/fixtures/series_10023_merged.json',
      ).readAsStringSync();
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.success(jsonDecode(mergedFixture) as Map<String, dynamic>),
        ],
      );
      final gateway = HttpMangaBakaMetadataGateway(client: client);

      final result = await gateway.fetchSeriesById(10023, followMerges: false);

      expect(client.calls.length, 1);
      result.fold(
        onSuccess: (series) {
          expect(series.state, MangaBakaSeriesState.merged);
          expect(series.mergedWith, isNotNull);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test(
      'returns the merged record itself when mergedWith points to self',
      () async {
        final client = _RecordingClient(
          responses: <_Stub>[
            _Stub.success(<String, dynamic>{
              'status': 200,
              'data': <String, dynamic>{
                'id': 99,
                'title': 'Self-merged',
                'state': 'merged',
                'merged_with': 99,
                'type': 'manga',
              },
            }),
          ],
        );
        final gateway = HttpMangaBakaMetadataGateway(client: client);

        final result = await gateway.fetchSeriesById(99);

        expect(client.calls.length, 1);
        result.fold(
          onSuccess: (series) => expect(series.id, 99),
          onFailure: (e) => fail('expected success, got $e'),
        );
      },
    );

    test('propagates 404 from the client as MangaBakaNotFoundError', () async {
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.failure(const MangaBakaNotFoundError(message: 'NOT_FOUND')),
        ],
      );
      final gateway = HttpMangaBakaMetadataGateway(client: client);

      final result = await gateway.fetchSeriesById(1);

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<MangaBakaNotFoundError>()),
      );
    });

    test(
      'returns MappingError when data is missing from the envelope',
      () async {
        final client = _RecordingClient(
          responses: <_Stub>[
            _Stub.success(<String, dynamic>{'status': 200}),
          ],
        );
        final gateway = HttpMangaBakaMetadataGateway(client: client);

        final result = await gateway.fetchSeriesById(1);

        result.fold(
          onSuccess: (_) => fail('expected failure'),
          onFailure: (e) => expect(e, isA<MangaBakaMappingError>()),
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _RecordingCall {
  _RecordingCall({required this.path, this.queryParameters});
  final String path;
  final Map<String, dynamic>? queryParameters;
}

class _Stub {
  _Stub.success(this.success) : failure = null;
  _Stub.failure(this.failure) : success = null;

  final Map<String, dynamic>? success;
  final KumoriyaError? failure;
}

class _RecordingClient implements MangaBakaHttpClient {
  _RecordingClient({List<_Stub>? responses})
    : _responses = responses ?? <_Stub>[];

  final List<_Stub> _responses;
  final List<_RecordingCall> calls = <_RecordingCall>[];

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> getJson({
    required String path,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(_RecordingCall(path: path, queryParameters: queryParameters));
    if (_responses.isEmpty) {
      throw StateError('No stubbed response for path=$path');
    }
    final stub = _responses.removeAt(0);
    if (stub.success != null) {
      return Success(stub.success!);
    }
    return Failure(stub.failure!);
  }
}
