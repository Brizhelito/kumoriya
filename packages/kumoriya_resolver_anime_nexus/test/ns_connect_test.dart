// ignore_for_file: avoid_print
/// Test: send CONNECT to namespace first, THEN auth
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
    'explicit namespace CONNECT then auth',
    () async {
      const browserFingerprint = '90843c4d-cfd1-4fab-8d84-f2b99ae1678f';
      const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

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
      print('[1] got hlsUrl');

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
      print('[2] connected');

      var result = 'none';
      final messages = <String>[];

      socket.listen((msg) {
        final msgStr = msg.toString();
        messages.add(msgStr);
        final display = msgStr.length > 100 ? msgStr.substring(0, 100) : msgStr;
        print('[rx] $display');

        if (msgStr.contains('authentication-error')) {
          result = 'auth_rejected';
        } else if (msgStr.contains('"ok"')) {
          result = 'auth_accepted';
        }
      });

      // Step 1: wait for handshake
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 2: send namespace CONNECT
      print('[3] Send namespace CONNECT...');
      socket.add('40/video,{}');
      print('[3] sent: 40/video,{}');

      // Step 3: wait a bit
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: send AUTH
      print('[4] Send AUTH...');
      final authMsg = jsonEncode({
        'ref': '',
        'fingerprint': browserFingerprint,
      });
      socket.add('42/video,["auth",$authMsg]');
      print('[4] sent auth');

      // Wait for response
      await Future.delayed(const Duration(seconds: 2));

      await socket.close(1000);
      dio.close();

      print('\n[ALL MESSAGES RECEIVED]:');
      for (final msg in messages) {
        print('  - ${msg.substring(0, 80)}...');
      }
      print('\n[RESULT] $result');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
