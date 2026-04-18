# Implementation Plan: Watch Party Realtime Migration

## Overview

This implementation migrates the watch party system from an in-memory implementation to a dedicated realtime service at `party.kumoriya.online` using Cloudflare Workers with Durable Objects. The migration involves three major components: the Party Realtime Service (TypeScript/Cloudflare Workers), Kumoriya API broker integration (Go), and Flutter client migration. The implementation follows a server-authoritative model with persistent state, reconnection support, and prepared WebRTC signaling infrastructure.

## Tasks

- [x] 1. Set up Party Realtime Service infrastructure and project structure
  - Create `infra/watch-party-realtime` directory with TypeScript project
  - Configure wrangler.toml with Durable Objects bindings (PARTY_REGISTRY, PARTY_ROOM)
  - Set up TypeScript configuration with strict mode and Cloudflare Workers types
  - Define environment variables/secrets structure (PARTY_INTERNAL_TOKEN, PARTY_SESSION_PUBLIC_KEY, PARTY_SESSION_ISSUER)
  - Create basic Worker entry point with HTTP and WebSocket routing skeleton
  - _Requirements: 1.1, 1.2, 1.3, 20.1, 20.2, 20.3, 20.4_

- [ ] 2. Implement data models and type definitions
  - [x] 2.1 Create core data model interfaces and types
    - Define SessionToken interface with Ed25519 JWT claims structure
    - Define RoomState, Member, ReadyState, MediaState, PlaybackState interfaces
    - Define WSEnvelope structure for all WebSocket messages
    - Define all client→server and server→client message payload types
    - Define error codes enum and ErrorPayload interface
    - _Requirements: 2.1, 3.3, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1_

  - [x] 2.2 Write property test for data model invariants
    - **Property 6: Ready State Dual-Layer Consistency**
    - **Validates: Requirements 7.1, 7.3, 7.4**

- [x] 3. Implement PartyRegistryDO (singleton Durable Object)
  - [x] 3.1 Create PartyRegistryDO class with Durable Object lifecycle
    - Implement constructor and fetch handler
    - Set up persistent storage schema (rooms, inviteCodes, userRooms maps)
    - Implement room creation with unique roomId (UUID v4) and inviteCode (6-char alphanumeric) generation
    - Implement invite code resolution endpoint
    - Implement user-to-room mapping management
    - _Requirements: 1.5, 2.2, 2.3, 2.4, 2.5, 3.2_

  - [x] 3.2 Write property test for room creation uniqueness
    - **Property 1: Room Creation Generates Unique Identifiers**
    - **Validates: Requirements 2.2, 2.3**

  - [x] 3.3 Write property test for invite code resolution determinism
    - **Property 2: Invite Code Resolution is Deterministic**
    - **Validates: Requirements 3.2**

  - [x] 3.4 Write unit tests for PartyRegistryDO
    - Test room creation success path
    - Test invite code resolution (valid and invalid codes)
    - Test user-to-room mapping enforcement (user already in room rejection)
    - Test cleanup when rooms are destroyed
    - _Requirements: 2.1, 2.2, 2.3, 3.2, 3.6_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run unit tests for PartyRegistryDO
  - Run property tests for room creation and invite code resolution

- [x] 5. Implement message acknowledgement and error handling
  - [x] 5.1 Implement ack and error message responses
    - Implement ack message generation with messageId correlation
    - Implement error message generation with code, message, retryable fields
    - Validate client messages include messageId for state-modifying operations
    - Reject messages without messageId with error code=invalid_message
    - Implement all error codes (invalid_token, expired_token, room_not_found, room_full, invalid_invite_code, rate_limit_exceeded, unauthorized, user_already_in_room, invalid_message)
    - _Requirements: Message Semantics (ack, error sections)_
    - _Note: This handles WebSocket protocol/application-level errors. Authentication/routing errors are handled in Task 17._

  - [x] 5.2 Write unit tests for message acknowledgement and errors
    - Test ack includes original messageId
    - Test error includes code, message, retryable
    - Test state-modifying messages without messageId rejected
    - Test all error code paths
    - _Requirements: Message Semantics_

