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

  test('search parses AnimeAV1 catalog results', () async {
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['search'], 'naruto');
        return http.Response.bytes(
          utf8.encode(
            File(
              '${fixtureDir.path}${Platform.pathSeparator}animeav1_search_naruto.html',
            ).readAsStringSync(),
          ),
          200,
          headers: const <String, String>{
            'content-type': 'text/html; charset=utf-8',
          },
        );
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

  test('detail and episodes parse from AnimeAV1 media page', () async {
    final fixture = File(
      '${fixtureDir.path}${Platform.pathSeparator}animeav1_detail_naruto.html',
    ).readAsStringSync();
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(fixture),
          200,
          headers: const <String, String>{
            'content-type': 'text/html; charset=utf-8',
          },
        ),
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
      },
    );
  });

  test('server links parse from AnimeAV1 bootstrap payload', () async {
    final plugin = AnimeAv1SourcePlugin(
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            File(
              '${fixtureDir.path}${Platform.pathSeparator}animeav1_episode_naruto_1.html',
            ).readAsStringSync(),
          ),
          200,
          headers: const <String, String>{
            'content-type': 'text/html; charset=utf-8',
          },
        );
      }),
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
