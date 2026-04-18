# Requirements Document: Watch Party Realtime Migration

## Introduction

This document specifies the requirements for migrating the watch party system from an in-memory implementation to a dedicated realtime service hosted at `party.kumoriya.online`. The new architecture uses Cloudflare Workers with Durable Objects as the authoritative source for room state, member presence, playback synchronization, and signaling. The system supports up to 4 members per room initially, with reconnection recovery and host authority policies.

## Glossary

- **Kumoriya_API**: The existing REST API service at `api.kumoriya.online` responsible for authentication, profiles, and watch party session ticket issuance
- **Party_Realtime_Service**: The new dedicated realtime service at `party.kumoriya.online` built with Cloudflare Workers and Durable Objects
- **PartyRegistryDO**: Singleton Durable Object managing room creation, invite code resolution, and user-to-room mapping
- **PartyRoomDO**: Per-room Durable Object maintaining authoritative state for membership, presence, playback, and host authority
- **Flutter_App**: The client application consuming watch party functionality
- **Host**: The room member with authority to control playback (play, pause, seek, media change)
- **Session_Token**: A JWT-style token signed and issued by Kumoriya_API (using its Ed25519 jwt_service.go) and validated by Party_Realtime_Service for WebSocket authentication
- **Invite_Code**: A 6-character alphanumeric code used to join an existing room
- **Playback_Intent**: A server-authoritative command representing playback state changes (play, pause, seek, media_change, episode_change, resync_request)
- **Reconnect_Grace_Period**: Time window allowing disconnected members to rejoin without losing their slot
- **WebRTC_Signaling**: Future voice chat signaling channel (prepared but not implemented in this migration)

## WebSocket Message Contract

The following event names are canonical and MUST be used consistently across all requirements, implementation, and client code. No aliases or alternate spellings are permitted.

### Client → Server Messages

| Event name | Description |
|---|---|
| `hello` | Initial handshake message sent after WebSocket connection is established |
| `heartbeat` | Periodic keep-alive sent every 25 seconds |
| `request_snapshot` | Request the current room snapshot |
| `set_ready` | Set the sender's ready state |
| `send_chat` | Send a chat message to the room |
| `send_reaction` | Send a reaction emote to the room |
| `playback_intent` | Host-only playback command (play, pause, seek, media_change, episode_change, resync_request) |
| `leave_room` | Explicit leave notification before disconnecting |
| `webrtc_signal` | WebRTC signaling payload (offer, answer, ICE candidate) |

### Server → Client Messages

| Event name | Description |
|---|---|
| `room_snapshot` | Full room state snapshot (members, presence, ready states, host, media, playback) |
| `member_joined` | A new member has joined the room |
| `member_left` | A member has left the room |
| `member_presence_changed` | A member's connection presence has changed |
| `member_ready_changed` | A member's ready state (effectiveReady) has changed |
| `chat_message` | A chat message broadcast to all members |
| `reaction_broadcast` | A reaction emote broadcast to all members |
| `playback_state_changed` | Authoritative playback state update |
| `media_changed` | The current media identifier has been changed by the host |
| `episode_changed` | The current episode identifier has been changed by the host |
| `host_transferred` | Host authority has been transferred to a new member |
| `room_closed` | The room has been destroyed |
| `ack` | Acknowledgement of a client message |
| `error` | Error response (includes reason code and message) |
| `webrtc_signal` | WebRTC signaling payload routed to target peer |

---

## Message Semantics

### Acknowledgements (`ack`)

- Client messages that modify state (`set_ready`, `send_chat`, `send_reaction`, `playback_intent`, `leave_room`) MUST include a client-provided `messageId` for correlation
- IF a state-modifying message lacks `messageId`, THEN THE PartyRoomDO SHALL reject the message with an `error` with `code=invalid_message`
- These messages SHALL receive an `ack` response on success
- The `ack` message SHALL include the original message's `messageId` for correlation