- [x] 6. Implement PartyRoomDO core state management
  - [x] 6.1 Create PartyRoomDO class with Durable Object lifecycle
    - Implement constructor, fetch handler, and WebSocket handler
    - Set up persistent storage for RoomState
    - Implement in-memory state for active connections, heartbeats, grace period timers
    - Implement room initialization with creator as first member and host
    - Implement member join/leave logic with 4-member limit enforcement
    - _Requirements: 1.6, 2.6, 2.7, 3.7, 3.8, 3.9, 13.2, 13.3_
    - _Note: WebSocket handler receives connections already authenticated and routed by Worker entry point (Task 17)_

  - [x] 6.2 Implement member presence and heartbeat tracking
    - Implement heartbeat message handler with lastHeartbeatMs update
    - Implement connection close handler with presence state update
    - Implement grace period timers (120s for members, 60s for host)
    - Implement reconnection logic with state restoration
    - Implement member removal after grace period expiration
    - Broadcast member_presence_changed messages
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

  - [x] 6.3 Write property test for grace period state preservation
    - **Property 7: Grace Period State Preservation**
    - **Validates: Requirements 5.4, 5.6, 7.4**

  - [x] 6.4 Write property test for reconnection state restoration
    - **Property 15: Reconnection State Restoration**
    - **Validates: Requirements 5.6, 17.3**

  - [x] 6.5 Write unit tests for presence and heartbeat logic
    - Test heartbeat updates lastHeartbeatMs
    - Test disconnection starts grace period
    - Test reconnection within grace period restores state
    - Test member removal after grace period expiration
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.6, 5.7_

- [x] 7. Implement host authority and transfer logic
  - [x] 7.1 Implement host authority enforcement
    - Implement playback_intent validation (host-only check)
    - Implement host transfer on host disconnect (60s grace period)
    - Implement host transfer to oldest connected member
    - Broadcast host_transferred messages
    - Implement empty room TTL (15 minutes) with room destruction
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 13.5_

  - [x] 7.2 Write property test for host authority exclusivity
    - **Property 3: Host Authority is Exclusive**
    - **Validates: Requirements 6.1**

  - [x] 7.3 Write property test for host transfer on host leave
    - **Property 16: Host Transfer on Host Leave**
    - **Validates: Requirements 6.5, 13.5**

  - [x] 7.4 Write property test for playback intent host-only enforcement
    - **Property 17: Playback Intent Host-Only Enforcement**
    - **Validates: Requirements 6.2, 6.3**

  - [x] 7.5 Write property test for empty room TTL
    - **Property 19: Empty Room TTL**
    - **Validates: Requirements 6.7, 6.8**

  - [x] 7.6 Write unit tests for host authority logic
    - Test host-only playback_intent acceptance
    - Test non-host playback_intent rejection
    - Test host transfer scenarios (disconnect, reconnect, timeout)
    - Test empty room TTL timer and destruction
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.7_

- [x] 8. Checkpoint - Ensure all tests pass
  - Run unit tests for PartyRoomDO, host authority, and presence tracking
  - Run property tests for host exclusivity, playback intent enforcement, grace period, and reconnection

