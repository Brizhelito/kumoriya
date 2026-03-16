// ignore_for_file: avoid_print, lines_longer_than_80_chars
/// Real integration test for the Anime Nexus WebSocket auth flow.
/// Run with: flutter test test/real_ws_connection_test.dart --timeout=120s
///
/// This test hits the real anime.nexus servers — it requires network
/// access and will fail if the server is down or the contract changes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'package:kumoriya_resolver_anime_nexus/src/models/nexus_browser_session.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/page_scraper.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/stream_data_fetcher.dart';
import 'package:kumoriya_resolver_anime_nexus/src/utils/nexus_constants.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, String>{
          'User-Agent': NexusConstants.userAgent,
        },
      ),
    );
  });

  tearDown(() => dio.close());

  test('download player JS and extract auth contract', () async {
    const watchUrlStr =
      'https://anime.nexus/watch/019b9e8f-edf6-71a7-87c5-c45f64297245/execution-537a058e13efbfab1729';

    print('[info] fetching watch page HTML...');
    final pageResp = await dio.get<String>(
      watchUrlStr,
      options: Options(responseType: ResponseType.plain),
    );
    final html = pageResp.data ?? '';
    print('[info] html-length=${html.length}');

    // Find ALL script tags
    final scriptRe = RegExp(r'<script[^>]*src="([^"]+)"[^>]*>');
    final scripts = scriptRe.allMatches(html).map((m) => m.group(1)!).toList();
    print('[info] script tags found: ${scripts.length}');
    for (final s in scripts) {
      print('  → $s');
    }

    // Find the player or main app bundle (likely the largest or one containing "player")
    String? playerJsUrl;
    for (final s in scripts) {
      if (s.contains('player') || s.contains('app') || s.contains('main')) {
        playerJsUrl = s;
        break;
      }
    }
    // If no "player" script, look for the _app chunk or the largest one
    playerJsUrl ??= scripts.isNotEmpty ? scripts.last : null;

    if (playerJsUrl != null) {
      final fullUrl = playerJsUrl.startsWith('http')
          ? playerJsUrl
          : '${NexusConstants.mainBase}$playerJsUrl';
      print('\n[info] downloading JS: $fullUrl');
      final jsResp = await dio.get<String>(
        fullUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final js = jsResp.data ?? '';
      print('[info] js-length=${js.length}');

      // Search for auth-related patterns showing 200 chars of context
      for (final pattern in <String>[
        r'"auth"',
        r"'auth'",
        'attestRef',
        'attestation',
        '.emit(',
      ]) {
        final re = RegExp('.{0,100}${RegExp.escape(pattern)}.{0,100}');
        final matches = re.allMatches(js).take(8);
        if (matches.isNotEmpty) {
          print('\n[js-pattern] "$pattern":');
          for (final m in matches) {
            print('  ${m.group(0)?.replaceAll('\n', ' ')}');
          }
        }
      }
    }

    // Also look for script tags in the RSC payload that might contain inline player code
    final inlineScriptRe = RegExp(r'<script[^>]*>([\s\S]{20,500}?)</script>');
    final inlineMatches = inlineScriptRe.allMatches(html).take(5);
    for (final m in inlineMatches) {
      final content = m.group(1) ?? '';
      if (content.contains('socket') || content.contains('attest') || content.contains('auth')) {
        print('\n[inline-script] ${content.substring(0, content.length.clamp(0, 300))}');
      }
    }

    print('\n[done]');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('full flow WS auth with real services', () async {
    const watchUrlStr =
      'https://anime.nexus/watch/019b9e8f-edf6-71a7-87c5-c45f64297245/execution-537a058e13efbfab1729';
    final watchUrl = Uri.parse(watchUrlStr);
    final browserSession = NexusBrowserSession.generate();
    print('[info] fingerprint=${browserSession.fingerprint}');
    print('[info] initial-cookies=${browserSession.cookieHeader}');

    // Use the actual services exactly as the resolver does
    print('\n[step-1] scrape page...');
    final pageData = await NexusPageScraper(dio).scrape(watchUrl, session: browserSession);
    final session2 = browserSession.withCookieHeader(pageData.cookieHeader);
    print('[step-1] episodeId=${pageData.episodeId}');
    print('[step-1] attestRef=${pageData.attestRef}');
    print('[step-1] pageCookies=${pageData.cookieHeader}');
    print('[step-1] session2-cookies=${session2.cookieHeader}');

    print('\n[step-2] fetch stream data...');
    final streamData = await NexusStreamDataFetcher(dio).fetch(
      episodeId: pageData.episodeId,
      session: session2,
    );
    print('[step-2] videoId=${streamData.videoId}');
    print('[step-2] hlsUrl=${streamData.hlsUrl}');
    print('[step-2] streamCookies=${streamData.cookieHeader}');

    // Browser contract: socket query videoId is the episode id.
    final cookieHeader = streamData.cookieHeader;
    final socketVideoId = pageData.episodeId;
    final m3u8Url = streamData.hlsUrl.toString();
    final attestRef = pageData.attestRef;
    final fingerprint = browserSession.fingerprint;

    print('\n[step-3] WS connect...');
    final wsUri = Uri(
      scheme: 'wss',
      host: 'prd-socket.anime.nexus',
      path: '/api/socket/',
      queryParameters: <String, String>{
        'videoId': socketVideoId,
        'fingerprint': fingerprint,
        'm3u8Url': m3u8Url,
        'EIO': '4',
        'transport': 'websocket',
      },
    );
    print('[step-3] wsUri=$wsUri');

    final wsHeaders = <String, dynamic>{
      'Origin': NexusConstants.mainBase,
      'Referer': watchUrlStr,
      HttpHeaders.userAgentHeader: NexusConstants.userAgent,
    };
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      wsHeaders[HttpHeaders.cookieHeader] = cookieHeader;
    }
    print('[step-3] cookie=${cookieHeader?.substring(0, (cookieHeader.length).clamp(0, 80))}...');

    final socket = await WebSocket.connect(wsUri.toString(), headers: wsHeaders);
    print('[step-3] connected readyState=${socket.readyState}');

    final authResult = Completer<String>();
    final nsReady = Completer<void>();

    socket.listen(
      (raw) {
        final f = raw.toString();
        print('[ws] $f');

        if (f.startsWith('0{')) { socket.add('40/video,'); return; }
        if (f == '2') { socket.add('3'); return; }
        if (f.startsWith('40/video,')) { if (!nsReady.isCompleted) nsReady.complete(); return; }
        if (f.startsWith('42/video,')) {
          try {
            final list = jsonDecode(f.substring(9)) as List<dynamic>;
            final event = list[0] as String;
            if (event == 'connected' && !authResult.isCompleted) authResult.complete('OK: ${jsonEncode(list[1])}');
            if (event == 'authentication-error' && !authResult.isCompleted) authResult.complete('FAIL: ${jsonEncode(list[1])}');
          } catch (_) {}
        }
      },
      onDone: () {
        if (!authResult.isCompleted) authResult.complete('CLOSED');
        if (!nsReady.isCompleted) nsReady.completeError('closed');
      },
    );

    await nsReady.future.timeout(const Duration(seconds: 10));

    // Send auth exactly as browser traffic shows (ref + fingerprint)
    final authPayload = jsonEncode(<Object>[
      'auth',
      <String, String>{
        'ref': attestRef,
        'fingerprint': fingerprint,
      },
    ]);
    print('\n[step-4] auth payload: $authPayload');
    socket.add('42/video,$authPayload');

    final result = await authResult.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 'TIMEOUT',
    );
    print('\n[RESULT] $result');

    await socket.close();

    if (result.startsWith('OK')) {
      print('\n✓ AUTH SUCCEEDED');
    } else {
      print('\n✗ AUTH FAILED');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
