// ignore_for_file: avoid_print
/// Test: send auth in CONNECT message (Socket.IO v4 style)
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
  test('Socket.IO auth in CONNECT message', () async {
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
    print('[1] got hlsUrl: ${streamData.hlsUrl}');

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
    var gotNamespaceConnect = false;

    socket.listen((msg) {
      final msgStr = msg.toString();
      final display = msgStr.length > 120 ? msgStr.substring(0, 120) : msgStr;
      print('[rx] $display');

      // Socket.IO message format: <packet-type>[namespace],[payload]
      if (msgStr.startsWith('40/video')) {
        gotNamespaceConnect = true;
        print('[rx] Got namespace CONNECT (40)');
      }

      if (msgStr.contains('authentication-error')) {
        authResponse = 'REJECTED: $msgStr';
      } else if (msgStr.contains('"ok"') || msgStr.startsWith('42/video')) {
        authResponse = 'ACCEPTED (got msg)';
      }
    }).onError((err) {
      print('[err] $err');
    });

    // Wait for namespace connect
    await Future.delayed(const Duration(milliseconds: 500));

    if (gotNamespaceConnect) {
      print('[3] Got namespace connect, now auth...');
      // Auth should be sent as a normal message after connect
      final authMsg = jsonEncode({
        'ref': '',
        'fingerprint': browserFingerprint,
      });
      socket.add('42/video,["auth",$authMsg]');
      print('[tx] sent auth');
    } else {
      print('[3] No namespace join, trying inline auth...');
      // Try sending auth inline with connect
      final connectAuth = jsonEncode({
        'auth': {
          'ref': '',
          'fingerprint': browserFingerprint,
        },
      });
      socket.add('/video,$connectAuth');
      print('[tx] sent inline auth');
    }

    // Wait for response
    await Future.delayed(const Duration(seconds: 3));

    await socket.close();
    dio.close();

    print('\n[RESULT] $authResponse (ns_connect=$gotNamespaceConnect)');
    expect(authResponse, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
