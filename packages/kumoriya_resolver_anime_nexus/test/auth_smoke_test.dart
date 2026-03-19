// ignore_for_file: avoid_print
/// Auth smoke test – mirrors scrapper_engine auth flow step-by-step.
///
/// Run: flutter test packages/kumoriya_resolver_anime_nexus/test/auth_smoke_test.dart --reporter expanded
///
/// What this validates:
///   1. Auth session bootstrap (/api/auth/session) returns set-cookie headers.
///   2. Stream metadata endpoint (/api/anime/details/episode/stream) returns a
///      Map<String, dynamic> payload with a data.hls field.
///   3. Page scraper extracts attestRef from watch page.
///   4. WebSocket global CONNECT with auth {videoId, fingerprint, m3u8Url, sessionId}
///      completes with CONNECT ACK (state: AUTHENTICATED).
///
/// Protocol (scrapper_engine-compatible):
///   - After Engine.IO OPEN → send 40{videoId, fingerprint, m3u8Url, sessionId}
///   - Server responds with 40{sid} → AUTHENTICATED (no separate auth event)
///   - Token requests: 42["get-token",{requestType,resourcePath,sessionId}]
///   - Token responses: server push 42["token",{...}]
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'package:kumoriya_resolver_anime_nexus/src/models/nexus_browser_session.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/page_scraper.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/stream_data_fetcher.dart';
import 'package:kumoriya_resolver_anime_nexus/src/utils/nexus_constants.dart';

// --- Test episode (use a stable, publicly accessible episode) ---
const _episodeUrl =
    'https://anime.nexus/watch/019cdcfe-dc32-7328-9747-0e6ef96dbd06/'
    'episode-10-c9b0cd86068190028be1';

Dio _buildDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: <String, String>{
      'User-Agent': NexusConstants.userAgent,
      'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
    },
  ),
);

