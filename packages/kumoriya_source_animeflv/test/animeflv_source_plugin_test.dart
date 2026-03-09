import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';
import 'package:test/test.dart';

void main() {
  final fixtureDir = Directory(
    '${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}fixtures',
  );

  test('search parses AnimeFLV browse results', () async {
    final plugin = AnimeFlvSourcePlugin(
      httpClient: MockClient((request) async {
        return http.Response(
          File(
            '${fixtureDir.path}${Platform.pathSeparator}animeflv_search_naruto.html',
          ).readAsStringSync(),
          200,
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

  test('episodes parse from AnimeFLV detail script', () async {
    final plugin = AnimeFlvSourcePlugin(
      httpClient: MockClient((request) async {
        return http.Response(
          File(
            '${fixtureDir.path}${Platform.pathSeparator}animeflv_detail_naruto.html',
          ).readAsStringSync(),
          200,
        );
      }),
    );

    final result = await plugin.getEpisodes('naruto');

    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (episodes) {
        expect(episodes, hasLength(3));
        expect(episodes.first.number, 1);
        expect(episodes.last.number, 3);
      },
    );
  });

  test('server links parse from AnimeFLV videos payload', () async {
    final plugin = AnimeFlvSourcePlugin(
      httpClient: MockClient((request) async {
        return http.Response(
          File(
            '${fixtureDir.path}${Platform.pathSeparator}animeflv_episode_naruto_1.html',
          ).readAsStringSync(),
          200,
        );
      }),
    );

    final result = await plugin.getEpisodeServerLinks(
      SourceEpisode(
        sourceEpisodeId: 'naruto_1',
        number: 1,
        title: 'Episodio 1',
        episodeUrl: Uri.parse('https://www3.animeflv.net/ver/naruto-1'),
      ),
    );

    result.fold(
      onFailure: (error) => fail('expected success, got ${error.message}'),
      onSuccess: (links) {
        expect(links, hasLength(3));
        expect(links.first.detectedHost, 'streamwish.to');
        expect(links[1].detectedHost, 'streamtape.com');
      },
    );
  });
}
