// ignore_for_file: avoid_print
/// Test with the REAL ref captured from browser
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
    'WS auth with REAL browser-captured ref',
    () async {
      const browserFingerprint = '90843c4d-cfd1-4fab-8d84-f2b99ae1678f';
      const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';
      // This ref was captured directly from browser auth message execution
      const realRef =
          'e1db8f4945532d7ecfac29092a9c33ab68aeb3408ca331762885862680741b30';

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          headers: <String, String>{'User-Agent': NexusConstants.userAgent},
        ),
      );

      print('[1] Fetch stream data...');
      final session = NexusBrowserSession.withValues(
        fingerprint: browserFingerprint,
      );
      final streamData = await NexusStreamDataFetcher(
        dio,
      ).fetch(episodeId: episodeId, session: session);
      print('[1] ✓ got hlsUrl');

      print('[2] Connect WS...');
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
        headers: <String, String>{'Origin': 'https://anime.nexus'},
      );
      print('[2] ✓ connected to WS');

      var result = 'none';
      final messages = <String>[];

      socket.listen((msg) {
        final msgStr = msg.toString();
        messages.add(msgStr);
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

      // Step 3: wait a bit
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: send AUTH with REAL ref
      print('[4] Send AUTH with real browser ref...');
      print('    ref: $realRef');
      final authMsg = jsonEncode({
        'ref': realRef,
        'fingerprint': browserFingerprint,
      });
      socket.add('42/video,["auth",$authMsg]');
      print('[4] ✓ sent auth');

      // Wait for response
      await Future.delayed(const Duration(seconds: 2));

      await socket.close(1000);
      dio.close();

      print('\n[MESSAGES RECEIVED]:');
      for (final msg in messages) {
        final display = msg.length > 80 ? msg.substring(0, 80) : msg;
        print('  ✓ $display');
      }

      print('\n[RESULT] → $result');
      expect(result, isNotEmpty, reason: 'Should have received auth response');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