### Errors (`error`)

- Any client message that fails validation or processing SHALL receive an `error` response
- The `error` message SHALL include:
  - `code`: A string error code (e.g., `rate_limit_exceeded`, `invalid_token`, `unauthorized`, `room_full`, `invalid_invite_code`)
  - `message`: A human-readable error description
  - `retryable`: A boolean indicating whether the client should retry the operation
- Rate limit violations SHALL use `error` with `code=rate_limit_exceeded` and `retryable=true`

### room_snapshot Structure

The `room_snapshot` message SHALL include the following minimal required fields:

- `roomId`: string
- `inviteCode`: string (optional, may be omitted for security)
- `hostId`: string (userId of current host)
- `members`: array of member objects, each containing:
  - `userId`: string
  - `name`: string
  - `presence`: string (connected | disconnected)
  - `effectiveReady`: boolean
  - `joinedAtMs`: number
- `media`: object containing current media identifier:
  - `anilistId`: number (AniList anime ID)
  - `animeTitle`: string (display title)
  - `episodeNumber`: number (current episode number)
- `playback`: object containing:
  - `status`: string (playing | paused)
  - `basePositionMs`: number
  - `effectiveAtMs`: number (server timestamp when this state became effective)
  - `generation`: number (monotonic counter incremented on every play, pause, seek, media_change, episode_change, and resync_request)
- `roomVersion`: number (monotonic counter for any room state change)
- `serverTimeMs`: number (current server timestamp for client drift calculation)

---

## Requirements

### Requirement 1: Dedicated Realtime Service Infrastructure

**User Story:** As a system architect, I want a dedicated realtime service at `party.kumoriya.online`, so that watch party state management is isolated and scalable.

#### Acceptance Criteria

1. THE Party_Realtime_Service SHALL be deployed at `party.kumoriya.online` using Cloudflare Workers
2. THE Party_Realtime_Service SHALL use Durable Objects for authoritative state management
3. THE Party_Realtime_Service SHALL expose a public WebSocket endpoint at `GET /ws`
4. THE Party_Realtime_Service SHALL expose internal HTTP endpoints at `/internal/v1/*` accessible only to Kumoriya_API, including `POST /internal/v1/rooms`, `GET /internal/v1/invite/:code`, `POST /internal/v1/rooms/:roomId/join`, and `POST /internal/v1/rooms/:roomId/leave`
5. THE Party_Realtime_Service SHALL implement PartyRegistryDO as a singleton Durable Object
6. THE Party_Realtime_Service SHALL implement PartyRoomDO as a per-room Durable Object
7. THE Party_Realtime_Service SHALL route DNS for `party.kumoriya.online` through Cloudflare proxy

### Requirement 2: Room Creation and Registration

**User Story:** As a user, I want to create a watch party room, so that I can invite friends to watch together.

#### Acceptance Criteria

1. WHEN Kumoriya_API receives a room creation request, THE Kumoriya_API SHALL call `POST /internal/v1/rooms` on Party_Realtime_Service
2. WHEN PartyRegistryDO receives a room creation request, THE PartyRegistryDO SHALL generate a unique roomId
3. WHEN PartyRegistryDO receives a room creation request, THE PartyRegistryDO SHALL generate a unique inviteCode
4. WHEN PartyRegistryDO creates a room, THE PartyRegistryDO SHALL instantiate a PartyRoomDO for that roomId
5. WHEN PartyRegistryDO creates a room, THE PartyRegistryDO SHALL map the creator userId to the roomId
6. WHEN PartyRoomDO is instantiated, THE PartyRoomDO SHALL set the creator as the initial Host
7. WHEN the creator joins as the first member, THE PartyRoomDO SHALL include the creator in the initial `room_snapshot` sent to the creator
8. WHEN room creation succeeds, THE Kumoriya_API SHALL sign and issue a Session_Token for the creator using its Ed25519 jwt_service.go
9. WHEN room creation succeeds, THE Kumoriya_API SHALL return roomId, inviteCode, and websocketUrl to Flutter_App

