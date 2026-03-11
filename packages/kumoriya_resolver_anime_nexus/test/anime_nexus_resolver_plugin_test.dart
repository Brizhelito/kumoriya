// ignore_for_file: lines_longer_than_80_chars

import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_anime_nexus/kumoriya_resolver_anime_nexus.dart';
import 'package:test/test.dart';

import 'package:kumoriya_resolver_anime_nexus/src/services/hls_manifest_parser.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/stream_data_fetcher.dart';

void main() {
  group('AnimeNexusResolverPlugin – manifest / supports', () {
    late AnimeNexusResolverPlugin plugin;

    setUp(() {
      plugin = AnimeNexusResolverPlugin();
    });

    test('manifest exposes resolver capabilities', () {
      expect(plugin.manifest.id, 'kumoriya.resolver.anime_nexus');
      expect(plugin.manifest.type, PluginType.resolver);
      expect(
        plugin.manifest.capabilities,
        contains(PluginCapability.streamResolution),
      );
    });

    test('supports valid Anime Nexus watch urls', () {
      expect(
        plugin.supports(
          Uri.parse(
            'https://anime.nexus/watch/019cd8e2-05d1-73d3-b322-e5f4efb70043/episode-10-sample',
          ),
        ),
        isTrue,
      );
    });

    test('supports valid Anime Nexus watch urls with execution slug', () {
      expect(
        plugin.supports(
          Uri.parse(
            'https://anime.nexus/watch/019b9e8f-edf6-71a7-87c5-c45f64297245/execution-537a058e13efbfab1729',
          ),
        ),
        isTrue,
      );
    });

    test('rejects watch url missing episode segment', () {
      expect(
        plugin.supports(
          Uri.parse(
            'https://anime.nexus/watch/019cd8e2-05d1-73d3-b322-e5f4efb70043',
          ),
        ),
        isFalse,
      );
    });

    test('rejects non-watch urls', () {
      expect(
        plugin.supports(Uri.parse('https://anime.nexus/series/some-anime')),
        isFalse,
      );
    });

    test('rejects other hosts', () {
      expect(
        plugin.supports(
          Uri.parse(
            'https://example.com/watch/019cd8e2-05d1-73d3-b322-e5f4efb70043/episode-1-sample',
          ),
        ),
        isFalse,
      );
    });

    test('rejects http-only urls', () {
      expect(
        plugin.supports(
          Uri.parse(
            'ftp://anime.nexus/watch/019cd8e2-05d1-73d3-b322-e5f4efb70043/episode-1',
          ),
        ),
        isFalse,
      );
    });
  });

  group('NexusStreamDataFetcher – unit', () {
    late Dio dio;
    late DioAdapter adapter;
    late NexusStreamDataFetcher fetcher;

    void mockAuthSession({
      Map<String, List<String>>? headers,
      int statusCode = 204,
    }) {
      final responseHeaders = <String, List<String>>{...?headers};
      adapter.onGet(
        'https://anime.nexus/api/auth/session',
        (server) => server.reply(statusCode, '', headers: responseHeaders),
      );
    }

    void mockEpisodeView({
      required String episodeId,
      Map<String, dynamic>? data,
      int statusCode = 200,
      Map<String, List<String>>? headers,
    }) {
      final responseHeaders = <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        ...?headers,
      };
      adapter.onPost(
        'https://api.anime.nexus/api/anime/details/episode/view',
        (server) => server.reply(
          statusCode,
          data ?? <String, dynamic>{},
          headers: responseHeaders,
        ),
        data: <String, String>{'id': episodeId},
      );
    }

    void mockBootstrap({
      required String episodeId,
      Map<String, List<String>>? authHeaders,
      Map<String, List<String>>? viewHeaders,
    }) {
      mockAuthSession(headers: authHeaders);
      mockEpisodeView(episodeId: episodeId, headers: viewHeaders);
    }

    setUp(() {
      dio = Dio();
      adapter = DioAdapter(dio: dio);
      fetcher = NexusStreamDataFetcher(dio);
    });

    test(
      'parses hls url, videoId from url path, and subtitles from api',
      () async {
        mockBootstrap(episodeId: 'episode-uuid-001');
        adapter.onGet(
          'https://api.anime.nexus/api/anime/details/episode/stream',
          (server) => server.reply(200, {
            'data': {
              'hls':
                  'https://api.anime.nexus/api/anime/video/abc-vid-123/stream/video.m3u8',
              'subtitles': [
                {
                  'src': 'https://cdn.example.com/en.vtt',
                  'label': 'English',
                  'srcLang': 'en',
                },
                {
                  'src': 'https://cdn.example.com/es.vtt',
                  'label': 'Spanish',
                  'srcLang': 'es',
                },
              ],
            },
          }),
          queryParameters: <String, dynamic>{
            'id': 'episode-uuid-001',
            'fillers': true,
            'recaps': true,
          },
        );

        final data = await fetcher.fetch(episodeId: 'episode-uuid-001');

        expect(data.hlsUrl.toString(), contains('video.m3u8'));
        expect(data.videoId, 'abc-vid-123');
        expect(data.subtitles, hasLength(2));
        expect(data.subtitles.first.src, 'https://cdn.example.com/en.vtt');
        expect(data.subtitles.first.label, 'English');
        expect(data.subtitles.first.srcLang, 'en');
        expect(data.subtitles.last.srcLang, 'es');
      },
    );

    test('extracts videoId from video object in payload', () async {
      mockBootstrap(episodeId: 'ep-002');
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(200, {
          'data': {
            'hls': 'https://api.anime.nexus/api/anime/video/stream/video.m3u8',
            'video': {'id': 'explicit-video-id-xyz'},
            'subtitles': <dynamic>[],
          },
        }),
        queryParameters: <String, dynamic>{
          'id': 'ep-002',
          'fillers': true,
          'recaps': true,
        },
      );

      final data = await fetcher.fetch(episodeId: 'ep-002');

      expect(data.videoId, 'explicit-video-id-xyz');
    });

    test('handles empty subtitles gracefully', () async {
      mockBootstrap(episodeId: 'ep-003');
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(200, {
          'data': {
            'hls':
                'https://api.anime.nexus/api/anime/video/vid-id/stream/video.m3u8',
            'subtitles': <dynamic>[],
          },
        }),
        queryParameters: <String, dynamic>{
          'id': 'ep-003',
          'fillers': true,
          'recaps': true,
        },
      );

      final data = await fetcher.fetch(episodeId: 'ep-003');

      expect(data.subtitles, isEmpty);
    });

    test('throws NexusStreamDataException when hls field is missing', () async {
      mockBootstrap(episodeId: 'ep-bad');
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(200, {
          'data': {'subtitles': <dynamic>[]},
        }),
        queryParameters: <String, dynamic>{
          'id': 'ep-bad',
          'fillers': true,
          'recaps': true,
        },
      );

      expect(
        () => fetcher.fetch(episodeId: 'ep-bad'),
        throwsA(isA<NexusStreamDataException>()),
      );
    });

    test(
      'throws NexusStreamDataException or DioException on 4xx status',
      () async {
        mockBootstrap(episodeId: 'ep-403');
        adapter.onGet(
          'https://api.anime.nexus/api/anime/details/episode/stream',
          (server) =>
              server.reply(403, <String, dynamic>{'error': 'Forbidden'}),
          queryParameters: <String, dynamic>{
            'id': 'ep-403',
            'fillers': true,
            'recaps': true,
          },
        );

        Object? thrown;
        try {
          await fetcher.fetch(episodeId: 'ep-403');
        } catch (e) {
          thrown = e;
        }

        expect(
          thrown,
          anyOf(isA<NexusStreamDataException>(), isA<DioException>()),
          reason: 'A 403 response must surface as a known failure type',
        );
      },
    );

    test('skips subtitle entries with missing src', () async {
      mockBootstrap(episodeId: 'ep-partial');
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(200, {
          'data': {
            'hls':
                'https://api.anime.nexus/api/anime/video/vid-x/stream/video.m3u8',
            'subtitles': [
              {'label': 'No src here'}, // No src field — must be skipped.
              {
                'src': 'https://cdn.example.com/valid.vtt',
                'label': 'Valid',
                'srcLang': 'en',
              },
            ],
          },
        }),
        queryParameters: <String, dynamic>{
          'id': 'ep-partial',
          'fillers': true,
          'recaps': true,
        },
      );

      final data = await fetcher.fetch(episodeId: 'ep-partial');

      expect(data.subtitles, hasLength(1));
      expect(data.subtitles.first.label, 'Valid');
    });

    test('merges cookies returned by bootstrap and stream requests', () async {
      mockBootstrap(
        episodeId: 'ep-cookies',
        authHeaders: <String, List<String>>{
          'set-cookie': <String>['sid=bootstrap-sid; Path=/'],
        },
        viewHeaders: <String, List<String>>{
          'set-cookie': <String>[
            'anime_nexus_session=bootstrap-session; Path=/; HttpOnly',
          ],
        },
      );
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(
          200,
          {
            'data': {
              'hls':
                  'https://api.anime.nexus/api/anime/video/vid-cookie/stream/video.m3u8',
              'subtitles': <dynamic>[],
            },
          },
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            'set-cookie': <String>['application_viewable=1; Path=/; HttpOnly'],
          },
        ),
        queryParameters: <String, dynamic>{
          'id': 'ep-cookies',
          'fillers': true,
          'recaps': true,
        },
      );

      final data = await fetcher.fetch(episodeId: 'ep-cookies');

      expect(data.cookieHeader, contains('sid=bootstrap-sid'));
      expect(
        data.cookieHeader,
        contains('anime_nexus_session=bootstrap-session'),
      );
      expect(data.cookieHeader, contains('application_viewable=1'));
    });
  });

  group('NexusHlsManifestParser – unit', () {
    const parser = NexusHlsManifestParser();
    const masterManifest = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="group_stream_480",NAME="Chinese",DEFAULT=NO,CHANNELS="2",AUTOSELECT=YES,LANGUAGE="chi",URI="https://us1.cdn.nexus/anime/streams/demo/demo/demo.mkv_1600-0.m3u8",CODECS="opus"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="group_stream_720",NAME="Chinese",DEFAULT=NO,CHANNELS="2",AUTOSELECT=YES,LANGUAGE="chi",URI="https://us1.cdn.nexus/anime/streams/demo/demo/demo.mkv_4400-0.m3u8",CODECS="opus"
#EXT-X-STREAM-INF:BANDWIDTH=12291546,AVERAGE-BANDWIDTH=2562874,RESOLUTION=1280x720,AUDIO="group_stream_720"
https://us1.cdn.nexus/anime/streams/demo/demo/demo.mkv_4400-1.m3u8
''';

    test(
      'parses audio groups and stream entries from Anime Nexus master HLS',
      () {
        final manifest = parser.parseMasterManifest(
          content: masterManifest,
          baseUri: Uri.parse(
            'https://api.anime.nexus/api/anime/video/abc/stream/video.m3u8',
          ),
        );

        expect(manifest.audioEntries, hasLength(2));
        expect(manifest.streamEntries, hasLength(1));
        expect(manifest.audioEntries[1].groupId, 'group_stream_720');
        expect(manifest.audioEntries[1].metadata.variant, '4400');
        expect(manifest.audioEntries[1].metadata.track, 0);
        expect(manifest.streamEntries.first.audioGroupId, 'group_stream_720');
        expect(manifest.streamEntries.first.qualityLabel, '720p');
        expect(manifest.streamEntries.first.metadata.variant, '4400');
        expect(manifest.streamEntries.first.metadata.track, 1);
      },
    );
  });
}
