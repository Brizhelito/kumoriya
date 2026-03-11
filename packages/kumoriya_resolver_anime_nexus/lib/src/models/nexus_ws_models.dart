final class NexusWsSession {
  const NexusWsSession({
    required this.sessionId,
    required this.authenticated,
    required this.sessionExpiry,
  });

  final String sessionId;
  final bool authenticated;
  final int sessionExpiry;
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
