import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kumoriya_resolver_anime_nexus/src/models/nexus_browser_session.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/page_scraper.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/stream_data_fetcher.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/ws_client.dart';
import 'package:kumoriya_resolver_anime_nexus/src/utils/nexus_constants.dart';

Future<void> main() async {
  const watchUrl =
      'https://anime.nexus/watch/019cb301-d4de-7052-b26a-0f9625a09a38/episode-1-0704963ad12400b916bf';
  const episodeId = '019cb301-d4de-7052-b26a-0f9625a09a38';

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: <String, String>{
        'User-Agent': NexusConstants.userAgent,
        'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
      },
    ),
  );

  var session = NexusBrowserSession.generate();
  print('session fingerprint=${session.fingerprint}');
  print('session cookies=${session.cookieHeader}');

  final page = await NexusPageScraper(
    dio,
  ).scrape(Uri.parse(watchUrl), session: session);
  print('attestRef=${page.attestRef}');
  session = session.withCookieHeader(page.cookieHeader);
  print('page cookies=${session.cookieHeader}');

  final stream = await NexusStreamDataFetcher(
    dio,
  ).fetch(episodeId: episodeId, session: session);
  print('stream hls=${stream.hlsUrl}');
  print('stream cookies=${stream.cookieHeader}');

  final ws = NexusWsClient(
    episodeId: episodeId,
    fingerprint: session.fingerprint,
    cookieHeader: stream.cookieHeader,
    m3u8Url: stream.hlsUrl.toString(),
  );

  try {
    await ws.connect(wsRef: page.attestRef);
    print('ws connected sessionId=${ws.session.sessionId}');
  } catch (error, stack) {
    print('ws error=$error');
    print(stack);
  } finally {
    await ws.close();
  }

  print('manual ws probe start');
  final socket = await WebSocket.connect(
    Uri(
      scheme: 'wss',
      host: 'prd-socket.anime.nexus',
      path: '/api/socket/',
      queryParameters: <String, String>{
        'videoId': episodeId,
        'fingerprint': session.fingerprint,
        'm3u8Url': stream.hlsUrl.toString(),
        'EIO': '4',
        'transport': 'websocket',
      },
    ).toString(),
    headers: <String, dynamic>{
      'Origin': NexusConstants.mainBase,
      'User-Agent': NexusConstants.userAgent,
      'Cookie': stream.cookieHeader,
    },
  );

  await for (final raw in socket) {
    final message = raw.toString();
    print('manual recv=$message');
    if (message.startsWith('0{')) {
      socket.add('40/video,');
      continue;
    }
    if (message.startsWith('40/video,')) {
      final authPayload = jsonEncode(<Object>[
        'auth',
        <String, String>{
          'ref': page.attestRef,
          'fingerprint': session.fingerprint,
        },
      ]);
      final authFrame = '42/video,$authPayload';
      print('manual send=$authFrame');
      socket.add(authFrame);
      continue;
    }
    if (message == '2') {
      socket.add('3');
      continue;
    }
    if (message.contains('connected') ||
        message.contains('authentication-error')) {
      break;
    }
  }
  await socket.close();
}
