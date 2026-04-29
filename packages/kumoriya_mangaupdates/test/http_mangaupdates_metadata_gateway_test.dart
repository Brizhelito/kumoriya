import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_mangaupdates/kumoriya_mangaupdates.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMangaUpdatesMetadataGateway.searchSeries', () {
    test(
      'returns Success([]) on empty query without hitting the network',
      () async {
        final client = _RecordingClient();
        final gateway = HttpMangaUpdatesMetadataGateway(client: client);

        final result = await gateway.searchSeries(query: '   ');

        expect(client.calls, isEmpty);
        result.fold(
          onSuccess: (entries) => expect(entries, isEmpty),
          onFailure: (e) => fail('expected success, got $e'),
        );
      },
    );

    test('maps the live search fixture into entries', () async {
      final fixture =
          jsonDecode(
                File('test/fixtures/series_search.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final client = _RecordingClient(
        responses: <_Stub>[_Stub.success(fixture)],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'solo leveling');

      expect(client.calls.single.method, _Method.post);
      expect(client.calls.single.path, 'series/search');
      expect(client.calls.single.body!['search'], 'solo leveling');
      result.fold(
        onSuccess: (entries) {
          expect(entries, isNotEmpty);
          expect(entries.first.id, 15180124327);
          expect(entries.first.title, 'Solo Leveling');
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test('returns MappingError when results array is missing', () async {
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.success(<String, dynamic>{'page': 1}),
        ],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'x');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<MangaUpdatesMappingError>()),
      );
    });

    test('lifts mapper FormatException into MappingError', () async {
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.success(<String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'record': <String, dynamic>{'series_id': 1, 'title': 'OK'},
              },
              <String, dynamic>{
                'record': <String, dynamic>{'title': 'broken'},
              },
            ],
          }),
        ],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'x');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<MangaUpdatesMappingError>()),
      );
    });

    test('propagates client failures unchanged', () async {
      const failure = MangaUpdatesRateLimitError(message: 'too many requests');
      final client = _RecordingClient(
        responses: <_Stub>[_Stub.failure(failure)],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.searchSeries(query: 'x');

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, same(failure)),
      );
    });
  });

  group('HttpMangaUpdatesMetadataGateway.fetchSeriesById', () {
    test('returns the mapped series on success', () async {
      final fixture =
          jsonDecode(
                File('test/fixtures/series_detail.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final client = _RecordingClient(
        responses: <_Stub>[_Stub.success(fixture)],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.fetchSeriesById(15180124327);

      expect(client.calls.single.method, _Method.get);
      expect(client.calls.single.path, 'series/15180124327');
      result.fold(
        onSuccess: (series) {
          expect(series.id, 15180124327);
          expect(series.completed, isTrue);
          expect(series.associatedTitles, isNotEmpty);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test('propagates 404 as MangaUpdatesNotFoundError', () async {
      final client = _RecordingClient(
        responses: <_Stub>[
          _Stub.failure(const MangaUpdatesNotFoundError(message: 'not found')),
        ],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.fetchSeriesById(1);

      result.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) => expect(e, isA<MangaUpdatesNotFoundError>()),
      );
    });
  });

  group('HttpMangaUpdatesMetadataGateway.fetchGroupById', () {
    test('returns the mapped group on success', () async {
      final fixture =
          jsonDecode(File('test/fixtures/group_detail.json').readAsStringSync())
              as Map<String, dynamic>;
      final client = _RecordingClient(
        responses: <_Stub>[_Stub.success(fixture)],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.fetchGroupById(60273359075);

      expect(client.calls.single.path, 'groups/60273359075');
      result.fold(
        onSuccess: (group) {
          expect(group.name, 'LeviatanScans');
          expect(group.active, isFalse);
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });
  });

  group('HttpMangaUpdatesMetadataGateway.searchReleases', () {
    test(
      'returns MappingError when neither seriesId nor groupId is supplied',
      () async {
        final client = _RecordingClient();
        final gateway = HttpMangaUpdatesMetadataGateway(client: client);

        final result = await gateway.searchReleases();

        expect(client.calls, isEmpty);
        result.fold(
          onSuccess: (_) => fail('expected failure'),
          onFailure: (e) => expect(e, isA<MangaUpdatesMappingError>()),
        );
      },
    );

    test('builds a series-scoped body and parses the live fixture', () async {
      final fixture =
          jsonDecode(
                File('test/fixtures/releases_search.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final client = _RecordingClient(
        responses: <_Stub>[_Stub.success(fixture)],
      );
      final gateway = HttpMangaUpdatesMetadataGateway(client: client);

      final result = await gateway.searchReleases(seriesId: 15180124327);

      expect(client.calls.single.path, 'releases/search');
      expect(client.calls.single.body!['search'], '15180124327');
      expect(client.calls.single.body!['search_type'], 'series');
      result.fold(
        onSuccess: (releases) {
          expect(releases, isNotEmpty);
          final first = releases.first;
          expect(first.groups, isNotEmpty);
          expect(first.timeAdded.year, greaterThan(2010));
        },
        onFailure: (e) => fail('expected success, got $e'),
      );
    });

    test(
      'combines seriesId and groupId in the body when both supplied',
      () async {
        final client = _RecordingClient(
          responses: <_Stub>[
            _Stub.success(<String, dynamic>{'results': <dynamic>[]}),
          ],
        );
        final gateway = HttpMangaUpdatesMetadataGateway(client: client);

        await gateway.searchReleases(seriesId: 7, groupId: 42, perPage: 10);

        final call = client.calls.single;
        expect(call.body!['search'], '7');
        expect(call.body!['search_type'], 'series');
        expect(call.body!['groups'], <int>[42]);
        expect(call.body!['perpage'], 10);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

enum _Method { get, post }

class _RecordingCall {
  _RecordingCall({
    required this.method,
    required this.path,
    this.queryParameters,
    this.body,
  });

  final _Method method;
  final String path;
  final Map<String, dynamic>? queryParameters;
  final Map<String, dynamic>? body;
}

class _Stub {
  _Stub.success(this.success) : failure = null;
  _Stub.failure(this.failure) : success = null;

  final Map<String, dynamic>? success;
  final KumoriyaError? failure;
}

class _RecordingClient implements MangaUpdatesHttpClient {
  _RecordingClient({List<_Stub>? responses})
    : _responses = responses ?? <_Stub>[];

  final List<_Stub> _responses;
  final List<_RecordingCall> calls = <_RecordingCall>[];

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> getJson({
    required String path,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(
      _RecordingCall(
        method: _Method.get,
        path: path,
        queryParameters: queryParameters,
      ),
    );
    return _next();
  }

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> postJson({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    calls.add(_RecordingCall(method: _Method.post, path: path, body: body));
    return _next();
  }

  Result<Map<String, dynamic>, KumoriyaError> _next() {
    if (_responses.isEmpty) {
      throw StateError('No stubbed response left');
    }
    final stub = _responses.removeAt(0);
    if (stub.success != null) {
      return Success(stub.success!);
    }
    return Failure(stub.failure!);
  }
}
