import 'dart:math';

final class NexusBrowserSession {
  NexusBrowserSession._({required this.fingerprint, this.cookieHeader});

  final String fingerprint;

  final String? cookieHeader;

  NexusBrowserSession withCookieHeader(String? value) {
    return NexusBrowserSession._(
      fingerprint: fingerprint,
      cookieHeader: _mergeCookieHeaders(cookieHeader, value),
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

  static String? _mergeCookieHeaders(String? existing, String? incoming) {
    final merged = <String, String>{};

    void absorb(String? header) {
      if (header == null || header.trim().isEmpty) {
        return;
      }

      for (final part in header.split(';')) {
        final cookie = part.trim();
        if (cookie.isEmpty) {
          continue;
        }
        final separator = cookie.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        merged[cookie.substring(0, separator)] = cookie.substring(
          separator + 1,
        );
      }
    }

    absorb(existing);
    absorb(incoming);

    if (merged.isEmpty) {
      return null;
    }

    return merged.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}
