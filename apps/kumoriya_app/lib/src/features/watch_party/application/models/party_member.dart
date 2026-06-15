enum PartyRole { host, member }

enum PartyMemberStatus {
  inLobby,
  loading,
  inPlayer,
  watching,
  paused,
  buffering;

  String get label {
    return switch (this) {
      PartyMemberStatus.inLobby => 'In Lobby',
      PartyMemberStatus.loading => 'Loading…',
      PartyMemberStatus.inPlayer => 'In Player',
      PartyMemberStatus.watching => 'Watching',
      PartyMemberStatus.paused => 'Paused',
      PartyMemberStatus.buffering => 'Buffering…',
    };
  }

  static PartyMemberStatus fromJson(String? value) {
    return switch (value) {
      'in_lobby' => PartyMemberStatus.inLobby,
      'loading' => PartyMemberStatus.loading,
      'in_player' => PartyMemberStatus.inPlayer,
      'watching' => PartyMemberStatus.watching,
      'paused' => PartyMemberStatus.paused,
      'buffering' => PartyMemberStatus.buffering,
      _ => PartyMemberStatus.inLobby,
    };
  }

  String get jsonValue {
    return switch (this) {
      PartyMemberStatus.inLobby => 'in_lobby',
      PartyMemberStatus.loading => 'loading',
      PartyMemberStatus.inPlayer => 'in_player',
      PartyMemberStatus.watching => 'watching',
      PartyMemberStatus.paused => 'paused',
      PartyMemberStatus.buffering => 'buffering',
    };
  }
}

final class PartyMember {
  const PartyMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.isReady = false,
    this.status = PartyMemberStatus.inLobby,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final PartyRole role;
  final DateTime joinedAt;
  final bool isReady;
  final PartyMemberStatus status;

  factory PartyMember.fromJson(Map<String, dynamic> json) => PartyMember(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    role: json['role'] == 'host' ? PartyRole.host : PartyRole.member,
    joinedAt: DateTime.parse(json['joinedAt'] as String),
    status: PartyMemberStatus.fromJson(json['status'] as String?),
  );

  PartyMember copyWith({
    bool? isReady,
    PartyRole? role,
    PartyMemberStatus? status,
  }) => PartyMember(
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    role: role ?? this.role,
    joinedAt: joinedAt,
    isReady: isReady ?? this.isReady,
    status: status ?? this.status,
  );
}
