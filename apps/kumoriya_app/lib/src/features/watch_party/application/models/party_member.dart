enum PartyRole { host, member }

final class PartyMember {
  const PartyMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.isReady = false,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final PartyRole role;
  final DateTime joinedAt;
  final bool isReady;

  factory PartyMember.fromJson(Map<String, dynamic> json) => PartyMember(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    role: json['role'] == 'host' ? PartyRole.host : PartyRole.member,
    joinedAt: DateTime.parse(json['joinedAt'] as String),
  );

  PartyMember copyWith({bool? isReady, PartyRole? role}) => PartyMember(
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    role: role ?? this.role,
    joinedAt: joinedAt,
    isReady: isReady ?? this.isReady,
  );
}
