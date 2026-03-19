import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:test/test.dart';

void main() {
  final fixtureDir = Directory(
    '${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}fixtures',
  );
  http.Response htmlResponse(String fixtureName) {
    return http.Response.bytes(
      utf8.encode(
        File(
          '${fixtureDir.path}${Platform.pathSeparator}$fixtureName',
        ).readAsStringSync(),
      ),
      200,
      headers: const <String, String>{
        'content-type': 'text/html; charset=utf-8',
      },
    );
  }

  test('search parses AnimeAV1 catalog results', () async {
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['search'], 'naruto');
        return htmlResponse('animeav1_search_naruto.html');
      }),
    );

    final result = await plugin.search(
      const SourceSearchQuery(query: 'naruto'),
    );

    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (matches) {
        expect(matches, hasLength(2));
        expect(matches.first.sourceId, 'naruto');
        expect(matches.first.title, 'Naruto');
      },
    );
  });

  test('search retries AnimeAV1 with conservative fallback query', () async {
    final requests = <String>[];
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient((request) async {
        final query = request.url.queryParameters['search'] ?? '';
        requests.add(query);

        if (query == 'Naruto 1st Season') {
          return http.Response.bytes(
            utf8.encode('<html><body></body></html>'),
            200,
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
            },
          );
        }

        if (query == 'Naruto') {
          return htmlResponse('animeav1_search_naruto.html');
        }

        return http.Response('unexpected query: $query', 500);
      }),
    );

    final result = await plugin.search(
      const SourceSearchQuery(query: 'Naruto 1st Season'),
    );

    expect(requests, <String>['Naruto 1st Season', 'Naruto']);
    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (matches) {
        expect(matches, hasLength(2));
        expect(matches.first.sourceId, 'naruto');
      },
    );
  });

  test(
    'search retries AnimeAV1 after trailing parenthetical fallback',
    () async {
      final requests = <String>[];
      final plugin = AnimeAv1SourcePlugin(
        httpClient: MockClient((request) async {
          final query = request.url.queryParameters['search'] ?? '';
          requests.add(query);

          if (query == 'Naruto (TV)') {
            return http.Response.bytes(
              utf8.encode('<html><body></body></html>'),
              200,
              headers: const <String, String>{
                'content-type': 'text/html; charset=utf-8',
              },
            );
          }

          if (query == 'Naruto') {
            return htmlResponse('animeav1_search_naruto.html');
          }

          return http.Response('unexpected query: $query', 500);
        }),
      );

      final result = await plugin.search(
        const SourceSearchQuery(query: 'Naruto (TV)'),
      );

      expect(requests, <String>['Naruto (TV)', 'Naruto']);
      result.fold(
        onFailure: (error) => fail('expected success, got ${error.message}'),
        onSuccess: (matches) {
          expect(matches, hasLength(2));
          expect(matches.first.sourceId, 'naruto');
        },
      );
    },
  );

  test('search retries AnimeAV1 after slug spacing fallback', () async {
    final requests = <String>[];
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient((request) async {
        final query = request.url.queryParameters['search'] ?? '';
        requests.add(query);

        if (query == 'Naruto!!!') {
          return http.Response.bytes(
            utf8.encode('<html><body></body></html>'),
            200,
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
            },
          );
        }

        if (query == 'naruto') {
          return htmlResponse('animeav1_search_naruto.html');
        }

        return http.Response('unexpected query: $query', 500);
      }),
    );

    final result = await plugin.search(
      const SourceSearchQuery(query: 'Naruto!!!'),
    );

    expect(requests, <String>['Naruto!!!', 'naruto']);
    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (matches) {
        expect(matches, hasLength(2));
        expect(matches.first.sourceId, 'naruto');
      },
    );
  });

  test(
    'detail and episodes parse from AnimeAV1 fallback DOM fixture',
    () async {
      final plugin = AnimeAv1SourcePlugin(
        httpClient: MockClient(
          (request) async => htmlResponse('animeav1_detail_naruto.html'),
        ),
      );

      final detailResult = await plugin.getAnimeDetail('naruto');
      final episodesResult = await plugin.getEpisodes('naruto');

      detailResult.fold(
        onFailure: (error) => fail('expected success, got ${error.message}'),
        onSuccess: (detail) {
          expect(detail.title, 'Naruto');
          expect(detail.releaseYear, 2002);
        },
      );
      episodesResult.fold(
        onFailure: (error) => fail('expected success, got ${error.message}'),
        onSuccess: (episodes) {
          expect(episodes, hasLength(3));
          expect(episodes.first.number, 1);
          expect(episodes.last.number, 3);
        },
      );
    },
  );

  test(
    'episodes parse complete single-block list from AnimeAV1 bootstrap',
    () async {
      final plugin = AnimeAv1SourcePlugin(
        httpClient: MockClient(
          (request) async =>
              htmlResponse('animeav1_detail_kimetsu_no_yaiba.html'),
        ),
      );

      final episodesResult = await plugin.getEpisodes('kimetsu-no-yaiba');

      episodesResult.fold(
        onFailure: (error) => fail('expected success, got ${error.message}'),
        onSuccess: (episodes) {
          expect(episodes, hasLength(26));
          expect(episodes.first.number, 1);
          expect(episodes.last.number, 26);
          expect(
            episodes.last.episodeUrl,
            Uri.parse('https://animeav1.com/media/kimetsu-no-yaiba/26'),
          );
        },
      );
    },
  );

  test(
    'episodes parse complete multi-block list from AnimeAV1 bootstrap',
    () async {
      final plugin = AnimeAv1SourcePlugin(
        httpClient: MockClient(
          (request) async =>
              htmlResponse('animeav1_detail_naruto_shippuuden.html'),
        ),
      );

      final episodesResult = await plugin.getEpisodes('naruto-shippuuden');

      episodesResult.fold(
        onFailure: (error) => fail('expected success, got ${error.message}'),
        onSuccess: (episodes) {
          expect(episodes, hasLength(500));
          expect(episodes.first.number, 1);
          expect(episodes[49].number, 50);
          expect(episodes[50].number, 51);
          expect(episodes.last.number, 500);
          expect(
            episodes.map((episode) => episode.number).toSet(),
            hasLength(500),
          );
          expect(
            episodes.last.episodeUrl,
            Uri.parse('https://animeav1.com/media/naruto-shippuuden/500'),
          );
        },
      );
    },
  );

  test('server links parse from AnimeAV1 bootstrap payload', () async {
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient(
        (request) async => htmlResponse('animeav1_episode_naruto_1.html'),
      ),
    );

    final result = await plugin.getEpisodeServerLinks(
      SourceEpisode(
        sourceEpisodeId: 'naruto_1',
        number: 1,
        title: 'Episodio 1',
        episodeUrl: Uri.parse('https://animeav1.com/media/naruto/1'),
      ),
    );

    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (links) {
        expect(links, hasLength(4));
        expect(links.first.serverName, 'HLS');
        expect(links[1].detectedHost, 'www.mp4upload.com');
        expect(links[2].detectedHost, 'streamtape.com');
      },
    );
  });
}