- [-] 9. Implement ready state management
  - [-] 9.1 Implement dual-layer ready state (readyPersisted/effectiveReady)
    - Implement set_ready message handler updating readyPersisted and effectiveReady
    - Implement effectiveReady calculation (readyPersisted AND connected)
    - Implement effectiveReady reset on disconnect (preserve readyPersisted)
    - Implement effectiveReady restoration on reconnect
    - Broadcast member_ready_changed messages
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ] 9.2 Write unit tests for ready state logic
    - Test set_ready updates both readyPersisted and effectiveReady
    - Test disconnect sets effectiveReady to false, preserves readyPersisted
    - Test reconnect restores effectiveReady from readyPersisted
    - Test room_snapshot reflects effectiveReady, not readyPersisted
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [-] 10. Implement server-authoritative playback synchronization
  - [-] 10.1 Implement playback state management
    - Implement playback_intent handler for play, pause, seek actions
    - Update authoritative playback state (status, basePositionMs, effectiveAtMs)
    - Implement generation counter increment on every playback state change
    - Broadcast playback_state_changed messages
    - Implement resync_request handler broadcasting current state
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9_

  - [ ] 10.2 Write property test for playback state monotonicity
    - **Property 4: Playback State Monotonicity**
    - **Validates: Requirements 8.5**

  - [ ] 10.3 Write unit tests for playback synchronization
    - Test play action updates state and increments generation
    - Test pause action updates state and increments generation
    - Test seek action updates position and increments generation
    - Test resync_request broadcasts current state
    - Test effectiveAtMs is set to server timestamp
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.9_

- [-] 11. Implement media and episode change logic
  - [ ] 11.1 Implement media_change and episode_change handlers
    - Implement media_change action updating media identifier
    - Implement episode_change action updating episode identifier
    - Reset playback position to 0 on media/episode change
    - Reset all member ready states to false on media/episode change
    - Increment generation counter on media/episode change
    - Broadcast media_changed and episode_changed messages
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [ ] 11.2 Write property test for media change resets position
    - **Property 8: Media Change Resets Position**
    - **Validates: Requirements 9.3**

  - [ ] 11.3 Write property test for media change resets ready states
    - **Property 9: Media Change Resets Ready States**
    - **Validates: Requirements 9.4**

  - [ ] 11.4 Write unit tests for media/episode change
    - Test media_change updates media and resets position
    - Test episode_change updates episode and resets position
    - Test ready states reset to false on media/episode change
    - Test generation counter increments
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 12. Checkpoint - Ensure all tests pass
  - Run unit tests for playback sync, media/episode change
  - Run property tests for playback monotonicity, media change resets

- [ ] 13. Implement chat messaging and reactions
  - [ ] 13.1 Implement chat message handling with rate limiting
    - Implement send_chat message handler with validation
    - Implement rate limiter (10 messages per 10 seconds per user)
    - Broadcast chat_message to all connected members
    - Return error with code=rate_limit_exceeded when limit exceeded
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 18.1, 18.4_

  - [ ] 13.2 Implement reaction handling with rate limiting
    - Implement send_reaction message handler with validation
    - Validate reaction type against allowed set (like, love, laugh, surprise, sad, angry)
    - Implement rate limiter (5 reactions per 5 seconds per user)
    - Broadcast reaction_broadcast to all connected members
    - Return error with code=rate_limit_exceeded when limit exceeded
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 18.2, 18.4_

  - [ ] 13.3 Write property test for chat rate limiting
    - **Property 13: Rate Limiting Enforces Chat Limit**
    - **Validates: Requirements 10.2, 10.3, 18.1**

  - [ ] 13.4 Write property test for reaction rate limiting
    - **Property 14: Rate Limiting Enforces Reaction Limit**
    - **Validates: Requirements 11.2, 11.3, 18.2**

  - [ ] 13.5 Write property test for member count limit
    - **Property 20: Member Count Limit**
    - **Validates: Requirements 3.7, 3.8**

  - [ ] 13.6 Write unit tests for chat and reactions
    - Test valid chat message broadcast
    - Test chat rate limit enforcement
    - Test valid reaction broadcast
    - Test reaction rate limit enforcement
    - Test invalid reaction type rejection
    - _Requirements: 10.1, 10.2, 10.3, 11.1, 11.2, 11.3_

