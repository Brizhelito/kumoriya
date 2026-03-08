import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';
import 'package:test/test.dart';

void main() {
  final searchFixture = File(
    'test/fixtures/jkanime_search_naruto.html',
  ).readAsStringSync();
  final detailFixture = File(
    'test/fixtures/jkanime_detail_naruto.html',
  ).readAsStringSync();
  final episodesFixture = File(
    'test/fixtures/jkanime_episodes_page1_naruto.json',
  ).readAsStringSync();
  final serverLinksFixture = File(
    'test/fixtures/jkanime_episode_server_links_page.html',
  ).readAsStringSync();
  final serverLinksEmptyFixture = File(
    'test/fixtures/jkanime_episode_server_links_empty.html',
  ).readAsStringSync();

  test('search parses JKAnime cards into source matches', () async {
    final plugin = JkAnimeSourcePlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/buscar/Naruto/');
        return http.Response(searchFixture, 200);
      }),
    );

    final result = await plugin.search(
      const SourceSearchQuery(query: 'Naruto'),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (items) {
        expect(items.length, 2);
        expect(items.first.sourceId, 'naruto');
      },
    );
  });

  test('getAnimeDetail parses minimal useful fields', () async {
    final plugin = JkAnimeSourcePlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/naruto/');
        return http.Response(detailFixture, 200);
      }),
    );

    final result = await plugin.getAnimeDetail('naruto');

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (detail) {
        expect(detail.title, 'Naruto');
        expect(detail.releaseYear, 2002);
      },
    );
  });

  test('getEpisodes loads ajax payload with csrf/session context', () async {
    final plugin = JkAnimeSourcePlugin(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/naruto/') {
          return http.Response(
            detailFixture,
            200,
            headers: <String, String>{'set-cookie': 'jk_session=abc; path=/'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/ajax/episodes/123/1') {
          expect(request.headers['x-csrf-token'], 'abc123token');
          expect(request.headers['cookie'], contains('jk_session=abc'));
          return http.Response(episodesFixture, 200);
        }

        return http.Response('not found', 404);
      }),
    );

    final result = await plugin.getEpisodes('naruto');

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (episodes) {
        expect(episodes.length, 2);
        expect(episodes.first.number, 1);
        expect(
          episodes.first.episodeUrl.toString(),
          'https://jkanime.net/naruto/1/',
        );
      },
    );
  });

  test('getEpisodeServerLinks parses server links from episode page', () async {
    final plugin = JkAnimeSourcePlugin(
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/naruto/1/');
        return http.Response(serverLinksFixture, 200);
      }),
    );

    final episode = SourceEpisode(
      sourceEpisodeId: '1',
      number: 1,
      title: 'Episode 1',
      episodeUrl: Uri.parse('https://jkanime.net/naruto/1/'),
    );

    final result = await plugin.getEpisodeServerLinks(episode);

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (links) {
        expect(links, hasLength(2));
        expect(links.first.serverName, 'Desu');
        expect(links.first.initialUrl.toString(), contains('/jkplayer/um?'));
      },
    );
  });

  test(
    'getEpisodeServerLinks returns empty list when no servers exist',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/2/');
          return http.Response(serverLinksEmptyFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '2',
        number: 2,
        title: 'Episode 2',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/2/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) => expect(links, isEmpty),
      );
    },
  );
}
