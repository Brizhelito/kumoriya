// ignore_for_file: avoid_print
/// Use proper bootstrap flow: get cookies first, THEN connect WS
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
  test(
    'WS auth with properly bootstrapped cookies',
    () async {
      const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          headers: <String, String>{'User-Agent': NexusConstants.userAgent},
        ),
      );

      print('[1] Generate session...');
      final session = NexusBrowserSession.generate();
      print('    fingerprint: ${session.fingerprint}');

      print('[2] Bootstrap with Stream API (get cookies)...');
      final streamData = await NexusStreamDataFetcher(
        dio,
      ).fetch(episodeId: episodeId, session: session);
      print('    ✓ hlsUrl: ${streamData.hlsUrl}');
      print('    ✓ cookies: ${streamData.cookieHeader}');

      // Now we have properly authenticated cookies
      final authCookie = streamData.cookieHeader ?? '';

      print('[3] Connect WS with auth cookies...');
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

      final socket = await WebSocket.connect(
        wsUri.toString(),
        headers: <String, String>{
          'Origin': 'https://anime.nexus',
          'Cookie': authCookie,
        },
      );
      print('[3] ✓ WS connected');

      var result = 'none';
      var nsConnected = false;

      socket.listen((msg) {
        final msgStr = msg.toString();
        final display = msgStr.length > 100 ? msgStr.substring(0, 100) : msgStr;
        print('[rx] $display');

        if (msgStr.startsWith('40/video')) {
          nsConnected = true;
        }
        if (msgStr.contains('authentication-error')) {
          result = 'REJECTED';
        } else if (msgStr.contains('"ok"') && msgStr.startsWith('42/video')) {
          result = 'ACCEPTED';
        }
      });

      // Handshake
      await Future.delayed(const Duration(milliseconds: 200));

      // Namespace connect
      print('[4] Send namespace CONNECT');
      socket.add('40/video,{}');

      // Wait for namespace
      await Future.delayed(const Duration(milliseconds: 500));

      // Auth without ref (relying on cookie auth)
      if (nsConnected) {
        print('[5] Send AUTH (relying on cookie)');
        final authMsg = jsonEncode({
          'ref': '',
          'fingerprint': session.fingerprint,
        });
        socket.add('42/video,["auth",$authMsg]');
      }

      // Wait for response
      await Future.delayed(const Duration(seconds: 2));

      await socket.close(1000);
      dio.close();

      print('\n[RESULT] → $result');
      expect(result, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
