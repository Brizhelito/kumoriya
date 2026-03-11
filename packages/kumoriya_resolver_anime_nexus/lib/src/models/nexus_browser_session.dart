import 'dart:math';

final class NexusBrowserSession {
  NexusBrowserSession._({required this.fingerprint, this.cookieHeader});

  final String fingerprint;

  final String? cookieHeader;

  NexusBrowserSession withCookieHeader(String? value) {
    return NexusBrowserSession._(
      fingerprint: fingerprint,
      cookieHeader: value ?? cookieHeader,
    );
  }

  factory NexusBrowserSession.generate() {
    final rng = Random.secure();

    String hex(int bytes) => List<String>.generate(
      bytes,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final fingerprint = _uuidV4(rng, hex);
    final sid = hex(16);

    return NexusBrowserSession._(
      fingerprint: fingerprint,
      cookieHeader: 'sid=$sid',
    );
  }

  static String _uuidV4(Random rng, String Function(int bytes) hex) {
    final p1 = hex(4);
    final p2 = hex(2);
    final p3 = '4${hex(1).substring(1)}';
    final p4a = (8 + rng.nextInt(4)).toRadixString(16);
    final p4b = hex(1).substring(1);
    final p5 = hex(6);
    return '$p1-$p2-$p3-$p4a$p4b-$p5';
  }
}
