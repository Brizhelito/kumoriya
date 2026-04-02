import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumoriya_app/src/features/downloads/application/hls_segment_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('HlsSegmentDownloader', () {
    test(
      'falls back to a lower-bandwidth variant when the preferred one fails',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kumoriya-hls-fallback',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final client = MockClient((request) async {
          return switch (request.url.toString()) {
            'https://cdn.example/master.m3u8' => http.Response('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2500000
high.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1200000
mid.m3u8
''', 200),
            'https://cdn.example/high.m3u8' => http.Response('''
#EXTM3U
#EXTINF:4.0,
high-1.ts
''', 200),
            'https://cdn.example/high-1.ts' => http.Response('blocked', 503),
            'https://cdn.example/mid.m3u8' => http.Response('''
#EXTM3U
#EXTINF:4.0,
mid-1.ts
#EXTINF:4.0,
mid-2.ts
''', 200),
            'https://cdn.example/mid-1.ts' => http.Response.bytes(<int>[
              1,
              2,
              3,
            ], 200),
            'https://cdn.example/mid-2.ts' => http.Response.bytes(<int>[
              4,
              5,
              6,
            ], 200),
            _ => http.Response('not found', 404),
          };
        });

        final output = p.join(tempDir.path, 'episode.ts');
        final downloader = HlsSegmentDownloader(
          httpClient: client,
          parallelSegments: 1,
          maxRetries: 1,
        );

        final result = await downloader.download(
          masterUrl: Uri.parse('https://cdn.example/master.m3u8'),
          outputPath: output,
        );

        expect(result.totalBytes, 6);
        expect(await File(output).readAsBytes(), <int>[1, 2, 3, 4, 5, 6]);
      },
    );

    test(
      'uses the media playlist directly when there are no variants',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kumoriya-hls-direct',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final requestedUrls = <String>[];
        final client = MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return switch (request.url.toString()) {
            'https://media.example/stream/playlist.m3u8' => http.Response('''
#EXTM3U
#EXTINF:4.0,
seg-1.ts
#EXTINF:4.0,
seg-2.ts
''', 200),
            'https://media.example/stream/seg-1.ts' => http.Response.bytes(
              <int>[9, 9],
              200,
            ),
            'https://media.example/stream/seg-2.ts' => http.Response.bytes(
              <int>[8, 8],
              200,
            ),
            _ => http.Response('not found', 404),
          };
        });

        final output = p.join(tempDir.path, 'media.ts');
        final downloader = HlsSegmentDownloader(
          httpClient: client,
          parallelSegments: 1,
          maxRetries: 1,
        );

        await downloader.download(
          masterUrl: Uri.parse('https://media.example/stream/playlist.m3u8'),
          outputPath: output,
        );

        expect(requestedUrls, <String>[
          'https://media.example/stream/playlist.m3u8',
          'https://media.example/stream/seg-1.ts',
          'https://media.example/stream/seg-2.ts',
        ]);
        expect(await File(output).readAsBytes(), <int>[9, 9, 8, 8]);
      },
    );

    test('times out when a playlist body never finishes streaming', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kumoriya-hls-timeout',
      );
      final hangingController = StreamController<List<int>>();

      addTearDown(() async {
        await hangingController.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final downloader = HlsSegmentDownloader(
        parallelSegments: 1,
        maxRetries: 1,
        playlistBodyTimeout: const Duration(milliseconds: 50),
        sendRequest: (request, {required timeout}) async {
          return switch (request.url.toString()) {
            'https://media.example/stream/playlist.m3u8' =>
              http.StreamedResponse(hangingController.stream, 200),
            _ => http.StreamedResponse(Stream<List<int>>.empty(), 404),
          };
        },
      );

      final output = p.join(tempDir.path, 'media.ts');

      await expectLater(
        downloader.download(
          masterUrl: Uri.parse('https://media.example/stream/playlist.m3u8'),
          outputPath: output,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
      'falls through quickly to the next variant after playlist timeout',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kumoriya-hls-variant-timeout',
        );
        final hangingController = StreamController<List<int>>();
        var timedOutVariantAttempts = 0;

        addTearDown(() async {
          await hangingController.close();
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final downloader = HlsSegmentDownloader(
          parallelSegments: 1,
          maxRetries: 3,
          playlistBodyTimeout: const Duration(milliseconds: 50),
          sendRequest: (request, {required timeout}) async {
            return switch (request.url.toString()) {
              'https://cdn.example/master.m3u8' => http.StreamedResponse(
                Stream<List<int>>.fromIterable([
                  utf8.encode('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000
high.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000
low.m3u8
'''),
                ]),
                200,
              ),
              'https://cdn.example/high.m3u8' => () {
                timedOutVariantAttempts++;
                return http.StreamedResponse(hangingController.stream, 200);
              }(),
              'https://cdn.example/low.m3u8' => http.StreamedResponse(
                Stream<List<int>>.fromIterable([
                  utf8.encode('''
#EXTM3U
#EXTINF:4.0,
seg-low-1.ts
'''),
                ]),
                200,
              ),
              'https://cdn.example/seg-low-1.ts' => http.StreamedResponse(
                Stream<List<int>>.fromIterable([
                  <int>[7, 8, 9],
                ]),
                200,
              ),
              _ => http.StreamedResponse(Stream<List<int>>.empty(), 404),
            };
          },
        );

        final output = p.join(tempDir.path, 'episode.ts');
        final result = await downloader.download(
          masterUrl: Uri.parse('https://cdn.example/master.m3u8'),
          outputPath: output,
        );

        expect(timedOutVariantAttempts, 1);
        expect(result.totalBytes, 3);
        expect(await File(output).readAsBytes(), <int>[7, 8, 9]);
      },
    );

    test(
      'aborts sibling variants early for premilkyway playlist timeouts',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kumoriya-hls-premilkyway-timeout',
        );
        final hangingController = StreamController<List<int>>();
        var lowVariantRequested = false;

        addTearDown(() async {
          await hangingController.close();
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final downloader = HlsSegmentDownloader(
          parallelSegments: 1,
          maxRetries: 3,
          playlistBodyTimeout: const Duration(milliseconds: 50),
          sendRequest: (request, {required timeout}) async {
            return switch (request.url.toString()) {
              'https://edge1.premilkyway.com/master.m3u8' =>
                http.StreamedResponse(
                  Stream<List<int>>.fromIterable([
                    utf8.encode('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000
high.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000
low.m3u8
'''),
                  ]),
                  200,
                ),
              'https://edge1.premilkyway.com/high.m3u8' =>
                http.StreamedResponse(hangingController.stream, 200),
              'https://edge1.premilkyway.com/low.m3u8' => () {
                lowVariantRequested = true;
                return http.StreamedResponse(
                  Stream<List<int>>.fromIterable([
                    utf8.encode('''
#EXTM3U
#EXTINF:4.0,
seg-low-1.ts
'''),
                  ]),
                  200,
                );
              }(),
              _ => http.StreamedResponse(Stream<List<int>>.empty(), 404),
            };
          },
        );

        final output = p.join(tempDir.path, 'episode.ts');

        await expectLater(
          downloader.download(
            masterUrl: Uri.parse('https://edge1.premilkyway.com/master.m3u8'),
            outputPath: output,
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(lowVariantRequested, isFalse);
      },
    );
  });
}