- [ ] 14. Implement room snapshot and state recovery
  - [ ] 14.1 Implement room_snapshot generation and delivery
    - Implement room_snapshot message construction with all required fields
    - Send room_snapshot on initial connection
    - Send room_snapshot on reconnection
    - Implement request_snapshot handler
    - Implement roomVersion increment on any state change
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8_

  - [ ] 14.2 Write property test for room version monotonicity
    - **Property 5: Room Version Monotonicity**
    - **Validates: Requirements 2, 3, 5, 6, 7, 9, 13**

  - [ ] 14.3 Write property test for room snapshot completeness
    - **Property 18: Room Snapshot Completeness**
    - **Validates: Requirements 12.2, 12.3, 12.4, 12.5, 12.6**

  - [ ] 14.4 Write unit tests for room snapshot
    - Test room_snapshot includes all required fields
    - Test room_snapshot sent on connection
    - Test room_snapshot sent on reconnection
    - Test request_snapshot triggers room_snapshot
    - Test roomVersion increments on state changes
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7_

- [ ] 15. Implement WebRTC signaling preparation
  - [ ] 15.1 Implement WebRTC signaling message routing
    - Implement webrtc_signal message handler
    - Route signal to target peer specified in message
    - Validate targetUserId exists in room
    - Do NOT implement WebRTC peer connection logic
    - Do NOT implement audio track handling
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.6_

  - [ ] 15.2 Write unit tests for WebRTC signaling
    - Test webrtc_signal routes to correct target peer
    - Test webrtc_signal rejects invalid targetUserId
    - Test signal payload types (offer, answer, ice-candidate)
    - _Requirements: 14.1, 14.2, 14.6_

- [ ] 16. Checkpoint - Ensure all tests pass
  - Run unit tests for chat, reactions, room snapshot, WebRTC signaling
  - Run property tests for rate limiting, member count limit, room version monotonicity

- [ ] 17. Implement Worker entry point with token validation
  - [ ] 17.1 Implement HTTP and WebSocket routing
    - Implement public WebSocket endpoint (GET /ws) with token query parameter
    - Implement internal HTTP endpoints (/internal/v1/rooms, /internal/v1/invite/:code, /internal/v1/rooms/:roomId/join, /internal/v1/rooms/:roomId/leave, /internal/v1/rooms/:roomId/member-verify)
    - Implement internal endpoint authentication with PARTY_INTERNAL_TOKEN
    - Route WebSocket connections to PartyRoomDO based on roomId from token
    - Route internal HTTP requests to PartyRegistryDO
    - _Requirements: 1.3, 1.4, 4.1, 4.4, 4.5_

  - [ ] 17.2 Implement Ed25519 token validation
    - Implement Ed25519 signature verification using PARTY_SESSION_PUBLIC_KEY
    - Extract and validate token claims (roomId, userId, sessionId, exp, iss, aud)
    - Check token expiration
    - Return WebSocket close codes for invalid tokens (4001, 4002, 4003)
    - _Requirements: 4.2, 4.3, 4.4_
    - _Note: This handles authentication/routing errors at Worker entry point. Protocol/application errors are handled in Task 5._

  - [ ] 17.3 Write property test for token validation accepts valid tokens
    - **Property 11: Token Validation Accepts Valid Tokens**
    - **Validates: Requirements 4.2, 4.4**

  - [ ] 17.4 Write property test for token validation rejects invalid tokens
    - **Property 12: Token Validation Rejects Invalid Tokens**
    - **Validates: Requirements 4.3**

  - [ ] 17.5 Write unit tests for Worker entry point
    - Test WebSocket endpoint accepts valid token
    - Test WebSocket endpoint rejects invalid token signature
    - Test WebSocket endpoint rejects expired token
    - Test WebSocket endpoint rejects token with invalid roomId
    - Test internal endpoints require PARTY_INTERNAL_TOKEN
    - Test routing to PartyRegistryDO and PartyRoomDO
    - _Requirements: 1.3, 1.4, 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 18. Checkpoint - Ensure all tests pass
  - Run unit tests for Worker entry point and token validation
  - Run property tests for token validation (accepts valid, rejects invalid)