### Requirement 3: Room Joining via Invite Code

**User Story:** As a user, I want to join a watch party using an invite code, so that I can watch with my friends.

#### Acceptance Criteria

1. WHEN Kumoriya_API receives a join request with inviteCode, THE Kumoriya_API SHALL call `GET /internal/v1/invite/:code` on Party_Realtime_Service to resolve the inviteCode to a roomId
2. WHEN PartyRegistryDO receives an inviteCode via `GET /internal/v1/invite/:code`, THE PartyRegistryDO SHALL resolve it to a roomId
3. IF inviteCode is invalid, THEN THE PartyRegistryDO SHALL return an error
4. WHEN Kumoriya_API has resolved the roomId, THE Kumoriya_API SHALL call `POST /internal/v1/rooms/:roomId/join` on Party_Realtime_Service with the resolved roomId
5. WHEN PartyRegistryDO receives a join request, THE PartyRegistryDO SHALL verify the user is not already in another room
6. IF a user is already in another room, THEN THE PartyRegistryDO SHALL return an error
7. WHEN PartyRoomDO receives a join request, THE PartyRoomDO SHALL verify the room has fewer than 4 members
8. IF the room is full, THEN THE PartyRoomDO SHALL return an error
9. WHEN a new member joins successfully, THE PartyRoomDO SHALL broadcast a `member_joined` message to all connected members except the new joiner
10. WHEN join succeeds, THE Kumoriya_API SHALL sign and issue a Session_Token for the joining user using its Ed25519 jwt_service.go
11. WHEN join succeeds, THE Kumoriya_API SHALL return roomId and websocketUrl to Flutter_App

### Requirement 4: WebSocket Connection and Authentication

**User Story:** As a user, I want to connect to the realtime service securely, so that my watch party session is authenticated.

#### Acceptance Criteria

1. WHEN Flutter_App connects to `GET /ws`, THE Flutter_App SHALL include the Session_Token as a query parameter
2. WHEN Party_Realtime_Service receives a WebSocket connection, THE Party_Realtime_Service SHALL validate the Session_Token signed by Kumoriya_API
3. IF Session_Token is invalid or expired, THEN THE Party_Realtime_Service SHALL close the connection with a WebSocket close code and reason: `invalid_token` (token signature invalid or malformed), `expired_token` (token past expiration time), or `room_not_found` (roomId in token does not exist)
4. WHEN Session_Token is valid, THE Party_Realtime_Service SHALL extract roomId and userId from the token
5. WHEN Session_Token is valid, THE Party_Realtime_Service SHALL route the connection to the appropriate PartyRoomDO
6. WHEN PartyRoomDO accepts a connection, THE PartyRoomDO SHALL add the socket to its active connections registry
7. WHEN a connection is established, THE PartyRoomDO SHALL send a `room_snapshot` message to the client

### Requirement 5: Member Presence and Heartbeat

**User Story:** As a user, I want the system to track who is actively connected, so that I know who is present in the watch party.

#### Acceptance Criteria

1. THE Flutter_App SHALL send a `heartbeat` message every 25 seconds
2. WHEN PartyRoomDO receives a heartbeat, THE PartyRoomDO SHALL update the member's lastHeartbeatMs timestamp
3. WHEN a member's connection closes, THE PartyRoomDO SHALL mark the member as disconnected
4. WHEN a member disconnects, THE PartyRoomDO SHALL start a reconnect grace period of 120 seconds for non-host members
5. WHEN the Host disconnects, THE PartyRoomDO SHALL start a reconnect grace period of 60 seconds
6. WHEN a member reconnects within the grace period, THE PartyRoomDO SHALL restore their membership status
7. IF a member does not reconnect within the grace period, THEN THE PartyRoomDO SHALL remove the member from the room
8. WHEN member presence changes, THE PartyRoomDO SHALL broadcast a `member_presence_changed` message to all connected members
9. WHEN a member's reconnect grace period expires without reconnection, THE PartyRegistryDO SHALL remove the userId-to-roomId mapping for that member

