// ignore_for_file: avoid_print
/// Test WS auth using a browser-obtained attestRef to verify if Dart's
/// page fetch is the issue (TLS fingerprinting / bot detection).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'package:kumoriya_resolver_anime_nexus/src/services/stream_data_fetcher.dart';
import 'package:kumoriya_resolver_anime_nexus/src/models/nexus_browser_session.dart';
import 'package:kumoriya_resolver_anime_nexus/src/utils/nexus_constants.dart';

void main() {
  test('WS auth with browser attestRef', () async {
    // Fresh unused attestRef fetched by Chrome (NOT consumed by any WS in Chrome)
    const browserAttestRef =
        '1b270c39f76bb783cb5870a360b0ee7d625b1fd4d101ff5a373982d42ec6ae72';
    const browserFingerprint = '90843c4d-cfd1-4fab-8d84-f2b99ae1678f';
    const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, String>{'User-Agent': NexusConstants.userAgent},
      ),
    );

    // We need a fresh m3u8Url — use the browser's fingerprint
    print('[step-1] fetch stream data with browser fingerprint...');
    final session = NexusBrowserSession.withValues(
      fingerprint: browserFingerprint,
    );
    final streamData = await NexusStreamDataFetcher(
      dio,
    ).fetch(episodeId: episodeId, session: session);
    print('[step-1] hlsUrl=${streamData.hlsUrl}');

    print('\n[step-2] WS connect with browser attestRef...');
    final wsUri = Uri(
      scheme: 'wss',
      host: 'prd-socket.anime.nexus',
      path: '/api/socket/',
      queryParameters: <String, String>{
        'videoId': episodeId,
        'fingerprint': browserFingerprint,
        'm3u8Url': streamData.hlsUrl.toString(),
        'EIO': '4',
        'transport': 'websocket',
      },
    );
    print('[step-2] wsUri=$wsUri');

    final wsHeaders = <String, dynamic>{
      'Origin': NexusConstants.mainBase,
      HttpHeaders.userAgentHeader: NexusConstants.userAgent,
    };

    final socket = await WebSocket.connect(
      wsUri.toString(),
      headers: wsHeaders,
    );
    print('[step-2] connected');

    final authResult = Completer<String>();
    final nsReady = Completer<void>();

    socket.listen(
      (raw) {
        final f = raw.toString();
        print('[ws] $f');
        if (f.startsWith('0{')) {
          socket.add('40/video,');
          return;
        }
        if (f == '2') {
          socket.add('3');
          return;
        }
        if (f.startsWith('40/video,')) {
          if (!nsReady.isCompleted) nsReady.complete();
          return;
        }
        if (f.startsWith('42/video,')) {
          try {
            final list = jsonDecode(f.substring(9)) as List<dynamic>;
            final event = list[0] as String;
            if (event == 'connected' && !authResult.isCompleted) {
              authResult.complete('OK: ${jsonEncode(list[1])}');
            }
            if (event == 'authentication-error' && !authResult.isCompleted) {
              authResult.complete('FAIL: ${jsonEncode(list[1])}');
            }
          } catch (_) {}
        }
      },
      onDone: () {
        if (!authResult.isCompleted) authResult.complete('CLOSED');
        if (!nsReady.isCompleted) nsReady.completeError('closed');
      },
    );

    await nsReady.future.timeout(const Duration(seconds: 10));

    final authPayload = jsonEncode(<Object>[
      'auth',
      <String, String>{
        'ref': browserAttestRef,
        'fingerprint': browserFingerprint,
      },
    ]);
    print('\n[step-3] auth payload: $authPayload');
    socket.add('42/video,$authPayload');

    final result = await authResult.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 'TIMEOUT',
    );
    print('\n[RESULT] $result');

    await socket.close();
    dio.close();

    expect(result, startsWith('OK'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
