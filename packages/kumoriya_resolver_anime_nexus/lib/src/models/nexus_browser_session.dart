import 'dart:math';

final class NexusBrowserSession {
  NexusBrowserSession._({required this.fingerprint, this.cookieHeader});

  /// Creates a session with an explicit fingerprint (for testing / replay).
  factory NexusBrowserSession.withValues({
    required String fingerprint,
    String? cookieHeader,
  }) =>
      NexusBrowserSession._(
        fingerprint: fingerprint,
        cookieHeader: cookieHeader,
      );

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

    // Seed with a synthetic sid cookie – the JS reference
    // (`createBrowserSession`) always starts with `sid=<random_hex>`,
    // and the server binds session state to this value from the very
    // first page scrape onward.  Without it the subsequent WebSocket
    // auth handshake fails with "Authentication failed".
    return NexusBrowserSession._(
      fingerprint: fingerprint,
      cookieHeader: 'sid=${hex(16)}',
    );
  }

  static String _uuidV4(Random rng, String Function(int bytes) hex) {
    final p1 = hex(4); // 8 hex chars
    final p2 = hex(2); // 4 hex chars
    // hex(2) = 4 hex chars; drop the first to keep 3, then prepend '4' → 4xxx
    final p3 = '4${hex(2).substring(1)}';
    final p4a = (8 + rng.nextInt(4)).toRadixString(16);
    // hex(2) = 4 hex chars; drop the first to keep 3 → y + xxx = 4 chars
    final p4b = hex(2).substring(1);
    final p5 = hex(6); // 12 hex chars
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
