final class NexusWsSession {
  const NexusWsSession({
    required this.sessionId,
    required this.authenticated,
    this.sessionExpiry = 0,
  });

  final String sessionId;
  final bool authenticated;
  final int sessionExpiry;

  Map<String, Object?> toMap() => <String, Object?>{
    'sessionId': sessionId,
    'authenticated': authenticated,
    'sessionExpiry': sessionExpiry,
  };

  factory NexusWsSession.fromMap(Map<String, dynamic> map) {
    return NexusWsSession(
      sessionId: map['sessionId']?.toString() ?? '',
      authenticated: map['authenticated'] == true,
      sessionExpiry: (map['sessionExpiry'] as num?)?.toInt() ?? 0,
    );
  }
}

final class NexusStreamToken {
  const NexusStreamToken({
    required this.token,
    required this.timestamp,
    required this.hash,
  });

  /// Full token string, e.g. "1773305579_df60ad1571a525e89085e88992fc61ce23073fe4".
  final String token;

  /// Unix timestamp extracted from the token.
  final int timestamp;

  /// Hash portion extracted from the token.
  final String hash;

  /// Conservative expiration: timestamp + 300 seconds (5 minutes).
  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch(
    timestamp * 1000,
  ).add(const Duration(seconds: 300));

  Map<String, Object?> toMap() => <String, Object?>{
    'token': token,
    'timestamp': timestamp,
    'hash': hash,
  };

  factory NexusStreamToken.fromMap(Map<String, dynamic> map) {
    final token = map['token']?.toString() ?? '';
    var timestamp = 0;
    var hash = '';

    if (map['timestamp'] is int) {
      timestamp = map['timestamp'] as int;
    } else {
      timestamp = int.tryParse(map['timestamp']?.toString() ?? '') ?? 0;
    }

    hash = map['hash']?.toString() ?? '';

    // Fallback: parse timestamp and hash from the token string if not
    // provided explicitly (format: "timestamp_hash").
    if ((timestamp == 0 || hash.isEmpty) && token.contains('_')) {
      final parts = token.split('_');
      if (parts.length == 2) {
        if (timestamp == 0) {
          timestamp = int.tryParse(parts[0]) ?? 0;
        }
        if (hash.isEmpty) {
          hash = parts[1];
        }
      }
    }

    return NexusStreamToken(token: token, timestamp: timestamp, hash: hash);
  }
}