- [ ] 19. Implement observability and logging
  - [ ] 19.1 Add structured logging for key events
    - Log room creation, join, leave, destruction events
    - Log WebSocket connection and disconnection events
    - Log host transfer events
    - Log rate limit violations
    - Log token validation failures
    - Include roomId, userId, sessionId, eventType, roomVersion in all logs
    - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.6_

  - [ ] 19.2 Add metrics emission
    - Emit metrics for active_rooms (gauge)
    - Emit metrics for active_connections (gauge)
    - Emit metrics for room_joins_total (counter)
    - Emit metrics for room_leaves_total (counter)
    - Emit metrics for host_transfers_total (counter)
    - Emit metrics for room_closures_total (counter)
    - Emit metrics for ws_errors_total (counter)
    - Emit metrics for reconnects_total (counter)
    - Emit metrics for resync_requests_total (counter)
    - _Requirements: 19.5_

- [ ] 20. Checkpoint - Ensure all tests pass
  - Run Worker unit tests, property tests, and integration tests
  - Verify all TypeScript/Cloudflare Workers components are stable

- [ ] 21. Implement Kumoriya API broker client (Go)
  - [ ] 21.1 Create PartyRealtimeBrokerClient in Go
    - Create HTTP client for Party Realtime Service internal endpoints
    - Implement CreateRoom method calling POST /internal/v1/rooms
    - Implement ResolveInviteCode method calling GET /internal/v1/invite/:code
    - Implement JoinRoom method calling POST /internal/v1/rooms/:roomId/join
    - Implement LeaveRoom method calling POST /internal/v1/rooms/:roomId/leave
    - Implement VerifyMember method calling POST /internal/v1/rooms/:roomId/member-verify
    - Add Bearer token authentication with PARTY_INTERNAL_TOKEN
    - Add timeout (10 seconds) and retry logic (2 attempts with exponential backoff)
    - _Requirements: 15.4, 21.3_

  - [ ] 21.2 Integrate broker client into existing API endpoints
    - Update POST /api/v1/party to call broker CreateRoom, sign Session_Token, return roomId, inviteCode, websocketUrl, token
    - Update POST /api/v1/party/join to call broker ResolveInviteCode and JoinRoom, sign Session_Token, return roomId, websocketUrl, token (inviteCode optional for joiner)
    - Update POST /api/v1/party/leave to call broker LeaveRoom (HTTP POST is primary leave mechanism)
    - Sign Session_Token using existing jwt_service.go Ed25519 signing with 60-minute expiration
    - Construct websocketUrl as wss://party.kumoriya.online/ws?token={Session_Token}
    - _Requirements: 2.8, 2.9, 3.10, 3.11, 13.1, 15.1, 15.2, 15.3, 15.6, 15.7, 15.8, 21.1, 21.2, 21.5_

  - [ ] 21.3 Write unit tests for broker client
    - Test CreateRoom calls correct endpoint with correct payload
    - Test ResolveInviteCode calls correct endpoint
    - Test JoinRoom calls correct endpoint with correct payload
    - Test LeaveRoom calls correct endpoint
    - Test VerifyMember calls correct endpoint
    - Test Bearer token authentication
    - Test timeout and retry logic
    - _Requirements: 15.4_

  - [ ] 21.4 Write integration tests for API endpoints
    - Test POST /api/v1/party end-to-end flow
    - Test POST /api/v1/party/join end-to-end flow
    - Test POST /api/v1/party/leave end-to-end flow
    - Test POST /api/v1/party/session/refresh end-to-end flow
    - Test Session_Token signing and claims
    - _Requirements: 2.8, 2.9, 3.10, 3.11, 15.6, 15.7, 21.5_

