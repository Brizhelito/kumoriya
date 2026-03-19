// ignore_for_file: avoid_print
/// Test WS with session cookie from browser
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
  test('WS auth with session cookie', () async {
    const browserFingerprint = '90843c4d-cfd1-4fab-8d84-f2b99ae1678f';
    const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';
    // Cookie obtained from browser
    const sessionCookie = 'sid=07c70171b49cd54012ed37b600d0db42';

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        headers: <String, String>{'User-Agent': NexusConstants.userAgent},
      ),
    );

    print('[1] Bootstrap auth session...');
    final session = NexusBrowserSession.withValues(
      fingerprint: browserFingerprint,
    );
    // This will create a new session with new cookies
    final streamData = await NexusStreamDataFetcher(
      dio,
    ).fetch(episodeId: episodeId, session: session);
    print('[1] ✓ got hlsUrl and new cookies');

    print('[2] Connect WS WITH session cookie...');
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

    final socket = await WebSocket.connect(
      wsUri.toString(),
      headers: <String, String>{
        'Origin': 'https://anime.nexus',
        'Cookie': sessionCookie, // Include the session cookie
      },
    );
    print('[2] ✓ connected to WS');

    var result = 'none';

    socket.listen((msg) {
      final msgStr = msg.toString();
      final display = msgStr.length > 100 ? msgStr.substring(0, 100) : msgStr;
      print('[rx] $display');

      if (msgStr.contains('authentication-error')) {
        result = 'REJECTED';
      } else if (msgStr.contains('"ok"') && msgStr.startsWith('42/video')) {
        result = 'ACCEPTED';
      }
    });

    // Step 1: wait for handshake
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 2: send namespace CONNECT
    print('[3] Send namespace CONNECT');
    socket.add('40/video,{}');

    // Step 3: wait
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 4: send AUTH WITHOUT ref (relying on cookie)
    print('[4] Send AUTH without ref (relying on cookie)...');
    final authMsg = jsonEncode({
      'ref': '', // Empty ref, relying on cookie
      'fingerprint': browserFingerprint,
    });
    socket.add('42/video,["auth",$authMsg]');

    // Wait for response
    await Future.delayed(const Duration(seconds: 2));

    await socket.close(1000);
    dio.close();

    print('\n[RESULT] → $result');
    expect(result, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
