import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';
import 'package:test/test.dart';

void main() {
  group('AnimeNexusSourcePlugin – manifest', () {
    test('manifest exposes source capabilities', () {
      final plugin = AnimeNexusSourcePlugin();

      expect(plugin.manifest.id, 'kumoriya.source.anime_nexus');
      expect(plugin.manifest.type, PluginType.source);
      expect(
        plugin.manifest.capabilities,
        containsAll(<PluginCapability>[
          PluginCapability.search,
          PluginCapability.animeDetail,
          PluginCapability.episodeList,
          PluginCapability.linkExtraction,
        ]),
      );
    });
  });

  group('AnimeNexusSourcePlugin – _fetchApiSubtitles via getEpisodeServerLinks', () {
    late Dio dio;
    late DioAdapter adapter;
    late AnimeNexusSourcePlugin plugin;

    setUp(() {
      dio = Dio(BaseOptions());
      adapter = DioAdapter(dio: dio);
      plugin = AnimeNexusSourcePlugin(
        dio: dio,
        seriesPageFetcher: (_) async {
          return '<html><head>'
              '<meta property="og:title" content="Watch Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City (Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni) TV Online Free - Fantasy">'
              '<meta property="og:description" content="Stream and watch Easygoing Territory Defense by the Optimistic Lord.">'
              '</head><body></body></html>';
        },
      );
    });

    test('builds ExternalSubtitleTrack list from API subtitles data', () async {
      const episodeId = '019cd8e2-05d1-73d3-b322-e5f4efb70043';
      final watchUrl = Uri.parse(
        'https://anime.nexus/watch/$episodeId/episode-10-abc',
      );

      // Mock the watch-page fetch (for language detection).
      adapter.onGet(
        watchUrl.toString(),
        (server) => server.reply(
          200,
          '<html>English subbed, English dubbed subtitles</html>',
        ),
      );

      // Mock the episode/stream API (for subtitles).
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(200, {
          'data': {
            'hls':
                'https://api.anime.nexus/api/anime/video/vid-001/stream/video.m3u8',
            'subtitles': [
              {
                'src': 'https://cdn.example.com/subs/en.vtt',
                'label': 'English',
                'srcLang': 'en',
              },
              {
                'src': 'https://cdn.example.com/subs/es.vtt',
                'label': 'Spanish',
                'srcLang': 'es',
              },
            ],
          },
        }),
        queryParameters: <String, dynamic>{
          'id': episodeId,
          'fillers': true,
          'recaps': true,
        },
      );

      final episode = SourceEpisode(
        sourceEpisodeId: episodeId,
        number: 10,
        title: 'Episode 10',
        episodeUrl: watchUrl,
      );

      final result = await plugin.getEpisodeServerLinks(episode);

      expect(result, isA<Success<List<SourceServerLink>, KumoriyaError>>());
      final links =
          (result as Success<List<SourceServerLink>, KumoriyaError>).value;
      expect(links, isNotEmpty);

      // All links should carry the subtitles from the API.
      for (final link in links) {
        expect(link.externalSubtitles, hasLength(2));
        expect(link.externalSubtitles.any((s) => s.language == 'en'), isTrue);
        expect(link.externalSubtitles.any((s) => s.language == 'es'), isTrue);
      }
    });

    test(
      'returns empty subtitles when API returns no subtitles field',
      () async {
        const episodeId = '019cd8e2-05d1-0000-b322-e5f4efb70044';
        final watchUrl = Uri.parse(
          'https://anime.nexus/watch/$episodeId/episode-1-abc',
        );

        adapter.onGet(
          watchUrl.toString(),
          (server) => server.reply(200, '<html>subtitles</html>'),
        );

        adapter.onGet(
          'https://api.anime.nexus/api/anime/details/episode/stream',
          (server) => server.reply(200, {
            'data': {
              'hls':
                  'https://api.anime.nexus/api/anime/video/v/stream/video.m3u8',
            },
          }),
          queryParameters: <String, dynamic>{
            'id': episodeId,
            'fillers': true,
            'recaps': true,
          },
        );

        final episode = SourceEpisode(
          sourceEpisodeId: episodeId,
          number: 1,
          title: 'Episode 1',
          episodeUrl: watchUrl,
        );

        final result = await plugin.getEpisodeServerLinks(episode);

        expect(result, isA<Success<List<SourceServerLink>, KumoriyaError>>());
        for (final link
            in (result as Success<List<SourceServerLink>, KumoriyaError>)
                .value) {
          expect(link.externalSubtitles, isEmpty);
        }
      },
    );

    test(
      'subtitle API failure is non-fatal and returns empty subtitle list',
      () async {
        const episodeId = '019cd8e2-ffff-ffff-b322-e5f4efb70045';
        final watchUrl = Uri.parse(
          'https://anime.nexus/watch/$episodeId/episode-2-abc',
        );

        adapter.onGet(
          watchUrl.toString(),
          (server) => server.reply(200, '<html>subtitles</html>'),
        );

        // API call for subtitles returns 500 — should be treated as non-fatal.
        adapter.onGet(
          'https://api.anime.nexus/api/anime/details/episode/stream',
          (server) => server.reply(500, 'Internal Server Error'),
          queryParameters: <String, dynamic>{
            'id': episodeId,
            'fillers': true,
            'recaps': true,
          },
        );

        final episode = SourceEpisode(
          sourceEpisodeId: episodeId,
          number: 2,
          title: 'Episode 2',
          episodeUrl: watchUrl,
        );

        final result = await plugin.getEpisodeServerLinks(episode);

        // The overall call should still succeed with empty subtitles.
        expect(result, isA<Success<List<SourceServerLink>, KumoriyaError>>());
        for (final link
            in (result as Success<List<SourceServerLink>, KumoriyaError>)
                .value) {
          expect(link.externalSubtitles, isEmpty);
        }
      },
    );

    test('deduplicates subtitle entries with the same src url', () async {
      const episodeId = '019cd8e2-dddd-dddd-b322-e5f4efb70046';
      final watchUrl = Uri.parse(
        'https://anime.nexus/watch/$episodeId/episode-3-abc',
      );

      adapter.onGet(
        watchUrl.toString(),
        (server) => server.reply(200, '<html>sub</html>'),
      );

      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episode/stream',
        (server) => server.reply(200, {
          'data': {
            'hls':
                'https://api.anime.nexus/api/anime/video/v/stream/video.m3u8',
            'subtitles': [
              {
                'src': 'https://cdn.example.com/en.vtt',
                'label': 'English',
                'srcLang': 'en',
              },
              {
                'src': 'https://cdn.example.com/en.vtt',
                'label': 'Duplicate',
                'srcLang': 'en',
              },
            ],
          },
        }),
        queryParameters: <String, dynamic>{
          'id': episodeId,
          'fillers': true,
          'recaps': true,
        },
      );

      final episode = SourceEpisode(
        sourceEpisodeId: episodeId,
        number: 3,
        title: 'Episode 3',
        episodeUrl: watchUrl,
      );

      final result = await plugin.getEpisodeServerLinks(episode);

      expect(result, isA<Success<List<SourceServerLink>, KumoriyaError>>());
      for (final link
          in (result as Success<List<SourceServerLink>, KumoriyaError>).value) {
        expect(link.externalSubtitles, hasLength(1));
      }
    });
  });
  group('AnimeNexusSourcePlugin - getEpisodes', () {
    late Dio dio;
    late DioAdapter adapter;
    late AnimeNexusSourcePlugin plugin;

    setUp(() {
      dio = Dio(BaseOptions());
      adapter = DioAdapter(dio: dio);
      plugin = AnimeNexusSourcePlugin(
        dio: dio,
        seriesPageFetcher: (_) async {
          return '<html><head>'
              '<meta property="og:title" content="Watch Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City (Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni) TV Online Free - Fantasy">'
              '<meta property="og:description" content="Stream and watch Easygoing Territory Defense by the Optimistic Lord.">'
              '</head><body></body></html>';
        },
      );
    });

    test('preserves API slug when building watch urls', () async {
      adapter.onGet(
        'https://api.anime.nexus/api/anime/details/episodes',
        (server) => server.reply(200, {
          'data': [
            {
              'id': '019b9e8f-edf6-71a7-87c5-c45f64297245',
              'title': 'Execution',
              'slug': 'execution-537a058e13efbfab1729',
              'number': 1,
            },
            {
              'id': '019cd8e2-05d1-73d3-b322-e5f4efb70043',
              'title': 'Episode 10',
              'slug': 'episode-10-15183f0a8751f2cffefa',
              'number': 10,
            },
          ],
        }),
        queryParameters: <String, dynamic>{
          'id': 'series-uuid-001',
          'page': 1,
          'perPage': 100,
          'order': 'asc',
          'fillers': true,
          'recaps': true,
        },
      );

      final result = await plugin.getEpisodes('series-uuid-001::sample-series');

      expect(result, isA<Success<List<SourceEpisode>, KumoriyaError>>());
      final episodes =
          (result as Success<List<SourceEpisode>, KumoriyaError>).value;
      expect(episodes, hasLength(2));
      expect(
        episodes.first.episodeUrl.toString(),
        'https://anime.nexus/watch/019b9e8f-edf6-71a7-87c5-c45f64297245/execution-537a058e13efbfab1729',
      );
      expect(
        episodes.last.episodeUrl.toString(),
        'https://anime.nexus/watch/019cd8e2-05d1-73d3-b322-e5f4efb70043/episode-10-15183f0a8751f2cffefa',
      );
    });
  });

  group('AnimeNexusSourcePlugin - getAnimeDetail', () {
    late Dio dio;
    late DioAdapter adapter;
    late AnimeNexusSourcePlugin plugin;

    setUp(() {
      dio = Dio(BaseOptions());
      adapter = DioAdapter(dio: dio);
      plugin = AnimeNexusSourcePlugin(
        dio: dio,
        seriesPageFetcher: (_) async {
          return '<html><head>'
              '<meta property="og:title" content="Watch Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City (Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni) TV Online Free - Fantasy">'
              '<meta property="og:description" content="Stream and watch Easygoing Territory Defense by the Optimistic Lord.">'
              '</head><body></body></html>';
        },
      );
    });

    test(
      'falls back to direct series page when search replay misses the payload',
      () async {
        const sourceId =
            '9ede6265-c9b9-47bf-bfb5-7e340223708e::easygoing-territory-defense-by-the-optimistic-lord-production-magic-turns-a-nameless-village-into-the-strongest-fortified-city-0504b068c520f15a4965';

        adapter.onGet(
          'https://api.anime.nexus/api/anime/shows',
          (server) => server.reply(200, {'data': const <Object>[]}),
          queryParameters: <String, dynamic>{
            'search':
                'easygoing territory defense by the optimistic lord production magic turns a nameless village into the strongest fortified city',
            'page': 1,
            'sortBy': 'name asc',
            'hasVideos': true,
            'includes[]': <String>['poster', 'genres', 'background'],
          },
        );
        final result = await plugin.getAnimeDetail(sourceId);

        expect(result, isA<Success<SourceAnimeDetail, KumoriyaError>>());
        final detail =
            (result as Success<SourceAnimeDetail, KumoriyaError>).value;
        expect(
          detail.title,
          'Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City (Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni)',
        );
        expect(detail.format, AnimeFormat.tv);
        expect(
          detail.synopsis,
          contains('Easygoing Territory Defense by the Optimistic Lord'),
        );
      },
    );
  });

  group('AnimeNexusSourcePlugin - search', () {
    late Dio dio;
    late DioAdapter adapter;
    late AnimeNexusSourcePlugin plugin;

    setUp(() {
      dio = Dio(BaseOptions());
      adapter = DioAdapter(dio: dio);
      plugin = AnimeNexusSourcePlugin(dio: dio);
    });

    test('falls back to a simplified query after transport failure', () async {
      adapter.onGet(
        'https://api.anime.nexus/api/anime/shows',
        (server) => server.reply(503, {'error': 'unavailable'}),
        queryParameters: <String, dynamic>{
          'search': 'JUJUTSU KAISEN Season 3: The Culling Game Part 1',
          'page': 1,
          'sortBy': 'name asc',
          'hasVideos': true,
          'includes[]': <String>['poster', 'genres', 'background'],
        },
      );
      adapter.onGet(
        'https://api.anime.nexus/api/anime/shows',
        (server) => server.reply(200, {
          'data': [
            {
              'id': 'series-1',
              'slug': 'jujutsu-kaisen-season-3-the-culling-game',
              'name': 'JUJUTSU KAISEN Season 3',
              'type': 'tv',
            },
          ],
        }),
        queryParameters: <String, dynamic>{
          'search': 'JUJUTSU KAISEN Season 3',
          'page': 1,
          'sortBy': 'name asc',
          'hasVideos': true,
          'includes[]': <String>['poster', 'genres', 'background'],
        },
      );

      final result = await plugin.search(
        const SourceSearchQuery(
          query: 'JUJUTSU KAISEN Season 3: The Culling Game Part 1',
        ),
      );

      expect(result, isA<Success<List<SourceAnimeMatch>, KumoriyaError>>());
      final matches =
          (result as Success<List<SourceAnimeMatch>, KumoriyaError>).value;
      expect(matches, hasLength(1));
      expect(matches.single.title, 'JUJUTSU KAISEN Season 3');
    });

    test('retries transient search failures before giving up', () async {
      var attempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final searchValue = options.queryParameters['search'];
            if (options.path == 'https://api.anime.nexus/api/anime/shows' &&
                searchValue == 'Koe no Katachi') {
              attempts++;
              if (attempts < 3) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    message: 'transient failure',
                  ),
                );
                return;
              }
            }
            handler.next(options);
          },
        ),
      );

      adapter.onGet(
        'https://api.anime.nexus/api/anime/shows',
        (server) => server.reply(200, {
          'data': [
            {
              'id': 'movie-1',
              'slug': 'koe-no-katachi',
              'name': 'Koe no Katachi',
              'type': 'movie',
              'year': 2016,
            },
          ],
        }),
        queryParameters: <String, dynamic>{
          'search': 'Koe no Katachi',
          'page': 1,
          'sortBy': 'name asc',
          'hasVideos': true,
          'includes[]': <String>['poster', 'genres', 'background'],
        },
      );

      final result = await plugin.search(
        const SourceSearchQuery(query: 'Koe no Katachi'),
      );

      expect(result, isA<Success<List<SourceAnimeMatch>, KumoriyaError>>());
      final matches =
          (result as Success<List<SourceAnimeMatch>, KumoriyaError>).value;
      expect(matches, hasLength(1));
      expect(matches.single.title, 'Koe no Katachi');
      expect(attempts, 3);
    });
  });
}