- [ ] 22. Implement session token refresh endpoint (Go)
  - [ ] 22.1 Implement POST /api/v1/party/session/refresh endpoint
    - **Request**: `POST /api/v1/party/session/refresh` with JSON body `{"roomId": "string"}`
    - **Response**: `{"token": "string", "websocketUrl": "string"}` on success, or error with appropriate status code
    - Validate user authentication credentials
    - Call broker VerifyMember to check user is still in room (active member OR member within reconnect grace)
    - Return error if user is no longer a member
    - Sign new Session_Token with same roomId, userId, sessionId claims and 60-minute expiration
    - Return new token and websocketUrl
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5_

  - [ ] 22.2 Write property test for token claims preservation
    - **Property 10: Token Claims Preservation**
    - **Validates: Requirements 21.5**

  - [ ] 22.3 Write unit tests for session refresh
    - Test refresh validates authentication
    - Test refresh verifies member status
    - Test refresh rejects non-member
    - Test new token has same claims (roomId, userId, sessionId)
    - Test new token has updated expiration
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5_

- [ ] 23. Checkpoint - Ensure all tests pass
  - Run Go unit tests for broker client and API endpoints
  - Run Go integration tests for session refresh flow

- [ ] 24. Update Flutter PartyApiClient DTOs
  - [ ] 24.1 Update PartyApiClient response DTOs
    - Update CreateRoomResponse to include token and websocketUrl fields
    - Update JoinRoomResponse to include token and websocketUrl fields
    - Parse token and websocketUrl from API responses in PartyApiClient
    - Update PartyApiClient method signatures to return complete response objects
    - _Requirements: 2.8, 2.9, 3.10, 3.11, 15.6, 15.7_

  - [ ] 24.2 Write unit tests for PartyApiClient DTOs
    - Test CreateRoomResponse parsing with all fields
    - Test JoinRoomResponse parsing with all fields
    - Test error handling for missing fields
    - _Requirements: 2.8, 2.9, 3.10, 3.11_

- [ ] 25. Implement Flutter PartyRealtimeClient
  - [ ] 25.1 Create PartyRealtimeClient class
    - Implement WebSocket connection to websocketUrl from API
    - Implement automatic reconnection with exponential backoff (up to 5 attempts)
    - Implement heartbeat sending every 25 seconds
    - Implement message parsing for all server→client message types
    - Implement message sending for all client→server message types
    - Implement connection state management (connecting, connected, disconnected, reconnecting)
    - _Requirements: 16.2, 16.3, 17.1, 17.2_

  - [ ] 25.2 Implement reconnection and token refresh logic
    - Detect WebSocket close and start reconnection attempts
    - Implement exponential backoff for reconnection (up to 5 attempts)
    - Detect expired token during reconnection
    - Call POST /api/v1/party/session/refresh to get new token
    - Retry WebSocket connection with new token
    - Display error if reconnection fails after all retries
    - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 21.6_

  - [ ] 25.3 Write unit tests for PartyRealtimeClient
    - Test WebSocket connection establishment
    - Test heartbeat sending
    - Test message parsing for all message types
    - Test message sending for all message types
    - Test reconnection with exponential backoff
    - Test token refresh on expired token
    - Test error handling and display
    - _Requirements: 16.2, 16.3, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6_

- [ ] 26. Implement Flutter PartySessionNotifier
  - [ ] 26.1 Rewrite PartySessionNotifier for server-authoritative state
    - Replace SignalingClient with PartyRealtimeClient
    - Implement state management from server messages (room_snapshot, member_joined, member_left, member_presence_changed, member_ready_changed, playback_state_changed, media_changed, episode_changed, chat_message, reaction_broadcast, host_transferred, room_closed)
    - Derive member list, presence, ready states, hostId, media, playback from server state
    - Remove dependency on P2P connectedPeerIds for lobby readiness
    - Implement playback_intent sending for host actions
    - Replace local state with server snapshot on room_snapshot message
    - _Requirements: 16.1, 16.4, 16.5, 16.6, 16.7, 16.8, 12.8_

  - [ ] 26.2 Write unit tests for PartySessionNotifier
    - Test state updates from room_snapshot
    - Test state updates from member_joined/left
    - Test state updates from member_presence_changed
    - Test state updates from member_ready_changed
    - Test state updates from playback_state_changed
    - Test state updates from media_changed/episode_changed
    - Test state updates from host_transferred
    - Test playback_intent sending (host-only)
    - _Requirements: 16.4, 16.5, 16.6, 16.7, 16.8_

