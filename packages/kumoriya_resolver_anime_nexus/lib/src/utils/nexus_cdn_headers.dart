import 'dart:math';

import 'nexus_constants.dart';

abstract final class NexusCdnHeaders {
  static Map<String, String> build({
    required String fingerprint,
    required String sessionId,
    required String videoId,
  }) {
    return <String, String>{
      'User-Agent': NexusConstants.userAgent,
      'Origin': NexusConstants.mainBase,
      'Referer': '${NexusConstants.mainBase}/',
      'Accept': '*/*',
      'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'cross-site',
      'cache-control': 'max-age=0',
      'x-client-fingerprint': fingerprint,
      'x-fingerprint': fingerprint,
      'x-session-id': sessionId,
      'x-video-uuid': videoId,
    };
  }
}

abstract final class NexusUuid {
  static final Random _rng = Random.secure();

  static String generate() {
    String hex(int bytes) => List<String>.generate(
      bytes,
      (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final p1 = hex(4);
    final p2 = hex(2);
    final p3 = '4${hex(1).substring(1)}';
    final p4a = (8 + _rng.nextInt(4)).toRadixString(16);
    final p4b = hex(1).substring(1);
    final p5 = hex(6);

    return '$p1-$p2-$p3-$p4a$p4b-$p5';
  }
}
