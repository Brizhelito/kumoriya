import 'dart:convert';

import 'package:http/http.dart' as http;

import '../application/models/models.dart';

/// REST client for party room management.
/// All real-time traffic goes P2P — this only handles room CRUD.
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

  /// POST /api/v1/party/join — join via invite code.
  Future<PartyRoom> joinRoom(String inviteCode) async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inviteCode': inviteCode}),
    );
    return _parseRoom(res, 200);
  }

  /// POST /api/v1/party/leave — leave current room.
  Future<void> leaveRoom() async {
    final res = await _http.post(
      Uri.parse('$_baseUrl$_basePath/leave'),
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
    final res = await _http.get(
      Uri.parse('$_baseUrl$_basePath/$roomId'),
    );
    if (res.statusCode == 404) return null;
    return _parseRoom(res, 200);
  }

  /// GET /api/v1/party/invite/:code — preview room before joining.
  Future<PartyRoom?> getRoomByInvite(String code) async {
    final res = await _http.get(
      Uri.parse('$_baseUrl$_basePath/invite/$code'),
    );
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
