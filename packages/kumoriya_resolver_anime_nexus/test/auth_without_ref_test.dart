// ignore_for_file: avoid_print
/// Test WS auth WITHOUT attestRef - maybe the server doesn't validate it?
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
  test('WS auth WITHOUT attestRef - only fingerprint', () async {
    const browserFingerprint = '90843c4d-cfd1-4fab-8d84-f2b99ae1678f';
    const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: <String, String>{
        'User-Agent': NexusConstants.userAgent,
      },
    ));

    // Fetch stream data to get valid m3u8Url
    print('[step-1] fetch stream data with browser fingerprint...');
    final session = NexusBrowserSession.withValues(
      fingerprint: browserFingerprint,
    );
    final streamData = await NexusStreamDataFetcher(dio).fetch(
      episodeId: episodeId,
      session: session,
    );
    print('[step-1] hlsUrl=${streamData.hlsUrl}');

    print('\n[step-2] WS connect WITHOUT attestRef...');
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

    final socket = await WebSocket.connect(wsUri.toString(),
        headers: <String, String>{'Origin': 'https://anime.nexus'});
    print('[step-2] connected');

    final authResult = Completer<String>();
    final nsReady = Completer<void>();

    socket.listen(
      (msg) {
        print('[ws] $msg');
        if (msg.toString().startsWith('40/video')) {
          nsReady.complete();
        } else if (msg.toString().startsWith('42/video,["ok"')) {
          authResult.complete('OK: auth succeeded');
        } else if (msg.toString().startsWith('42/video,["authentication-error"')) {
          authResult.complete('FAIL: ${msg.toString()}');
        }
      },
      onDone: () {
        if (!authResult.isCompleted) authResult.complete('CLOSED');
        if (!nsReady.isCompleted) nsReady.completeError('closed');
      },
    );

    await nsReady.future.timeout(const Duration(seconds: 10));

    // Send auth with EMPTY ref (no attestRef in payload)
    print('\n[step-3] sending auth with EMPTY ref...');
    final authPayload = jsonEncode(<Object>[
      'auth',
      <String, String>{
        'ref': '',  // No attestRef
        'fingerprint': browserFingerprint,
      },
    ]);
    print('[auth-payload] $authPayload');
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