### Requirement 6: Host Authority and Transfer

**User Story:** As a host, I want exclusive control over playback, so that the watch party stays synchronized.

#### Acceptance Criteria

1. THE PartyRoomDO SHALL designate exactly one member as the Host at all times
2. WHEN a non-host member sends a `playback_intent` message, THE PartyRoomDO SHALL reject the message
3. WHEN the Host sends a `playback_intent` message, THE PartyRoomDO SHALL accept and process the intent
4. WHEN the Host disconnects and reconnects within 60 seconds, THE PartyRoomDO SHALL restore Host authority to the original Host
5. IF the Host does not reconnect within 60 seconds and the room is not empty, THEN THE PartyRoomDO SHALL transfer Host authority to the oldest connected member
6. WHEN Host authority is transferred, THE PartyRoomDO SHALL broadcast a `host_transferred` message to all connected members
7. WHEN a room becomes empty, THE PartyRoomDO SHALL start a 15-minute empty room TTL timer
8. IF the room remains empty for 15 minutes, THEN THE PartyRoomDO SHALL destroy the room
9. WHEN a room is destroyed after the empty room TTL, THE PartyRegistryDO SHALL remove all userId-to-roomId mappings for that room's members

### Requirement 7: Ready State Management

**User Story:** As a user, I want to signal when I'm ready to start watching, so that the host knows when everyone is prepared.

#### Acceptance Criteria

1. WHEN a member sends a `set_ready` message, THE PartyRoomDO SHALL update the member's `readyPersisted` value and set `effectiveReady` to the new value
2. WHEN a member's `effectiveReady` changes, THE PartyRoomDO SHALL broadcast a `member_ready_changed` message to all connected members
3. WHEN a member disconnects, THE PartyRoomDO SHALL set `effectiveReady` to false while preserving the member's `readyPersisted` value
4. WHEN a member reconnects within the grace period, THE PartyRoomDO SHALL restore `effectiveReady` from `readyPersisted`
5. THE `room_snapshot` and `member_ready_changed` messages SHALL reflect `effectiveReady`, not `readyPersisted`

### Requirement 8: Server-Authoritative Playback Synchronization

**User Story:** As a host, I want to control playback (play, pause, seek), so that all members watch in sync.

#### Acceptance Criteria

1. WHEN the Host sends a `playback_intent` with action `play`, THE PartyRoomDO SHALL update the authoritative playback state to playing
2. WHEN the Host sends a `playback_intent` with action `pause`, THE PartyRoomDO SHALL update the authoritative playback state to paused
3. WHEN the Host sends a `playback_intent` with action `seek`, THE PartyRoomDO SHALL update the authoritative playback position
4. WHEN PartyRoomDO updates playback state, THE PartyRoomDO SHALL record effectiveAtMs as the server timestamp
5. WHEN PartyRoomDO updates playback state, THE PartyRoomDO SHALL increment the playback generation counter
6. WHEN PartyRoomDO updates playback state, THE PartyRoomDO SHALL broadcast a `playback_state_changed` message to all connected members
7. THE PartyRoomDO SHALL NOT continuously publish currentTime updates
8. WHEN a client detects drift exceeding a threshold, THE Flutter_App SHALL send a `resync_request` playback_intent
9. WHEN PartyRoomDO receives a `resync_request`, THE PartyRoomDO SHALL broadcast the current authoritative playback state

### Requirement 9: Media and Episode Change

**User Story:** As a host, I want to change the current media or episode, so that the watch party can progress through content.

#### Acceptance Criteria

