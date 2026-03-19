// ignore_for_file: avoid_print
/// Auth using ONLY fingerprint (no ref field at all)
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
    'WS auth with ONLY fingerprint (no ref field)',
    () async {
      const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          headers: <String, String>{'User-Agent': NexusConstants.userAgent},
        ),
      );

      print('[1] Generate and bootstrap session...');
      final session = NexusBrowserSession.generate();
      print('    fingerprint: ${session.fingerprint}');

      final streamData = await NexusStreamDataFetcher(
        dio,
      ).fetch(episodeId: episodeId, session: session);
      print('    ✓ got cookies');

      final authCookie = streamData.cookieHeader ?? '';

      print('[2] Connect WS...');
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
      print('[2] ✓ WS connected');

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

      await Future.delayed(const Duration(milliseconds: 200));

      // Namespace connect
      print('[3] Namespace CONNECT');
      socket.add('40/video,{}');
      await Future.delayed(const Duration(milliseconds: 500));

      // Auth with ONLY fingerprint, no ref field
      print('[4] Send AUTH (fingerprint ONLY, NO ref)');
      final authMsg = jsonEncode({
        'fingerprint': session.fingerprint,
        // NO 'ref' field at all
      });
      socket.add('42/video,["auth",$authMsg]');
      print(
        '[4] ✓ sent: 42/video,["auth",{fingerprint:"${session.fingerprint}"}]',
      );

      await Future.delayed(const Duration(seconds: 2));

      await socket.close(1000);
      dio.close();

      print('\n[RESULT] → $result');
      expect(result, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
