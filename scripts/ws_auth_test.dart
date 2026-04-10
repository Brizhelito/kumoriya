/// Standalone Dart script that replicates the JS ws-auth-test flow
/// to diagnose exactly where the Dart implementation diverges.
///
/// Run: dart run scripts/ws_auth_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const mainBase = 'https://anime.nexus';
const apiBase = 'https://api.anime.nexus';
const userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/146.0.0.0 Safari/537.36';

final watchUrl =
    'https://anime.nexus/watch/019cdcfe-dc32-7328-9747-0e6ef96dbd06/episode-10-c9b0cd86068190028be1';

void main() async {
  print('=== Dart WS Auth Test ===');
  print('watchUrl: $watchUrl');

  final client = HttpClient();
  client.userAgent = userAgent;

  try {
    // Step 1: Create browser session
    final rng = Random.secure();
    String hex(int bytes) => List<String>.generate(
      bytes,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final fingerprint = _uuidV4(rng, hex);
    var cookieHeader = 'sid=${hex(16)}';

    print('\n[1] Browser session created');
    print('  fingerprint: $fingerprint');
    print('  cookieHeader: $cookieHeader');

    // Step 2: Scrape watch page
    print('\n[2] Scraping watch page...');
    final pageResult = await _scrapeWatchPage(client, watchUrl, cookieHeader);
    final episodeId = pageResult['episodeId']!;
    final attestRef = pageResult['attestRef']!;
    cookieHeader = _mergeCookies(cookieHeader, pageResult['setCookies'] ?? '');
    print('  episodeId: $episodeId');
    print('  attestRef: ${attestRef.substring(0, 16)}...');
    print('  cookieHeader: $cookieHeader');

    // Step 3: Fetch stream data
    print('\n[3] Fetching stream data...');

    // 3a: Auth session bootstrap
    final authCookies = await _bootstrapAuthSession(client, cookieHeader);
    cookieHeader = _mergeCookies(cookieHeader, authCookies);
    print('  after auth bootstrap: $cookieHeader');

    // 3b: Episode view bootstrap
    final viewCookies = await _bootstrapEpisodeView(
      client,
      episodeId,
      cookieHeader,
      fingerprint,
    );
    cookieHeader = _mergeCookies(cookieHeader, viewCookies);
    print('  after episode view: $cookieHeader');

    // 3c: Stream data request
    final streamResult = await _fetchStreamData(
      client,
      episodeId,
      cookieHeader,
      fingerprint,
    );
    final hlsUrl = streamResult['hlsUrl']!;
    final videoId = streamResult['videoId']!;
    cookieHeader = _mergeCookies(
      cookieHeader,
      streamResult['setCookies'] ?? '',
    );
    print('  hlsUrl: $hlsUrl');
    print('  videoId: $videoId');
    print('  cookieHeader: $cookieHeader');

    // Step 4: WebSocket connect
    print('\n[4] Connecting WebSocket...');
    final wsUri = Uri(
      scheme: 'wss',
      host: 'prd-socket.anime.nexus',
      path: '/api/socket/',
      queryParameters: {
        'videoId': episodeId,
        'fingerprint': fingerprint,
        'm3u8Url': hlsUrl,
        'EIO': '4',
        'transport': 'websocket',
      },
    );
    print('  WS URL: $wsUri');

    final ws = await WebSocket.connect(
      wsUri.toString(),
      headers: {
        'Origin': mainBase,
        HttpHeaders.userAgentHeader: userAgent,
        if (cookieHeader.isNotEmpty) HttpHeaders.cookieHeader: cookieHeader,
      },
    );
    print('  WebSocket opened');

    final namespaceReady = Completer<void>();
    final authed = Completer<void>();
    String? sessionJson;

    ws.listen(
      (raw) {
        final msg = raw.toString();
        if (msg.startsWith('0{') || msg == '0') {
          print('  <- Engine.IO OPEN');
          print('  -> Sending 40/video,');
          ws.add('40/video,');
          return;
        }
        if (msg == '2') {
          ws.add('3');
          return;
        }
        if (msg == '3') return;
        if (msg.startsWith('40/video,')) {
          print(
            '  <- Namespace connect ACK: ${msg.substring(0, _min(80, msg.length))}',
          );
          if (!namespaceReady.isCompleted) namespaceReady.complete();
          return;
        }
        if (msg.startsWith('42/video,')) {
          final payload = msg.substring('42/video,'.length);
          print(
            '  <- EVENT: ${payload.substring(0, _min(120, payload.length))}',
          );
          try {
            final list = jsonDecode(payload) as List;
            final event = list[0] as String;
            if (event == 'connected') {
              sessionJson = jsonEncode(list[1]);
              if (!authed.isCompleted) authed.complete();
            } else if (event == 'authentication-error') {
              final data = list.length > 1 ? list[1] : null;
              final message = (data is Map)
                  ? data['message']?.toString() ?? 'Unknown'
                  : 'Unknown';
              if (!authed.isCompleted) {
                authed.completeError(Exception('Auth failed: $message'));
              }
            }
          } catch (e) {
            print('  !! Parse error: $e');
          }
          return;
        }
        if (msg.startsWith('44/video,')) {
          print('  <- CONNECT ERROR: ${msg.substring('44/video,'.length)}');
          if (!namespaceReady.isCompleted) {
            namespaceReady.completeError(Exception('Namespace connect error'));
          }
          return;
        }
        print(
          '  <- UNKNOWN: ${msg.toString().substring(0, _min(80, msg.toString().length))}',
        );
      },
      onError: (Object e) {
        print('  !! Socket error: $e');
        if (!namespaceReady.isCompleted) namespaceReady.completeError(e);
        if (!authed.isCompleted) authed.completeError(e);
      },
      onDone: () {
        print('  !! Socket closed');
        if (!namespaceReady.isCompleted) {
          namespaceReady.completeError(Exception('Socket closed'));
        }
        if (!authed.isCompleted) {
          authed.completeError(Exception('Socket closed'));
        }
      },
    );

    await namespaceReady.future.timeout(const Duration(seconds: 10));
    print('  Namespace ready');

    final authPayload = jsonEncode([
      'auth',
      {'ref': attestRef, 'fingerprint': fingerprint},
    ]);
    print('  -> Sending auth: 42/video,$authPayload');
    ws.add('42/video,$authPayload');

    await authed.future.timeout(const Duration(seconds: 10));
    print('  ✅ AUTHENTICATED!');
    print('  session: $sessionJson');

    await ws.close();
    print('\n=== SUCCESS ===');
  } catch (e) {
    print('\n❌ FAILED: $e');
    exit(1);
  } finally {
    client.close();
  }
}

String _uuidV4(Random rng, String Function(int) hex) {
  final p1 = hex(4);
  final p2 = hex(2);
  final p3 = '4${hex(2).substring(1)}';
  final p4a = (8 + rng.nextInt(4)).toRadixString(16);
  final p4b = hex(2).substring(1);
  final p5 = hex(6);
  return '$p1-$p2-$p3-$p4a$p4b-$p5';
}

int _min(int a, int b) => a < b ? a : b;

Future<Map<String, String>> _scrapeWatchPage(
  HttpClient client,
  String url,
  String cookie,
) async {
  final req = await client.getUrl(Uri.parse(url));
  req.headers.set(
    'Accept',
    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  );
  req.headers.set('Origin', mainBase);
  req.headers.set('Referer', '$mainBase/');
  req.headers.set('sec-fetch-dest', 'document');
  req.headers.set('sec-fetch-mode', 'navigate');
  req.headers.set('sec-fetch-site', 'none');
  req.headers.set('Cookie', cookie);

  final resp = await req.close();
  final html = await resp.transform(utf8.decoder).join();
  final setCookies = _extractSetCookies(resp);

  final attestMatch = RegExp(r'attestRef:"([0-9a-f]{64})"').firstMatch(html);
  if (attestMatch == null) throw Exception('No attestRef found in HTML');

  final uri = Uri.parse(url);
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final watchIdx = segments.indexOf('watch');
  final episodeId = watchIdx >= 0 ? segments[watchIdx + 1] : '';

  return {
    'episodeId': episodeId,
    'attestRef': attestMatch.group(1)!,
    'setCookies': setCookies,
  };
}

Future<String> _bootstrapAuthSession(HttpClient client, String cookie) async {
  final req = await client.getUrl(Uri.parse('$mainBase/api/auth/session'));
  req.headers.set('Accept', 'application/json, text/plain, */*');
  req.headers.set('Referer', '$mainBase/');
  req.headers.set('sec-fetch-dest', 'empty');
  req.headers.set('sec-fetch-mode', 'cors');
  req.headers.set('sec-fetch-site', 'same-origin');
  req.headers.set('Cookie', cookie);

  final resp = await req.close();
  await resp.drain<void>();
  return _extractSetCookies(resp);
}

Future<String> _bootstrapEpisodeView(
  HttpClient client,
  String episodeId,
  String cookie,
  String fingerprint,
) async {
  final req = await client.postUrl(
    Uri.parse('$apiBase/api/anime/details/episode/view'),
  );
  req.headers.set('Accept', 'application/json, text/plain, */*');
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Referer', '$mainBase/');
  req.headers.set('Origin', mainBase);
  req.headers.set('sec-fetch-dest', 'empty');
  req.headers.set('sec-fetch-mode', 'cors');
  req.headers.set('sec-fetch-site', 'same-site');
  req.headers.set('x-client-fingerprint', fingerprint);
  req.headers.set('x-fingerprint', fingerprint);
  req.headers.set('Cookie', cookie);
  req.add(utf8.encode(jsonEncode({'id': episodeId})));

  final resp = await req.close();
  await resp.drain<void>();
  return _extractSetCookies(resp);
}

Future<Map<String, String>> _fetchStreamData(
  HttpClient client,
  String episodeId,
  String cookie,
  String fingerprint,
) async {
  final url =
      '$apiBase/api/anime/details/episode/stream?id=${Uri.encodeComponent(episodeId)}&fillers=true&recaps=true';

  Future<HttpClientResponse> makeReq(String c) async {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('Accept', 'application/json, text/plain, */*');
    req.headers.set('Referer', '$mainBase/');
    req.headers.set('Origin', mainBase);
    req.headers.set('sec-fetch-dest', 'empty');
    req.headers.set('sec-fetch-mode', 'cors');
    req.headers.set('sec-fetch-site', 'same-site');
    req.headers.set('x-client-fingerprint', fingerprint);
    req.headers.set('x-fingerprint', fingerprint);
    req.headers.set('Cookie', c);
    return req.close();
  }

  var resp = await makeReq(cookie);
  if (resp.statusCode == 403) {
    cookie = _mergeCookies(cookie, _extractSetCookies(resp));
    await resp.drain<void>();
    resp = await makeReq(cookie);
  }

  final body = await resp.transform(utf8.decoder).join();
  if (resp.statusCode != 200) {
    throw Exception('Stream data returned ${resp.statusCode}: $body');
  }

  final payload = jsonDecode(body) as Map<String, dynamic>;
  final data = payload['data'] as Map<String, dynamic>;
  final hls = data['hls']?.toString().trim() ?? '';

  var videoId = '';
  if (data['video'] is Map) {
    videoId = (data['video'] as Map)['id']?.toString() ?? '';
  }
  if (videoId.isEmpty && data['video_meta'] is Map) {
    videoId = (data['video_meta'] as Map)['id']?.toString() ?? '';
  }
  if (videoId.isEmpty) {
    final hlsUri = Uri.parse(hls);
    final segs = hlsUri.pathSegments;
    final vi = segs.indexOf('video');
    if (vi >= 0 && vi + 1 < segs.length) videoId = segs[vi + 1];
  }

  return {
    'hlsUrl': hls,
    'videoId': videoId,
    'setCookies': _extractSetCookies(resp),
  };
}

String _extractSetCookies(HttpClientResponse resp) {
  final cookies = <String>[];
  resp.headers.forEach((name, values) {
    if (name.toLowerCase() == 'set-cookie') {
      cookies.addAll(values);
    }
  });
  return cookies.join('\n');
}

String _mergeCookies(String existing, String? setCookies) {
  final merged = <String, String>{};

  for (final part in existing.split(';')) {
    final cookie = part.trim();
    if (cookie.isEmpty) continue;
    final sep = cookie.indexOf('=');
    if (sep <= 0) continue;
    merged[cookie.substring(0, sep)] = cookie.substring(sep + 1);
  }

  if (setCookies != null && setCookies.isNotEmpty) {
    for (final raw in setCookies.split('\n')) {
      final cookie = raw.split(';').first.trim();
      if (cookie.isEmpty) continue;
      final sep = cookie.indexOf('=');
      if (sep <= 0) continue;
      merged[cookie.substring(0, sep)] = cookie.substring(sep + 1);
    }
  }

  if (merged.isEmpty) return '';
  return merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
}