1. WHEN the Host sends a `playback_intent` with action `media_change`, THE PartyRoomDO SHALL update the current media identifier
2. WHEN the Host sends a `playback_intent` with action `episode_change`, THE PartyRoomDO SHALL update the current episode identifier
3. WHEN media or episode changes, THE PartyRoomDO SHALL reset the playback position to 0
4. WHEN media or episode changes, THE PartyRoomDO SHALL reset all member ready states to false
5. WHEN media changes, THE PartyRoomDO SHALL broadcast a `media_changed` message to all connected members
6. WHEN episode changes, THE PartyRoomDO SHALL broadcast an `episode_changed` message to all connected members

### Requirement 10: Chat Messaging

**User Story:** As a user, I want to send chat messages to other watch party members, so that we can communicate during playback.

#### Acceptance Criteria

1. WHEN a member sends a `send_chat` message, THE PartyRoomDO SHALL validate the message content is not empty
2. WHEN a member sends a `send_chat` message, THE PartyRoomDO SHALL enforce a rate limit of 10 messages per 10 seconds per user
3. IF a member exceeds the rate limit, THEN THE PartyRoomDO SHALL reject the message
4. WHEN a valid chat message is received, THE PartyRoomDO SHALL broadcast a `chat_message` to all connected members with sender metadata
5. THE PartyRoomDO SHALL NOT persist chat message history beyond the current session

### Requirement 11: Reaction Emotes

**User Story:** As a user, I want to send reaction emotes during playback, so that I can express emotions without interrupting the experience.

#### Acceptance Criteria

1. WHEN a member sends a `send_reaction` message, THE PartyRoomDO SHALL validate the reaction type is in the allowed set: `like`, `love`, `laugh`, `surprise`, `sad`, `angry`
2. WHEN a member sends a `send_reaction` message, THE PartyRoomDO SHALL enforce a rate limit of 5 reactions per 5 seconds per user
3. IF a member exceeds the rate limit, THEN THE PartyRoomDO SHALL reject the reaction
4. WHEN a valid reaction is received, THE PartyRoomDO SHALL broadcast a `reaction_broadcast` message to all connected members with sender metadata
5. THE PartyRoomDO SHALL NOT persist reaction history

### Requirement 12: Room Snapshot and State Recovery

**User Story:** As a user, I want to receive the current room state when I connect or reconnect, so that I can see the latest status immediately.

#### Acceptance Criteria

1. WHEN a member connects to PartyRoomDO, THE PartyRoomDO SHALL send a `room_snapshot` message
2. THE `room_snapshot` message SHALL include the complete member list with presence and ready states
3. THE `room_snapshot` message SHALL include the current Host identifier
4. THE `room_snapshot` message SHALL include the current media and episode identifiers
5. THE `room_snapshot` message SHALL include the current playback state (playing/paused, position, effectiveAtMs)
6. THE `room_snapshot` message SHALL conform to the structure defined in the Message Semantics section
7. WHEN a member reconnects after disconnection, THE PartyRoomDO SHALL send an updated `room_snapshot` message
8. THE Flutter_App SHALL replace local state with the received snapshot to ensure consistency

### Requirement 13: Room Leave and Cleanup

**User Story:** As a user, I want to leave a watch party cleanly, so that my slot is freed for others.

#### Acceptance Criteria

1. WHEN Kumoriya_API receives a leave request, THE Kumoriya_API SHALL call `POST /internal/v1/rooms/:roomId/leave` on Party_Realtime_Service
2. WHEN PartyRoomDO receives a leave request, THE PartyRoomDO SHALL remove the member from the room
3. WHEN a member leaves, THE PartyRoomDO SHALL close the member's WebSocket connection
4. WHEN a member leaves, THE PartyRoomDO SHALL broadcast a `member_left` message to remaining members
5. IF the leaving member is the Host and other members remain, THEN THE PartyRoomDO SHALL transfer Host authority to the oldest remaining member
6. WHEN PartyRegistryDO is notified of a member leaving, THE PartyRegistryDO SHALL remove the userId-to-roomId mapping

