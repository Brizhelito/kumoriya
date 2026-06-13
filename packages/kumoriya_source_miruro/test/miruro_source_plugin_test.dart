import 'dart:convert';

import 'package:kumoriya_anilist/src/contracts/anilist_metadata_gateway.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_miruro/kumoriya_source_miruro.dart';
import 'package:kumoriya_source_miruro/src/miruro_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'keeps all provider variants while preserving preferred provider order',
    () async {
      final plugin = MiruroSourcePlugin(
        anilistGateway: _FakeAnilistMetadataGateway(),
        client: _FakeMiruroClient(
          responses: <String, Map<String, dynamic>>{
            'episodes': <String, dynamic>{
              'providers': <String, dynamic>{
                'bonk': <String, dynamic>{
                  'episodes': <String, dynamic>{
                    'sub': <Map<String, dynamic>>[
                      <String, dynamic>{'id': 'bonk-ep-1', 'number': 1},
                    ],
                  },
                },
                'pewe': <String, dynamic>{
                  'episodes': <String, dynamic>{
                    'sub': <Map<String, dynamic>>[
                      <String, dynamic>{'id': 'pewe-ep-1', 'number': 1},
                    ],
                  },
                },
              },
            },
          },
        ),
      );

      final result = await plugin.getEpisodes('21');

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (episodes) {
          expect(episodes, hasLength(1));
          final sourceEpisodeId =
              jsonDecode(episodes.single.sourceEpisodeId)
                  as Map<String, dynamic>;
          expect(sourceEpisodeId['provider'], 'pewe');
          expect(sourceEpisodeId['variants'], hasLength(2));
          expect(
            (sourceEpisodeId['variants'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map((variant) => variant['provider']),
            <String>['pewe', 'bonk'],
          );
        },
      );
    },
  );

  test(
    'aggregates direct streams from all encoded variants and preserves subtitles',
    () async {
      final plugin = MiruroSourcePlugin(
        anilistGateway: _FakeAnilistMetadataGateway(),
        client: _FakeMiruroClient(
          responses: <String, Map<String, dynamic>>{
            'sources': <String, dynamic>{
              'streams': <Map<String, dynamic>>[
                <String, dynamic>{
                  'url': 'https://vault-05.uwucdn.top/stream/abc/uwu.m3u8',
                  'type': 'hls',
                  'quality': '1080p',
                },
                <String, dynamic>{
                  'url': 'https://kwik.cx/e/InzZMv1U52OE',
                  'type': 'embed',
                  'quality': '1080p',
                },
              ],
              'subtitles': <Map<String, dynamic>>[
                <String, dynamic>{
                  'label': 'English',
                  'lang': 'en',
                  'url':
                      'https://mt.nekostream.site/example/subtitles/English.vtt',
                  'default': true,
                },
              ],
            },
          },
        ),
      );

      final result = await plugin.getEpisodeServerLinks(
        SourceEpisode(
          sourceEpisodeId: jsonEncode(<String, dynamic>{
            'episodeId': 'ep-1',
            'provider': 'kiwi',
            'category': 'sub',
            'anilistId': '21',
            'variants': <Map<String, dynamic>>[
              <String, dynamic>{
                'episodeId': 'ep-1',
                'provider': 'kiwi',
                'category': 'sub',
                'anilistId': '21',
              },
              <String, dynamic>{
                'episodeId': 'ep-1b',
                'provider': 'pewe',
                'category': 'dub',
                'anilistId': '21',
              },
            ],
          }),
          number: 1,
          title: 'Episode 1',
          episodeUrl: Uri.parse('https://www.miruro.tv/watch/21'),
        ),
      );

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (links) {
          expect(links, hasLength(2));
          expect(links.first.initialUrl.host, 'vault-05.uwucdn.top');
          expect(links.first.externalSubtitles, hasLength(1));
          expect(links.first.externalSubtitles.single.label, 'English');
          expect(links.first.externalSubtitles.single.isDefault, isTrue);
          expect(links.map((link) => link.serverName), <String>[
            'KIWI 1080p',
            'PEWE 1080p',
          ]);
        },
      );
    },
  );

  test('keeps successful provider variants when another variant fails', () async {
    final plugin = MiruroSourcePlugin(
      anilistGateway: _FakeAnilistMetadataGateway(),
      client: _FakeMiruroClient(
        onPipeRequest: (path, {query}) async {
          expect(path, 'sources');
          if (query?['provider'] == 'pewe') {
            throw Exception('provider temporarily blocked');
          }
          return <String, dynamic>{
            'streams': <Map<String, dynamic>>[
              <String, dynamic>{
                'url': 'https://vault-05.uwucdn.top/stream/abc/uwu.m3u8',
                'type': 'hls',
                'quality': '1080p',
              },
            ],
          };
        },
      ),
    );

    final result = await plugin.getEpisodeServerLinks(
      SourceEpisode(
        sourceEpisodeId: jsonEncode(<String, dynamic>{
          'anilistId': '21',
          'variants': <Map<String, dynamic>>[
            <String, dynamic>{
              'episodeId': 'ep-1',
              'provider': 'kiwi',
              'category': 'sub',
              'anilistId': '21',
            },
            <String, dynamic>{
              'episodeId': 'ep-1b',
              'provider': 'pewe',
              'category': 'sub',
              'anilistId': '21',
            },
          ],
        }),
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://www.miruro.tv/watch/21'),
      ),
    );

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (links) {
        expect(links, hasLength(1));
        expect(links.single.serverName, 'KIWI 1080p');
      },
    );
  });
}

final class _FakeMiruroClient extends MiruroClient {
  _FakeMiruroClient({
    this.responses = const <String, Map<String, dynamic>>{},
    this.onPipeRequest,
  });

  final Map<String, Map<String, dynamic>> responses;
  final Future<Map<String, dynamic>> Function(
    String path, {
    Map<String, dynamic>? query,
  })?
  onPipeRequest;

  @override
  Future<Map<String, dynamic>> pipeRequest(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final handler = onPipeRequest;
    if (handler != null) {
      return handler(path, query: query);
    }

    final response = responses[path];
    if (response == null) {
      throw StateError('No fake response configured for path: $path');
    }
    return response;
  }
}

final class _FakeAnilistMetadataGateway implements AnilistMetadataGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError();
  }
}
