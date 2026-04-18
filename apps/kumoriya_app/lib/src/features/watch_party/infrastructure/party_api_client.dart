import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/models/models.dart';

/// REST client for party room management.
///
/// In the legacy (v1) flow the response is `{ "room": {...} }`.
/// In the realtime (v2) flow the response is
/// `{ "room": {...}, "realtimeSession": {...} }`. The helpers
/// `createRoomV2` / `joinRoomV2` / `refreshSession` are used by
/// `PartyRealtimeClient`; the older methods remain for compatibility
/// while the migration is in progress.
final class PartyApiClient {
  PartyApiClient({required http.Client httpClient, required String baseUrl})
    : _http = httpClient,
      _baseUrl = baseUrl;

  final http.Client _http;
  final String _baseUrl;

  static const _basePath = '/api/v1/party';

  /// POST /api/v1/party — create a new watch-party room.
  Future<PartyRoom> createRoom({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
    int maxMembers = 4,
  }) async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'anilistId': anilistId,
        'animeTitle': animeTitle,
        'episodeNumber': episodeNumber,
        'maxMembers': maxMembers,
      }),
    );
    return _parseRoom(res, 201);
  }

  /// POST /api/v1/party — v2 variant returning room + realtime session.
  Future<PartyRoomWithSession<PartyRoom>> createRoomV2({
    required int anilistId,
    required String animeTitle,
    required double episodeNumber,
    int maxMembers = 4,
  }) async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'anilistId': anilistId,
        'animeTitle': animeTitle,
        'episodeNumber': episodeNumber,
        'maxMembers': maxMembers,
      }),
    );
    return _parseRoomWithSession(res, 201);
  }

  /// POST /api/v1/party/join — join via invite code.
  Future<PartyRoom> joinRoom(String inviteCode) async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inviteCode': inviteCode}),
    );
    return _parseRoom(res, 200);
  }

  /// POST /api/v1/party/join — v2 variant returning room + realtime session.
  Future<PartyRoomWithSession<PartyRoom>> joinRoomV2(String inviteCode) async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inviteCode': inviteCode}),
    );
    return _parseRoomWithSession(res, 200);
  }

  /// POST /api/v1/party/session/refresh — mint a new realtime session for
  /// an already-joined user.
  Future<PartyRealtimeSession> refreshSession(String roomId) async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath/session/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'roomId': roomId}),
    );
    if (res.statusCode != 200) {
      throw PartyApiException(res.statusCode, _errorBody(res));
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return PartyRealtimeSession.fromJson(json['session'] as Map<String, dynamic>);
  }

  /// POST /api/v1/party/leave — leave current room. In the v2 brokered flow
  /// the server needs the `roomId` explicitly (the API is stateless between
  /// requests); in v1 it is inferred from the authenticated user.
  Future<void> leaveRoom({String? roomId}) async {
    final uri = roomId == null
        ? Uri.parse('$_baseUrl$_basePath/leave')
        : Uri.parse('$_baseUrl$_basePath/leave').replace(
            queryParameters: {'roomId': roomId},
          );
    final res = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw PartyApiException(res.statusCode, _errorBody(res));
    }
  }

  /// GET /api/v1/party/me — get the room I'm currently in.
  Future<PartyRoom?> getMyRoom() async {
    final res = await _http.get(Uri.parse('$_baseUrl$_basePath/me'));
    if (res.statusCode == 404) return null;
    return _parseRoom(res, 200);
  }

  /// GET /api/v1/party/:id — get room by ID.
  Future<PartyRoom?> getRoom(String roomId) async {
    final res = await _http.get(Uri.parse('$_baseUrl$_basePath/$roomId'));
    if (res.statusCode == 404) return null;
    return _parseRoom(res, 200);
  }

  /// GET /api/v1/party/invite/:code — preview room before joining.
  Future<PartyRoom?> getRoomByInvite(String code) async {
    final res = await _http.get(Uri.parse('$_baseUrl$_basePath/invite/$code'));
    if (res.statusCode == 404) return null;
    return _parseRoom(res, 200);
  }

  /// PATCH /api/v1/party/:id — host updates anime/episode.
  Future<PartyRoom> updateRoom(
    String roomId, {
    int? anilistId,
    String? animeTitle,
    double? episodeNumber,
  }) async {
    final body = <String, dynamic>{};
    if (anilistId != null) body['anilistId'] = anilistId;
    if (animeTitle != null) body['animeTitle'] = animeTitle;
    if (episodeNumber != null) body['episodeNumber'] = episodeNumber;
    final res = await _http.patch(
      Uri.parse('$_baseUrl$_basePath/$roomId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parseRoom(res, 200);
  }

  // ── internal ──

  PartyRoom _parseRoom(http.Response res, int expectedStatus) {
    if (res.statusCode != expectedStatus) {
      throw PartyApiException(res.statusCode, _errorBody(res));
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return PartyRoom.fromJson(json['room'] as Map<String, dynamic>);
  }

  PartyRoomWithSession<PartyRoom> _parseRoomWithSession(
    http.Response res,
    int expectedStatus,
  ) {
    if (res.statusCode != expectedStatus) {
      throw PartyApiException(res.statusCode, _errorBody(res));
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rawRoom = json['room'] as Map<String, dynamic>;
    // The v2 response may omit `members` / `createdAt` since the Worker
    // owns them. Build a defensive fallback so PartyRoom.fromJson keeps
    // working against both shapes.
    final room = PartyRoom.fromJson({
      'members': const [],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      ...rawRoom,
    });
    final session = PartyRealtimeSession.fromJson(
      json['realtimeSession'] as Map<String, dynamic>,
    );
    return PartyRoomWithSession<PartyRoom>(room: room, session: session);
  }

  String _errorBody(http.Response res) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['error'] as String? ?? res.body;
    } catch (_) {
      return res.body;
    }
  }
}

class PartyApiException implements Exception {
  PartyApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'PartyApiException($statusCode): $message';
}