### Requirement 14: WebRTC Signaling Preparation (Voice Chat)

**User Story:** As a developer, I want WebRTC signaling infrastructure prepared, so that voice chat can be added in the future without architectural changes.

#### Acceptance Criteria

1. THE Party_Realtime_Service SHALL accept `webrtc_signal` messages from clients
2. WHEN PartyRoomDO receives a `webrtc_signal` message, THE PartyRoomDO SHALL route the signal to the target peer specified in the message
3. THE PartyRoomDO SHALL NOT implement WebRTC peer connection logic
4. THE PartyRoomDO SHALL NOT implement audio track handling
5. THE Flutter_App SHALL NOT implement getUserMedia, RTCPeerConnection, or audio UI in this migration
6. THE `webrtc_signal` message contract SHALL support offer, answer, and ICE candidate payloads

### Requirement 15: Kumoriya API Broker Migration

**User Story:** As a backend developer, I want Kumoriya_API to act as a broker to Party_Realtime_Service, so that authentication and session management remain centralized.

#### Acceptance Criteria

1. THE Kumoriya_API SHALL maintain existing public endpoints: `POST /api/v1/party`, `POST /api/v1/party/join`, `POST /api/v1/party/leave`, `GET /api/v1/party/me`, `GET /api/v1/party/invite/:code`, `POST /api/v1/party/session/refresh`
2. WHEN Kumoriya_API receives a party request, THE Kumoriya_API SHALL validate user authentication
3. WHEN authentication succeeds, THE Kumoriya_API SHALL call the corresponding Party_Realtime_Service internal endpoint
4. THE Kumoriya_API SHALL implement a PartyRealtimeBrokerClient for internal communication with Party_Realtime_Service
5. THE Kumoriya_API SHALL NOT use in-memory PartyService, SignalRelay, or PartySignalHandler after migration
6. THE Kumoriya_API SHALL be the trust root for Session_Token signing, using its Ed25519 jwt_service.go; Party_Realtime_Service SHALL only validate tokens, never issue them
7. WHEN Party_Realtime_Service returns a successful response, THE Kumoriya_API SHALL sign and include a Session_Token in the response to Flutter_App
8. THE Kumoriya_API SHALL construct websocketUrl as `wss://party.kumoriya.online/ws?token={Session_Token}`

### Requirement 16: Flutter Client Migration

**User Story:** As a mobile developer, I want Flutter_App to use the new server-authoritative flow, so that watch party state is consistent and reliable.

#### Acceptance Criteria

1. THE Flutter_App SHALL replace SignalingClient with PartyRealtimeClient
2. THE PartyRealtimeClient SHALL connect to the websocketUrl provided by Kumoriya_API
3. THE PartyRealtimeClient SHALL send heartbeat messages every 25 seconds
4. THE PartyRealtimeClient SHALL handle incoming messages: `room_snapshot`, `member_joined`, `member_left`, `member_presence_changed`, `member_ready_changed`, `playback_state_changed`, `media_changed`, `episode_changed`, `chat_message`, `reaction_broadcast`, `host_transferred`, `room_closed`
5. THE Flutter_App SHALL rewrite PartySessionNotifier to use server-authoritative state
6. THE PartySessionNotifier SHALL derive member list, presence, ready states, hostId, media, and playback state from server messages
7. THE Flutter_App SHALL NOT depend on P2P connectedPeerIds for lobby readiness
8. WHEN the Host sends a playback command, THE Flutter_App SHALL send a `playback_intent` message to Party_Realtime_Service

### Requirement 17: Reconnection and Error Handling

**User Story:** As a user, I want automatic reconnection when my connection drops, so that I don't lose my watch party session.

#### Acceptance Criteria

