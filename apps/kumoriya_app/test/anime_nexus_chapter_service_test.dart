import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/anime_nexus_chapter_service.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/mal_metadata_bridge_service.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_availability_cache_codec.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_selection_policy.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  group('AnimeNexusChapterService', () {
    test('parses opening and ending cues from chapters vtt', () async {
      final plugin = AnimeNexusSourcePlugin();
      final store = _FakeSourceAvailabilityStore();
      final requests = <String>[];
      final codec = SourceAvailabilityCacheCodec(
        sourcePlugins: <SourcePlugin>[plugin],
        selectionPolicy: const SourceSelectionPolicy(),
      );

      await store.replaceAvailability(
        42,
        codec.encode(
          anilistId: 42,
          updatedAt: DateTime.now(),
          summary: SourceAvailabilitySummary(
            sources: <SourceAvailability>[
              SourceAvailability(
                manifest: plugin.manifest,
                status: SourceAvailabilityStatus.available,
                decision: const SourceMatchDecision(
                  verdict: true,
                  confidence: MatchConfidence.high,
                  reason: 'test',
                  acceptanceSignals: <String>['test'],
                  rejectionSignals: <String>[],
                ),
                episodes: <SourceEpisode>[
                  SourceEpisode(
                    sourceEpisodeId: 'episode-uuid-1',
                    number: 1,
                    title: 'Episode 1',
                    episodeUrl: Uri.parse(
                      'https://anime.nexus/watch/episode-uuid-1/episode-1',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final client = MockClient((request) async {
        requests.add('${request.method} ${request.url}');

        if (request.url.toString() ==
            'https://anime.nexus/watch/episode-uuid-1/episode-1') {
          expect(request.headers['cookie'], startsWith('sid='));
          return http.Response(
            '<html></html>',
            200,
            headers: <String, String>{'set-cookie': 'watch_boot=omega; Path=/'},
          );
        }

        if (request.url.toString() == 'https://anime.nexus/api/auth/session') {
          expect(request.headers['cookie'], startsWith('sid='));
          expect(request.headers['cookie'], contains('watch_boot=omega'));
          return http.Response(
            jsonEncode(<String, Object?>{'ok': true}),
            200,
            headers: <String, String>{
              'set-cookie': 'auth_token=alpha; Path=/; HttpOnly',
            },
          );
        }
        if (request.url.toString() ==
            'https://api.anime.nexus/api/anime/details/episode/view') {
          final fingerprint = request.headers['x-fingerprint'];
          expect(fingerprint, isNotNull);
          expect(request.headers['x-client-fingerprint'], fingerprint);
          expect(request.headers['cookie'], contains('sid='));
          expect(request.headers['cookie'], contains('watch_boot=omega'));
          expect(request.headers['cookie'], contains('auth_token=alpha'));
          expect((request).bodyFields['id'], 'episode-uuid-1');
          return http.Response(
            '',
            200,
            headers: <String, String>{
              'set-cookie': 'episode_view=beta; Path=/',
            },
          );
        }
        if (request.url.toString() ==
            'https://api.anime.nexus/api/anime/details/episode/stream?id=episode-uuid-1&fillers=true&recaps=true') {
          final fingerprint = request.headers['x-fingerprint'];
          expect(fingerprint, isNotNull);
          expect(request.headers['x-client-fingerprint'], fingerprint);
          expect(request.headers['cookie'], contains('sid='));
          expect(request.headers['cookie'], contains('watch_boot=omega'));
          expect(request.headers['cookie'], contains('auth_token=alpha'));
          expect(request.headers['cookie'], contains('episode_view=beta'));
          return http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{
                'chapters':
                    'https://api.anime.nexus/api/anime/video/video-uuid-1/stream/cues.vtt',
              },
            }),
            200,
          );
        }
        if (request.url.toString() ==
            'https://api.anime.nexus/api/anime/video/video-uuid-1/stream/cues.vtt') {
          return http.Response(
            'WEBVTT\n\n'
            '00:00:00.000 --> 00:03:32.000\n'
            'Episode\n\n'
            '00:03:32.000 --> 00:04:54.000\n'
            'Opening\n\n'
            '00:04:54.000 --> 00:22:34.000\n'
            'Episode\n\n'
            '00:22:34.000 --> 00:24:07.000\n'
            'Ending\n',
            200,
          );
        }
        throw Exception('unexpected request: ${request.url}');
      });

      final service = AnimeNexusChapterService(
        httpClient: client,
        sourceAvailabilityStore: store,
        sourceAvailabilityCacheCodec: codec,
      );

      final segments = await service.getEpisodeSegments(
        anilistId: 42,
        episodeNumber: 1,
      );

      expect(segments, hasLength(2));
      expect(segments.first.kind, AniSkipSegmentKind.opening);
      expect(segments.first.start, const Duration(minutes: 3, seconds: 32));
      expect(segments.last.kind, AniSkipSegmentKind.ending);
      expect(segments.last.end, const Duration(minutes: 24, seconds: 7));
      expect(requests, <String>[
        'GET https://anime.nexus/watch/episode-uuid-1/episode-1',
        'GET https://anime.nexus/api/auth/session',
        'POST https://api.anime.nexus/api/anime/details/episode/view',
        'GET https://api.anime.nexus/api/anime/details/episode/stream?id=episode-uuid-1&fillers=true&recaps=true',
        'GET https://api.anime.nexus/api/anime/video/video-uuid-1/stream/cues.vtt',
      ]);
    });

    test('derives cues.vtt from hls when chapters is null', () async {
      final plugin = AnimeNexusSourcePlugin();
      final store = _FakeSourceAvailabilityStore();
      final requests = <String>[];
      final codec = SourceAvailabilityCacheCodec(
        sourcePlugins: <SourcePlugin>[plugin],
        selectionPolicy: const SourceSelectionPolicy(),
      );

      await store.replaceAvailability(
        42,
        codec.encode(
          anilistId: 42,
          updatedAt: DateTime.now(),
          summary: SourceAvailabilitySummary(
            sources: <SourceAvailability>[
              SourceAvailability(
                manifest: plugin.manifest,
                status: SourceAvailabilityStatus.available,
                decision: const SourceMatchDecision(
                  verdict: true,
                  confidence: MatchConfidence.high,
                  reason: 'test',
                  acceptanceSignals: <String>['test'],
                  rejectionSignals: <String>[],
                ),
                episodes: <SourceEpisode>[
                  SourceEpisode(
                    sourceEpisodeId: 'ep-uuid-2',
                    number: 1,
                    title: 'Episode 1',
                    episodeUrl: Uri.parse(
                      'https://anime.nexus/watch/ep-uuid-2/episode-1',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final client = MockClient((request) async {
        requests.add('${request.method} ${request.url}');

        if (request.url.path.contains('/watch/')) {
          return http.Response('<html></html>', 200);
        }
        if (request.url.path == '/api/auth/session') {
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/episode/view')) {
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/episode/stream')) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{
                'chapters': null,
                'hls':
                    'https://api.anime.nexus/api/anime/video/019bace2-60f1-7192-b3b8-3b96d31ebba2/stream/video.m3u8',
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/stream/cues.vtt')) {
          expect(request.headers['origin'], 'https://anime.nexus');
          expect(request.headers['referer'], 'https://anime.nexus/');
          return http.Response(
            'WEBVTT\n\n'
            '00:00:00.000 --> 00:01:30.000\n'
            'Episode\n\n'
            '00:01:30.000 --> 00:03:00.000\n'
            'Opening\n\n'
            '00:03:00.000 --> 00:22:00.000\n'
            'Episode\n\n'
            '00:22:00.000 --> 00:23:30.000\n'
            'Ending\n',
            200,
          );
        }
        throw Exception('unexpected request: ${request.url}');
      });

      final service = AnimeNexusChapterService(
        httpClient: client,
        sourceAvailabilityStore: store,
        sourceAvailabilityCacheCodec: codec,
      );

      final segments = await service.getEpisodeSegments(
        anilistId: 42,
        episodeNumber: 1,
      );

      expect(segments, hasLength(2));
      expect(segments.first.kind, AniSkipSegmentKind.opening);
      expect(segments.first.start, const Duration(minutes: 1, seconds: 30));
      expect(segments.last.kind, AniSkipSegmentKind.ending);
      expect(segments.last.end, const Duration(minutes: 23, seconds: 30));
      expect(
        requests.last,
        'GET https://api.anime.nexus/api/anime/video/019bace2-60f1-7192-b3b8-3b96d31ebba2/stream/cues.vtt',
      );
    });

    test('returns empty when Anime Nexus episode is unavailable', () async {
      final plugin = AnimeNexusSourcePlugin();
      final service = AnimeNexusChapterService(
        httpClient: MockClient((_) async => throw Exception('no network')),
        sourceAvailabilityStore: _FakeSourceAvailabilityStore(),
        sourceAvailabilityCacheCodec: SourceAvailabilityCacheCodec(
          sourcePlugins: <SourcePlugin>[plugin],
          selectionPolicy: const SourceSelectionPolicy(),
        ),
      );

      final segments = await service.getEpisodeSegments(
        anilistId: 404,
        episodeNumber: 1,
      );

      expect(segments, isEmpty);
    });
  });
}

final class _FakeSourceAvailabilityStore implements SourceAvailabilityStore {
  final Map<int, List<SourceAvailabilityCacheRecord>> _records =
      <int, List<SourceAvailabilityCacheRecord>>{};

  @override
  Future<Result<void, KumoriyaError>> clearAvailability(int anilistId) async {
    _records.remove(anilistId);
    return const Success(null);
  }

  @override
  Future<Result<int, KumoriyaError>> deleteOlderThan(Duration maxAge) async {
    return const Success(0);
  }

  @override
  Future<Result<List<SourceAvailabilityCacheRecord>, KumoriyaError>>
  getAvailability(int anilistId) async {
    return Success(
      _records[anilistId] ?? const <SourceAvailabilityCacheRecord>[],
    );
  }

  @override
  Future<Result<void, KumoriyaError>> replaceAvailability(
    int anilistId,
    List<SourceAvailabilityCacheRecord> records,
  ) async {
    _records[anilistId] = records;
    return const Success(null);
  }
}
