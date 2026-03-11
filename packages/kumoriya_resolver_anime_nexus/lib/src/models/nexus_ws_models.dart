final class NexusWsSession {
  const NexusWsSession({
    required this.sessionId,
    required this.authenticated,
    required this.sessionExpiry,
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
      sessionExpiry: map['sessionExpiry'] is int
          ? map['sessionExpiry'] as int
          : int.tryParse(map['sessionExpiry']?.toString() ?? '') ?? 0,
    );
  }
}

final class NexusStreamToken {
  const NexusStreamToken({
    required this.token,
    required this.nextTokenId,
    required this.expires,
  });

  final String token;
  final String nextTokenId;
  final int expires;

  Map<String, Object?> toMap() => <String, Object?>{
    'token': token,
    'nextTokenId': nextTokenId,
    'expires': expires,
  };

  factory NexusStreamToken.fromMap(Map<String, dynamic> map) {
    return NexusStreamToken(
      token: map['token']?.toString() ?? '',
      nextTokenId: map['nextTokenId']?.toString() ?? '',
      expires: map['expires'] is int
          ? map['expires'] as int
          : int.tryParse(map['expires']?.toString() ?? '') ?? 0,
    );
  }
}