void main() {
  late Dio dio;
  late NexusBrowserSession session;

  setUp(() {
    dio = _buildDio();
    session = NexusBrowserSession.generate();
    print('\n[smoke] fingerprint=${session.fingerprint}');
    print('[smoke] initial-cookies=${session.cookieHeader}');
  });

  tearDown(() => dio.close());

  group('Auth smoke (live) –', () {
    // ------------------------------------------------------------------ [1]
    test(
      '[1] auth session bootstrap sets cookies',
      () async {
        print('\n--- [1] GET /api/auth/session ---');
        final response = await dio.get<dynamic>(
          '${NexusConstants.mainBase}/api/auth/session',
          options: Options(
            validateStatus: (s) => s != null && s < 500,
            headers: <String, String>{
              'Accept': 'application/json, text/plain, */*',
              'Referer': '${NexusConstants.mainBase}/',
              'sec-fetch-dest': 'empty',
              'sec-fetch-mode': 'cors',
              'sec-fetch-site': 'same-origin',
              if (session.cookieHeader != null) 'Cookie': session.cookieHeader!,
            },
          ),
        );
        print('[1] status=${response.statusCode}');
        final setCookies = response.headers['set-cookie'];
        print('[1] set-cookie=$setCookies');

        expect(
          response.statusCode,
          lessThan(500),
          reason: 'Auth session should not return 5xx',
        );
        // On a clear IP, the server sets cookies here.
        // On a blocked IP, this step may return 403 HTML.
        if (response.statusCode == 200 && response.data is Map) {
          print('[1] ✅ auth session returned JSON map');
        } else {
          print(
            '[1] ⚠️  auth session returned status=${response.statusCode} '
            '(type=${response.data.runtimeType}). '
            'Cloudflare may be blocking this IP.',
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    // ------------------------------------------------------------------ [2]
    test(
      '[2] stream metadata returns data.hls (full fetch flow)',
      () async {
        print('\n--- [2] NexusStreamDataFetcher.fetch() ---');
        final episodeId = Uri.parse(
          _episodeUrl,
        ).pathSegments.where((s) => s.isNotEmpty).toList()[1];
        print('[2] episodeId=$episodeId');

        try {
          final streamData = await NexusStreamDataFetcher(
            dio,
          ).fetch(episodeId: episodeId, session: session);
          print('[2] ✅ hlsUrl=${streamData.hlsUrl}');
          print('[2] videoId=${streamData.videoId}');
          expect(streamData.hlsUrl.toString(), isNotEmpty);
          expect(streamData.videoId, isNotEmpty);
        } on NexusStreamDataException catch (e) {
          // Surface the real reason (Cloudflare block vs auth issue)
          print('[2] ❌ NexusStreamDataException: ${e.message}');
          if (e.message.contains('blocking') ||
              e.message.contains('unexpected content') ||
              e.message.contains('403')) {
            print(
              '[2] → Likely cause: Cloudflare is blocking this IP/VPN. '
              'Try disabling VPN or running from a different network.',
            );
          }
          rethrow;
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    // ------------------------------------------------------------------ [3]
    test(
      '[3] page scraper extracts attestRef',
      () async {
        print('\n--- [3] NexusPageScraper.scrape() ---');
        try {
          final pageData = await NexusPageScraper(
            dio,
          ).scrape(Uri.parse(_episodeUrl), session: session);
          print('[3] ✅ episodeId=${pageData.episodeId}');
          print('[3] attestRef=${pageData.attestRef.substring(0, 16)}...');
          expect(pageData.episodeId, isNotEmpty);
          expect(pageData.attestRef.length, equals(64));
        } on NexusScraperException catch (e) {
          print('[3] ❌ NexusScraperException: ${e.message}');
          if (e.message.contains('empty HTML') ||
              e.message.contains('attestRef')) {
            print(
              '[3] → Likely cause: Cloudflare returned HTML challenge instead '
              'of the watch page. Disable VPN and retry.',
            );
          }
          rethrow;
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          print('[3] ❌ DioException status=$status: ${e.message}');
          print(
            '[3] → Likely cause: Cloudflare is blocking this IP/VPN (status $status). '
            'Disable VPN or run from a different network.',
          );
          rethrow;
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    // ------------------------------------------------------------------ [4+5]
    test(
      '[4+5] WS connect + auth handshake (requires [2]+[3])',
      () async {
        print('\n--- [4+5] Full WS auth flow (global CONNECT protocol) ---');
        final episodeId = Uri.parse(
          _episodeUrl,
        ).pathSegments.where((s) => s.isNotEmpty).toList()[1];
        print('[4] episodeId=$episodeId');

        // Step 4: Get stream data (provides hlsUrl + videoId)
        final NexusStreamDataFetcher fetcher = NexusStreamDataFetcher(dio);
        final streamData = await fetcher.fetch(
          episodeId: episodeId,
          session: session,
        );
        print('[4] ✅ videoId=${streamData.videoId}');
        print('[4] ✅ hlsUrl=${streamData.hlsUrl}');
        print(
          '[4] cookieHeader=${streamData.cookieHeader != null ? "present (${streamData.cookieHeader!.length} chars)" : "MISSING ⚠️"}',
        );

        // Step 5: Generate client sessionId (UUID v4)
        final rng = Random.secure();
        final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        final hex = bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        final clientSessionId =
            '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
            '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
            '-${hex.substring(20)}';
        print('[5] clientSessionId=$clientSessionId');
        print('[5] fingerprint=${session.fingerprint}');

        // Step 6: Open WebSocket
        final wsUri = Uri(
          scheme: 'wss',
          host: 'prd-socket.anime.nexus',
          path: '/api/socket/',
          queryParameters: <String, String>{
            'videoId': streamData.videoId,
            'fingerprint': session.fingerprint,
            'm3u8Url': streamData.hlsUrl.toString(),
            'EIO': '4',
            'transport': 'websocket',
          },
        );
        print('[6] WS uri=$wsUri');

        final wsHeaders = <String, Object>{
          'Origin': NexusConstants.mainBase,
          HttpHeaders.userAgentHeader: NexusConstants.userAgent,
          if (streamData.cookieHeader != null)
            HttpHeaders.cookieHeader: streamData.cookieHeader!,
        };
        print(
          '[6] WS headers: Origin=${NexusConstants.mainBase} | '
          'Cookie=${streamData.cookieHeader != null ? "present" : "MISSING ⚠️"}',
        );

        final socket = await WebSocket.connect(
          wsUri.toString(),
          headers: wsHeaders,
        );
        print('[6] ✅ WebSocket TCP+TLS upgraded');

        final authed = Completer<String>();
        final allFrames = <String>[];

        socket.listen(
          (raw) {
            final msg = raw.toString();
            allFrames.add(msg);
            final preview = msg.length > 200
                ? '${msg.substring(0, 200)}…'
                : msg;

            // Annotate frames with human-readable tags
            if (msg.startsWith('0{') || msg == '0') {
              print('[ws] ← ENGINE_IO_OPEN $preview');
            } else if (msg == '2') {
              print('[ws] ← PING');
            } else if (msg.startsWith('40') && !msg.startsWith('40/')) {
              // Global namespace CONNECT ACK = AUTHENTICATED
              String sid = '';
              try {
                sid =
                    (jsonDecode(msg.substring(2)) as Map)['sid']?.toString() ??
                    '';
              } catch (_) {}
              print('[ws] ← CONNECT_ACK (AUTHENTICATED) sid=$sid');
            } else if (msg.startsWith('42') && !msg.startsWith('42/')) {
              // Global EVENT
              try {
                final list = jsonDecode(msg.substring(2)) as List<dynamic>;
                final event = list[0] as String;
                final data = list.length > 1 ? list[1] : null;
                print('[ws] ← EVENT[$event] data=${jsonEncode(data)}');
                if (event == 'authentication-error') {
                  final m = (data is Map) ? data['message'] : null;
                  print('[ws] ❌ AUTH REJECTED by server');
                  print('[ws]    reason: $m');
                  if (!authed.isCompleted) authed.complete('AUTH_ERROR: $m');
                  return;
                }
              } catch (e) {
                print('[ws] ← EVENT (parse error: $e) raw=$preview');
              }
            } else if (msg.startsWith('44') && !msg.startsWith('44/')) {
              print('[ws] ← CONNECT_ERROR ${msg.substring(2)}');
              if (!authed.isCompleted) {
                authed.complete('CONNECT_ERROR: ${msg.substring(2)}');
              }
            } else {
              print('[ws] ← $preview');
            }

            if (msg.startsWith('0{') || msg == '0') {
              // Engine.IO OPEN → send global Socket.IO CONNECT with auth payload
              final authObj = <String, Object>{
                'videoId': streamData.videoId,
                'fingerprint': session.fingerprint,
                'm3u8Url': streamData.hlsUrl.toString(),
                'sessionId': clientSessionId,
              };
              final frame = '40${jsonEncode(authObj)}';
              socket.add(frame);
              print('[7] → CONNECT_WITH_AUTH ${jsonEncode(authObj)}');
              return;
            }
            if (msg == '2') {
              socket.add('3');
              return;
            }
            // Global CONNECT ACK = auth succeeded
            if (msg.startsWith('40') && !msg.startsWith('40/')) {
              if (!authed.isCompleted) authed.complete('AUTHENTICATED');
              return;
            }
          },
          onError: (Object e) {
            print('[ws] ❌ SOCKET_ERROR type=${e.runtimeType} detail=$e');
            if (!authed.isCompleted) authed.complete('SOCKET_ERROR: $e');
          },
          onDone: () {
            print(
              '[ws] ⚠️  SOCKET_CLOSED closeCode=${socket.closeCode} '
              'closeReason=${socket.closeReason ?? "none"}',
            );
            if (!authed.isCompleted) authed.complete('SOCKET_CLOSED');
          },
        );

        final result = await authed.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('[ws] ⚠️  TIMEOUT — no auth response in 15s');
            print('[ws]    frames received so far: ${allFrames.length}');
            for (final f in allFrames) {
              print('[ws]    $f');
            }
            return 'TIMEOUT';
          },
        );
        await socket.close();

        print('\n[RESULT] $result');
        if (result != 'AUTHENTICATED') {
          print('[DIAGNOSIS] Auth failed. Debug checklist:');
          print('  videoId     = ${streamData.videoId}');
          print('  fingerprint = ${session.fingerprint}');
          print('  sessionId   = $clientSessionId');
          print('  m3u8Url     = ${streamData.hlsUrl}');
          print(
            '  cookieHdr   = ${streamData.cookieHeader?.substring(0, 40) ?? "MISSING"}...',
          );
          print('  Total WS frames received: ${allFrames.length}');
          print('  All frames:');
          for (var i = 0; i < allFrames.length; i++) {
            print('    [$i] ${allFrames[i]}');
          }
        }
        expect(
          result,
          equals('AUTHENTICATED'),
          reason: 'WS global CONNECT ACK not received. Got: $result',
        );
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