- [ ] 27. Implement Flutter rate limit error handling
  - [ ] 27.1 Add rate limit error display in UI
    - Handle error messages with code=rate_limit_exceeded
    - Display user-friendly message for chat rate limit
    - Display user-friendly message for reaction rate limit
    - Display user-friendly message for playback intent rate limit
    - _Requirements: 18.5_

  - [ ] 27.2 Write widget tests for rate limit error display
    - Test chat rate limit error display
    - Test reaction rate limit error display
    - Test playback intent rate limit error display
    - _Requirements: 18.5_

- [ ] 28. Checkpoint - Ensure all tests pass
  - Run Flutter unit tests for PartyRealtimeClient and PartySessionNotifier
  - Run Flutter widget tests for rate limit error handling
  - Verify all Flutter components are stable before deployment

- [ ] 29. Deploy Party Realtime Service to Cloudflare
  - [ ] 29.1 Configure DNS and deployment
    - Configure DNS for party.kumoriya.online to route through Cloudflare proxy
    - Set up Cloudflare Worker secrets (PARTY_INTERNAL_TOKEN, PARTY_SESSION_PUBLIC_KEY)
    - Deploy Worker using wrangler deploy
    - Verify Worker is accessible at party.kumoriya.online
    - Verify internal endpoints require authentication
    - _Requirements: 1.7, 20.1, 20.2, 20.5_

  - [ ] 29.2 Create deployment documentation
    - Document wrangler.toml configuration
    - Document environment variables and secrets setup
    - Document deployment commands
    - Document DNS configuration
    - Document rollback procedure
    - _Requirements: 20.5_

- [ ] 30. Integration testing and validation
  - [ ] 30.1 Run end-to-end integration tests (minimum required flows)
    - Test complete room creation flow (API → Worker → DO → WebSocket)
    - Test complete join flow (API → Worker → DO → WebSocket)
    - Test reconnection flow with grace period
    - Test token refresh flow
    - _Requirements: All requirements_

  - [ ] 30.2 Run additional end-to-end integration tests (optional)
    - Test host transfer scenarios
    - Test playback synchronization
    - Test chat and reactions
    - Test rate limiting
    - _Requirements: All requirements_

  - [ ] 30.3 Validate observability and monitoring
    - Verify logs are emitted for key events
    - Verify metrics are emitted correctly
    - Verify structured logging includes required fields
    - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6_

- [ ] 31. Decommission old P2P watch party components
  - [ ] 31.1 Remove P2P watch party infrastructure from Flutter client
    - Remove PartySyncEngine class and all references (P2P sync logic)
    - Remove SignalingClient usage for watch party lobby/sync (keep if reusable for future voice chat)
    - Evaluate WebRtcPeerManager: remove if watch-party-specific, refactor if reusable for voice chat
    - Remove P2P-related dependencies from pubspec.yaml only if not needed for future voice chat
    - Update PartySessionNotifier to remove P2P state management
    - Remove connectedPeerIds and P2P connection logic from lobby readiness checks
    - _Requirements: Migration from in-memory to Cloudflare Workers_
    - _Note: Preserve WebRTC infrastructure that can be reused for future voice chat feature_

  - [ ] 31.2 Write migration validation tests
    - Test that old P2P watch party components are no longer referenced
    - Test that new server-authoritative flow works end-to-end
    - _Requirements: Migration validation_

- [ ] 32. Final validation and sign-off

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties across all inputs
- Unit tests validate specific examples, edge cases, and error conditions
- Integration tests validate end-to-end flows across components
- The implementation uses TypeScript for Party Realtime Service, Go for Kumoriya API broker, and Dart/Flutter for client
- Session tokens are signed by Kumoriya API using Ed25519 and validated by Party Realtime Service
- All state is server-authoritative with persistent storage in Durable Objects
- WebRTC signaling infrastructure is prepared but not fully implemented
