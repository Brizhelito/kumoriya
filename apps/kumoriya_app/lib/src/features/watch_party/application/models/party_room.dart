import 'party_member.dart';

final class PartyRoom {
  const PartyRoom({
    required this.id,
    required this.hostId,
    required this.members,
    required this.anilistId,
    required this.animeTitle,
    required this.episodeNumber,
    required this.maxMembers,
    required this.inviteCode,
    required this.createdAt,
  });

  final String id;
  final String hostId;
  final List<PartyMember> members;
  final int anilistId;
  final String animeTitle;
  final double episodeNumber;
  final int maxMembers;
  final String inviteCode;
  final DateTime createdAt;

  factory PartyRoom.fromJson(Map<String, dynamic> json) => PartyRoom(
        id: json['id'] as String,
        hostId: json['hostId'] as String,
        members: (json['members'] as List)
            .map((e) => PartyMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        anilistId: json['anilistId'] as int,
        animeTitle: json['animeTitle'] as String,
        episodeNumber: (json['episodeNumber'] as num).toDouble(),
        maxMembers: json['maxMembers'] as int,
        inviteCode: json['inviteCode'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  bool get isFull => members.length >= maxMembers;

  PartyRoom copyWith({
    List<PartyMember>? members,
    int? anilistId,
    String? animeTitle,
    double? episodeNumber,
    String? hostId,
  }) =>
      PartyRoom(
        id: id,
        hostId: hostId ?? this.hostId,
        members: members ?? this.members,
        anilistId: anilistId ?? this.anilistId,
        animeTitle: animeTitle ?? this.animeTitle,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        maxMembers: maxMembers,
        inviteCode: inviteCode,
        createdAt: createdAt,
      );
}
