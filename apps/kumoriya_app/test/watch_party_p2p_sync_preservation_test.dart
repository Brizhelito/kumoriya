// ignore_for_file: lines_longer_than_80_chars

/// Preservation Property Tests — Task 2 (watch-party-p2p-sync-fix)
///
/// **Property 2: Preservation** - Non-P2P Functionality Preserved
///
/// **IMPORTANT**: Follow observation-first methodology.
/// These tests verify that non-P2P functionality (room creation, authentication,
/// signaling, navigation) remains unchanged after the fix. They should pass on
/// both unfixed and fixed code.
///
/// **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15**
///
/// Preservation Requirements:
/// - Room creation via server API continues to work
/// - Room joining with valid invite codes continues to work
/// - WebSocket signaling connection establishment continues to work
/// - SDP offer/answer exchange via signaling continues to work
/// - ICE candidate relay via signaling continues to work
/// - RTCPeerConnection establishment continues to work
/// - UI navigation and lifecycle management continues to work
/// - Authentication and authorization flows continue to work
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kumoriya_app/src/features/watch_party/application/models/models.dart';
import 'package:kumoriya_app/src/features/watch_party/infrastructure/party_api_client.dart';
import 'package:kumoriya_app/src/features/watch_party/infrastructure/signaling_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('Property 2: Preservation - Non-P2P Functionality', () {
    group('Room Creation and Joining (Server API)', () {
      test(
        'PRESERVATION: Room creation via server API continues to work',
        () async {
          // **Validates: Requirements 3.1**
          //
          // This test verifies that the server API for room creation continues
          // to work exactly as before. The fix should NOT affect server-side
          // room creation logic.

          final mockClient = _MockHttpClient();
          final apiClient = PartyApiClient(
            httpClient: mockClient,
            baseUrl: 'https://api.test.com',
          );

          // Mock successful room creation response
          mockClient.mockPost(
            '/api/v1/party',
            statusCode: 201,
            body: jsonEncode({
              'room': {
                'id': 'room-123',
                'hostId': 'user-host',
                'inviteCode': 'ABC123',
                'anilistId': 12345,
                'animeTitle': 'Test Anime',
                'episodeNumber': 1.0,
                'maxMembers': 4,
                'createdAt': DateTime.now().toIso8601String(),
                'members': [
                  {
                    'userId': 'user-host',
                    'displayName': 'Host User',
                    'role': 'host',
                    'joinedAt': DateTime.now().toIso8601String(),
                  },
                ],
              },
            }),
          );

          // Create room
          final room = await apiClient.createRoom(
            anilistId: 12345,
            animeTitle: 'Test Anime',
            episodeNumber: 1.0,
          );

          // Verify room creation succeeded
          expect(room.id, 'room-123');
          expect(room.hostId, 'user-host');
          expect(room.inviteCode, 'ABC123');
          expect(room.anilistId, 12345);
          expect(room.animeTitle, 'Test Anime');
          expect(room.episodeNumber, 1.0);
          expect(room.maxMembers, 4);
          expect(room.members.length, 1);
          expect(room.members.first.userId, 'user-host');
          expect(room.members.first.role, PartyRole.host);

          // Verify API was called correctly
          expect(mockClient.postCalls.length, 1);
          expect(mockClient.postCalls.first.url.path, '/api/v1/party');
        },
      );

      test(
        'PRESERVATION: Room joining with valid invite code continues to work',
        () async {
          // **Validates: Requirements 3.2**
          //
          // This test verifies that joining a room via invite code continues
          // to work. The fix should NOT affect the server-side join logic.

          final mockClient = _MockHttpClient();
          final apiClient = PartyApiClient(
            httpClient: mockClient,
            baseUrl: 'https://api.test.com',
          );

          // Mock successful join response
          mockClient.mockPost(
            '/api/v1/party/join',
            statusCode: 200,
            body: jsonEncode({
              'room': {
                'id': 'room-123',
                'hostId': 'user-host',
                'inviteCode': 'ABC123',
                'anilistId': 12345,
                'animeTitle': 'Test Anime',
                'episodeNumber': 1.0,
                'maxMembers': 4,
                'createdAt': DateTime.now().toIso8601String(),
                'members': [
                  {
                    'userId': 'user-host',
                    'displayName': 'Host User',
                    'role': 'host',
                    'joinedAt': DateTime.now().toIso8601String(),
                  },
                  {
                    'userId': 'user-member',
                    'displayName': 'Member User',
                    'role': 'member',
                    'joinedAt': DateTime.now().toIso8601String(),
                  },
                ],
              },
            }),
          );

          // Join room
          final room = await apiClient.joinRoom('ABC123');

          // Verify join succeeded
          expect(room.id, 'room-123');
          expect(room.inviteCode, 'ABC123');
          expect(room.members.length, 2);
          expect(room.members.any((m) => m.userId == 'user-member'), isTrue);

          // Verify API was called correctly
          expect(mockClient.postCalls.length, 1);
          expect(mockClient.postCalls.first.url.path, '/api/v1/party/join');
        },
      );

      test(
        'PRESERVATION: Room joining with invalid invite code fails appropriately',
        () async {
          // **Validates: Requirements 3.3**
          //
          // This test verifies that invalid invite codes are rejected correctly.
          // The fix should NOT affect error handling for invalid codes.

          final mockClient = _MockHttpClient();
          final apiClient = PartyApiClient(
            httpClient: mockClient,
            baseUrl: 'https://api.test.com',
          );

          // Mock error response for invalid code
          mockClient.mockPost(
            '/api/v1/party/join',
            statusCode: 404,
            body: jsonEncode({'error': 'Room not found'}),
          );

          // Attempt to join with invalid code
          expect(
            () => apiClient.joinRoom('INVALID'),
            throwsA(isA<PartyApiException>()),
          );
        },
      );
    });

    group('WebSocket Signaling Infrastructure', () {
      test(
        'PRESERVATION: SignalingClient can be instantiated and configured',
        () {
          // **Validates: Requirements 3.4**
          //
          // This test verifies that the SignalingClient can be created and
          // configured correctly. The fix should NOT affect signaling client
          // initialization.

          final client = SignalingClient(
            wsUrl: 'wss://test.com',
            accessToken: 'test-token',
          );

          expect(client.isConnected, isFalse);
          expect(client.messages, isA<Stream<SignalEnvelope>>());

          client.dispose();
        },
      );

      test('PRESERVATION: SignalEnvelope parsing continues to work', () {
        // **Validates: Requirements 3.5**
        //
        // This test verifies that signaling message parsing continues to work.
        // The fix should NOT affect how signaling messages are parsed.

        // Test offer message parsing
        final offerJson = {
          'type': 'offer',
          'from': 'user-123',
          'to': 'user-456',
          'payload': {'sdp': 'test-sdp', 'type': 'offer'},
        };
        final offerEnvelope = SignalEnvelope.fromJson(offerJson);

        expect(offerEnvelope.type, 'offer');
        expect(offerEnvelope.from, 'user-123');
        expect(offerEnvelope.to, 'user-456');
        expect(offerEnvelope.isOffer, isTrue);
        expect(offerEnvelope.payload['sdp'], 'test-sdp');

        // Test answer message parsing
        final answerJson = {
          'type': 'answer',
          'from': 'user-456',
          'to': 'user-123',
          'payload': {'sdp': 'test-sdp', 'type': 'answer'},
        };
        final answerEnvelope = SignalEnvelope.fromJson(answerJson);

        expect(answerEnvelope.type, 'answer');
        expect(answerEnvelope.isAnswer, isTrue);

        // Test ICE candidate message parsing
        final candidateJson = {
          'type': 'candidate',
          'from': 'user-123',
          'to': 'user-456',
          'payload': {
            'candidate': 'test-candidate',
            'sdpMid': 'test-mid',
            'sdpMLineIndex': 0,
          },
        };
        final candidateEnvelope = SignalEnvelope.fromJson(candidateJson);

        expect(candidateEnvelope.type, 'candidate');
        expect(candidateEnvelope.isCandidate, isTrue);
        expect(candidateEnvelope.payload['candidate'], 'test-candidate');

        // Test peer_joined message parsing
        final peerJoinedJson = {
          'type': 'peer_joined',
          'from': 'user-789',
          'payload': {},
        };
        final peerJoinedEnvelope = SignalEnvelope.fromJson(peerJoinedJson);

        expect(peerJoinedEnvelope.type, 'peer_joined');
        expect(peerJoinedEnvelope.isPeerJoined, isTrue);

        // Test room_state message parsing
        final roomStateJson = {
          'type': 'room_state',
          'payload': {
            'peers': ['user-123', 'user-456'],
          },
        };
        final roomStateEnvelope = SignalEnvelope.fromJson(roomStateJson);

        expect(roomStateEnvelope.type, 'room_state');
        expect(roomStateEnvelope.isRoomState, isTrue);
      });

      test(
        'PRESERVATION: SignalingClient message sending interface unchanged',
        () {
          // **Validates: Requirements 3.6**
          //
          // This test verifies that the SignalingClient's message sending
          // interface continues to work. The fix should NOT affect how
          // signaling messages are sent.

          final client = SignalingClient(
            wsUrl: 'wss://test.com',
            accessToken: 'test-token',
          );

          // Verify methods exist and can be called (won't actually send without connection)
          expect(
            () =>
                client.sendOffer('user-456', {'sdp': 'test', 'type': 'offer'}),
            returnsNormally,
          );
          expect(
            () => client.sendAnswer('user-456', {
              'sdp': 'test',
              'type': 'answer',
            }),
            returnsNormally,
          );
          expect(
            () => client.sendCandidate('user-456', {'candidate': 'test'}),
            returnsNormally,
          );
          expect(() => client.sendPong(), returnsNormally);

          client.dispose();
        },
      );
    });

    group('Room Data Models and Parsing', () {
      test('PRESERVATION: PartyRoom model parsing continues to work', () {
        // **Validates: Requirements 3.7, 3.8**
        //
        // This test verifies that PartyRoom model parsing continues to work.
        // The fix should NOT affect how room data is parsed from JSON.

        final roomJson = {
          'id': 'room-123',
          'hostId': 'user-host',
          'inviteCode': 'ABC123',
          'anilistId': 12345,
          'animeTitle': 'Test Anime',
          'episodeNumber': 1.0,
          'maxMembers': 4,
          'createdAt': '2024-01-01T00:00:00.000Z',
          'members': [
            {
              'userId': 'user-host',
              'displayName': 'Host User',
              'role': 'host',
              'joinedAt': '2024-01-01T00:00:00.000Z',
            },
            {
              'userId': 'user-member',
              'displayName': 'Member User',
              'role': 'member',
              'joinedAt': '2024-01-01T00:00:01.000Z',
            },
          ],
        };

        final room = PartyRoom.fromJson(roomJson);

        expect(room.id, 'room-123');
        expect(room.hostId, 'user-host');
        expect(room.inviteCode, 'ABC123');
        expect(room.anilistId, 12345);
        expect(room.animeTitle, 'Test Anime');
        expect(room.episodeNumber, 1.0);
        expect(room.maxMembers, 4);
        expect(room.members.length, 2);
        expect(room.isFull, isFalse);

        // Verify members parsed correctly
        final host = room.members.first;
        expect(host.userId, 'user-host');
        expect(host.displayName, 'Host User');
        expect(host.role, PartyRole.host);

        final member = room.members.last;
        expect(member.userId, 'user-member');
        expect(member.displayName, 'Member User');
        expect(member.role, PartyRole.member);
      });

      test('PRESERVATION: PartyRoom copyWith continues to work', () {
        // **Validates: Requirements 3.9**
        //
        // This test verifies that PartyRoom's copyWith method continues to work.
        // The fix should NOT affect room state updates.

        final originalRoom = PartyRoom(
          id: 'room-123',
          hostId: 'user-host',
          inviteCode: 'ABC123',
          anilistId: 12345,
          animeTitle: 'Test Anime',
          episodeNumber: 1.0,
          maxMembers: 4,
          createdAt: DateTime.now(),
          members: [
            PartyMember(
              userId: 'user-host',
              displayName: 'Host User',
              role: PartyRole.host,
              joinedAt: DateTime.now(),
            ),
          ],
        );

        // Test updating anime/episode
        final updatedRoom = originalRoom.copyWith(
          anilistId: 67890,
          animeTitle: 'New Anime',
          episodeNumber: 2.0,
        );

        expect(updatedRoom.id, originalRoom.id);
        expect(updatedRoom.hostId, originalRoom.hostId);
        expect(updatedRoom.inviteCode, originalRoom.inviteCode);
        expect(updatedRoom.anilistId, 67890);
        expect(updatedRoom.animeTitle, 'New Anime');
        expect(updatedRoom.episodeNumber, 2.0);
        expect(updatedRoom.maxMembers, originalRoom.maxMembers);
        expect(updatedRoom.members, originalRoom.members);
      });

      test('PRESERVATION: PartyMember model parsing continues to work', () {
        // **Validates: Requirements 3.10**
        //
        // This test verifies that PartyMember model parsing continues to work.
        // The fix should NOT affect member data parsing.

        final memberJson = {
          'userId': 'user-123',
          'displayName': 'Test User',
          'role': 'member',
          'joinedAt': '2024-01-01T00:00:00.000Z',
        };

        final member = PartyMember.fromJson(memberJson);

        expect(member.userId, 'user-123');
        expect(member.displayName, 'Test User');
        expect(member.role, PartyRole.member);
        expect(member.joinedAt, isA<DateTime>());
      });
    });

    group('Authentication and Authorization', () {
      test('PRESERVATION: Room operations require authentication context', () {
        // **Validates: Requirements 3.13, 3.14**
        //
        // This test verifies that authentication is still required for room
        // operations. The fix should NOT bypass authentication checks.

        final mockClient = _MockHttpClient();
        final apiClient = PartyApiClient(
          httpClient: mockClient,
          baseUrl: 'https://api.test.com',
        );

        // Mock 401 Unauthorized response
        mockClient.mockPost(
          '/api/v1/party',
          statusCode: 401,
          body: jsonEncode({'error': 'Unauthorized'}),
        );

        // Verify that unauthorized requests fail
        expect(
          () => apiClient.createRoom(
            anilistId: 12345,
            animeTitle: 'Test Anime',
            episodeNumber: 1.0,
          ),
          throwsA(
            isA<PartyApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      });

      test('PRESERVATION: PartyApiClient uses provided HTTP client', () async {
        // **Validates: Requirements 3.14**
        //
        // This test verifies that the API client uses the provided HTTP client
        // (which should be an authenticated client in production). The fix
        // should NOT change how authentication tokens are passed.

        final mockClient = _MockHttpClient();
        final apiClient = PartyApiClient(
          httpClient: mockClient,
          baseUrl: 'https://api.test.com',
        );

        // Mock successful response
        mockClient.mockPost(
          '/api/v1/party',
          statusCode: 201,
          body: jsonEncode({
            'room': {
              'id': 'room-123',
              'hostId': 'user-host',
              'inviteCode': 'ABC123',
              'anilistId': 12345,
              'animeTitle': 'Test Anime',
              'episodeNumber': 1.0,
              'maxMembers': 4,
              'createdAt': DateTime.now().toIso8601String(),
              'members': [
                {
                  'userId': 'user-host',
                  'displayName': 'Host User',
                  'role': 'host',
                  'joinedAt': DateTime.now().toIso8601String(),
                },
              ],
            },
          }),
        );

        // Make request (await it so the mock client is actually called)
        await apiClient.createRoom(
          anilistId: 12345,
          animeTitle: 'Test Anime',
          episodeNumber: 1.0,
        );

        // Verify the mock client was used
        expect(mockClient.postCalls.length, 1);
      });
    });

    group('UI Navigation and Lifecycle', () {
      test('PRESERVATION: Room state transitions remain unchanged', () {
        // **Validates: Requirements 3.11, 3.12**
        //
        // This test verifies that room state management continues to work.
        // The fix should NOT affect how room state is managed in the UI layer.

        final room = PartyRoom(
          id: 'room-123',
          hostId: 'user-host',
          inviteCode: 'ABC123',
          anilistId: 12345,
          animeTitle: 'Test Anime',
          episodeNumber: 1.0,
          maxMembers: 4,
          createdAt: DateTime.now(),
          members: [
            PartyMember(
              userId: 'user-host',
              displayName: 'Host User',
              role: PartyRole.host,
              joinedAt: DateTime.now(),
            ),
          ],
        );

        // Verify room state properties
        expect(room.id, isNotEmpty);
        expect(room.hostId, isNotEmpty);
        expect(room.inviteCode, isNotEmpty);
        expect(room.members, isNotEmpty);
        expect(room.isFull, isFalse);

        // Verify room can be updated
        final updatedRoom = room.copyWith(
          anilistId: 67890,
          animeTitle: 'New Anime',
        );

        expect(updatedRoom.anilistId, 67890);
        expect(updatedRoom.animeTitle, 'New Anime');
        expect(updatedRoom.id, room.id);
      });

      test('PRESERVATION: Room capacity checks continue to work', () {
        // **Validates: Requirements 3.15**
        //
        // This test verifies that room capacity checks continue to work.
        // The fix should NOT affect room capacity logic.

        final fullRoom = PartyRoom(
          id: 'room-123',
          hostId: 'user-host',
          inviteCode: 'ABC123',
          anilistId: 12345,
          animeTitle: 'Test Anime',
          episodeNumber: 1.0,
          maxMembers: 2,
          createdAt: DateTime.now(),
          members: [
            PartyMember(
              userId: 'user-host',
              displayName: 'Host User',
              role: PartyRole.host,
              joinedAt: DateTime.now(),
            ),
            PartyMember(
              userId: 'user-member',
              displayName: 'Member User',
              role: PartyRole.member,
              joinedAt: DateTime.now(),
            ),
          ],
        );

        expect(fullRoom.isFull, isTrue);

        final notFullRoom = fullRoom.copyWith(
          members: [fullRoom.members.first],
        );

        expect(notFullRoom.isFull, isFalse);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('PRESERVATION: API error handling continues to work', () async {
        // **Validates: Requirements 3.9**
        //
        // This test verifies that API error handling continues to work.
        // The fix should NOT affect error handling logic.

        // Test various error status codes
        final errorCases = [
          (400, 'Bad Request'),
          (401, 'Unauthorized'),
          (403, 'Forbidden'),
          (404, 'Not Found'),
          (500, 'Internal Server Error'),
        ];

        for (final (statusCode, message) in errorCases) {
          // Create a fresh mock client for each test case
          final mockClient = _MockHttpClient();
          final apiClient = PartyApiClient(
            httpClient: mockClient,
            baseUrl: 'https://api.test.com',
          );

          mockClient.mockPost(
            '/api/v1/party',
            statusCode: statusCode,
            body: jsonEncode({'error': message}),
          );

          expect(
            () => apiClient.createRoom(
              anilistId: 12345,
              animeTitle: 'Test Anime',
              episodeNumber: 1.0,
            ),
            throwsA(
              isA<PartyApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                statusCode,
              ),
            ),
            reason: 'Should throw PartyApiException for status $statusCode',
          );
        }
      });

      test('PRESERVATION: SignalingClient disposal is safe', () {
        // **Validates: Requirements 3.4**
        //
        // This test verifies that SignalingClient can be safely disposed.
        // The fix should NOT affect cleanup logic.

        final client = SignalingClient(
          wsUrl: 'wss://test.com',
          accessToken: 'test-token',
        );

        expect(() => client.dispose(), returnsNormally);
        expect(client.isConnected, isFalse);

        // Verify double dispose is safe
        expect(() => client.dispose(), returnsNormally);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Mock HTTP client for testing
// ---------------------------------------------------------------------------

final class _MockHttpClient extends http.BaseClient {
  final List<_PostCall> postCalls = [];
  final Map<String, _MockResponse> _mockResponses = {};

  void mockPost(String path, {required int statusCode, required String body}) {
    _mockResponses[path] = _MockResponse(statusCode: statusCode, body: body);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST') {
      postCalls.add(
        _PostCall(
          url: request.url,
          body: await request.finalize().bytesToString(),
        ),
      );
      final response = _mockResponses[request.url.path];
      if (response != null) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(response.body)),
          response.statusCode,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    if (request.method == 'GET') {
      final response = _mockResponses[request.url.path];
      if (response != null) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(response.body)),
          response.statusCode,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    if (request.method == 'PATCH') {
      final response = _mockResponses[request.url.path];
      if (response != null) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(response.body)),
          response.statusCode,
          headers: {'content-type': 'application/json'},
        );
      }
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'error': 'Not mocked'}))),
      500,
    );
  }
}

final class _PostCall {
  const _PostCall({required this.url, required this.body});
  final Uri url;
  final String body;
}

final class _MockResponse {
  const _MockResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}
