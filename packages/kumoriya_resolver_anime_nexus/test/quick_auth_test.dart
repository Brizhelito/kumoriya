// ignore_for_file: avoid_print
/// Simple test: send auth immediately with empty ref
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
  test('send auth with empty ref, no namespace join wait', () async {
    const browserFingerprint = '90843c4d-cfd1-4fab-8d84-f2b99ae1678f';
    const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      headers: <String, String>{'User-Agent': NexusConstants.userAgent},
    ));

    print('[1] Fetch stream data...');
    final session = NexusBrowserSession.withValues(fingerprint: browserFingerprint);
    final streamData = await NexusStreamDataFetcher(dio).fetch(
      episodeId: episodeId,
      session: session,
    );
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

    final socket = await WebSocket.connect(wsUri.toString(),
        headers: <String, String>{'Origin': 'https://anime.nexus'});
    print('[2] connected');

    var authResponse = 'none';
    socket.listen((msg) {
      final msgStr = msg.toString();
      print('[msg] ${msgStr.substring(0, 100)}');
      if (msgStr.contains('authentication-error')) {
        authResponse = 'REJECTED: $msgStr';
      } else if (msgStr.contains('ok')) {
        authResponse = 'ACCEPTED: $msgStr';
      }
    });

    // Send auth immediately without waiting
    await Future.delayed(const Duration(milliseconds: 100));
    
    print('[3] Send auth with EMPTY ref...');
    final auth = jsonEncode(<Object>[
      'auth',
      <String, String>{
        'ref': '',
        'fingerprint': browserFingerprint,
      },
    ]);
    socket.add('42/video,$auth');
    print('[3] sent: 42/video,$auth');

    // Wait for response
    await Future.delayed(const Duration(seconds: 2));

    await socket.close();
    dio.close();

    print('\n[RESULT] $authResponse');
    expect(authResponse, contains(RegExp(r'ACCEPTED|REJECTED')));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
