import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
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
  final detailNoH3Fixture = File(
    'test/fixtures/jkanime_detail_without_h3.html',
  ).readAsStringSync();
  final episodesFixture = File(
    'test/fixtures/jkanime_episodes_page1_naruto.json',
  ).readAsStringSync();
  final searchDuplicatesFixture = File(
    'test/fixtures/jkanime_search_duplicates_and_external.html',
  ).readAsStringSync();
  final serverLinksFixture = File(
    'test/fixtures/jkanime_episode_server_links_page.html',
  ).readAsStringSync();
  final serverLinksEmptyFixture = File(
    'test/fixtures/jkanime_episode_server_links_empty.html',
  ).readAsStringSync();
  final serverLinksHrefFallbackFixture = File(
    'test/fixtures/jkanime_episode_server_links_href_fallback.html',
  ).readAsStringSync();
  final serverLinksPartialFixture = File(
    'test/fixtures/jkanime_episode_server_links_partial_mapping.html',
  ).readAsStringSync();
  final serverLinksBrokenFixture = File(
    'test/fixtures/jkanime_episode_server_links_buttons_without_mapping.html',
  ).readAsStringSync();
  final serverLinksMultilineVariantsFixture = File(
    'test/fixtures/jkanime_episode_server_links_multiline_variants.html',
  ).readAsStringSync();
  final serverLinksElementIdFixture = File(
    'test/fixtures/jkanime_episode_server_links_element_id_fallback.html',
  ).readAsStringSync();
  final serverLinksMalformedScriptFixture = File(
    'test/fixtures/jkanime_episode_server_links_malformed_script.html',
  ).readAsStringSync();
  final serverLinksMarkupWithoutButtonsFixture = File(
    'test/fixtures/jkanime_episode_server_links_markup_without_buttons.html',
  ).readAsStringSync();
  final serverLinksMismatchedIndexesFixture = File(
    'test/fixtures/jkanime_episode_server_links_mismatched_indexes.html',
  ).readAsStringSync();
  final serverLinksFullSourcesFixture = File(
    'test/fixtures/jkanime_episode_server_links_full_sources_and_downloads.html',
  ).readAsStringSync();
  final serverLinksDynamicPayloadFixture = File(
    'test/fixtures/jkanime_episode_server_links_dynamic_servers_payload.html',
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

  test('search skips duplicate and external host candidates', () async {
    final plugin = JkAnimeSourcePlugin(
      httpClient: MockClient((request) async {
        return http.Response(searchDuplicatesFixture, 200);
      }),
    );

    final result = await plugin.search(
      const SourceSearchQuery(query: 'Naruto'),
    );
    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (items) {
        expect(items, hasLength(1));
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

  test('getAnimeDetail can fallback to og:title when h3 is missing', () async {
    final plugin = JkAnimeSourcePlugin(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/naruto/');
        return http.Response(detailNoH3Fixture, 200);
      }),
    );

    final result = await plugin.getAnimeDetail('naruto');
    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (detail) {
        expect(detail.title, 'Naruto');
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

  test(
    'getEpisodeServerLinks supports href option fallback when data-id is absent',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/3/');
          return http.Response(serverLinksHrefFallbackFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '3',
        number: 3,
        title: 'Episode 3',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/3/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          expect(links, hasLength(2));
          expect(links[1].language, 'lat');
        },
      );
    },
  );

  test(
    'getEpisodeServerLinks keeps mapped links when payload is partial',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/4/');
          return http.Response(serverLinksPartialFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '4',
        number: 4,
        title: 'Episode 4',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/4/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          expect(links, hasLength(1));
          expect(links.first.serverName, 'Desu');
        },
      );
    },
  );

  test(
    'getEpisodeServerLinks parses multiline quoted variants and direct URLs',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/6/');
          return http.Response(serverLinksMultilineVariantsFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '6',
        number: 6,
        title: 'Episode 6',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/6/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          expect(links, hasLength(2));
          expect(links.first.language, 'sub');
          expect(links.last.language, 'lat');
          expect(
            links.last.initialUrl.toString(),
            'https://stream.jkanimecdn.com/embed/xyz987',
          );
        },
      );
    },
  );

  test(
    'getEpisodeServerLinks can resolve index from element id fallback',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/7/');
          return http.Response(serverLinksElementIdFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '7',
        number: 7,
        title: 'Episode 7',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/7/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          expect(links, hasLength(1));
          expect(links.single.serverId, '12-desu');
        },
      );
    },
  );

  test(
    'getEpisodeServerLinks returns empty safely when markup exists but no server buttons',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/8/');
          return http.Response(serverLinksMarkupWithoutButtonsFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '8',
        number: 8,
        title: 'Episode 8',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/8/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) => expect(links, isEmpty),
      );
    },
  );

  test(
    'getEpisodeServerLinks fails safely when server buttons cannot be mapped',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/5/');
          return http.Response(serverLinksBrokenFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '5',
        number: 5,
        title: 'Episode 5',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/5/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'jkanime.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test(
    'getEpisodeServerLinks fails with parse error for malformed video script',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/9/');
          return http.Response(serverLinksMalformedScriptFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '9',
        number: 9,
        title: 'Episode 9',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/9/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'jkanime.parse');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test(
    'getEpisodeServerLinks extracts expanded stream/download sources and resolves c1 wrappers',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/11/');
          return http.Response(serverLinksFullSourcesFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '11',
        number: 11,
        title: 'Episode 11',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/11/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          expect(links, hasLength(12));

          final streamLinks = links
              .where((link) => link.linkType == SourceServerLinkType.stream)
              .toList(growable: false);
          final downloadLinks = links
              .where((link) => link.linkType == SourceServerLinkType.download)
              .toList(growable: false);

          expect(streamLinks, hasLength(10));
          expect(downloadLinks, hasLength(2));

          final voe = streamLinks.firstWhere(
            (link) => link.serverName == 'VOE',
          );
          expect(voe.initialUrl.host, 'voe.sx');
          expect(voe.detectedHost, 'voe.sx');

          final mediafire = downloadLinks.firstWhere(
            (link) => link.serverName == 'Mediafire',
          );
          expect(mediafire.initialUrl.host, 'c1.jkplayers.com');
          expect(mediafire.detectedHost, 'mediafire.com');
        },
      );
    },
  );

  test(
    'getEpisodeServerLinks fails with inconsistent error for mismatched indexes',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/10/');
          return http.Response(serverLinksMismatchedIndexesFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '10',
        number: 10,
        title: 'Episode 10',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/10/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isFailure, isTrue);
      result.fold(
        onFailure: (error) {
          expect(error.kind, KumoriyaErrorKind.mapping);
          expect(error.code, 'jkanime.inconsistent');
        },
        onSuccess: (_) => fail('expected failure'),
      );
    },
  );

  test(
    'getEpisodeServerLinks expands stream list from dynamic var servers payload',
    () async {
      final plugin = JkAnimeSourcePlugin(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/naruto/12/');
          return http.Response(serverLinksDynamicPayloadFixture, 200);
        }),
      );

      final episode = SourceEpisode(
        sourceEpisodeId: '12',
        number: 12,
        title: 'Episode 12',
        episodeUrl: Uri.parse('https://jkanime.net/naruto/12/'),
      );

      final result = await plugin.getEpisodeServerLinks(episode);
      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          final streamLinks = links
              .where((link) => link.linkType == SourceServerLinkType.stream)
              .toList(growable: false);
          final downloadLinks = links
              .where((link) => link.linkType == SourceServerLinkType.download)
              .toList(growable: false);

          expect(streamLinks, hasLength(11));
          expect(downloadLinks, hasLength(1));

          expect(
            streamLinks.any((link) => link.serverName == 'Streamwish'),
            isTrue,
          );
          expect(
            streamLinks.any((link) => link.serverName == 'Mixdrop'),
            isTrue,
          );
          expect(
            streamLinks.any((link) => link.serverName == 'Doodstream'),
            isTrue,
          );

          final streamwish = streamLinks.firstWhere(
            (link) => link.serverName == 'Streamwish',
          );
          expect(streamwish.initialUrl.host, 'sfastwish.com');
          expect(streamwish.detectedHost, 'sfastwish.com');

          final mediafire = downloadLinks.single;
          expect(mediafire.serverName, 'Mediafire');
          expect(mediafire.initialUrl.host, 'mediafire.com');
          expect(mediafire.detectedHost, 'mediafire.com');
        },
      );
    },
  );
}