1. WHEN the WebSocket connection closes unexpectedly, THE Flutter_App SHALL attempt to reconnect using the same Session_Token
2. THE Flutter_App SHALL retry reconnection with exponential backoff up to 5 attempts
3. IF reconnection succeeds within the grace period, THEN THE PartyRoomDO SHALL restore the member's session
4. IF reconnection fails after all retries, THEN THE Flutter_App SHALL display an error and return to the lobby
5. WHEN the Session_Token expires during reconnection, THE Flutter_App SHALL call `POST /api/v1/party/session/refresh` on Kumoriya_API to obtain a new Session_Token before retrying the WebSocket connection
6. WHEN a connection error occurs, THE Flutter_App SHALL display a user-friendly error message indicating the failure reason

### Requirement 18: Rate Limiting and Abuse Prevention

**User Story:** As a system administrator, I want rate limiting on user actions, so that the service is protected from abuse.

#### Acceptance Criteria

1. THE PartyRoomDO SHALL enforce a rate limit of 10 chat messages per 10 seconds per user
2. THE PartyRoomDO SHALL enforce a rate limit of 5 reactions per 5 seconds per user
3. THE PartyRoomDO SHALL enforce a rate limit of 10 playback intents per 10 seconds per host
4. IF a rate limit is exceeded, THEN THE PartyRoomDO SHALL reject the message and send an `error` message with `code=rate_limit_exceeded` and `retryable=true`
5. THE Flutter_App SHALL display a user-friendly message when rate limits are exceeded

### Requirement 19: Monitoring and Observability

**User Story:** As a system operator, I want logging and metrics for the realtime service, so that I can monitor health and diagnose issues.

#### Acceptance Criteria

1. THE Party_Realtime_Service SHALL log room creation, join, leave, and destruction events
2. THE Party_Realtime_Service SHALL log WebSocket connection and disconnection events
3. THE Party_Realtime_Service SHALL log host transfer events
4. THE Party_Realtime_Service SHALL log rate limit violations
5. THE Party_Realtime_Service SHALL emit metrics for active rooms, active connections, and message throughput
6. THE Party_Realtime_Service SHALL log errors with sufficient context for debugging

### Requirement 20: Configuration and Deployment

**User Story:** As a DevOps engineer, I want the realtime service to be configurable and deployable via standard tooling, so that I can manage it consistently.

#### Acceptance Criteria

1. THE Party_Realtime_Service SHALL be configured via environment variables or Cloudflare Worker secrets
2. THE Party_Realtime_Service SHALL use Wrangler for deployment
3. THE Party_Realtime_Service SHALL define routes for `party.kumoriya.online/*` in wrangler.toml
4. THE Party_Realtime_Service SHALL use TypeScript for type safety
5. THE Party_Realtime_Service SHALL include a README with setup and deployment instructions
6. THE Party_Realtime_Service SHALL be deployed independently of Kumoriya_API

### Requirement 21: Session Token Refresh

**User Story:** As a user, I want to refresh my session token when it expires during reconnection, so that I can rejoin my watch party without losing my slot.

#### Acceptance Criteria

1. THE Kumoriya_API SHALL expose `POST /api/v1/party/session/refresh` for session token renewal
2. WHEN Kumoriya_API receives a refresh request, THE Kumoriya_API SHALL validate the user's authentication credentials
3. WHEN Kumoriya_API receives a refresh request, THE Kumoriya_API SHALL verify the user is still an active member of the room via Party_Realtime_Service
4. IF the user is no longer a member of the room, THEN THE Kumoriya_API SHALL return an error indicating the session cannot be refreshed
5. WHEN validation succeeds, THE Kumoriya_API SHALL sign and issue a new Session_Token using its Ed25519 jwt_service.go
6. WHEN Flutter_App reconnects with an expired Session_Token, THE Flutter_App SHALL call `POST /api/v1/party/session/refresh` before retrying the WebSocket connection
