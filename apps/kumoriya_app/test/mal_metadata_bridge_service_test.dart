import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/mal_metadata_bridge_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  group('MalMetadataBridgeService AniSkip cache', () {
    test('returns cached AniSkip segments without network', () async {
      final store = _FakeAniSkipCacheStore();
      await store.upsert(
        AniSkipCacheRecord(
          anilistId: 100,
          episodeNumber: 1,
          payloadJson: jsonEncode(<Map<String, Object>>[
            <String, Object>{
              'kind': 'opening',
              'startMs': 1000,
              'endMs': 90000,
            },
          ]),
          updatedAt: DateTime.now(),
          requestedEpisodeLengthSeconds: 1440,
        ),
      );

      final client = MockClient((_) async {
        throw Exception('network should not be called');
      });
      final service = MalMetadataBridgeService(
        httpClient: client,
        aniSkipCacheStore: store,
      );

      final segments = await service.getAniSkipSegments(
        anilistId: 100,
        episodeNumber: 1,
        episodeLengthSeconds: 1440,
      );

      expect(segments.length, 1);
      expect(segments.first.kind, AniSkipSegmentKind.opening);
      expect(segments.first.start, const Duration(seconds: 1));
      expect(segments.first.end, const Duration(seconds: 90));
    });

    test(
      'prefetches AniSkip for multiple episodes and persists cache',
      () async {
        final store = _FakeAniSkipCacheStore();
        var malIdCalls = 0;
        final aniSkipCalls = <int>[];
        final client = MockClient((request) async {
          if (request.url.host == 'graphql.anilist.co') {
            malIdCalls++;
            return http.Response(
              jsonEncode(<String, Object?>{
                'data': <String, Object?>{
                  'Media': <String, Object?>{'idMal': 555},
                },
              }),
              200,
            );
          }

          if (request.url.host == 'api.aniskip.com') {
            final episodeNumber = int.parse(request.url.pathSegments[3]);
            aniSkipCalls.add(episodeNumber);
            return http.Response(
              jsonEncode(<String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'skip_type': 'op',
                    'interval': <String, Object?>{
                      'start_time': 5,
                      'end_time': 95,
                    },
                  },
                ],
              }),
              200,
            );
          }

          throw Exception('unexpected request: ${request.url}');
        });

        final service = MalMetadataBridgeService(
          httpClient: client,
          aniSkipCacheStore: store,
        );

        final report = await service.prefetchAniSkipForAnime(
          anilistId: 100,
          episodeNumbers: const <int>[1, 2],
        );

        expect(malIdCalls, 1);
        expect(aniSkipCalls, <int>[1, 2]);
        expect(report.requestedEpisodes, 2);
        expect(report.cachedEpisodes, 0);
        expect(report.fetchedEpisodes, 2);
        expect(report.failedEpisodes, 0);
        expect(store.records.keys, containsAll(<String>['100:1', '100:2']));

        final offlineService = MalMetadataBridgeService(
          httpClient: MockClient((_) async => throw Exception('offline')),
          aniSkipCacheStore: store,
        );
        final cachedSegments = await offlineService.getAniSkipSegments(
          anilistId: 100,
          episodeNumber: 2,
          episodeLengthSeconds: 1440,
        );
        expect(cachedSegments, isNotEmpty);
        expect(cachedSegments.first.kind, AniSkipSegmentKind.opening);
      },
    );
  });
}

final class _FakeAniSkipCacheStore implements AniSkipCacheStore {
  final Map<String, AniSkipCacheRecord> records =
      <String, AniSkipCacheRecord>{};

  @override
  Future<Result<void, KumoriyaError>> clearAnime(int anilistId) async {
    records.removeWhere((key, _) => key.startsWith('$anilistId:'));
    return const Success(null);
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final before = records.length;
    records.removeWhere((_, record) => record.updatedAt.isBefore(cutoff));
    return Success(before - records.length);
  }

  @override
  Future<Result<AniSkipCacheRecord?, KumoriyaError>> getEpisode(
    int anilistId,
    int episodeNumber,
  ) async {
    return Success(records['$anilistId:$episodeNumber']);
  }

  @override
  Future<Result<List<AniSkipCacheRecord>, KumoriyaError>> getEpisodesForAnime(
    int anilistId,
  ) async {
    final values =
        records.values
            .where((record) => record.anilistId == anilistId)
            .toList(growable: false)
          ..sort(
            (left, right) => left.episodeNumber.compareTo(right.episodeNumber),
          );
    return Success(values);
  }

  @override
  Future<Result<void, KumoriyaError>> upsert(AniSkipCacheRecord record) async {
    records['${record.anilistId}:${record.episodeNumber}'] = record;
    return const Success(null);
  }
}
